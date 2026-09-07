# Spike ｜ `codex` 的可编程接入面（2026-09-07，组织者实测）

> 工单 D1 要求「每家一份最小 spike 记录」。本文是 **codex 家**（`luna` / `kimi`）那一份。
> 轮次仍为 DRAFT（协议只允许一个 ACTIVE 轮次）；本文是组织者取证，**落为该轮只读输入**。
>
> ⚠ 本文只回答「**接口提供什么**」。它**不回答**「跑起来是否如此」——
> 端到端实跑属该轮 D1 的后半，未做。**不得据本文写成「已接线」**
> （同一形态的教训见 `agent-dev-guide` 里 `NotImplementedError` 那条）。

## 一、结论：审批可以回到调用方，并且可以被答复

工单 §2.1 的三问，对 codex 家的答案：

| 问 | 答 | 依据 |
| --- | --- | --- |
| 运行时能否**收到**审批请求 | **能** | 协议定义了 `ExecCommandApprovalParams`、`ApplyPatchApprovalParams`、`FileChangeRequestApprovalParams`、`PermissionsRequestApprovalParams`、`McpServerElicitationRequestParams` |
| 能否**答复** | **能** | 上述每一个都有配对的 `…Response` |
| 答复后能否**继续同一次执行** | **接口形状支持**（审批是同一 turn 内的往返），⚠ **未实跑验证** | `ReviewDecision` 含 `approved` = "the agent should execute it" |

## 二、取证

```bash
codex app-server generate-json-schema --out <DIR>     # 协议全量 JSON Schema
```

### 2.1 审批类消息（成对存在 = 有请求有响应）

```
ExecCommandApprovalParams / Response          每条命令
ApplyPatchApprovalParams / Response           每次改文件
FileChangeRequestApprovalParams / Response
PermissionsRequestApprovalParams / Response
CommandExecutionRequestApprovalParams / Response
McpServerElicitationRequestParams / Response  询问
PermissionProfileListParams / Response        权限档位可枚举
ItemGuardianApprovalReviewStarted/CompletedNotification
```

### 2.2 请求带什么（**这决定能不能「拦」**）

`ExecCommandApprovalParams` 的字段：

```
approvalId  callId  command  conversationId  cwd  parsedCmd  reason
```

`parsedCmd` 是结构化的 `ParsedCommand`，**含被读文件的路径**
（schema 原文：「Path to the file being read by the command…resolved against the `cwd`」）。

### 2.3 可以答什么

`ReviewDecision` 八个取值：

| 取值 | 含义 |
| --- | --- |
| `approved` | 批准本次，agent 执行 |
| `approved_for_session` | 批准且本会话后续同类不再问 |
| `approved_execpolicy_amendment` | 批准并落一条执行策略修正 |
| `approved_mcp_policy_amendment` | 批准并修正该 MCP 工具的策略 |
| `network_policy_amendment` | 持久化一条网络策略（allow / deny） |
| `denied` | 拒绝本次，但流程继续 |
| `abort` | 拒绝且中止 |
| `timed_out` | 自动审批复核超时 |

## 三、这对本项目的两处直接后果

1. **今晚「无法回答『有没有绕过』」的问题，在这个接口下可以当场解决。**
   2026-09-06 查参与方是否读了禁读文件，只能事后 `grep` 组织者抓的 stdout，
   等级 `reported`——「日志里没看到」≠「确认未读」。
   而 `ExecCommandApprovalParams.parsedCmd` 带被读文件路径，
   **是可见且可拒的**，等级可达 `tool.enforced`。
2. **`denied` 与 `abort` 分开，正对应「拒绝本次」与「拒绝且中止」**，
   而 `timed_out` 是协议自带的超时档——与协议 §14.1「最后一道关卡不设超时默认」
   的关系须在该轮判定：**接口提供超时默认，不等于我们该用它。**

## 四、其他事实

- `codex mcp-server`（stdio MCP）握手成功，`protocolVersion 2024-11-05`，
  暴露 `codex`（起会话，带 `sandbox` 参数）与 `codex-reply`（按 `threadId` 续接）两个工具；
  但它 **自报 deprecated**（"will be removed in a future release"），
  且 `initialize` 只声明 `capabilities.tools`，**未声明 elicitation**——
  审批大概率不会经它回到调用方。**继任者是 `app-server`。**
- `app-server` 标 `[experimental]`，另有 `daemon` / `proxy` / `generate-ts` 子命令。

## 五、覆盖声明

**查了**：`codex app-server generate-json-schema` 的全量输出；`ExecCommandApproval` 的
请求与响应两份 schema 原文；`codex mcp-server` 的 `initialize` 与 `tools/list` 实际响应。

**没查**：`app-server` 的实际启动与会话流程；审批请求是否真的在 turn 内送达；
答复后是否真的原地继续；`qoder` 与 `cursor-agent` 两家的对应接口（**另两份 spike，未做**）。

**未验证 ⚠**：全文所有「能」都是**接口声明层**的能，不是**跑通层**的能。
