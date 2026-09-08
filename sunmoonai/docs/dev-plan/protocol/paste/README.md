# 投喂话术模板 ｜ 交互会话用

`dispatch.md` 是**一次性命令行**的形态；这一份是**交互会话里贴的那句话**的形态。
两者的区别与取舍写在 `dispatch.md` 开头（agent 卡住时人当场能处理）。

## 为什么路径全是写死的

`rounds/dev-plan-refact/findings.md` **F-17**：2026-09-08，整合方按 GO.md 停下，
报了四条「缺东西」，四条全部属实——**在它的分支上**属实。它的分支冻结在四小时前。

GO.md 里早就写着「通知去主线读」，**但那句话只存在于主线那一版上**：
要读到它，得先知道去主线读。**修「读错地方」的修法，写在了只有读对地方的人才看得见的地方。**

由此得出（`artifact-lifecycle-notes.md` §28 / L-7）：

> 真正的入口不是 `GO.md` 这份文件，**是所有者在窗口里说的那句话**。
> 它是全系统唯一一条**不经过任何投影**的通道——所以它必须自带绝对路径，
> 而不能靠人记得写对。

**所以模板里没有「路径」这个空。**要填的只有 `{家名}` `{环节}` `{轮次}`，填错了对方会立刻报错，
不会像 F-17 那样静默地读到一份旧的还以为是新的。

## 用哪一份

| 情况 | 文件 |
|---|---|
| 常规派发（任何环节） | `派发.txt` —— 通常整段贴，一个空都不用填 |
| 对方报「缺东西 / 字段是空的 / 没有这个文件」 | `过期投影.txt` |

⚠ **先别信「它搞错了」。**F-17 那次，对方报的四条全对。
拿到这种报告的第一动作是核实**主线上**是什么、**它分支上**是什么——两边不一样就是本文这一类。

## 自动填

```bash
cd ~/master/k8s
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste            # 当前环节还缺的家
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste cursor     # 指名一家
python3 sunmoonai/docs/dev-plan/protocol/round-dispatch.py --paste cursor --stale   # 用过期投影那一份
```

轮次、环节从 `round-status.py --json` 取，**不用手填**。
