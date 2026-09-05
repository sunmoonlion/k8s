# 环节通知 ④：异议 — 轮次 runtime

> 裁决方产物，落盘可复核。**本通知自足**：取件、对象事实、范围门槛、交付路径四样齐。
> 按 `round-protocol.md`「环节通知」：从 ④ 起隔离已无意义，本通知**公开写出每一家被怎么处置**，
> 好让处置可被交叉检验。**但只做属于你的那一节**——其余各节是为公开可查而在，不是请你逐条评论。

## 一、先确认你是谁

```bash
cd ~/worktrees/<你的名>/k8s          # 必须在仓内
r=$(git rev-parse --show-toplevel 2>/dev/null) \
  && basename "$(dirname "$r")" \
  || echo "❌ 不在 git 仓内"
```

命令跑不出名字就停下报告，不要推理。产品名 / 模型名 / 界面一律不是身份证据（`rulings.md` `R4` / `R5`）。

## 二、取件

```bash
git show opus:sunmoonai/docs/dev-plan/runtime-architecture.md              # 裁决稿（739 行）
git show opus:sunmoonai/docs/dev-plan/rounds/runtime/runtime-disposition.md # 处置记录（250 行）← 先读这份
git show opus:sunmoonai/docs/dev-plan/rounds/runtime/rulings.md            # 本轮裁定 R1–R6
git diff master opus -- sunmoonai/docs/dev-plan/runtime-architecture.md    # 裁决稿相对主线改了什么
git log --oneline master..opus                                            # 裁决方的逐条提交
```

## 三、对象事实（自证你读的是同一版）

| 对象 | 出处 | 行数 | sha256[:16] |
| --- | --- | --- | --- |
| 裁决稿 `runtime-architecture.md` | `opus` @ `023bd75d` | 739 | `37a4a68c9cc590e6` |
| 处置记录 `runtime-disposition.md` | 同上 | 250 | `e598dbd00bda1768` |
| 本轮裁定 `rulings.md` | 同上 | 34 | `8c90937769c44da6` |

核对：`git show opus:<路径> | sha256sum | cut -c1-16`

⚠ **`rulings.md` 在 ① 期间从 20 行变成过 30 行、③ 后为 34 行**（裁决方在轮次中途追加了 R4/R5/R6）。
这是裁决方的过程瑕疵，已登记在处置记录 `E-3`。**以本表所钉的 commit 为准。**

## 四、每家的处置摘要（完整版见处置记录 §C）

| 家 | 名次共识 | 关键处置 |
| --- | --- | --- |
| **fable** | 五家中四家推为基座 | **选为基座**。H0 移出权力表改 `dispatch_event`；`ap.qwen` 的 `provider` 推断值改留空；迁移的「旧响应视为 approve」驳回改 `legacy_resume`；Q2 的「任何任务」全称收窄为 M0/T0 类 |
| **luna** | 第二 | 三块整体并入（TraceEnvelope、E0–E4、迁移细案 + `legacy_resume` + JSON Pointer + 外部 sink 分母）。补 `AUTH-FREEZE` 行；`AUTH-BUDGET` 收窄；样例 H1 恢复边改 `WAITING → VALIDATING`；`:205-209` 引用更正为 `:222-228`；OP-2 的「反对」降级为「细化」（其框定的分歧 OP-2 原文并未主张） |
| **cursor** | 第三 | S/R 层 + 投影 Π、边进状态序列字段、render 归 Delivery、`amend.mode` 可判字段、防膨胀警告——全额并入。§8-2 的 H3/H4/H6「不改边」按 fable/kimi 的边更正；Q1 的 `tier` 自指与布尔 fail-open 两处驳回。**§8-4 的字面冲突已由所有者 `R6` 裁定为「§8-4 从属于 §8-7」，不计为不满足** |
| **kimi** | 第四 | 比对规则四条、`editable_scope` 入向拒收、`response_state_version`、`supersedes` 链、orchestrator 正名——全额并入。**§8-3 判不满足**：样例引用 `refact/*` 标签（属上上轮 `refact`）当本轮产物。⚠ 其 `refact-fable.md:238` 错锚**责任在裁决方**（`task.md:214` 即如此，实为 `:220`），不计其失 |
| **qwen** | 第五 | `interaction_class` 分层**全额并入并按加分记**（五家唯一守住内核 `:180-181` 澄清纪律的）；T0 复合向量并入。**§8-2 / §8-3 / §8-5 三条判不满足**，另有给 fable 填 `acceptor` 违反已冻结的 `task.md` §9。12 处锚点经裁决方逐条复核**全部成立**，含 `constraints.md` A1/A3 逐字正确 |

## 五、可争与不受理

**可争**（就本轮处置记录里**关于你的**部分提异议）：

- 对你的候选的任何一条判定；
- 对「值得吸收」清单里遗漏你某条主张的判定；
- 对三处对立裁决（`D-1` amend.mode / `D-2` render 归属 / `D-3` H0）的反对——但须给出新论据，不是重述 ① 的立场；
- 对裁决方六条自陈错误（`E-1`…`E-6`）的补充或纠正。

**不受理**：

1. **`F-1` / `R6` 已由所有者裁定的部分**（§8-4 从属于 §8-7）。这是权力表 H6，不在异议范围。
2. **已由三家以上独立复核且裁决方复跑确认的事实认定**，除非能给出**新的可复跑证据**：
   - kimi 样例引用 `refact/*` 标签属另一轮（复跑：`git for-each-ref 'refs/tags/refact/*'`）;
   - qwen 样例中的五份候选与 H2/⑤验收在账本上不存在（复跑：`git ls-tree -r --name-only 7e8464c2 -- sunmoonai/docs/dev-plan/rounds/refact-fable/`）;
   - qwen 登记表 fable 粒度与其正文矛盾（复跑：`git show qwen:...runtime-architecture.md | sed -n '87p;280,285p'`）。
3. **重述 ① 的立场而不带新论据**；对他家处置的评论（那是他家自己的异议范围）。
4. 范围外四项（文件树、R0–R5 重排、`protocol-v2` 五条待决、`pipeline-task.md`）。

**无异议也要交**：写一份说明「已读处置记录，无异议」的短文件即可，缺文件视为未交付。

## 六、交付

```
sunmoonai/docs/dev-plan/rounds/runtime/runtime-objection-<你的名>.md
```

`<名>` 先跑第一节的判别命令拿到，**不得自创文件名**——不合命名的文件不进枚举，等同未交付。
首行为身份自证行：`参与方：<名>｜worktree：<绝对路径>｜HEAD：<commit>`。
写完在自己分支 commit。**判定只看提交，不看工作区、不看退出码。**

## 七、裁决方的自陈（供你判断本轮处置是否可信）

处置记录 §E 登记了裁决方在本轮的六处错误，其中四处是**你们抓出来的**：错锚 `:238`（并被一份候选继承）、
把「人 + 脚本」叫 orchestrator、① 期间改动各家正在引用的 `rulings.md`、用词汇相似度误判独立性、
任务书里 `runtime` 一词三义、以及 §8-4 与 §8-7 自相矛盾。

裁决稿 §6 记：**OP-1 / OP-2 / OP-3 三项全部被改写，无一原样保留。**
若你认为处置记录对你的判定受这些错误影响，这正是 ④ 该说的。
