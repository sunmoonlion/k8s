# 已签发入口证书的统一消费

目标：一套平台部署代码、KIND/kubeadm 两种建集群方式。CA、叶证书签发和轮换独立于建集群；集群只接收明确指定的服务证书。Harbor 仍在集群外，地址和原 CA 保留。

**云上未经实机验证。** 本次改写 step12，新增可供两种适配器调用的 `materials/tls_resources.py`。当前只有云端入口接通；KIND 适配、正式签发五年叶证书和入口握手验收尚待完成。没有生成/替换任何现场证书，没有连接云主机或 Kubernetes API。

## 从旧调用链移出的动作

旧 step12 默认调用 `utils/unified-cert-secret-management/deploy-all.sh`；force 能删除原 CA，rotate/force 还能顺带操作其他集群。旧检查在缺配置、缺文件或 SSH 失败时可能跳过并返回成功。

新 step12 不调用上述入口。旧证书工具保留，不能作为新版基础设施步骤的隐式后备。保留 `step12_ca_generation.sh` 文件名兼容总控标识，菜单说明已经改为“校验并安装已签发入口证书”。私有覆盖若仍开启 `STEP12_FORCE_REGENERATE`、`STEP12_CA_ROTATE` 或填有 `STEP12_ADDITIONAL_CLUSTERS`，会明确拒绝。

## 配置与命令

```bash
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step12_ca_generation.sh --dry-run
CLUSTER=C2 bash sunmoonai/infrastructure/steps/step12_ca_generation.sh --dry-run
```

省略动作也只打印；不会读取证书描述文件、私钥或联系节点。只有后续准入完成，才运行 `--apply` 或 `--verify`。两者均需完整锁、物料 SHA、已登记主机/集群身份和明确的仓库 profile。目前总闭包仍为 false，不能开放实际总控。

| 配置 | 用途 |
| --- | --- |
| `STEP12_ENABLED` | 明确开启/关闭 |
| `STEP12_TARGET` | 固定 master；由已登记 master 的 root 私有 admin.conf 调用 API |
| `STEP12_TLS_BUNDLE_FILE` | Git 外私有 JSON 描述文件；可通过 C1/C2 前缀或既有私有覆盖指定 |
| `REGISTRY_CONFIG_FILE` | 原 CA 的公开文件和 SHA 来源，与 step11 保持同一信任输入 |

描述文件示例（只描述位置，不能把证书私钥正文放进 Git）：

```json
{
  "schema": 1,
  "certificates": [
    {
      "namespace": "ingress-platform-dev",
      "name": "traefik-tls-secret",
      "certificate_file": "~/private/registry-platform/ingress/fullchain.pem",
      "certificate_sha256": "填写该证书链文件的64位SHA256",
      "private_key_file": "~/private/registry-platform/ingress/tls.key",
      "dns_names": ["sunmoonai.com", "*.sunmoonai.com"]
    }
  ]
}
```

描述文件及私钥须位于 Git 检出目录以外，所有者为执行用户或 root，其他用户无权限（通常0600/0400）。路径可用 `~`，不展开 `$HOME`、命令或任意 Shell 表达式；拒绝符号链接、非普通文件、过大文件和其他用户可写输入。证书链文件另有 SHA 固定。允许明确配置 dev/prod 两个入口命名空间各一份；不自动跨环境复制。描述文件准备由后续签发/正式部署单元完成，本次没有创建真实私有输入。

## 校验与创建顺序

