# 本机宿主 Harbor 隔离恢复执行卡

2026-09-27。所有者要求助手自行判断推进，不再逐项审技术方案。此卡只覆盖新目录的隔离恢复和只读验收；正式 30443 入口、旧 Harbor、KIND 节点和历史恢复卷均不操作。

## 资源与步骤

- 输入：固定官方 2.13.2 安装包、20260926 冷备 registry、已通过 PG17.6 演练的逻辑 dump/角色；SHA 固定在代码。
- 输出：`/data/harbor/candidates/harbor-2.13.2-20260927/recovery`，只新建，不重试覆盖。
- `recovery_candidate.py --apply` 导入六个运行镜像（独立别名）、复制 registry 并全文件复核、生成私有 Compose。源包/原服务不变，配置保留原 TLS、密钥和外部 URL。六镜像真实 UID 已从归档核对：Harbor/Nginx 10000，Redis 999；PG 1001。镜像隐式 VOLUME 全部用 bind/tmpfs 承接。
- `recovery_run.py run --apply` 最多 40 分钟：新建 1 个数据库 init 容器（无网络），以及 7 个 Compose 服务（PG、Redis、registry、registryctl、core、portal、proxy），均使用独立名前缀 `sunmoon-harbor-recovery-20260927`，restart=no。独立 internal 网络，只有 proxy 的 127.0.0.1:18443 发布。
- PostgreSQL 17.6 新空库逻辑恢复后，与演练清单比对全部49表/10364行及角色/序列/结构等；通过才启动 Harbor 只读组件。jobservice、扫描/GC/复制不启用，Redis 使用空缓存，不重放旧队列。
- registry 数据只读 bind，registry readonly=true、禁止上传清理/delete，core READ_ONLY=true。官方 Compose 作为输入证据，实际运行另渲染配置并检查解析后的凭据原值不变。
- 验收全部目录/元数据/429 个含子清单制品（以冻结清单为准），HTTP 逐 manifest 验摘要，实际流式读取一层并核对字节/digest；所有复制文件已逐字节哈希复核。匿名私有 manifest 被拒，原认证可用，TLS 严格校验。token realm 仍保留原域名30443，但验证请求显式发到候选18443，不把凭据送旧入口。
- 初始创建8个容器，修复中另建3个替代容器；最后停止并保留全部11个新容器和网络。不能把只读演练成功写成后台任务/正式迁移成功。

## 空间、停止与失败

开始时 C盘可用244336463872字节，新盘可用103602659328字节。准备操作要求新盘至少40 GiB，约17 GiB registry副本加镜像包/配置/数据库有独立余量。不删除任何旧文件腾空间。

失败保留日志、目录、状态与新容器。恢复停止命令：`sudo python3 sunmoonai/registry-platform/recovery_run.py stop --apply`，仅匹配本次登记的名称及标签；不执行 down/rm/prune。执行进程意外结束后首先跑此停止入口，检查状态，不重新覆盖数据。

本单元结束还要核对旧容器/卷清单及旧 Harbor TLS 健康。后续正式切换须重新取得同一冻结点的最新数据，演练快照不能直接宣称最新；原始备份和当前服务继续保留。

## 实际验收与已知限制（2026-09-27）

`recovery_run.py resume --apply` 完成：3 项目、64 仓库、429 个含子清单制品、164 tags 及完整制品元数据与冻结备份一致；429 个 manifest 逐件通过 HTTP 字节摘要校验，匿名私有 manifest 全部被拒，TLS 校验通过；另流式读取 121,690,112 字节镜像层并核验摘要。恢复准备已校验全部4400个 registry 文件、17,850,816,895字节；PG17.6逻辑恢复49表/10364行及结构、角色、序列等一致。

11个演练容器全部停止保留，无新增匿名卷；Docker 卷数量仍为43。旧30443入口 TLS 健康为 healthy，未切换入口。脱敏结果见 [验收证据](../../scripts/results/luna-host-harbor-readonly-recovery.20260927.json)。

修复过程均只作用新副本，旧备份不改：

1. registry 只读父目录缺嵌套 root.crt 目标，补入原签名证书。
2. 按所有者“平台保持版本”要求，用原 Bitnami Redis 8.2.1 摘要替代准备阶段导入但不再使用的官方 Redis；空缓存不迁移队列。原输入缓存无密码，新隔离缓存单独启用认证，业务/Harbor 原凭据不变。
3. Docker internal 网络未实现期望的回环端口发布，proxy 另接无 masquerade 的前端网桥；后端仍仅在 internal 网络，只有127.0.0.1:18443发布。
4. 修改 env_file 不会改变已创建容器的环境，另建 core-auth 使用新缓存认证，旧 core 停止保留。
5. umask0077使复制目录实际为0700，导致registry HTTP500；仅新 registry 副本10127个 inode 调整为UID10000、目录0750/文件0640，内容摘要不变。

目前是本批次迁移工具，修复入口和私有运行状态保留。`recovery_candidate.py` 已阻止再按初始渲染器准备新批次，避免重现旧 Redis/网络配置；正式可复用部署入口必须吸收上述修复，不能直接把本批次临时 Compose 当最终安装入口。本次不包含 jobservice/扫描/推送、节点删除重建独立性或最终 CI/CD 验收。
