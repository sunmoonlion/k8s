# V5 镜像版本治理与 React 迁移发布规则

状态：`DRAFT_FOR_REVIEW`（2026-07-14）

## 结论

1. `P0-007B` 是实施阶段号，不是 Harbor 镜像版本号。
2. 当前三个 Admin Backend 已接受的 `1.0.1` 保持不变且不可变。
3. Info React 的 `p0-007b-*` 仅是 candidate；本阶段不提升为 `1.1.0`，也不覆盖现有 `1.0.1`。
4. 当前 Info `1.0.1` 前端仍是 Vue 回滚基线。Knowledge/Research 尚未完成 React Admin 迁移，不能删除 Vue 回滚资产。
5. 三个 Admin React 迁移完成后，再通过单独 release decision 选择正式版本，并生成一份统一 release manifest；在此之前不得执行任何正式 retag/push/deploy。

## 当前资产矩阵

| 资产 | 当前状态 | 处理规则 |
| --- | --- | --- |
| Info/Knowledge/Research Admin Backend `1.0.1` | 已接受稳定版本 | 不覆盖、不删除；部署按 digest 核对 |
| Info Admin Frontend `1.0.1` | 旧 Vue 基线 | 仅作回滚；不把 React candidate 直接推成同名 tag |
| Info React `p0-007b-*` | 通过隔离验收的 candidate | 保留 digest；不作为普通部署默认值 |
| Knowledge/Research Admin Frontend | 尚未完成 React 迁移 | 继续按各自现状运行，不提前切换 |
| tpl-admin-frontend candidate `p0-007c-*` | 模板冻结候选 | 只作为后续实例迁移输入，不等同于业务 App 正式 release |

## 不允许的操作

- 不能把同一个 `1.0.1` tag 从 Vue digest 改指向 React digest。
- 不能因为“阶段版本都想写成 1.0.1”而覆盖 Harbor stable tag。
- 不能在三个 Admin 迁移完成前删除 Vue 镜像、Git 回滚 tag 或其 digest 记录。
- 不能把 Info 单独提升为 `1.1.0`，再让其他组件继续使用 `1.0.1`，除非新的 release decision 明确接受组件级版本差异。

## Vue 退出条件

Vue 只能在以下条件全部满足后退出 active path：

- Info、Knowledge、Research Admin 均完成独立 React 等价迁移和真实业务验收；
- 每个 App 均有迁移前 Git tag、旧镜像 digest、React candidate digest、隔离验证和回滚演练；
- 统一 release manifest 已冻结，正式 Deployment 已按 digest 验证并经过观察期；
- 旧 Vue 资产已归档到只读回滚位置，而不是通过删除或复用 tag 隐藏。

## 待 operator 核对的历史问题

当前本地证据能够确认 `p0-007c-*` candidate digest，但不能证明历史上是否曾经用相同的
`tpl-admin-frontend:1.0.1` tag 重新 push 过镜像。该事实必须通过 Harbor 的 tag/digest
审计或 registry inspect 核对；在核对前不得声称该 tag “没有变化”。如果确认发生过复用，
将其记录为历史治理缺陷，不再继续复用 stable tag。

