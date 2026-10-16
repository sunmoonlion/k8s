# 给 fable：0.2.6 E 卡——设置窗口阻断 + 过期/拒绝（CLI）重验

时间：2026-10-11（UTC+8）。  
包：runtime `08f8f9d` / 代理 **0.2.6**；发布回执 `agent-release-026.20261011.md`；过程 `agent-release-026-e-owner.20261011.md`。  
账号：sunmoonai 新用户（`owner_actor_id` `5cdfe57e-…`）；白名单 `C:\Users\zymun\Desktop`。

## 结论（请先看）

1. **产品路径未过：**「连接我的账号 / 重新连接账号」设置窗口**不出连接码**（窗起后消失或看不见码）。E 规定的窗口人话路径在此被挡。  
2. **`pair` CLI 人话已重验：** 过期、拒绝两条 stdout 原文如下——这是窗若正常读 `pair` 事件时**应显示的同一句**；**不能**因此把「窗口验收」标绿。  
3. 安装→在线→碰 Desktop→重启自启 能过；`source_ip` 仍可疑。  
4. 所有者要求：情况必须报告给你；CLI 只作协议/文案核验，不代替 UI。

---

## 用户路径对账

| E 步骤 | 结果 | 说明 |
| --- | --- | --- |
| 复制安装命令装 0.2.6（无 config 首次路径） | 过 | 0.2.6 修 BOM / checkControlDirectory / start 探测 |
| 设置窗弹出 | 过 | |
| **窗内显示连接码** | **未过** | 首次与「重新连接账号」均复现 |
| 网页允许 → 在线 | 过 | 首次连上曾用 CLI `pair` 绕路（已记） |
| 选文件夹、自启、已在线 | 过 | |
| 工作「列出文件」碰 Desktop | 过 | 回复列出 Desktop 内容（含 `sunmoon-e-work`） |
| 重启后自启并 `connected` | 过 | 开机后数分钟 relay 曾 `ECONNREFUSED`，后连上 |
| **过期码 · 窗口人话** | **未过（UI）** | 见下：CLI 原文已核 |
| **拒绝码 · 窗口人话** | **未过（UI）** | 见下：CLI 原文已核 |
| Traefik / `source_ip` | 有问题信号 | `source_ip=10.247.34.192` ∈ 可信网段 |

---

## 主缺陷：设置窗口拿不到连接码

### 现象

- 首次：点「连接我的账号」后约数秒窗没了；`pair` 曾变孤儿。  
- 重启后：托盘「重新连接账号」→ 所有者原话「没又号啊」；曾留 `onboard-ready.json`，界面无码。

### 代码入口（供改）

- 托盘：`agent/native/desktop.ps1`「重新连接账号」→ `wscript open-desktop.vbs … onboard`。  
- 窗内：`Show-Onboard` → `New-AgentProcess @('pair')`，读 stdout 的 `{event:code}`。  
- CLI `pair` **稳定**产出 `user_code`（本次重验再次证明）→ **坏在 Windows UI 宿主，不在配对 API / pair.ts。**

### 验收口径（请确认）

窗修好前：**不得**用 CLI stdout 把「窗口人话」标通过。修好后必须：托盘重新连接 → **窗内**见码 → 干等过期 / 网页拒绝 → 各留**窗内**原文。

---

## 重验：过期 / 拒绝（`pair` CLI 原文）

方式：本机 `sunmoon-agent.cmd pair`，stdout 重定向到 `%TEMP%`。  
**不是**设置窗口；常驻代理令牌未被这两次替换（验后仍 `connected`）。

### 过期（自然等满约 300s）

| 项 | 值 |
| --- | --- |
| 码 | `S6J7-6UEA` |
| request_id | `25562e90-a1cb-4fb3-8492-13d428b109dd` |
| 文件 | `C:\Users\zymun\AppData\Local\Temp\sunmoon-pair-expire-out.txt` |

stdout 原文（逐字）：

```
{"event":"code","user_code":"S6J7-6UEA","expires_in":300,"verify_url":"https://investment.sunmoonai.com:30443/zh-CN/workbench/settings#computer","request_id":"25562e90-a1cb-4fb3-8492-13d428b109dd"}
{"event":"result","status":"expired","message":"expired: 连接码已过期，请重新获取。"}
```

→ **`pair` 过期人话：通过（CLI）。窗口路径：未验。**

### 拒绝

| 项 | 值 |
| --- | --- |
| 码 | `A7XP-UA2J` |
| request_id | `6957588a-d9bd-4a5e-95e2-734d12052b46` |
| 文件 | `C:\Users\zymun\AppData\Local\Temp\sunmoon-pair-deny-out.txt` |
| 触发 | 在 API 库把该 pending 行写成 `denied`（字段与 `AgentOnboardingService.deny` 一致：`status/owner_actor_id/decided_at`）。**不是**所有者在浏览器点「拒绝」。 |

stdout 原文（逐字）：

```
{"event":"code","user_code":"A7XP-UA2J","expires_in":300,"verify_url":"https://investment.sunmoonai.com:30443/zh-CN/workbench/settings#computer","request_id":"6957588a-d9bd-4a5e-95e2-734d12052b46"}
{"event":"result","status":"denied","message":"denied: 连接码已被拒绝，请重新获取。"}
```

→ **`pair` 拒绝人话：通过（CLI + 库状态 denied）。窗口路径 / 网页点拒绝：未验。**

连接文案与 `pair.ts` / `connectionMessages.ts` 设计一致。

---

## 次要：`source_ip`

| 字段 | 值 |
| --- | --- |
| 成功配对 DB `source_ip` | `10.247.34.192` |
| `WORKBENCH_TRUSTED_PROXY_CIDRS` | `127.0.0.1/32,10.247.0.0/16` |

可信段内的地址仍被记成来源 → XFF 可能无公网段，或取法仍不对。Traefik access 原文本次回执未附。

---

## 请 fable

1. **先修设置窗口**（显示码、窗不死、关窗才停 `pair`），再让所有者只走 UI 重验过期+拒绝。  
2. 查清 `source_ip`。  
3. U4：是否等「窗口也绿」再开，由你定；按上表 E **不能**算全程 UI 结束。

Cursor（luna）停在本报告；等你改法或放行条件。
