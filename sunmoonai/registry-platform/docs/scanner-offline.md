# Trivy 原版本迁移与离线数据库

本次复用原 Harbor 扫描器程序，另行更新漏洞数据库。范围仅为扫描器物料与隔离验收；**尚未将 Trivy 接入新宿主 Harbor，不能据此认为 Jobservice、扫描登记或 CI/CD 已恢复。**

## 为什么可以复用旧镜像

本次按原版本搬迁 Harbor 2.13.2。旧 StatefulSet `cicd-platform-dev/sunmoonai-harbor-trivy` 实际为 `bitnami/harbor-adapter-trivy:2.13.2-debian-12-r2`，Pod 在 `kind-worker2`、Ready、重启数0。原镜像仍可从已固定 SHA 的冷备物料恢复，不必重新下载可变 tag。它与 Kubernetes 节点镜像、Calico 及容器运行时的升级是不同范围。

复用不意味着该镜像没有漏洞或适合无限期使用。实际程序 `trivy --version` 为 **0.64.1**；adapter 元数据却报告 `dev/Unknown`，因此保留精确 image index、amd64 manifest 和 config 三项摘要，不能只依赖版本展示。源归档与当前运行镜像一致性已核验，尚未独立验证发布者签名。

原 Trivy 的实际缓存 `/bitnami/harbor-adapter-trivy/.cache` 只有空目录，约12KiB。两份冷备 `trivy.tar` / `trivy-active.tar` 各10KiB，未包含漏洞数据库。旧 Pod Ready、元数据接口可访问，**均不能证明它已经成功扫描过镜像**。不在旧环境提交扫描或下载任务。

旧 release 标签实际为 `app.kubernetes.io/instance=sunmoonai`。以后沿 Pod→PVC→PV 核对，不能用猜测的 `sunmoonai-harbor` 标签判断资源不存在。

## 已准备的原镜像

- 源：`releases/harbor-preserve-20260926/preparation/images/kind-worker2-harbor-amd64.tar`，SHA `eef8fa55e3847e351c1989ccd675c5de4606ca2ee2ed00efc966e27c434b0c61`。
- 新物料：`~/packages-to-be-installed/releases/harbor-trivy-2.13.2-original-linux-amd64/trivy-linux-amd64.tar`，97,976,320字节，SHA `2232799c70feb49731350f872af70e0c33fae320b9a2189b473d146c6d4392c1`。
- amd64 manifest：`sha256:7c973faed0944ae77350605ea85d5a9d592fd1258e5bd0ad6f3feb701f826d1e`；完整记录 [scanner-image.lock.json](../scanner-image.lock.json)。宿主 Docker 已导入该摘要，UID1001、无声明卷。

从 `k8s` 根执行，默认只打印；准备只接受全新的输出目录，失败产物保留。所有 OCI 内容按原 descriptor 校验，不执行归档中的程序：

```bash
python3 -B sunmoonai/registry-platform/prepare_scanner.py \
  --source /home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/preparation/images/kind-worker2-harbor-amd64.tar \
  --root /home/zymun/packages-to-be-installed/releases/harbor-trivy-2.13.2-original-linux-amd64
```

本批已经执行过 `--apply`，不要再次对同目录准备。加载前先核对归档 SHA，再用 `docker load --input`；运行必须固定 manifest ID，不用 tag 跟随变化。

## 数据库准备方法

