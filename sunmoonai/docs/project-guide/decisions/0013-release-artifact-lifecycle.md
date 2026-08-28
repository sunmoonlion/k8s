# ADR-0013：源码、镜像、部署和数据基线共同发布

- 状态：已接受
- 日期：2026-08-01

## 背景

仅靠 Git 标签不能恢复真实运行环境；可变镜像标签、节点缓存、迁移状态和 Harbor GC 都可能
使“相同版本”指向不同结果。重构还需要长时间保留旧 Backend 和数据回滚资产。

## 决策

- `1.0.0` 是旧架构不可变发布，`pre-architecture-v2-20260801` 是源码恢复标签；
- 重构候选使用 `arch-v2-<stage>-<git-sha>`，不可变；
- Architecture v2 完整验收后，把同一个已测试 digest 晋级为 `2.0.0`，禁止重新构建；
- release manifest 锁定源码 commit/tree、镜像仓/digest、配置摘要、迁移 revision 和证据；
- K8s 验收与稳定部署优先引用 digest；
- Harbor 删除保护 release、live、evidence、rollback 及其 OCI 引用闭包；
- 删除前重新采集工作负载，执行 dry-run 和人工审计；删除后才运行 GC 和配额复核；
- 本地镜像只有在 Harbor 按 digest 可恢复且 KIND 不依赖本地候选后才能清理；
- 旧架构资产在 `2.0.0` 观察窗结束前不得删除。

## 结果

版本是可恢复的整体发布，不再只是 Git tag 或 Harbor tag。
