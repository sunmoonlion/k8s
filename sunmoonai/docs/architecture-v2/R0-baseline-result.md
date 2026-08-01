# Architecture v2 R0 旧架构封板结果

日期：2026-08-01

结果：`PASSED`

## 1. Git 封板

- 12 个实例组件仓、3 个实例父仓和 k8s 的 `codex-1` 已受控归并至 master；
- 分叉仓使用双亲 merge commit 保留历史，最终普通文件 tree 以 codex-1 为准；
- 三个父仓只允许子模块 gitlink 指向已归并的组件 master；
- k8s master 独有的旧拓扑 Worker PVC 结果未进入权威 tree，但提交仍保留在历史中；
- 7 个模板组件仓和 tpl-app 原本已处于同步 master；
- 24 个源码仓均建立 `pre-architecture-v2-20260801` 标签；
- 16 个本地和远端 `codex-1` 均已删除；
- 12 个实例组件仓、3 个实例父仓、4 个默认模板组件仓、tpl-app 和 k8s 共 21 个仓已建立并推送 `architecture-v2`；
- React Router、Vue、Nest 三个参考仓保留在 master，不进入默认架构施工链。

完整 commit/tree 锁见 `pre-refactor-source-lock.json`。逐项验证结果：24/24 commit、tree、
基线标签一致。

## 2. 镜像与 Harbor 封板

镜像锁 `pre-refactor-image-lock.json` 共保护 35 个 artifact：

- 19 个 `1.0.0` 发布 artifact；
- 13 个 KIND 当前工作负载引用 artifact；
- 3 个 P0-008C 证据候选 artifact。

只读验证结果：

```json
{"result":"passed","locked_artifacts":35,"release_artifacts":19,"live_artifacts":13,"credentials_printed":false,"mutation_performed":false}
```

原 `prune_v1_harbor.py` 会把 3 个 P0-008C 证据候选误判为删除对象，现已改为强制读取
Architecture v2 锁。修正后的 dry-run 结果：

```json
{"result":"dry-run","repositories":19,"protected_artifacts":35,"delete_candidates":0}
```

本阶段未删除、重建、重新标记或推送任何镜像，未执行 Harbor GC，也未改变 KIND 工作负载。

## 3. R0 退出条件

- 源码可由 master 或基线标签恢复：通过；
- 镜像可由锁定 digest 恢复：通过；
- master 保持稳定、施工仅进入 architecture-v2：通过；
- codex-1 不再作为并行事实源：通过；
- Harbor 清理不会误删发布、live、evidence 或 rollback artifact：通过；
- 工作区无架构代码改动：通过。

R0 已关闭。下一步仅进入 R1 架构与迁移 ADR 冻结。
