# 给 astra：0.2.8 桌面链修复（2026-10-11）

> 所有者 2026-10-11 定：桌面这条链由 astra 负责到 0.2.8 发布前；Qwen 不再改 `runtime/agent`。远程写本页，所有者同步过来；做完写回执，所有者同步回去，远程审读。审读记录在 `luna-feedback.md`。

## 一、先补上一轮的三处

远程审过取证 `3d8f8e7` 与 WIP `f5809f1`：根因成立（第 3 节对照最硬），候选 B 方向对。补：

1. 报告第 1 节：正文说枚举到原三个进程的窗口（标题、句柄、700×480），但表格为空、`initial-inspection.json` 里三个 pid 都是 `exists:false`（所有者 22:3x 已结束它们）。补上 22:34:20 那次枚举的原始输出；拿不到就把结论第 1 条改成「原进程已结束，未取到；由第 3 节对照代替」。正文不能比证据多说。
2. `desktop.ps1`：`Shown` 里可见性检查失败时，除了改标签，要 `$Form.Close()` 让进程退出，不留隐形窗口。
3. `Add-Type` 挪到文件顶部与其它 `Add-Type` 一起，只编译一次；`-Action tray` 的窗口以后也能用。

4. **（2026-10-12 审读加）权限确认窗同样处理**：`-Action confirm` 由 `src/windowsDesktop.ts` 的 `desktopRequest` 以 `windowsHide: true` 起 powershell，它是该进程的第一个窗口，和设置窗一样会被隐藏启动压住，压住即 65 秒超时等于自动拒绝。给它同样的 `Shown` 显式显示 + 失败 `Close()` + `New-FormWatchdog`；`watchdog.test.mjs` 加 confirm 一组。

> 2026-10-12 远程审读：第三节 1–7 条与第一节 1–3 全部通过（记录在 `luna-feedback.md`），只剩上面这第 4 条。做完直接进第六节的 0020。

## 二、在哪改

`runtime` 仓 luna 分支，基线 `d90cef3`（现网 0.2.7），你的 WIP 在 `f5809f1` 之上继续。本地提交，不 push，不合并别的分支。版本三处 0.2.8 已改。每条一个提交，提交说明写清改了什么、怎么验的。

## 三、改什么（按顺序）

| # | 改什么 | 要点 |
| --- | --- | --- |
| 1 | 设置窗口看不见 | 候选 B：`Shown` 里 `ShowWindow(handle, SW_SHOW)` + `Activate()`，确认 `IsWindowVisible` 后才写 `onboard-ready.json`；失败 `Close()`。已在 WIP，按第一节补完 |
| 2 | 窗口看门狗 | onboard 与 tray/本机设置两个窗：Timer 每秒查 `$Form.IsDisposed -or -not $Form.IsHandleCreated`，窗没了就 `[Windows.Forms.Application]::Exit()`；脚本整体 `try/finally` 保证退出并清就绪文件 |
| 3 | `onboard-window` 兜底 | `resident.ts` `runDesktopScript`：`onboard-ready.json` 消失、或其中 pid 已死超过 10 秒，就结束该 powershell 子进程并退出；最长寿命 30 分钟 |
| 4 | 卸载前收自己人 | `uninstall.mjs` 在 `stop` 之后、删文件之前：枚举本用户进程里可执行路径在安装目录下的 `node.exe`，和命令行含 `desktop.ps1` 的 powershell；命令行含我们 `cli.js` / `desktop.ps1` 的按 PID 结束并等退出；其它的不动，列出 PID 与命令行后停下报「有进程占着安装目录」。**禁止按进程名杀** |
| 5 | 删文件重试 | `removeVerifiedBundle` 遇 `EPERM`/`EBUSY` 重试 10 × 500 ms，仍失败报错带文件名 |
| 6 | 半卸状态可修复 | `uninstall.mjs` 删文件前写 `<目录>\.uninstall-incomplete`，删完去掉；`upgrade.mjs` 见标记、或清单在但核对不过时返回 `action: "repair"`；`install.ps1.tmpl` 据此在确认无自己人进程后把残目录改名 `sunmoon-agent.broken-<时间>`（不删），再按全新安装走，配置保留；文案「上次升级没做完，已清理残留」。`install.ps1.tmpl` 的真源在 k8s 仓 `gitops/components/app-platform/investment-app/investment-backend/agent-releases/install.ps1.tmpl`，runtime 里 `agent/distribution/install.ps1.tmpl` 要同步改、两边逐字节一致、无 BOM |
| 7 | 文案 | 安装失败时加一句：「可能有旧窗口的进程还开着，先在托盘退出、关掉所有 SunMoon 窗口再试」 |

