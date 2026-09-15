# `protocol/` —— 流程规范

> 依据的通用规范：[多方竞争协议](../../../dev-agent-standards/protocol/competition-rules.md)

这里放流程规范（`competition-protocol.md`、`GO.md`），以及执行规范用的脚本 `competition-status.py`。脚本跟着规范改；两边对不上时以规范为准。

历次竞争的产物在 `dev-plan/rounds/`（历史目录名，冻结不改），这里放流程本身。

## 文件

| 文件 | 是什么 |
| --- | --- |
| `GO.md` | agent 每个环节的入口：你是谁 → 哪个环节 → 读通知 → 四条禁令 → 卡住怎么办 → 交卷 |
| `competition-protocol.md` | 规范：一次多方竞争怎么走，谁能做什么 |
| `competition-status.py` | 从 git 提交推出当前环节、本环节通知在哪、组织者是谁；判定前先查本次的角色配置；`--verify` 判 ⑤ 里能机器判的部分 |

调用方式和退出码写在 `competition-protocol.md` 的「8b. 脚本怎么调」。改了脚本参数，必须同步改那一节。

谁参赛、谁裁决、谁验收，都写在每次竞争自己的 `round.md` 里，不另设登记表。

## 投喂

每个环节，所有者在各参赛方的窗口里说同一句话，各家一字不差：

```text
看一下 ~/master/k8s/sunmoonai/docs/dev-plan/protocol/GO.md，照做。
```

- **路径必须是主线的绝对路径。**参赛方的分支从 ① 起不再跟进主线，写成相对路径，对方会读到自己 worktree 里的旧 `GO.md`。
- **说完不用再交代别的。**对方读 `GO.md` 后，自己跑 `competition-status.py` 算出当前环节，再去读该环节的通知，通知里写了交什么、交到哪。
- **看谁交了**：`cd ~/master/k8s && python3 sunmoonai/docs/dev-agent-task/composition/protocol/competition-status.py`，看「缺」那一行。以产物出现为准，不以对方说「做完了」为准。
- **对方报「缺东西 / 字段是空的 / 没有这个文件」**：是供给出了错，交给组织者去修，不要让对方自己想办法。
- **不用命令行一次性投喂**（`codex exec` / `agent -p` / `qoder -p`）：权限开关会把审批提前答掉，所有者当场批不了。

## 所有者的确认

所有者是人，不参赛，也不被投喂。所有者的确认，以**所有者本人署名的提交**为准：git 作者是 `sunmoonlion <13701819268@163.com>`。

agent 的一切提交——参赛产物、代写的组织者文件——一律用 `--author` 署自己的名（例如 `--author="opus <opus@agents.local>"`），所以两者分得开。`GO.md` 第六节的提交命令已带上。
