# Cursor 回执：0.2.6 首次安装路径

时间：2026-10-11（UTC+8）。依据 k8s `388649f1` 最后一节。

## 改动（runtime `08f8f9d`）

1. `install.ps1.tmpl` 去掉 UTF-8 BOM；注释写明 `irm | iex` 不能带 BOM。全新安装不再在装完后立刻 `autostart enable`，只在 `config.json` 已存在（升级）时补开自启。
2. `checkControlDirectory`：没有 `config.json` 时 `mkdir` 后按空白名单 `assertWindowsHome`；`cli` 的 `autostart` 移到 `loadConfig` 之前。
3. `start()`：win32 且没有 `windowsSandbox` 时先 `detectWindowsSandbox` 并写回配置。

Linux 全新状态用例在 `agent/test/freshInstall.test.ts`。`pnpm test` 217 通过 / 32 跳过，`tsc` 干净，`bundle.test.mjs` 32 通过（断言模板不以 BOM 开头）。

## 组包与上传

| 项 | 值 |
| --- | --- |
| 目录 | `C:\Users\zymun\sunmoon-probe-runs\windows-agent-c2-20261010\sunmoon-agent-08f8f9d` |
| ZIP | `sunmoon-agent-0.2.6-08f8f9d-windows-x64.zip` |
| 大小 | 175307261 |
| ZIP SHA256 | `351a765956b359e19c2877520c71cf21bfa0c3c30f159395e6c0c2397a30acfc` |
| 清单 SHA256 | `ba95669c44a24f6ecfaff073be27570960f0ac2aaf7abd623581d2488ccb9035` |
| 源码 | `08f8f9dfb20b79b5483dc324a30c6fc9a9fefee6` |
| 对象键 | `windows-x64/0.2.6/sunmoon-agent-0.2.6-08f8f9d-windows-x64.zip` |

`windows-candidate.mjs`（包内 Node）：`result: pass`，agent 0.2.6，Codex 0.155.1，Node 24.19.0，98 文件，未启动代理。`agent-release-verify` 通过。`agent-release-upload`：`uploaded: true`，`readback_verified: true`。

安装模板 runtime 与 k8s `agent-releases/install.ps1.tmpl` 逐字节相同，SHA256 `c797221de5dc9304d722771d38f40093712c2b6e568c2d1a05e75106a4a1b5a1`，无 BOM。

## 发布

只 stage 投资。差异：`agent-releases/config.yaml`、`install.ps1.tmpl`、`runtime/agent-releases.sops.yaml`、四处 `config-sha256`（`ee4a46c6…8781`）。后端镜像未换，仍是 `b09a366f3d71…`。

| 项 | 值 |
| --- | --- |
| stage | `42d2d7da` |
| 发布摘要 | `sha256:43ccc0798285b6cd2a5e14ebb8583150b991202cbd18d32be53c3abb6f09f014` |
| 晋级 | `eed658b2` |
| 回退点 | 摘要 `sha256:7884dbc6…bd3f`，修订 `a0fcdce6` |

`make application-check APP=investment` 退出码 0：

```
{
  "browser_ui_clicks_verified": false,
  "business_provider_configured": false,
  "entry_port": 29443,
  "install_command_issued": true,
  "web_member_organization": "sunmoonai"
}
```

## 所有者首次路径（待做）

机器上仍是 0.2.5、没有 `config.json`。请从网页「复制安装命令」再走一遍：升级卸 0.2.5 → 装 0.2.6 → 弹设置窗口 → 连接账号 → 输码允许 → 选文件夹 → 自启（第三步勾上）→ 完成 → 已在线。每步原文进下一份回执。之后继续重启 / 过期码 / 拒绝码。
