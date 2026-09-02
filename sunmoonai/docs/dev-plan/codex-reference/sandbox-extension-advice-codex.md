# Codex 沙箱扩展建议：从源码边界出发

> 研究基线：`/home/zymun/repo/codex` @ `3929c99a97`，2026-08-28

## 结论

如果目标是给 Codex 增加更细的文件或网络能力，正确扩展点是“权限 profile + 单命令附加权限 + approval 上限”，不是再造一个布尔 `unsafe` 开关。源码已经把基础权限、用户审批、单次命令请求、企业约束和平台执行后端拆开；扩展应保持这一分层。

对于 Investment 的 Agent 工具，同样应采用“默认拒绝、能力最小化、逐次授权、拒绝规则不可被升级绕过”的模型。尤其不能把业务工具的 approval 与操作系统 sandbox 混为一谈。

## 1. 五层权限模型

1. **文件系统策略**：`read/write/deny` entries，支持绝对路径、glob 与特殊路径。
2. **网络策略**：`Restricted/Enabled`，与文件权限正交。
3. **审批策略**：`UnlessTrusted/OnRequest/Granular/Never`，决定何时可询问用户。
4. **单命令请求**：`UseDefault/RequireEscalated/WithAdditionalPermissions`。
5. **managed requirements**：限制本地配置可选 profile，是权限上限而不是默认值。

`SandboxPermissions` 明确区分完全绕过沙箱与仍在沙箱内临时扩权（`protocol/src/models.rs:46-79`）。因此一般的“多写一个目录”应走 `WithAdditionalPermissions`，只有后端无法表达或执行该能力时才考虑 `RequireEscalated`。

## 2. 访问判定语义

文件 entry 同时比较路径具体程度和冲突优先级：更具体的路径胜出；同等具体程度下 `deny > write > read`（`protocol/src/permissions.rs:92-120, 1605-1610`）。这允许：

```text
/workspace            write
/workspace/secrets    deny
/workspace/cache      write
```

工作区可写并不意味着元数据可写。`.git`、`.agents`、`.codex` 默认是受保护名称；除非对元数据路径给出显式 write entry，否则写入会在执行前被拒绝（`protocol/src/permissions.rs:24-73`）。legacy `WritableRoot` 也携带 read-only subpaths 和 protected metadata names（`protocol/src/protocol.rs:1053-1069`）。

这一点不能为了“方便 Agent 自动配置”而移除，否则可通过 `.git/hooks`、项目指令或 Codex 配置建立持久权限提升链。

## 3. 审批不是授权本身

`AskForApproval` 只控制是否以及何时把请求交给用户：

- `UnlessTrusted`：只自动通过已知安全且只读的命令；
- `OnRequest`：模型显式请求；
- `Granular`：分别控制 sandbox、rules、skill、permission tool、MCP elicitation；
- `Never`：不询问，失败直接回模型。

源码会在非 `OnRequest` 且未预批准时拒绝显式 escalation，而不是偷偷执行（`core/src/tools/handlers/shell.rs:122-137`）。批准结果还可以按 key 缓存为 session approval；缓存的是已批准对象，不是任意后续命令的通行证（`core/src/tools/sandboxing.rs:64-115`）。

## 4. 推荐的扩展顺序

### A. 固定、长期、可审计的目录

定义命名 permission profile：

```toml
default_permissions = "investment-analysis"

[permissions.investment-analysis]
extends = ":workspace"

[permissions.investment-analysis.filesystem]
":workspace_roots" = "write"
"/srv/investment/reference-data" = "read"
"/srv/investment/export" = "write"
"/srv/investment/secrets" = "deny"
```

实际 key/schema 应以当前 `config.schema.json` 为准；上例表达设计意图，不应不经 schema 校验直接投产。

### B. 单次新增目录或 socket

使用 `WithAdditionalPermissions`，将规范化后的精确目录作为本命令附加 entry。运行时仍保留 deny-read 限制；源码测试明确要求 deny-read 阻断显式 escalation 与 policy bypass（`core/src/tools/sandboxing_tests.rs:149`）。

### C. 后端确实无法沙箱表达

才使用 `RequireEscalated`，并要求：

- 明确 justification；
- 命令目标已由只读检查解析成绝对路径；
- prefix rule 只覆盖可复用的窄命令族；
- destructive 命令不提供持久 prefix rule；
- managed policy 仍可拒绝。

## 5. 不建议的做法

- 新增 `allow_all=true` 并绕开 profile 编译。
- 将 network enabled 隐含为 filesystem write 的副作用。
- 将 approval policy 当作 sandbox policy；“never ask”不等于“允许所有”。
- 仅靠命令字符串前缀限制路径；shell 重定向、变量、subshell 和符号链接都会破坏假设。
- 把 `.git/.codex/.agents` 纳入普通 writable root。
- escalation 后丢掉原有 deny-read；这会让“可执行但不可读秘密”的边界失效。
- 在各平台各写一套不一致的权限语义；profile 应先编译成统一中间表示，再交给 Seatbelt/Landlock/Windows backend。

## 6. 对 Investment SandboxPort 的建议

当前 Investment 已有领域 `SandboxRequest/SandboxResult/SandboxPort`。建议将它保持为业务能力端口，不冒充 OS 沙箱，并增加：

```text
SandboxRequest
├── tenant_id / actor_id / run_id / invocation_id
├── action: read_file | write_artifact | run_query | execute_code
├── resource_refs[]
├── requested_capabilities[]
├── idempotency_key
└── budget

Decision
├── allow | deny | require_approval
├── effective_capabilities[]
├── policy_version
└── reason_code
```

OS sandbox 负责进程/文件/网络隔离；业务 policy 负责 tenant、数据集、工具、金额或风险等级。两者都通过才执行。任何外部副作用使用 outbox/idempotency ledger，不能因 OS 命令成功就认为业务事务完成。

## 7. 验证清单

- 路径规范化与 symlink alias 是否保持 deny？
- 相同路径冲突是否稳定执行 `deny > write > read`？
- 缺失的 `.codex/.git/.agents` 能否被新建？应不能。
- 附加权限是否只作用于一次命令/一次已批准 grant？
- `Never` 和 Granular 禁用时是否无 UI prompt 且明确失败？
- escalation 是否保留 deny-read？
- Linux/macOS/Windows 的实际 enforcement 是否与统一策略相同？
- 日志是否记录请求能力、有效能力、批准来源与 policy version，但不记录秘密正文？

## 源码索引

- 单命令权限枚举：[models.rs](/home/zymun/repo/codex/codex-rs/protocol/src/models.rs:46)
- approval 与 legacy sandbox：[protocol.rs](/home/zymun/repo/codex/codex-rs/protocol/src/protocol.rs:898)
- 文件权限算法：[permissions.rs](/home/zymun/repo/codex/codex-rs/protocol/src/permissions.rs:92)
- profile 编译：[config/permissions.rs](/home/zymun/repo/codex/codex-rs/core/src/config/permissions.rs:347)
- shell 审批入口：[shell.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/handlers/shell.rs:88)
- orchestration primitives：[sandboxing.rs](/home/zymun/repo/codex/codex-rs/core/src/tools/sandboxing.rs:1)
