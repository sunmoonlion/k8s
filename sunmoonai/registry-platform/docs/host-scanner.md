# 宿主 Harbor 的受管官方扫描器

目标仍为一套部署代码、两种建群方式。扫描器随独立宿主 Harbor 管理，与 KIND 节点无数据挂载关系。Harbor2.13.2、PostgreSQL17.6、Redis8.2.1不变；使用已验证的官方扫描器原始镜像，不制作补丁镜像，已知问题见[运行依赖结论](scanner-offline.md)。云端只共用配置生成代码，**未经实机验证**。

## 配置和生命周期

`host_scanner.py` 给已停止、已完成数据对账的宿主实例加入三项服务：

| 服务 | 用途与边界 |
| --- | --- |
| trivy | 官方固定镜像，UID10000，只读根，全部能力移除，内部网络，无宿主端口；固定回环 HTTP 健康检查，无 `-k` |
| registry-route | 仅在 Harbor 内部网络把 canonical 域名30443直通到 proxy8443；不发布宿主端口、不挂证书私钥；与宿主公开 SNI 代理不同 |
| scan-jobs | 原Harbor2.13.2官方Jobservice镜像，独立 Redis 队列命名空间；旧候选 jobservice 容器停止保留 |

公开镜像身份固定为 `sha256:215c07b71c37fc7fc16e02d9185d936dcb8884a80e810817c2cd058bbd7c4e98`，实际Trivy0.72.0。数据库仍来自独立固定批次，运行时禁止自动公网下载；扫描前检查漏洞库48小时、Java库7天新鲜度。定时更新编排尚未完成，不能长期依赖本次快照。

扫描器缓存、配置和任务日志在实例下的 `scanner/`，随 `/data/harbor` 落在独立数据盘；原配置完整保存到 `before-scanner/`。转换中断会留下启动阻断标记，不偷偷覆盖重试。原八个服务容器由 Compose `--no-recreate` 保留，只增加三个停止的新容器。

```bash
# 从 k8s 仓根执行；默认只打印。正式动作需按已授权范围加 --apply。
python3 -B sunmoonai/registry-platform/host_scanner.py \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --batch /home/zymun/packages-to-be-installed/releases/trivy-db-20260927-v1
python3 -B sunmoonai/registry-platform/host_scanner_verify.py \
  --config sunmoonai/registry-platform/config/harbor-main-local.json
python3 -B sunmoonai/registry-platform/host_runtime.py start \
  --config sunmoonai/registry-platform/config/harbor-main-local.json --with-jobs
python3 -B sunmoonai/registry-platform/host_runtime.py stop \
  --config sunmoonai/registry-platform/config/harbor-main-local.json
```

只读模式的普通 start 用于只读核对，启动扫描器但不启动任务服务；明确 `--with-jobs` 才启动已验收的受管任务服务。新增[受管可写模式](host-mode.md)的普通 start 会自动启动受管任务服务。stop 统一停止任务服务、扫描器、内部路由和基础服务，保留所有容器和数据。镜像仓可写转换另做，本步骤不等于能推送镜像或入口已切换。

## 登记与验收

登记采用 Harbor 官方可插拔扫描器接口，名称 **`sunmoon-trivy`**，内部URL `http://trivy:8080`。它是可管理登记，可在 Core 的 `WITH_TRIVY=False` 启动后保留。三个项目的默认扫描器映射逐一核对；不采用旧集群的 Pod DNS 地址。

验收先导出PG17.6逻辑备份，再短暂允许候选 API 写元数据，设置登记并执行固定私有nginx镜像扫描。registry的文件挂载始终只读。报告成功后恢复API只读、停止所有服务，再重启Core确认同一个UUID仍是默认。中断则保留写窗口标记等待核实。

2026-09-27 已实测通过：扫描150条发现、状态Success；3项目映射一致，Core重启后默认登记保留。登记UUID `07d3f625-ba80-11f1-b91d-a6673bbf47a3`，报告SHA256 `8246529b6a40832f270a8dabd173736b5a08512121adf96ab35e239310396f49`。原始结果在私有实例 `scanner/registration-v2/result.json`，失败首轮保留在v1。

