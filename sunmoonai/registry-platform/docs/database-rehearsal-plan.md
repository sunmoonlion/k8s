# PostgreSQL 17.6 冷备份逻辑恢复演练执行卡

状态：所有者明确“你执行”后，**本次数据库逻辑恢复演练已通过**，执行代码提交 `fd282292be6492fa9757800fe24282a32a63e5a3`。这是宿主 Harbor 迁移前的数据库单元，不能代替 Harbor 全目录/密钥/认证验收或正式切换。

## 1. 本次要验证什么

从已经完成的冷备份复制 PostgreSQL 数据，使用原 17.6 镜像启动一个隔离的临时源库，执行逻辑导出；再用独立空目录初始化目标 PostgreSQL 17.6，执行逻辑导入并核对。物理 PGDATA 只用于临时源库读取已有冷备份，目标库始终通过逻辑导入建立。

不连接 Kubernetes API、不缩放旧 Harbor、不改现有恢复副本、不复制完整 registry、不切入口。旧 Harbor 继续服务。此演练不冻结当前旧 Harbor，因此成功结果只覆盖 **2026-09-26 冷备份时点**；正式迁移仍需在批准窗口生成同一冻结时点的最新数据库、registry 和秘密快照。

## 2. 已核实输入

| 输入 | 固定值 / 证据 |
| --- | --- |
| 新盘 | UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`，PID 1/Docker 可见，三处挂载检查通过 |
| 冷备份根 | `/home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z` |
| 数据库归档 | `volumes/database.tar`，195,020,800 字节，SHA256 `d6eaee7507f5393613fe253298813c24627ff248162237d1c02b76847f1ae59d` |
| 备份 PGDATA | `./data/PG_VERSION` 为 `17`，归档仅普通文件/目录，UID/GID 1001 |
| 固定运行镜像 | `bitnami/postgresql@sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b`，linux/amd64，已在本机缓存 |
| 镜像来源核对 | 旧 Pod 实际 imageID、准备批次 OCI manifest、本机 RepoDigests 相同；OCI config digest 为 `c5041d46…`，与 manifest digest 是不同对象，不误判为版本冲突 |
| 数据库 | `registry`，源连接角色 postgres，shared_preload_libraries 为 pgaudit |

预检必须重新校验以上归档字节、大小、PG_VERSION、镜像摘要、挂载与至少 20 GiB 可用空间。运行时检查数据库服务版本必须为 `170006`；标签文字不能替代运行版本。没有自动下载、重打标签、Docker 导入或低版本回退。

## 3. 新增对象与资源

- 新目录：`/data/harbor/rehearsals/pg17-20260927T040000Z`，名字只是固定批次标识，真正开始时间写入 state.json。
- 三个专属容器：`sunmoon-pg17-20260927T040000Z-source`、`-init`、`-target`；先查重，再记录创建意图与实际 ID。
- 两个数据库副本及 dump/角色文件预计不到 1 GiB，开始前保留至少 20 GiB 可用；这是容量估计，不是目录硬配额。单个容器最多 1 GiB 内存、2 CPU、128 PID，两个数据库会同时运行。
- 每个容器 `--network=none`、无发布端口、无 Docker socket、UID 1001、只读根文件系统、移除 capabilities、no-new-privileges、restart=no、禁用容器日志驱动。
- 显式覆盖镜像声明的三个 VOLUME：数据库目录绑定新盘；两个 init 脚本目录绑定只读配置。直接执行 postgres/initdb 二进制，不执行入口初始化脚本；启动前拒绝任何匿名卷、外部网络或端口绑定。
- 镜像 `/etc/passwd` 无 UID 1001 条目。候选代码在私有配置目录提供 passwd/group，通过镜像已有 libnss_wrapper 显式映射，不改镜像、不以 root 运行 PostgreSQL；不依赖入口脚本隐式补环境。
- 数据库仅容器内 Unix socket，限定 postgres 本地连接；不开放 TCP，连接由 `docker exec` 完成。源与目标均加载原 pgaudit 库。
- 无论成功失败，正常异常路径尝试停止本次新容器，**不删除容器、卷、目录或 dump**。停止后的演练对象纳入最终清理清单，须符合最后清理时的批准边界。

## 4. 可审阅执行入口

仓库根为 `/home/zymun/worktrees/luna/k8s`。默认命令纯打印，不连接 Docker/网络、不创建目录：

```bash
python3 sunmoonai/registry-platform/database-rehearsal.py run \
  --backup /home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z \
  --run-dir /data/harbor/rehearsals/pg17-20260927T040000Z
```

只读预检（需 root 读取服务空间与 Docker 信息）：

```bash
sudo -n python3 sunmoonai/registry-platform/database-rehearsal.py check \
  --backup /home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z \
  --run-dir /data/harbor/rehearsals/pg17-20260927T040000Z
