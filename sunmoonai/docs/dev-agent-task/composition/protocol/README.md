# `protocol/` —— 流程规范

> 依据的通用规范：[多方竞争协议](../../../dev-agent-standards/detailed-rules/protocol/competition-rules.md)

这里放流程规范（`competition-protocol.md`、`competition-operations.md`、`GO.md`）。环节判定由组织者按协议「环节判定」一节的判据核对并留痕。

每次竞争的记录放在所属任务的目录里。

## 文件

| 文件 | 是什么 |
| --- | --- |
| `GO.md` | agent 每个环节的入口：你是谁 → 哪个环节 → 读通知 → 四条禁令 → 卡住怎么办 → 交卷 |
| `competition-protocol.md` | 规范：一次多方竞争怎么走，谁能做什么 |
| `competition-operations.md` | 操作闭环与取件：各环节谁做、产物放哪、验收方怎么算 |

谁参赛、谁裁决、谁验收，都写在每次竞争自己的 `round.md` 里，不另设登记表。

## 投喂

每个环节，所有者在各参赛方的窗口里说同一句话，各家一字不差：

```text
看一下 ~/master/k8s/sunmoonai/docs/dev-agent-task/composition/protocol/GO.md，照做。
```

- **路径必须是主线的绝对路径。**参赛方的分支从 ① 起不再跟进主线，写成相对路径，对方会读到自己 worktree 里的旧 `GO.md`。
- **说完不用再交代别的。**对方读 `GO.md` 后，按 `competition-protocol.md`「收到『继续』时怎么办」自己定位当前环节，再去读该环节的通知，通知里写了交什么、交到哪。
- **看谁交了**：按协议「环节判定」一节的判据查各家已提交的产物。以产物出现为准，不以对方说「做完了」为准。
- **对方报「缺东西 / 字段是空的 / 没有这个文件」**：是供给出了错，交给组织者去修，不要让对方自己想办法。
- **不用命令行一次性投喂**（`codex exec` / `agent -p` / `qoder -p`）：权限开关会把审批提前答掉，所有者当场批不了。

## 所有者的确认

所有者是人，不参赛，也不被投喂。所有者的确认，以**所有者本人署名的提交**为准：git 作者是 `sunmoonlion <13701819268@163.com>`。

agent 的一切提交——参赛产物、代写的组织者文件——一律用 `--author` 署自己的名（例如 `--author="opus <opus@agents.local>"`），所以两者分得开。`GO.md` 第六节的提交命令已带上。
