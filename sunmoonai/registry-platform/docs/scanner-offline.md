# Trivy 镜像、离线数据库与接入验收

先对原 Harbor 扫描器程序与更新后的漏洞数据库做隔离验收，随后按所有者授权准备维护中的新版扫描器；两批镜像分别保留。**独立扫描通过不表示新宿主 Harbor 的 Jobservice、扫描登记或 CI/CD 已恢复。**Harbor主服务仍按2.13.2迁移，后续升级单独进行，见[版本决策](harbor-version-reassessment.md)。

## 新版扫描器候选（2026-09-27）

官方稳定镜像`ghcr.io/goharbor/trivy-adapter-photon:v2.15.2`，amd64 manifest为`sha256:215c07b71c37fc7fc16e02d9185d936dcb8884a80e810817c2cd058bbd7c4e98`。官方构建使用adapter0.38.0和Trivy0.72.0；不能将包装tag误写成Trivy2.15.2，也不能据此说Harbor主服务已升级。[固定清单](../scanner-stable.lock.json)。

`prepare_scanner_candidate.py`默认只打印，`--root <新批次目录> --apply`通过官方GHCR下载固定manifest/config/8层并逐字节验SHA，6GiB空闲门槛、压缩层总量512MiB上限、有界重试、失败保留。东京执行目录`/home/zym/sunmoon-scanner-stable-20260927-v1/materials`，无远程Docker或部署；回传唯一物料根`~/packages-to-be-installed/releases/harbor-scanner-stable-v2.15.2-linux-amd64`。归档164,341,760字节，SHA`c17bf77f9a57a2751fdf5aa40e936e91fafd78f17e4041f86a7af9c024d2f2a5`；回传后全OCI图复核并导入本机。发布者签名尚未独立验证。

实际执行`scanner_verify.py --profile stable --batch /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1 --apply`，容器`sunmoon-trivy-stable-offline-20260927`在无网络、无端口、UID10000、只读根和专用可写数据库副本中扫描自身rootfs，退出0，识别487包。报告SHA`80144060cb2b8e58991e156e07f35e831f674adaad1961369899c33be16d7d9a`，17条CRITICAL（9个不同CVE）、82条HIGH、21条MEDIUM、7条LOW、1条UNKNOWN。严重发现涉及Photon5.0 curl/curl-libs、nss-libs及openssl/openssl-libs，完整脱敏记录见[证据](../../scripts/results/luna-trivy-stable-offline.20260927.json)。

**功能通过，正式安全准入仍为false。**不能因“最新稳定版”忽略安全发现，也不能直接把检测条目全认定成可利用漏洞。Java数据库归档已核，没有Java样本扫描。旧、新系统包组成与扫描器版本不同，不用漏洞数量相减宣称风险下降。试验容器已停止保留，缓存约2.8GiB，仅列最后清理候选。

## 私有镜像标准接口验收

`scanner_adapter_verify.py`默认打印计划；实际动作仅针对已准备的本地只读宿主副本，云上未经实机验证。独立缓存校验同一批数据库，在受管internal网络增加扫描器及TLS直通容器：内部canonical域名30443只转该副本proxy8443，不发布宿主端口、不改系统DNS、不挂TLS私钥。扫描器只接收一个仓库的pull令牌，管理员凭据留在宿主验收进程。

固定目标为`k8s-images/nginx@sha256:c97ddadf7d610991aded1178ca552543d835f1c4e28284caf46c9f98f66c4a7a`。先验证匿名拒绝、manifest摘要与TLS；随后按标准`/api/v1/scan`入队、轮询报告，检查目标摘要及扫描器身份。Redis使用独立DB5命名空间，任务TTL1h；原备份、镜像数据只读，不刷新令牌。结束停止并保留新容器和宿主副本；私有日志、报告、env及回执只落Git外0700试验目录。默认不启动Jobservice，不把adapter直调等同于完整Harbor扫描验收。

```bash
python3 -B sunmoonai/registry-platform/scanner_adapter_verify.py \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --batch /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1
# 实际验收另加 --docker-credentials /home/zymun/.docker/config.json --apply，并使用sudo。
```

## 完整 Harbor 扫描链路验收（2026-09-27 已通过）

