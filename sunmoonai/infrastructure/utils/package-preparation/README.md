package-preparation 使用说明

该目录提供基础设施安装前的“离线包同步”与“安装后清理”能力，目录/结构与 packages-management 兼容：

- 本地：`~/packages-to-be-installed/{debs,images,tars,charts}`
- 节点：`~/packages-to-be-installed/{debs,images,tars,charts}`

脚本：`package-sync.sh`
配置：`package-sync.conf`

配置说明（package-sync.conf）
- 节点列表（必填）：`SERVER_1_*`、`SERVER_2_*`...
  - 必需：`SERVER_N_PUBLIC_IP`、`SERVER_N_USER`
  - 可选：`SERVER_N_SSH_PORT`（默认 22）、`SERVER_N_SECRET`（密钥）或 `SERVER_N_PASS`（密码）
- 自动清理开关：
  - `AUTO_CLEANUP_AFTER_SYNC=false`（默认）
    - 同步结束后是否立刻清理包文件；一般保持 false，避免刚同步完就清空导致后续安装找不到包
  - `AUTO_CLEANUP_AFTER_INSTALL=true`（默认）
    - 安装完成后是否清理包文件；推荐保持 true，释放磁盘空间

常用命令
- 仅同步（不安装）
  - 同步全部：`infrastructure/utils/package-preparation/package-sync.sh sync-packages-to-all-nodes all`
  - 仅镜像：`infrastructure/utils/package-preparation/package-sync.sh sync-packages-to-all-nodes images`
  - 别名：`infrastructure/utils/package-preparation/package-sync.sh sync-images-to-all-nodes`
- 清理包文件
  - 清理单节点：`.../package-sync.sh cleanup-node-packages <ip> [user] [port] [all|debs|tars|charts]`
  - 清理所有节点：`.../package-sync.sh cleanup-packages-on-all-nodes [all|debs|tars|charts]`
- 状态与预演
  - 查看配置/节点摘要：`.../package-sync.sh status`
  - 预演同步（不传输）：`.../package-sync.sh sync-packages-to-all-nodes images --dry-run`

与部署脚本的集成
- 在 `deploy-infrastructure-all.sh` 安装前：
  - `"$PROJECT_ROOT/utils/package-preparation/package-sync.sh" sync-packages-to-all-nodes all`
  - 或：`"$PROJECT_ROOT/utils/package-preparation/package-sync.sh" sync-packages-to-all-nodes images`
- 安装完成后批量清理：
  - `"$PROJECT_ROOT/utils/package-preparation/package-sync.sh" cleanup-packages-on-all-nodes all`

注意
- 同步与安装解耦：只执行同步不会触发安装
- 镜像 tar 体积大，建议优先同步 images 或先用 `--dry-run` 预估
- 仅密码登录的节点需安装 `sshpass` 以启用自动化传输


附：目录结构（节选）
- 本地与节点统一结构：
  - `~/packages-to-be-installed/`
    - `debs/`、`images/`、`tars/`、`charts/`

附：工作流（Infrastructure 阶段）
1) 同步包到所有节点（本页命令）
2) 安装基础设施
3) 安装完成后（按需）清理节点包文件

实施检查清单（简版）
- [x] 创建并配置 `package-sync.conf`（至少 1 个 SERVER_*）
- [x] 同步命令已在 `deploy-infrastructure-all.sh` 集成
- [x] dry-run 能正常输出计划
- [x] 安装完成后清理逻辑可用（按需）

关键原则
1) 目录结构不可变，兼容 `packages-management`
2) 同步与安装解耦，避免强耦合导致失败
3) 清理在“安装后”时机执行最稳妥
4) 永远不删除正在使用中的镜像/文件


