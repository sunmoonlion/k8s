# docs/platform/ 并入别处后删除（Opus，2026-10-16）

所有者定：「按这个做吧」——`docs/platform/` 与项目总览重复，规矩进 `constraints.md`，事实进总览与模块文档，还没做的进待办账，然后整个删掉。原文 Git 历史 `53767f6a:docs/platform/`。

## architecture.md 逐节去向

| 原来的节 | 去向 |
| --- | --- |
| 适用范围与目标（单机 KIND 不是生产高可用；一套部署代码两种建群） | `C-R10`（已有）；总览 §6（已有） |
| 职责与所有权（宿主、仓库、公共 TLS、建群、发布控制、身份、平台与应用各管什么） | 总览 §6、`project-guide/repos/k8s.md` 的 infrastructure 表（已有） |
| Make 公开入口、Ansible 编排、Flux 拥有声明；不加平行 CLI、转接层、部署状态机 | **新增 `C-R13`** |
| 配置归属（同职责目录、单一来源：site、artifacts 锁、sources、flux-source、组件 config；秘密不进普通配置） | **新增 `C-R14`** |
| 平台、应用与命名空间（命名空间对照、common 不经 tpl、foundations 独占共享对象、platform-system） | **新增 `C-R15`**；命名空间表在 `repos/k8s.md`（已有）；platform-system 补进 `repos/k8s.md` |
| 存储与身份恢复（230G 数据盘与挂载、Retain、要备份的东西、同盘不防硬件故障、身份丢失不重建、Git 退回不回滚数据） | `infrastructure/host/README.md`、`gitops/components/foundations/README.md`（已有）；「要备份的」补进 `topics/data.md`；`C-R5`、`C-R12`（已有） |
| 网络、TLS（30443 SNI、HAProxy 不持私钥、未登记域名仍转旧 kind 且旧 kind 受保护） | 总览 §3（已有）；「不持私钥」「旧 kind 受保护」补进 `repos/k8s.md` 的 entry 行 |
| 运行安全基线（默认拒绝、非 root、只读根、去 capabilities、不挂 SA 令牌、有限例外、明文协议靠策略） | **新增 `C-I10`** |
| 在线构建（国内源优先、失败切一次官方源加代理） | `infrastructure/applications/README.md`、AGENTS.md（已有） |
| 版本（固定 manifest 与 SHA、不追 latest） | `C-R3`（已有） |
| 官方镜像优先、RAGFlow 派生受守卫 | **新增 `C-R16`** |
| 发布（已提交对象 → 不可变候选 → 显式晋级） | `C-R4`、`C-R5`（已有） |
| 升级准入 | **新增 `C-R17`** |
| 源码、物料、数据所有权；推回由所有者同步 | `C-R1`、`C-R2`（已有）；「推回不自动」已不是现行做法（远程助手推 qwen 分支、所有者定），不搬 |
| 操作语义（plan / render / stage / check 的副作用；手册写清） | **新增 `C-R18`** |
| 关掉开关不停服、prune=false、不删 PVC、不重建身份、不清 managedFields、不日常 force apply | `C-R11` 补了 managedFields、节点卷与「关闭 enabled 不停服」 |
| 维护窗口 2 小时、容量 10 GiB | `docs/README.md`、`infrastructure/host/README.md`、AGENTS.md（已有） |
| 清理策略先批准、保护在用与回退资源 | **新增 `C-R19`** |

## verification.md

「未完成项」6 条进待办账 104–109（开机恢复剩余验证、Harbor 独立持久化实测、长期空间管理、数据与身份灾备、生产安全与业务补齐、云端建群验证）。其余是 2026-10-03 到 10-06 的带日期验收流水，属于历史，按 Git 历史取。

## component-account-maintenance.md

2026-10-05 那一次「组件拆阶段 + 账号轮换」维护窗口的执行单，已结束，历史。

## 引用

57 个文件里指向这三份的链接：讲规矩的改指 `constraints.md`「发布」，讲「未完成项」的改指待办账 104–109，讲验收记录的改为「已删，Git 历史 `53767f6a:docs/platform/verification.md`」；README、docs/README、总览、`repos/k8s.md` 的入口句手工改顺。门禁：活文档 187 份通过。
