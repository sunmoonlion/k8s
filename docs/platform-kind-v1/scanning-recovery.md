# Harbor 离线扫描与隔离恢复

本单元沿用官方 Harbor 2.15.2 Compose、固定镜像和原生 Make/Ansible。数据库物料是扫描情报数据，不是容器镜像，放在物料批次的 `databases/`，与安装包和镜像归档分开。

## 规则对应

| 规则 | 本单元落实 |
| --- | --- |
| C-R1、C-R2 | 扫描报告携带镜像摘要、数据库归档摘要和更新时间；恢复只使用发布锁内镜像。 |
| C-I3、C-I8 | API 管理操作与只读拉取身份分开；CA、挂载、摘要、隔离检查失败即停止。 |
| 数据迁移验收要求 | 用一致性冷备份实际启动独立服务、认证拉取，并比对全部 registry 文件；不把备份摘要正确等同于服务恢复成功。 |

## 离线数据库与真实扫描

在 `infrastructure/`：

```sh
make fetch-artifacts ARTIFACTS=trivy-db,trivy-java-db
make check-artifacts ARTIFACTS=trivy-db,trivy-java-db
make scanner-db-plan
make scanner-db-install
make scanner-db-verify
make registry-scan-check
```

- 下载复用 `artifacts/files.yaml`，先做容量检查，再校验官方归档大小和 SHA256。大数据库采用 curl 保留 `.part` 续传，每次连接最长 180 秒、有限重试；未完成的内容不进入正式归档。`files.lock.json` 同时保存 OCI manifest 身份、归档内两个文件的大小/摘要、schema 和更新时间。
- 漏洞库 schema 2，Java 索引库 schema 1；两者分别用于漏洞判断和 Java 包识别。使用官方默认 `mirror.gcr.io/aquasec/`，HTTPS 校验保持启用。来源与内容摘要已锁定，尚未加入发布者签名验证。
- 安装检查 Docker 所见数据盘后，以 scanner 的 UID/GID 10000 解包到同一文件系统的临时目录，逐文件核验，再原子移动到缺失的 `db/`、`java-db/`。已有目录只允许字节相同，不覆盖正在使用的数据库；中断后临时目录由该调用清除。
- `scanner-db-verify` 离线验证内容；扫描验收另要求情报更新时间不超过七天，拒绝未来时间或过旧数据库。这是本项目的验收门槛，不是官方数据库更新周期。Trivy 跳过在线更新和 Java 索引更新，使用离线扫描。
- `registry-scan-check` 请求 Harbor API → jobservice → Trivy adapter 的真实扫描，等到本次任务完成并取得漏洞报告；仅容器 healthy 不算通过。当前验证对象是已发布的固定 HAProxy 镜像，并非全部应用发布门禁。
- 报告在实例的 `scan-reports/` 下，root:0600；记录日期、镜像、扫描器、数据库和漏洞明细。扫描成功不代表无漏洞，不自动放行高风险发现，也不生成自制补丁镜像。

首次安装和相同版本复核已经进入统一入口。**定期数据库换版、维护窗口内替换与旧库回退仍须补齐**，不能把当前离线快照永久当成最新情报。后续换版需解析官方 schema tag 的新 manifest/layer，校验归档、更新锁和文件摘要；不得只改文件名、忽略摘要或改成跳过扫描。

