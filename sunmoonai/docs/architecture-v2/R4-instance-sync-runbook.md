# Architecture v2 R4 实例同步规则

状态：`ACTIVE / INFO DONE / KNOWLEDGE DONE / INVESTMENT RENAME NEXT`

唯一模板源：`architecture-v2-r3.2-20260808`。R3.1 仅保留为历史证据，不得继续作为新同步目标。

R4 只允许按 `Info -> Knowledge -> Research` 串行同步同一个已验收模板 release。前一个实例未完成
源码、配对、身份、数据库与回滚门禁时，不得修改下一个实例。

## 1. 三方比较

`scripts/sync_r4_instance.py` 对每个组件比较：

1. 实例原先继承的模板 commit；
2. release manifest 锁定的新模板 commit；
3. 实例当前 commit。

同步器要求实例仓 clean 且 HEAD 与配置完全一致。任何本地差异必须归入
`domain-extension`、`deployment-config` 或 `temporary-compatibility`；未分类差异记为
`prohibited-drift`，计数非零时禁止写入。

## 2. 禁止全局名称替换

不得把 `tpl`、`template` 或 `Template` 做正则或全局单词替换。它会破坏合法标识，例如：

- CSS `grid-template-columns`；
- Next.js metadata 的 `template` 键；
- npm 包 `@babel/template`；
- 面向所有 App 的 `z.enum(['tpl', 'info', ...])` 合同。

实例化只允许配置中的“精确字符串 + 可选路径 glob”白名单。同步器回归测试必须证明上述合法标识
保持不变。

## 3. Migration 边界

R4 不拼接模板 Alembic root。每个实例继续保留当前规范数据库历史；模板 auth/outbox migration
必须由 `skip_template` 显式记录 owner 和 R5 截止阶段。R5 再以实例当前 head 为
`down_revision` 重建统一 migration，并完成备份、恢复、数据对账和切换。

## 4. 冲突处理

- `target`：采用已验收共同实现，适用于安全、构建、环境 schema、配对测试等共同能力；
- `local`：只允许保留有明确差异类别的领域扩展或部署配置；
- `merge`：只接受无冲突三方合并，真实冲突仍失败；
- `skip_template`：只用于阶段边界明确、带 owner/deadline 的暂缓项。

所有 `target/local/merge/skip` 条目必须写明原因；`temporary-compatibility` 必须同时写明 owner
与截止阶段。禁止用宽泛的 `tests/test_*` 等规则掩盖共享安全测试漂移。

## 5. 执行顺序

每个组件执行：`plan -> prohibited-drift=0 -> 临时工作区 apply -> 测试 -> 实例 apply -> 测试 ->
提交 -> clean commit 再 plan -> 证据固化`。每个 App 还必须通过 Admin/Backend、Web/Backend、双端
身份隔离、KIND、严格 TLS 和原生回滚门禁，才可进入下一个 App。

模板在 R4 前若发现缺陷，必须先修模板、更新 release manifest、重建镜像并复验受影响的 R3
门禁；不得在实例仓静默打补丁后继续扩散。

## 6. 串行进度

- Info：`DONE`，见 `R4-info-result.md` 与 `evidence/R4-info-gate/`；
- Knowledge：`DONE`，见 `R4-knowledge-result.md` 与 `evidence/R4-knowledge-gate/`；
- Investment：`NEXT`，以 Research 历史为主体原地改名，必须继续使用
  `architecture-v2-r3.2-20260808`；见 `../investment清理和改名.md`。
