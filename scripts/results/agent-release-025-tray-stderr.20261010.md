# Cursor 回执：0.2.5 托盘真实入口，PowerShell 标准错误取证

时间：2026-10-10 19:25（UTC+8）。只取证，没有按猜测改启动方式。没有上传，没有改 `agent-releases/config.yaml`，没有 stage，没有发布。

## 这次跑的程序

已安装目录 `C:\Users\zymun\AppData\Local\Programs\sunmoon-agent`，清单 SHA256 `9b9d3a1381904683a010df53d9d4282a490464d44794c75dcd2d9569b64cb5d5`，源码 `8fcf7a865e5fa95ee7d190504dec57bde34c4718`。这版 `openDesktop` 没有 `detached: true`，原来的标准流是 `stdio: ["pipe", "pipe", "ignore"]`。

真实入口：`C:\Users\zymun\AppData\Local\Programs\sunmoon-agent\sunmoon-agent.cmd menu`。没有设置 `SUNMOON_AGENT_HOME`，用的是所有者本机已有配置。取证前把这一处标准错误临时改到 `%TEMP%\sunmoon-tray-err.txt`（`C:\Users\zymun\AppData\Local\Temp\sunmoon-tray-err.txt`）。跑完已改回 `ignore`。

## PowerShell 报错原文

文件存在，**0 字节**。没有报错原文。

同一次 `menu` 的标准输出：

```
{"action":"tray","started":false}
```

退出码 0，从启动到返回约 1.2 秒。按这份已安装代码，只有收到 `{"desktop":"ready"}` 才会这样返回；进程提前退出或 15 秒内没有这一行都会失败。

返回后立刻查：

- `tray.json` 为 `{"runId":"40cfac29-7e19-4a95-931c-05bdef55e758","pid":23764}`
- pid 23764 已不在
- 命令行含 `desktop.ps1` 的进程数量为 0
- `tray.json` 还在（脚本正常退出时会在 `finally` 里删掉它）

`tray.json` 写在 `[Console]::InputEncoding` / `OutputEncoding`、读完 stdin、创建托盘图标之后，`Application.Run()` 之前。这次脚本已经执行到写文件，标准错误里没有任何异常。

## 因此没有改的两处

① stdin 回调后才返回：这版已经这样做，而且这次在约 1.2 秒内收到了就绪行。  
② `detached: true` 导致无控制台、编码赋值抛错：这版 `openDesktop` 没有 `detached`。标准错误是空的，编码赋值没有抛错。没有加 try/catch，也没有再改 spawn 参数。

停在这里。托盘进程没有留下来，所有者看不到托盘。第 3 条放行条件不满足，第二段没有开始。