1. SSH 前核完整物料闭包和身份，读取描述文件及输入，公开 CA 只从已明确指定的仓库 profile 获取。没有根 CA 私钥输入。
2. 管理机核 PEM 格式、证书文件 SHA、叶证书不是 CA、SAN 包含根域和一级通配域、剩余有效期至少24小时、私钥匹配。
3. 使用 OpenSSL 3 的指定 CA（关闭默认 CA 路径/存储）、sslserver 用途、auth_level 2、域名和当前有效期校验证书链。私钥经 stdin 交 OpenSSL，不进入 argv、环境或临时文件；临时目录只放公开证书并在结束清理。
4. 通过原有严格 SSH 发布公共程序；证书请求仅到已登记 master。目标再次做同样的密码学校验；每次 API 请求前复核 kube-system UID 和 kubeadm CA，核节点身份。
5. 先核全部目标 Namespace 属于本集群、处于 Active，再检查所有现有 Secret。只有缺失对象可以创建；现有对象必须归属标签、证书/CA摘要注解、type 和完整 data 都一致，否则停止，不接管、不覆盖、不删除。
6. 创建标准 `kubernetes.io/tls` Secret，data 为 `tls.crt`、`tls.key`、`ca.crt`；通过 stdin 传给 kubectl。创建后重读并精确比较。

`--verify` 在缺失 Secret 时失败，不补建。SSH 程序仍发布公开代码、保留 root 私有请求与审计收据，所以不是全主机零写。请求文件位于 `/var/lib/sunmoon/requests/<代码摘要>/`，0600，含服务叶证书私钥；必须按凭据保护，不能复制进一般日志/证据/代码库。TLS 分支的错误日志不记录 kubectl/OpenSSL stderr、Secret 正文或私钥，终端只报告安全的阶段错误。

本单元不更改 kubeadm CA/证书期限，不签发 CA 或服务证书，不重启 Docker、containerd、Traefik 或 Harbor。匹配的 Secret 可以重复检查；要更换已安装证书，必须走后续明确的续签/轮换流程，不能借安装覆盖现有 Secret。

## 边界与首次实际部署清单

- 五年叶证书的签发尚未完成；原 CA 的有效期必须覆盖计划期限。此消费者只检查传入证书当前有效并至少剩24小时，不声称已签发五年证书。
- 本次没有读取真实私钥或运行实际证书链/密钥匹配验证；静态检查和 OpenSSL 选项存在性检查不能代替密码学输入验收。
- 新集群须明确 Secret 的存储加密、etcd/备份保护和 RBAC，按生产准入验收；该单元不把 base64 当作加密，也没有配置存储加密。
- 首次云部署先核时间同步、实际 CA 指纹和签发输入，再运行缺项创建，确认 Secret 标签/摘要。已有 Secret 不符时保留现场，不用 force 修复。
- step13 须消费同 namespace 的 `traefik-tls-secret` 并验实际 TLS 握手；Secret 字节相同不代表入口链路已经使用它。
- KIND 调用须走同一资源函数并绑定明确 kubeconfig/kubectl/UID；此适配尚未接通，不可将云端主机程序直接用于 WSL。
- Harbor 叶证书与入口叶证书由各自明确输入管理；本步骤只创建入口 Secret，不负责 Harbor 启停或证书替换。

格式与验证依据：[Kubernetes TLS Secret](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)、[OpenSSL 3 验证选项](https://docs.openssl.org/3.0/man1/openssl-verification-options/)。API 校验类型和键名不能代替证书链/私钥匹配检查，因此这些检查在两端执行。

## 本次证据与回退

`sunmoonai/scripts/results/luna-tls-consumer.20260927.json`：4 个 Python AST 和远端 payload、3 个 Shell 的 bash -n/ShellCheck、主 conf bash -n、C1/C2 的 step01–12 共24组只打印演练、129 文件1,236,303,984字节 SHA 核对通过。本机 OpenSSL help 确认所用选项存在。未添加/运行测试套件。

主配置仅 Step12 尾部改动，其前所有字节私下比较相同。平台版本、物料、现场服务、旧节点及卷不变。本轮没有需要恢复的服务变更；代码回退不能用于绕开闭包门禁运行旧 force 路径。后续实际创建中断时，保留已创建 Secret，只有同输入/同归属才能续行。

规则核对：C-I8 配错拒绝；C-D1 不重建/覆盖现有证书真源；C-R1 代码、物料锁、公开证书摘要与明确集群身份共同约束执行。主锁继续关闭，step13、仓库正式生命周期及前置步骤、KIND/平台接线与最终验收仍待完成；最终清理照旧最后执行。