## 四、怎么验（真机，写进回执，缺一条不算完）

1. 每条配单测（vitest / `node --test distribution/test/<文件>`），全量过；`tsc` 过；`bundle.test.mjs` 过。
2. `distribution/build.mjs` 在干净工作区组本机候选，装到临时目录（照 0.2.4 回执「0.2.1 形态，临时目录」），**不动现装**的 `C:\Users\zymun\AppData\Local\Programs\sunmoon-agent` 与 `.sunmoon-agent`。
3. 真机证据：从**托盘菜单**那条链开出设置窗，`EnumWindows` 见 `visible=true`，`Get-Process powershell | Where MainWindowTitle` 能看到「SunMoon - 设置」，截图存 `C:\Users\zymun\sunmoon-probe-runs\windows-agent-028\`。
4. 第 2、3 条：手动 `Dispose` 窗体或结束 powershell，2 秒内相关进程退出、就绪文件被清。
5. 第 4、6 条：预置一个孤儿 `onboard-window`，和一个随手删了几个文件的半卸目录，升级能自动收掉、自动修复，配置 sha 不变。
6. 点「连接我的账号」看到 8 位码与倒计时、浏览器打开核对页、窗口一直在。**输码、允许、拒绝留给所有者亲手点**，不要用界面自动化代替他。
7. 观察有没有控制台闪出。

## 五、规矩

- 不改沙箱、协议过滤、配对协议、令牌处理。
- 不贴 `config.json`；诊断状态目录里的凭据不进回执。
- 不结束与 SunMoon 无关的进程。
- zip 与回退目录放 `~/sunmoon-probe-runs/`，不进任何 git 仓。
- 回执放 `runtime/scripts/results/windows-agent-0.2.8-*.20261011.md`：原文输出、每条的证据、没做到的明说。
- 做完告诉所有者，他同步给远程审读；发布卡仍由 Cursor 跑，你不发布。

## 六、接着做 0020，合成 0.3.0 一次发（所有者 2026-10-11 夜定「做好后直接做」）

第三节 1–7 条做完、第四节验过之后**不停、不发 0.2.8**，直接按 [`tree-build/SDD/modules/0020-agent-setup-in-browser.md`](../../../design/SDD/modules/0020-agent-setup-in-browser.md) 做卡 P1–P4，最后版本三处改 **0.3.0**（你已改的 0.2.8 到时覆盖），一起交审、一起发。

要点：
- 第三节第 1 条（`Shown` 显式显示）和第 2 条（看门狗）在 0020 之后仍然要：向导窗撤了，本机设置、连接状态、权限确认三个窗还是 WinForms，同样走隐藏启动。写成通用的，不要只给向导窗。
- 0020 §四的四件，所有者的决定：做；选目录第一期留托盘「白名单与上限设置」；开机自启默认开、页面不问；你做。
- 0020 的验收照 §五各卡，加第四节的真机规矩；`pair --page` 的站点输码、允许、拒绝那几下留给所有者。
- 回执按段分开：`windows-agent-0.2.8-*.md`（1–7 条）与 `windows-agent-0.3.0-*.md`（P1–P4），都放 `runtime/scripts/results/`。
- 中途设计走不通（例如默认浏览器打不开、回环页被策略拦）先停下写清楚，交远程改设计，不要绕。