[Trivy 0.64 官方离线说明](https://trivy.dev/v0.64/docs/advanced/air-gap/)区分漏洞库、Java索引和可能的外部网络请求。[数据库自托管说明](https://trivy.dev/v0.64/docs/advanced/self-hosting/)要求持续更新数据库，并说明这类 OCI 数据层不是普通容器镜像层。

`prepare_scanner_db.py` 只访问官方 GHCR 的两个公开数据库：`aquasecurity/trivy-db:2`、`aquasecurity/trivy-java-db:1`。这里2/1是数据库格式版本，不是程序版本。`resolve`先把 tag 解析为固定 manifest；`download`只按固定 descriptor 下载，`verify`逐字节核验压缩文件、内部数据库与元数据，拒绝额外文件/链接/异常大小。无需 Docker 拉取或解包镜像。匿名短期 token 仅在内存和 curl stdin，不进入命令行、文件或日志。

每批独立目录，更新时新建下一批，不能原地刷新旧锁：

```bash
# 在获授权的东京下载机执行；默认只打印，加 --apply 才查询/下载。
python3 prepare_scanner_db.py resolve --root /home/zym/trivy-db-20260927-v1 --apply
python3 prepare_scanner_db.py download --root /home/zym/trivy-db-20260927-v1 --apply
python3 prepare_scanner_db.py verify --root /home/zym/trivy-db-20260927-v1 --apply

# 回本机唯一物料根；不使用 --delete，不传送凭据。
rsync -a --partial --partial-dir=.rsync-partial --timeout=60 \
  --exclude='*.partial' --exclude=.download.lock \
  -e 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15' \
  txy-tokyo:/home/zym/trivy-db-20260927-v1/ \
  /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1/
python3 -B sunmoonai/registry-platform/prepare_scanner_db.py verify \
  --root /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1 --apply
```

本次程序通过 `ssh ... python3 - < prepare_scanner_db.py` stdin 执行，没有在东京部署服务；上述文件形式等价。下载过程保留已完成 blob 和失败 `.partial`；再次 download 复核完整文件、仅重新下载未完成项。公网单文件失败重试有上限；回传用 rsync 断点。下载须留文件大小之外至少6GiB，单数据库压缩上限2GiB，内部文件总上限16GiB。

东京本批已完成下载与归档全字节校验：

| 项目 | 漏洞库 | Java数据库 |
| --- | --- | --- |
| 格式 | 2 | 1 |
| 压缩字节 | 123,462,871 | 973,426,852 |
| 数据库本体字节 | 1,448,931,328 | 1,537,712,128 |
| UpdatedAt（UTC） | 2026-09-27 07:04:17 | 2026-09-27 01:08:08 |

新鲜度准入目前为漏洞库48小时、Java库7天，未来时钟误差最多10分钟；过期停止验收，准备新批。它是本次物料准入门槛，**尚未接入正式定时更新/告警**。每次正式部署和更新前重新检查；不得用旧验收收据永久绕过时效。

## 隔离扫描与后续接线

`scanner_verify.py` 只允许本机本批新目录，完整核验后解出两个数据库，运行固定原镜像，扫描它自己的公开 rootfs。使用 network=none、只读根文件系统、UID1001、cap-drop、资源限制与专用可写缓存绑定，无 Docker socket、宿主凭据、集群连接、端口或隐式卷。下载归档不挂入容器，程序只可写已验证后的缓存副本。日志/报告保存于新物料工作目录，结束停止保留容器。

```bash
python3 -B sunmoonai/registry-platform/scanner_verify.py \
  --batch /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1
# 实际验收需 sudo -n，添加 --apply；本批只允许首次执行。
```

通过条件：进程正常结束、产生有效JSON报告并识别软件包。发现漏洞本身不算扫描器故障；漏洞门禁策略另行决定。这个 rootfs 验收不等于 Harbor adapter 排队、私有镜像拉取、Java样本扫描、项目默认扫描器或CI/CD验收。

本次首轮目录受sudo的umask077影响，且数据库文件/挂载设为只读，打开数据库失败；只修目录权限后仍失败。Trivy实际要求可写数据库缓存，v2已改为UID1001独占的目录0700/文件0600，独立于原始归档。原`trivy-offline-trial-20260927`目录、容器和两次日志保留，新验收使用`trivy-offline-trial-20260927-v2`及同后缀容器。不能把失败重试说成一次通过；也不能将“跳过数据库更新”误解成“数据库文件一定可只读挂载”。

### 本次实际结果及正式使用判断

东京及本机完整字节核验均通过，v2容器在network=none下退出0，识别954个软件包并生成报告。报告SHA `f3124025d612c690e35501591610258d58e9fb2136e64a31f04ec812db9a5c75`；[脱敏证据](../../scripts/results/luna-trivy-offline.20260927.json)保留数据库内外摘要、失败记录及统计。两个验收容器均已停止，各0个Docker管理卷；卷总数仍46。新/旧Harbor均未在本单元启动或改配置。

扫描器自身镜像报告23条CRITICAL、309条HIGH发现。CRITICAL按CVE去重为9个，同一CVE会命中多个包、多个二进制以及内置SBOM；**不是23个互不相同且已证实可利用的漏洞**。本次确认“旧程序可以扫描”，并未批准它成为长期正式镜像，`formal_admission=false`。

已核的例子：

| 发现 | 原版本与修复线索 | 可利用性判断边界 |
| --- | --- | --- |
| CVE-2025-68121 | 报告中的Go1.24.6；修复分支含1.24.13/1.25.7 | [Go官方记录](https://pkg.go.dev/vuln/GO-2026-4337)涉及TLS恢复会话和CA配置变化，需要进一步核本程序调用方式 |
| CVE-2026-33186 | gRPC1.72.2；该项修复1.79.3 | [维护者公告](https://github.com/grpc/grpc-go/security/advisories/GHSA-p77j-4mvh-x3m3)要求特定服务端鉴权规则与畸形路径输入；依赖存在不等于当前CLI模式可被利用 |
| CVE-2023-45853 | 报告命中Debian12 zlib1g | [Debian说明](https://security-tracker.debian.org/tracker/CVE-2023-45853)对该发行版zlib注明未构建受影响MiniZip代码，不能只按严重级别认定此二进制包可被利用 |

其他发现还包括OpenSSL、GnuTLS、Perl及Go依赖，尚未逐条完成适用性审查。下一步评估维护中的扫描器/adapter与Harbor2.13.2协议兼容，先选能覆盖实际安全修复的候选，再离线扫描和Harbor集成验收；不能仅更新漏洞库就宣称旧程序已修复，也不为此改动PostgreSQL17.6/Redis8.2.1。

两份验收数据库缓存约5.56GiB可重建，列入最终清理时的候选盘点；现在全部保留，不能据此自动删除容器/卷、原始物料或备份。

正式接线仍须：

1. 原扫描器服务与Core的 `WITH_TRIVY` / adapter URL 一起迁移；保留/映射原默认登记，核对迁移前后配置，不用SQL伪造一致。
2. 扫描缓存、报告与Redis队列使用宿主独立持久路径，纳入启停、备份恢复及空间预算；启动不从公网临时下载。
3. 实际验证 Jobservice→adapter→私有registry 的认证/TLS与扫描结果，证明 Java 数据库也能参与样本扫描。
4. 更新数据库走新批次、核验、新鲜度检查、停止扫描任务后替换、恢复验收；失败保留上一批。不能清空旧节点/卷或唯一备份。

规则：C-R1/R2原版本与摘要；C-I8错误物料拒绝；C-D1正式数据仍独立于KIND；C-T5仅本地luna。云上安装与调度未经实机验证，当前只复用物料方法。
