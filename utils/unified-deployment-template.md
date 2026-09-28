# 共享部署函数库

`unified-deployment-template.sh` 供现有组件 source，仍有大量调用方。它不是另一个平台总控；日常入口是仓库根 `./sunmoon`。

## 接口与配置

| 能力 | 入口 |
| --- | --- |
| 集群参数解析 | `unified_parse_cluster_arg`，唯一实现在 `cluster-arg-parser.sh`，模板 source 后提供同名函数 |
| 配置读取/映射 | `read_k8s_config`、`cluster-config-mapping.sh`，现有配置 `k8s-admin.conf` 保留 |
| kubectl 环境 | `setup_kubectl_environment` / `setup_connection`；总控显式部署只复核固定目标，人工旧路径仍有 CURRENT_* 状态 |
| 子组件运行 | `deploy-runtime-helpers.sh` 在显式部署中复核固定目标，失败立即停止，不读取旧状态 |
| 组件镜像准入 | `ensure_component_images_in_harbor component [project] [dry_run]`，调用统一 Registry 检查器 |
| 历史函数名 | `push_component_images_to_harbor` 当前只是镜像检查函数别名，不执行推送 |

集群参数支持 `--cluster KIND`、`--cluster C1`、`-c2`。组件必须继续保留自己的失败传播；不能把脚本变量 dry_run 当作所有分支已经无副作用的证明。

镜像检查以显式组件清单为输入；`dry_run=true` 只打印镜像检查计划，其他情况进行严格 CA/摘要检查。缺镜像、权限不足和网络故障都应停止；先通过 `./sunmoon harbor publish` 准备镜像，不临时调用旧物料菜单向节点导入。

## 本次整理边界

参数解析去掉重复函数，保留公共库实现；Document Converter 已改用同一个 Registry 镜像检查模块。
连接建立/状态缓存/自动重连保留给旧的独立人工路径；显式总控部署通过 `deploy-target.sh` 绕开它们，目标变化、内容变化或 UID 查询失败即停止。人工工具本身的 TLS/目标行为仍待适配。本批没有连接集群、创建隧道或运行部署。

人工连接工具见 [连接说明](k8s-admin-README.md)，每个文件的保留/合并/删除依据见 [清单](../sunmoonai/operations/utils-refactor-inventory.md)。