### 两个实施问题

1. 准备时误将公开物料锁交给私有文件权限读取器，因公开文件可组写而拒绝。修复后复核整个物料锁摘要及已落地数据库每个文件摘要，限定从“只复制了cache/job-logs、旧配置未变”的阶段续接。没有修改物料权限或跳过摘要。
2. 首次登记用了有空格的 `Sunmoon Trivy`。Harbor将登记名放进临时机器人用户名；Trivy的字符串列表解析会按空格拆分，报用户名/密码数量不一致。改名为 `sunmoon-trivy`，保留UUID后成功；没有换镜像或修改凭据。依据：[Harbor临时扫描机器人构造](https://github.com/goharbor/harbor/blob/v2.13.2/src/controller/scan/base_controller.go)、[Trivy列表参数解析](https://github.com/aquasecurity/trivy/blob/v0.72.0/pkg/flag/options.go)。以后扫描器机器名限定小写字母、数字和连字符。

## 备份、恢复和空间

`host_backup.py` 对带扫描器的实例把整个 `scanner/` 纳入runtime归档，数据库逻辑导出包含默认登记；恢复仍沿用同一个 `restore-prepare → create → restore → verify` 流程。Compose恢复只改宿主路径和部署身份，服务内别名保持不变，因此数据库里的 `http://trivy:8080` 不依赖原部署名。

可选 `--registry-from-backup <已独立恢复过的旧备份>`：先完整验证旧备份，再在源服务停止后逐文件比较实时镜像目录的全部SHA、大小和所有权。全部相同时，对**完整只读registry.tar**创建硬链接，新的备份目录仍含完整tar，不指向运行数据。数据库/runtime每次新备份；归档只创建不覆盖。任一镜像文件变化则拒绝复用，须重新分配完整备份空间。

硬链接共享物理占用，删除一个名字不会释放仍被另一备份引用的内容；最后清理的释放量不能重复统计。跨盘或机器外复制需要传输完整文件。本次没有删除任何归档或数据。

规则核对：C-R1/C-R2固定镜像与物料摘要；C-I8文件/容器/挂载不符停止；C-D1扫描数据不挂入KIND；C-T5只提交本地luna、不push。

## 本次实测收尾（2026-09-27）

统一 `start --with-jobs` 已实际启动 trivy、registry-route、scan-jobs；原 jobservice 停止，API 与 registry 保持只读。统一 stop 后全部11个服务均 exited，初始化器也已停止，Docker卷仍46个，旧KIND和验证KIND六节点仍运行。

新备份 `/data/harbor/backups/host-scanner-20260927-v1` 已完成：49表、11156行；registry共4400文件、17850816895字节，与原备份逐文件一致。完整registry.tar为17868021760字节，SHA256 `db2fad362a3e9b5d205e55764dc3ad8a675025e7a666ec759e53a5e8c9fbea3c`，与原备份共享归档inode（链接数2）。runtime.tar为2993111040字节，SHA256 `07802eacf951e6fb69790227d75bdd2abda755d9435f9cf04da83b6e6776931b`，包含扫描器数据库、任务日志和私有配置。数据库和归档均重新校验。

**新备份尚未独立恢复**（restore_verified=false）；不能把原布局的恢复结果当作新布局结果。恢复后可用 `host_scanner_verify.py --existing-registration` 验证已有登记，只有独立恢复的新实例可用，不重新登记；此分支目前仅静态检查和默认计划通过。数据盘当前可用24361865216字节（约22.69GiB），尚不满足另复制完整镜像目录、扫描库并保留20GiB余量的门槛，不绕过门槛、不提前清理旧副本。

脱敏回执：[受管扫描器结果](../../scripts/results/luna-harbor-managed-scanner.20260927.json)。正式推送、入口切换、CI/CD、定时漏洞库更新及云端运行仍未验收。
