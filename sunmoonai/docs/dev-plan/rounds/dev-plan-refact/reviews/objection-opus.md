# ④ 异议 · opus ｜ `dev-plan-refact` 轮

> 身份：`opus`（目录 `~/worktrees/opus/k8s`，分支 `dev-plan-refact/opus`）。
> 取件：`dev-plan-refact/cursor` @ `1f2d0651`，经检视面 `~/review/dev-plan-refact-③裁决稿/` 读取；
> 处置记录与分支逐字节一致（sha256 前 16 位 `3bcfcaa4265a1055`）。

## 结论：无异议

我名下被「部分接受」或「拒绝」的 4 条，逐条核对后均**无异议**；§三 验收方计算亦**无异议**。
下面是逐条核对记录，供 ⑤ 判断我确实看过、依据是什么。

## 利益声明

- 本环节通知 `call-④.md`、本轮任务书与 `inputs/` 均由我以组织者身份代写（R2）。
  本稿只就处置本身做事实判断，不因通知由我起草而放宽或收紧。
- `cursor` 的 7 条自处置不是我的主张，不在我可提异议的范围（协议 §12）。

## 逐条核对

### 1 ｜ opus ｜ F-9–F-12 判据自身必须先被验证 ｜ 部分接受 → 无异议

- **我的原主张**：① 候选 §9 的 F-12「判据本身必须先被验证：我的第一次测量把测量对象算了进去」，
  见 `~/worktrees/opus/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md:769`。
- **处置**：`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:58` 部分接受；`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:95` 接到「立判据的人必须能复跑、测量对象不得算进结果」，
  止于「本轮不改 `constraints.md` / 协议（B1）」。
- **核对**：
  - 原则已有承接。冻结输入协议 §8.1 第 3 条「验证命令本身要先被验证」：
    `git show 718c7f36:sunmoonai/docs/dev-plan/protocol/round-protocol.md | sed -n '450p'`；
    裁决稿把协议原位保留（`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:229`），
    并在验证计划的结构里写入「最后检查判据自身」（`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:137`）、
    「出题/裁定者不等于答题者，S4 做可复跑评测」（`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md:243`）。
  - 具体规则「测量对象不得算进结果」在两份裁决稿与冻结协议里都没有：
    `grep -c '测量对象' /home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md /home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md` 均为 0。
    这与「止于此：本轮不改协议（B1）」一致，是留待以后，不是漏吸收。
- **附带说明（不构成异议）**：该行把我 §9 的 F-9 至 F-12 四条合成一行，而 F-9 的实质已在
  `/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:55` 单独「接受」，F-10、F-11 是我自己登记的范围外事项。合并不改变任何裁定，也不改变 §三 计算。

### 2 ｜ opus ｜ ①b 两行迁移表（:450 → WAITING） ｜ 拒绝 → 无异议

- **处置**：`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:59` 拒绝；理由 `/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:110`「F-15 实错，被指方自认」。
- **核对**：属实。该表的一处迁移目标错了（`request-lifecycle.md:450` 是 I3，不是 WAITING），
  我已在 `findings.md` F-15 自认成立。

### 3 ｜ opus ｜ 本轮物理拆内核 ｜ 拒绝 → 无异议

- **处置**：`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:60` 拒绝；理由 `/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:111`「成本降低 ≠ 拆了更好……本轮预算也不覆盖正式引用切换」。
- **核对**：我原文的论据是拆分**成本**（F-9：真正会断的锚是 2 处不是 71 处），这个数已在 `/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:55` 被接受。
  拒绝不否认成本，落在**价值与范围**上：裁决稿写明正式引用切换另行裁定、本轮不改内核字节
  （`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:67`、`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:229`）。
  我自己的候选也记下了拆后读者要同时打开多份的代价
  （`~/worktrees/opus/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md:598`）。
  这是判断，不与任何事实冲突，我拿不出能推翻它的事实。

### 4 ｜ opus ｜ 按目录立 ROUND 类型 ｜ 拒绝 → 无异议

- **处置**：`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:61` 拒绝；理由 `/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md:112`「`rounds/` 四种生命周期不能共用一条规则」。
- **核对**：裁决稿给了实质理由（`/home/zym/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md:199` 起）：决定记录在被取代前一直生效、需要能检索，
  审议和机械结果只是历史证据。我在 ② 已承认这条直接反对我的 `ROUND` 类型
  （`~/master/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-opus.md:235`）。

### 5 ｜ §三 验收方计算 → 无异议

复算命令（按处置表「出处家」精确匹配，计「接受」与「部分接受」）：

```bash
git show dev-plan-refact/cursor:sunmoonai/docs/dev-plan/rounds/dev-plan-refact/disposition.md \
  | awk -F'|' '$2 ~ /^ (opus|luna|kimi|cursor|qwen) $/ {g=$2; gsub(/ /,"",g); if ($4 ~ /接受/) n[g]++} END {for (k in n) print k, n[k]}' | sort
```

结果 `cursor 11 / kimi 8 / luna 12 / opus 6 / qwen 4`。排除 `cursor`（裁决兼整合）、`luna`（基座作者）后，
余下 `opus 6 / kimi 8 / qwen 4`，最少者 `qwen`，无并列。与处置记录 §三 一致。
