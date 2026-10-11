# Cursor 回执：0.2.6 E 所有者路径（做到「碰文件夹」）

时间：2026-10-11（UTC+8）。接 `agent-release-026.20261011.md`。账号为 sunmoonai 组织新用户（`owner_actor_id` `5cdfe57e-…`）。

## 已核到的现场

| 项 | 值 |
| --- | --- |
| 代理 | 0.2.6，`relay.status=connected`，roots=`C:\Users\zymun\Desktop` |
| 环境 | `18e9634c-…` online，`agent_version=0.2.6` |
| 自启 | `autostart status` → `installed:true` `enabled:true`，任务名 `SunMoonAgent-5b4377b497ee820ab8d076cf` |
| 开始菜单 | `SunMoon 代理.lnk` 在 |
| 沙箱 | `4c67dcfb-…` ready，relay_user `u-5cdfe57e345f` |

## 配对与 `source_ip`

成功配对一条（`status=delivered`，`decided_at` 02:45:07Z，`delivered_at` 02:45:09Z，机器名 `zymun`，代理 0.2.6）。此前同机有多条 `expired`（窗口「连接我的账号」退出后 CLI `pair` 绕路才成）。

| 字段 | 值 |
| --- | --- |
| 后端 `source_ip` | `10.247.34.192` |
| Pod 环境 `WORKBENCH_TRUSTED_PROXY_CIDRS` | `127.0.0.1/32,10.247.0.0/16` |

`10.247.34.192` 落在已声明的可信网段里，却仍被记成 `source_ip`——说明从右往左跳过可信地址之后，链上没有留下真实来源（或 XFF 本身只有这一段）。**未验** Traefik 访问日志原文（本回执写时未抓到带 pairing 的 access 行）。

## 「连接我的账号」窗口（未过，CLI 绕路）

设置窗口点「连接我的账号」后约 8 秒桌面进程退出，配对轮询变孤儿；所有者用 CLI `pair` 拿到码（例 `BFXQ-WEX9`，已用毕），网页允许后配置写出、代理在线。此缺陷仍在 0.2.6，记给 fable，本包未修。

## 项目与碰文件夹

所有者新建项目：

- 标题 `Desktop`，`path=""`，`workspace_root=C:\Users\zymun\Desktop`
- 项目 id `e531b9e3-4b49-4f5e-ae0f-d1336dcb9570`（挂在当前 online 环境）

工作会话：

- id `fd64dba7-…`，kind=`work`，title=`列出文件`，`project_root=C:\Users\zymun\Desktop`
- 命令：`session.start_thread` done、`turn.start` done（payload text=`列出文件`）
- 桥：`stream bridged` 02:54:58Z；02:59:29Z 起有多条 `fs/getMetadata` 被本机白名单拒绝（路径在 roots 外）——不影响本次列目录

助手回复原文（节选，会话事件 `item/completed`）：

```
当前目录 `C:\Users\zymun\Desktop` 的内容如下：

**文件夹**
- `2022年之前的备份`
- `k8s`
- `note`
- `sunmoon-e-work`
- `toolboxes`
- `财务分析与预测智能体`

**文件**
- `Cursor.lnk`
- `Microsoft Edge.lnk`
- `Qoder IDE.lnk`
- `Visual Studio Code.lnk`
- `WorkBuddy.lnk`
- `新建 文本文档.txt`
- `新建 文本文档 (2).txt`
- `desktop.ini`（隐藏系统文件）

需要查看某个文件夹的内容吗？
```

与本机 `Desktop` 实目录一致（含 `sunmoon-e-work`）。**「碰所选文件夹」通过。**

## 重启自启

2026-10-11 约 11:07（UTC+8）重启后：

- `03:07:01Z` `sunmoon-agent starting` 0.2.6（登录自启拉起）
- 前几分钟 `ECONNREFUSED: 连不上 relay.sunmoonai.com`（本机网络/DNS 未就绪），约 `03:11:28Z` `relay connected`
- 现状：`connected`，roots 仍是 Desktop，自启任务仍 enabled

**重启自启通过。**

## 「重新连接账号」仍不出码

托盘点「重新连接账号」会起 onboard 窗口（现场留下 `onboard-ready.json`），但窗口再次消失、界面不显示连接码——与首次「连接我的账号」同一缺陷。

**窗口路径仍未过。** 已按所有者要求用 CLI **重验**过期/拒绝人话，原文进给 fable 的报告（明确：CLI ≠ 窗口验收）。见 `agent-release-026-e-fable-blockers.20261011.md`。

### CLI 重验摘要

| 项 | 码 | stdout `message` |
| --- | --- | --- |
| 过期（干等 300s） | `S6J7-6UEA` | `expired: 连接码已过期，请重新获取。` |
| 拒绝（库状态改 denied，非网页点拒绝） | `A7XP-UA2J` | `denied: 连接码已被拒绝，请重新获取。` |

验后代理仍 `0.2.6 connected`。

## 还没做（等 fable 修窗口后再走 UI）

1. ~~重启 Windows~~（已过）
2. 过期码：**窗口**人话（CLI 已核，UI 未验）
3. 拒绝码：**窗口**人话（CLI 已核，UI / 网页拒绝未验）
4. Traefik 访问日志来源原文（与 `source_ip` 对照；现记 `10.247.34.192` 可疑）

U4 仍等 E 按正确口径审过后再做。