```

**下面命令已执行成功，仅作为本次记录，不要重复运行已有批次。** 所有者无需复制到 PowerShell：

```bash
sudo -n python3 sunmoonai/registry-platform/database-rehearsal.py run \
  --backup /home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z \
  --run-dir /data/harbor/rehearsals/pg17-20260927T040000Z --apply
```

过程：复制备份 → 启动临时源 → 盘点 → pg_dump -Fc/pg_dumpall globals → 空目录 initdb → 恢复角色和数据库 → 内容核对 → 停止三容器。除 initdb 已创建的 `CREATE ROLE postgres;` 外，不忽略角色 SQL；pg_restore 使用 `--exit-on-error --create`，SQL 使用 `ON_ERROR_STOP`。原角色口令哈希留在私有 globals.sql，不输出到终端或 Git。

## 5. 通过条件、失败与恢复

通过必须同时满足：

1. 源和目标实际版本 17.6。
2. 全部业务表集合/所有者/行数相同，按稳定排序逐表计算行内容 SHA256 相同。
3. schema-only dump（仅排除随机 psql restrict token）SHA256 相同。
4. 序列参数、last_value、is_called、扩展版本相同。
5. 角色属性/口令哈希、数据库权限/所有者/locale、large objects 的内容摘要相同。
6. 导出文件及 state.json 已保存，三个新容器停止；旧容器/卷集合无删除，新容器没有匿名卷。

预计 5–10 分钟，数据库阶段设 15 分钟总截止及单命令超时，超时后仍尝试停止新容器。中断/断电不能保证 finally 执行；重连后只对 state.json 中名称、ID、专属 label 全部匹配的容器续接停止：

```bash
sudo -n python3 sunmoonai/registry-platform/database-rehearsal.py stop \
  --backup /home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z \
  --run-dir /data/harbor/rehearsals/pg17-20260927T040000Z --apply
```

停止恢复不受 20 GiB 剩余容量门槛限制，但要求状态目录仍位于正确 UUID 的新盘上。不自动重新执行失败批次；已有目录、容器冲突或证据不明时保留现场。旧服务没有被修改，因此本单元回退就是停止新演练容器并保留数据，没有旧服务缩放或入口恢复动作。

state.json、inventory.json、registry.dump、globals.sql 为 root 私有目录内容；对外只报告版本、数量、校验是否一致、停止状态和限制，不贴数据行、角色口令或密钥。

## 6. 适用范围与后续

本入口固定本机历史冷备份，**不是统一云端部署入口，云端未经实机验证**。正式 registry-platform 的本地/SSH 共用部署、官方 prepare 配置映射、NGINX SNI 物料、完整 Harbor 恢复及云 steps 尚待后续单元。通过本演练不代表可正式写入宿主 Harbor。

技术依据：[PostgreSQL 17 pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html) 的恢复与错误处理选项；[Docker none 网络](https://docs.docker.com/engine/network/drivers/none/) 的隔离行为。源码/数据版本锁定落实 C-R1；数据迁移的恢复与对账要求按 constraints 数据节执行；本单元仅数据库证据，不冒充跨系统验收。

## 7. 本次实际结果（2026-09-27）

- 04:06:54 UTC 开始，约半分钟完成执行，04:08 后完成独立收尾复核；无恢复错误、无停止错误。
- 服务端和 pg_dump/pg_dumpall/pg_restore 均为 PostgreSQL 17.6。
- 49 张表、10,364 行；逐表内容 SHA256、schema、所有者/权限、角色属性及口令哈希、序列参数与 is_called、扩展、large objects 全部一致。
- 三个新容器均 exited、ExitCode=0，network=none、无端口、无匿名卷、restart=no。原 7 个容器身份/状态未变，Docker 卷仍为原 43 个。
- 旧 Harbor `/api/v2.0/health` 返回 200/healthy，保持 TLS 校验；没有访问集群 API、调整旧副本或切换入口。
- 新盘实际占用 182,140,928 字节（约 173.70 MiB）；registry.dump 540,024 字节，globals.sql 671 字节，四份私有输出均 0600。冷备份原件 SHA256 未变。
- 证据：[执行结果](../../scripts/results/luna-registry-database-rehearsal.20260927.json)、[执行前](../../scripts/results/luna-pg-rehearsal-before.20260927.json)、[执行后](../../scripts/results/luna-pg-rehearsal-after.20260927.json)。私有数据、密码哈希及 SQL 没有进 Git。
- 当前只证明历史冷备份可在相同数据库版本逻辑迁移。Harbor 官方应用接入、原加密密钥/认证、registry 全目录摘要、后台任务及入口迁移尚未完成。

原目录、三个停止容器和导出文件全部保留，登记最终收尾复核；**不代表获准删除任何容器或卷**。剩余清理仍在完整迁移验收后进行。