在宿主隔离副本上实际执行 `scanner_adapter_verify.py`，追加 `--harbor-jobservice --docker-credentials /home/zymun/.docker/config.json --apply`（sudo），批次为 `releases/trivy-harbor-chain-20260927-v3`。Harbor Core/Jobservice **2.13.2** → 官方固定扫描器镜像（包装标签 **2.15.2**，实际 Trivy **0.72.0**）→ 离线数据库 → 私有镜像扫描 → Harbor 取回报告，最终 **Success**。与 adapter 直调的 150 条发现逐项一致：High 38、Medium 65、Low 45、Unknown 2。adapter 自报版本为 `dev`，因此以镜像摘要和实际 Trivy 版本记录身份，不把预期源码版本冒充运行时版本。

本次实际验证了这组版本的扫描接口可配合，不代表所有功能或正式配置均验完。报告 SHA256 为 `0b78d4e444ce205fd41159a195449511d16cd120ee44908d41ad826c77e657ff`，见[脱敏回执](../../scripts/results/luna-trivy-harbor-chain.20260927.json)。镜像层目录始终只读；验收前导出候选数据库；仅临时开放候选 API 元数据写入，用于登记扫描器、设默认和提交任务。新 Jobservice 容器使用独立且初始为空的 Redis 队列命名空间，保留前次任务记录。登记已经撤销、API 只读已经恢复、候选及三个试验容器均已停止保留。正式入口未切换，永久扫描器登记、推送、机器人令牌、CI/CD、Java 样本及安全准入仍待完成。

### 前几次未通过的真实原因

| 批次 | 原因 | 修正 |
|---|---|---|
| adapter 首轮 | 验收代码请求了不支持的报告 media type，HTTP 415 | 按接口声明使用 `application/vnd.security.vulnerability.report; version=1.1` |
| 完整链路首轮 | Harbor 已报告 Success，但验收代码按 adapter 原始结构查顶层 artifact | 按 Harbor 原生结构核 artifact API、报告 ID、scanner 和每条发现的 artifact_digests |
| 完整链路 v2 | Jobservice 镜像声明 `/var/log/jobs/`，与允许的 `/var/log/jobs` 被当成不同路径 | 规范化尾斜杠，继续拒绝其他未批准卷 |
| 完整链路 v3 | 完整检查通过 | 保留回执和停止状态 |

这些失败不能归因于版本不兼容。所有失败目录及容器保留，到最终清理时统一处理。首轮启动原候选 Jobservice 后留下 26 个 Redis 键；后续使用独立命名空间，没有 flush 或删除旧队列。普通启动检查 `metadata_acceptance_open`，若临时写入窗口被中断，必须先核实恢复状态。

### 扫描器自身的安全问题另行处理

自身镜像的 17 条 CRITICAL 并非上述私有 nginx 镜像的扫描结果。原始严重级别保留，不能当成 17 个已经证实可利用的漏洞，也不能忽略。尚未批准正式运行。

已核两主程序 ELF 均无 PT_INTERP/PT_DYNAMIC：Trivy SHA256 `0e69edd134a3c338baa1a6806920773615d682b18cbc6a0cba2a3b658ef9b63e`，adapter SHA256 `86b6fe7108d66f9c4b5d31b14d2adc68019a2f8550bc2435719ea5ee553cfa1c`。这仅表明两者没有常规 ELF 动态链接，不能排除调用其他程序。镜像继承的健康检查会执行 curl，其备用 HTTPS 探针带 `-k`；它与已验证严格 TLS 的镜像拉取客户端不同，正式配置还需调整探针。

后续按上游适用条件核实 curl、NSS、OpenSSL 发现，优先采用有明确修复的官方镜像；否则评估固定安全补丁构建并重新扫描，不在部署时临时全量更新包或批量忽略 CVE。上游依据：[curl CVE-2026-11564](https://curl.se/docs/CVE-2026-11564.html)、[curl CVE-2026-19931](https://curl.se/docs/CVE-2026-19931.html)、[OpenSSL 2026-08-25 公告](https://openssl-library.org/news/secadv/20260825.txt)、[Mozilla NSS 公告](https://www.mozilla.org/en-US/security/advisories/mfsa2026-68/#CVE-2026-16389)。功能兼容通过与安全准入必须分别记录。

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
