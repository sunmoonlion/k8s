# sunmoon-link：本地代理

> 最后更新：2026-10-17 ｜ 由 runtime 改名 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

用户电脑上唯一要装的东西。中文叫**本地代理**，英文 2026-10-16 定为 **sunmoon-link**（命令、安装包、Windows 计划任务现在还叫 `sunmoon-agent` / `SunMoonAgent-*`，下次发 Windows 版时顺带改；协议字段、代码内部命名不改；仓名 2026-10-17 由 `runtime` 改为 `sunmoon-link`，[决策](../../dev-investment-agent/tree-build/decisions.md)、[0028](../../dev-investment-agent/tree-build/SDD/modules/0028-knowbench-rename.md)）。它**只做转发与本机把关**：包着钉版的 `codex exec-server`，出站连会合点，让云端沙箱里的 Codex 能在用户允许的范围内读写本机文件；不跑模型循环，不接触模型 key。不参与集群部署，不要求与平台仓并列。

## 结构

```text
sunmoon-link/
├── agent/                 本地代理（Node / TypeScript，包名 @sunmoon/agent）
│   ├── src/               cli、配对（pair*）、会合点客户端与协议（relayClient、relayProtocol）、exec-server 封装、
│   │                      本机上限与过滤（permissions、filter、outerSandbox、localConfirm）、本地文件与项目、常驻与服务、Windows 引导
│   ├── distribution/      安装包：构建、打包、安装 / 升级 / 卸载、Windows 模板（install.ps1.tmpl、windows-x64.json）
│   ├── native/            Windows 原生辅助脚本（提权准备、隐藏运行、桌面快捷方式）
│   ├── contracts/         relay-permissions.lock.json（会合点权限回执契约的锁）
│   └── test/              vitest
├── probe/                 早期探针与联调脚本（app-server、exec-server、两机桥接）
└── scripts/               联调脚本与回执 results/
```

## 关键事实

- **执行隔离**：Windows 用内层 Codex 沙箱 + 严格协议过滤（不嵌套外沙箱；`init` 实际试跑受限命令，有可用的 elevated 环境优先用，否则探 unelevated，都不行就拒绝启动，不自动提权）；Linux 用 bwrap 外沙箱。
- **本机上限**（`C-A11`）：根目录白名单、沙箱模式、网络；越出的写与对外动作本机当面确认；放宽类改动要在本机确认窗里点允许。
- **版本成对**（`C-C8`）：exec-server 与沙箱里的 app-server 钉同一版，会合点在握手里核对，不匹配拒绝连接。
- **安装与配对**：网页「接入电脑」给一行命令；安装包由 knowbench 发放（对象存储桶 `agent-releases`）；连会合点用 knowbench 签发、会合点就地验签的短期令牌。
- **数据不经云端**：用户在别的电脑上看不到这台电脑的文件，文件只在装着代理的那台电脑上。

设计：[0005 代理](../../dev-investment-agent/tree-build/SDD/modules/0005-agent.md)、[0012 Windows 安装与首次接入](../../dev-investment-agent/tree-build/SDD/modules/0012-agent-onboarding.md)、安全模型见 [`SDD/architecture/security.md`](../../dev-investment-agent/tree-build/SDD/architecture/security.md)「本地上限」。

## 发版

走发布卡：在 sunmoon-link 仓里构建 Windows 安装包 → 改 `k8s/gitops/components/app-platform/knowbench-app/knowbench-backend/agent-releases/config.yaml`（版本、ZIP 与清单摘要、对象名，唯一输入）→ `make -C infrastructure agent-release-verify` / `agent-release-upload AGENT_ZIP=<绝对路径>` 校验并条件上传 → 按发布链部署 knowbench → 在所有者的 Windows 上真机验。说明见该目录 `README.md`。