依据：[Trivy 数据库](https://trivy.dev/docs/dev/configuration/db/)、[0.72.0 数据库读取逻辑](https://github.com/aquasecurity/trivy/blob/v0.72.0/pkg/db/db.go)、[Harbor 扫描](https://goharbor.io/docs/main/administration/vulnerability-scanning/)。

## 用现有冷备份独立恢复

这两个入口只读或恢复到全新的演练目录，**不原地恢复、不切换正式入口**：

```sh
make registry-recovery-plan \
  BACKUP=/data/harbor/maintenance/docker-20261001T053018Z/new-harbor-cold.tar \
  BACKUP_SHA256=68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96
make registry-recovery-check \
  BACKUP=/data/harbor/maintenance/docker-20261001T053018Z/new-harbor-cold.tar \
  BACKUP_SHA256=68f0f80957a655bdc1773f47af4ef223c92005190ac245f6957c0bc3d4ea0e96
```

冷备份形成于全部新 Harbor 服务停止时，含 `/etc/sunmoon/registry`、`/opt/sunmoon/registry` 与实例 `data/`，包括数据库、加密密钥、账号、证书、镜像和运行配置。这是同版本物理恢复；跨版本升级必须另行遵循官方升级方案。当前入口接受既有冷备份，新的备份创建和轮换还不是自动化交付项。

恢复边界：

1. 原备份只读，SHA256 精确匹配；拒绝重复路径、越界路径、链接和特殊文件。恢复前核实际挂载和容量预算。
2. 从备份解出所有普通文件，逐文件摘要、长度、属主和权限比对。结果写 `restored-files.json`，启动前另保存全部 registry 文件摘要 `registry-before.json`。
3. 原生 Compose 只读渲染副本；专用的小程序 `prepare-recovery.py` 仅校验备份并改写这份演练配置，生命周期由 Ansible/Compose 负责。所有 bind 指向演练副本，缺失挂载拒绝；镜像必须在发布锁内，重启策略为 no；后端网络设为 internal，仅 proxy 另接专用 access 网络以发布本机端口。
4. 演练只监听 `127.0.0.1:12443`，单独 Compose 项目和网络。core 的外部地址改成演练端口，并实际检查 `WWW-Authenticate` token realm，防止拉取意外借用正式仓库的认证服务。没有修改全局 DNS、CA 或入口。
5. 验全部服务健康、恢复的管理员登录、固定私有镜像，再以备份中的 puller 身份完整拉取。独立校验所有 OCI blob、manifest 和 image config，并再次比较全部 registry 文件集/摘要。
6. 成功或失败都停止本次演练项目，确认无运行容器；成功另复核正式 Harbor 健康。保留隔离目录、停止的容器和 `verified.json`，列入本次最终清理，不删除备份和旧资源。

演练不证明 WSL 自动挂载、重启和 KIND 删除重建持久化，也不证明云端可用；这些仍独立验收。演练所用备份早于本轮离线扫描库导入，扫描情报可按物料锁重新准备，不能声称该备份包含后来产生的扫描报告。

## 2026-10-01 实际结果

- 本次漏洞库更新时间 **2026-10-01 01:24 UTC**，Java 索引 **2026-09-27 01:08 UTC**。后者不是今天的最新版：本地 GHCR/镜像站大文件速度只有几十 KiB/s，东京 SSH 超时；复核官方不可变 manifest 后复用已有四天前快照。索引由硬链接放入新物料批次，删除旧缓存路径不会移除新路径内容，也不调用旧部署实现。两库压缩共 1,098,440,570 字节，解包文件共 3,008,844,062 字节。
- 首次安装 `ok=52 changed=8 failed=0`；加入按缺失库计算容量后，重复安装 `ok=35 changed=0 failed=0`。真实 Harbor 扫描 `ok=48 changed=4 failed=0`，扫描器 **Trivy v0.72.0**，状态 Success。私有报告 `/data/harbor/platform-kind-v1/scan-reports/haproxy-cud54j28.json`。
- HAProxy 验收镜像摘要 `sha256:5924fd69580b75444653595c750080fdde968097baaba62b8cade154511a0272`。报告有 **201 条包/CVE 记录，86 个不同 CVE**：High 50（11 个不同 CVE）、Medium 84、Low 65、Unknown 2；无 Critical 记录。这里只证明扫描链路可用，安全验收仍未完成。
- 其中 libpcre2-8-0、libssl3t64、openssl、openssl-provider-legacy 有报告中的修复版本。只读检查正式入口 `/proc/1/maps`，确认 HAProxy 进程加载了 PCRE2、libssl、libcrypto；不能把这些包一概当作未使用。加载也不等于漏洞路径可触达，仍需结合 TCP/SNI 配置与上游公告评估。本次没有自制补丁、修改镜像或忽略风险放行；后续建群可继续，生产安全门禁须单独收敛。
- 隔离恢复 `ok=40 changed=5 failed=0`：恢复并核对 **1,625 个普通文件**，全部 **16 个 registry 数据文件**前后摘要一致，完整拉回 **6 层、8 个 OCI blob**；image config `sha256:c6f9accb39104d084a2e8012cdfc52f2a69db18790bf04e981cd6bbc8ea7c624`。恢复身份与 token realm `https://harbor.sunmoonai.com:12443/service/token` 通过，正式 Harbor 保持 healthy。
- 成功回执 `/data/harbor/platform-kind-v1/recovery/rehearsal-20261001061625045631223/verified.json`。该项目已停止。此前三次尝试分别在副本挂载路径识别、internal 网络端口发布、检查请求缺少域名 Host 头处停止；前者未建容器，后两次已按 always 停止。问题都在演练编排/检查，不是备份数据恢复失败；失败记录不当作成功验收。

本轮恢复副本与停止的演练容器待最终清理；不自动删除冷备份。若 Ansible 被强杀，`always` 不保证执行，应根据对应 `prepared.json` 的 project/compose 路径调用官方 Compose `stop --timeout 60` 并核对无运行容器。演练容器 restart=no，不随 Docker 自动恢复。
