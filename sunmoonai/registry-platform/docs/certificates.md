# 原 CA 下的五年服务证书

目标：一套部署代码、两种建群方式。签发在管理机完成，部署端只消费叶证书与公有 CA；本地和云端使用相同的证书校验与 Secret 创建实现。云上分发和安装**未经实机验证**。

后续更新：新宿主实例已使用Harbor叶证书在18443完成实际TLS握手及只读镜像验收，然后停止；原30443未替换，Traefik叶尚未安装。见[宿主实例记录](host-instance.md)。

## 本次结果

2026-09-27 已签发，未安装、未重启服务、未切换入口：

| 用途 | SAN | 到期日（UTC） | 证书 SHA256 |
| --- | --- | --- | --- |
| Harbor HTTPS | `harbor.sunmoonai.com` | 2031-09-27 10:05:21 | `e2700dc171e2e0a2d9f028d7d4fcab35e1af717e67ac19d71414af41e7be5b03` |
| Traefik 入口 | `sunmoonai.com`、`*.sunmoonai.com` | 2031-09-27 10:05:21 | `b5a2ef29f1c4eeb68c9dd1865c32b5dca8cb969a3b5e1e14c02e663fdfd081ea` |

原 SunMoonAI Root CA 到期日 2036-05-07 07:48:53 UTC，文件 SHA256 为 `30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec`，未轮换。签发前后原 CA 证书及私钥逐字节一致。Harbor 内部令牌签名证书、core 加密密钥不是这里的 HTTPS 叶证书，本次未改变。

实际批次：`/home/zymun/private/registry-platform/tls-20260927-five-year`，目录 0700、文件 0600，不在 Git 中。Harbor 与入口分别使用 RSA4096 密钥；dev/prod 的入口描述符引用同一份入口证书，用于各自集群上的同名域名。公有 CA 可分发给客户端，**CA 私钥只留在原签发位置**，服务私钥只送其服务端，不能装进 Docker 客户端信任目录。

[公开验收记录](../../scripts/results/luna-five-year-certificates.20260927.json) 包含 OpenSSL 的链、用途、主机名校验、私钥配对和真实 step12 输入校验结果。API/真实握手/客户端兼容性验收尚未执行，不能把离线校验写成部署成功。

## 重复方法

以下从 `k8s` 根目录运行。已有批次只读复核，不能重复签发覆盖：

```bash
python3 -B sunmoonai/registry-platform/certificates.py check \
  --output "$HOME/private/registry-platform/tls-20260927-five-year" \
  --ca-sha256 30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec \
  --minimum-days 90
```

准备新的批次时，指定新的绝对路径及受保护的原 CA 输入。`issue` 默认只打印，不读取 CA 私钥；`--apply` 才签发。输出父目录必须已存在、本人所有且为 0700；输出及其父路径不允许 symlink/组或其他用户可写，不允许位于 Git 下。示例以本次原 CA 位置为准，后续先复核管理机路径：

```bash
python3 -B sunmoonai/registry-platform/certificates.py issue \
  --output "$HOME/private/registry-platform/tls-NEW-BATCH" \
  --ca-cert "$HOME/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt" \
  --ca-key "$HOME/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.key" \
  --ca-sha256 30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec
```

复核计划后，同一命令增加 `--apply`。CA 必须覆盖未来五个日历年，否则停止，不自动续 CA；失败时保留 staging 排查，不删除后盲目重试。当前管理机使用 Python3、cryptography41.0.7、OpenSSL；这些管理工具尚未归入云端系统离线依赖闭包，不能据此宣称新管理机可完全离线签发。

## 使用方

旧 Traefik 主入口转发、Secret 总控、TLS Secret 安装与 server-cert 生成脚本及三个专属配置已移入
[云端历史目录](../../../legacy/cloud/README.md)，原路径不留转发或可执行副本。
普通部署不再通过这些入口重新签发证书。此处记录的原 CA 位置、五年证书批次和现场 Secret 均未移动/删除；
归档源代码不能作为允许清理 CA/私钥目录的依据。通用证书组合分发工具仍需独立审阅，非当前安装入口。

`config/local-wsl.conf` 已指向本次批次，并锁定 CA SHA；这些配置引用不触发安装。`config/cloud.example.conf` 保留空的显式叶证书/私钥/描述符字段，未来由管理机准备云端输入，不会自动复制本机签发私钥。

统一入口（默认只打印）：

```bash
bash sunmoonai/registry-platform/deploy-certificates.sh --cluster KIND --dry-run
bash sunmoonai/registry-platform/deploy-certificates.sh --cluster C1 --dry-run
bash sunmoonai/registry-platform/deploy-certificates.sh --cluster C2 --dry-run
```

KIND 实施时还要给 `--kubectl`、`--kubeconfig`、`--expected-uid`，可用 `--ca-file`、`--ca-sha256`、`--tls-bundle` 明确覆盖本地配置引用。禁止使用当前旧集群代替尚未创建的正式 main。云端沿用 step12 的显式主机/集群身份；`STEP12_TLS_BUNDLE_FILE` 优先，其次读取仓库主机配置的 `REGISTRY_TLS_BUNDLE_FILE`。

两适配器调用同一 `tls_resources.execute`：校验链/用途/域名/私钥/公有 CA 摘要、目标 namespace 所有权和 cluster UID，预检已有 Secret；缺失才创建，相异则停止，不覆盖或接管。`--verify` 不补建。KIND 的 TLS 与入口适配器共用 `local_cluster.py`，检查固定版本 kubectl、私有 kubeconfig 字节不变、HTTPS API、静态凭据、每次请求前集群 UID。主物料闭包尚未完成，`--apply/--verify` 仍在访问 API 前被门禁挡住，不绕过。

## 后续维护和回退

- 五年有效期按所有者决定实施；每次部署/维护先 `check --minimum-days 90`，证书到期提醒的定时任务尚未安装。业务客户端还需做实际握手验收。
- 安装由 Harbor 正式准备流程和集群 TLS 消费流程分别完成。SNI 代理只透传，不持有服务私钥。
- 原服务证书和恢复演练副本保留。正式切换前记录证书 SHA、使用方、原配置和回退位置；不能把改 profile 当成所有客户端已经更新。
- 泄露时停止使用该服务叶密钥，重新生成独立新批次并更新服务；不要重新使用泄露密钥。内部 CA/客户端是否配置 CRL/OCSP 另行核实，不能承诺旧证书已自动吊销。
- 证书批次随 `~/private` 纳入加密机器外备份接口；机器外落点仍待所有者确定，未上传任何私钥。

规则：C-I8 配置冲突拒绝；C-R1/R2 固定版本与公开摘要；C-T5 仅本地 luna 交付，不 push。
