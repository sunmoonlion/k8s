# 新部署体系交接

## 目标与授权

从零建立可长期维护、符合生产工程规范的部署代码，第一期 KIND。五仓从各自本地 master 建立 `platform-kind-v1` 分支和工作区；原 luna 仅作参考。所有者已要求按方案继续，当前实现配置、物料身份与只读预检，服务部署尚未开始。

入口：[架构](docs/platform-kind-v1/architecture.md)、[输入盘点](docs/platform-kind-v1/inventory.md)、[版本表](docs/platform-kind-v1/images.md)、[当前操作](platform/README.md)。

## 工作区与边界

- 工作区 `/home/zymun/worktrees/platform-kind-v1`，五仓并列；各仓基线见盘点。k8s 初始提交 `4156a8b0a7b93b16fc8f77eadfcda36332eb0aff`。
- 新实现位于 k8s 的 `platform/`，不调用旧部署程序。其他四仓尚未修改。
- 新路径不在当前工具默认可写范围，写入须走工具权限流程。
- 五仓 12 个子模块已从本机对象初始化到 gitlink 固定提交；未联网同步。同步白名单未登记，未 push。
- 本单元未改变集群、Harbor、数据或 Windows 任务，未删除旧实现。原 luna 的验收不能作为本实现的验收。

## 已定方向

Ansible 管宿主机，官方 Harbor 安装器与 Compose，KIND 管建群，Flux 管集群声明，OCI 固定制品作部署来源，SOPS 管秘密；入口使用原生工具。

所有者取消旧数据和旧镜像迁移，应用可适配并重新构建。选择 Kubernetes 1.36.5、KIND 0.33.0、Calico 3.32.2、Flux 2.9.5、Harbor 2.15.2，业务 Python 按所有者要求为 **3.13.15**；完整版本与例外见版本表。KIND 1.36.5 需要官方构建流程产出，不能用已有 1.36.4 镜像充数。无业务迁移需求不代表允许擅自删除受保护的旧节点、卷或代码。

## 2026-10-01 实际进度

1. 建立原生 Make 入口：tools、images、check-images、preflight；尚无 deploy/start/stop。
2. Ansible 2.21.4 及其依赖带哈希锁，实际安装到 platform/.venv。宿主仍用 Python 3.12.3，与业务 Python 3.13.15 分开。
3. 43 个上游镜像目标中，39 个已取得并复算 linux/amd64 manifest 摘要。东京仅查询公开元数据，没有下载镜像层或留下脚本。
4. Casdoor、BusyBox helper、Calico CNI、Calico kube-controllers 遇 Docker Hub 匿名限流，4 项 unresolved，停止重复请求。Casdoor 带 v 的 tag 不存在；不带 v 的目标仍未核实。清单 complete=false、offline_ready=false。
5. 实际只读挂载预检通过：ok=5、changed=0、failed=0。首次 df 的 YAML 参数拆分错误已修正后重跑。三个挂载匹配 ext4、UUID a28de356-4ba1-4a21-93f5-744b9b9d8be0 和各自 FSROOT；当时数据文件系统可用 76,159,590,400 字节。该数不是 Windows C 盘物理空闲。
6. 四个后端依赖锁均含 asyncpg、greenlet、httptools、pydantic-core、uvloop 的 cp313 Linux amd64 wheel 记录；这是依赖元数据检查，不是构建或运行通过。八个前端包的 Node 范围覆盖所选 24.21.0，暂未修改应用。
7. 未执行业务测试；未完成镜像拉取、KIND 节点构建、完整工具/chart 锁、离线闭包或新环境部署。

## 后续执行顺序

1. 补齐未核实的 4 个镜像、宿主工具和 chart 锁，生成 KIND 1.36.5 构建物料与完整依赖清单。身份未核实的项不得充数；镜像清单通过也不代表离线材料完整。
2. 完成 Docker 服务挂载可见性、Windows C 盘增长预算和物料容量准入。数据盘已扩到 230 GiB；继续遵守至少预留 50 GiB 的要求。
3. 实现并验收官方 Harbor 新装、备份恢复和入口；继而 KIND 创建与 Flux 引导，所有配置只有一处真源。
4. 按依赖次序部署平台；业务改动从模板吸收后推广实例，复用已有业务验收。
5. 验收一键部署、单组件开关、统一启停、WSL/KIND 重启和 KIND 删除重建后的持久化；补齐长期空间管理。
6. 最终按授权处理旧实现及本次临时材料，记录退出条件与实际释放量。保护旧节点/卷、未实机验证云流程的旧代码和他人 local-integration 工作，不能批量清理代替审查。

无需重新索要已明确范围的许可。新增停服、破坏性删除或环境切换依具体授权执行。没有用户设定的 token 或时间预算。
