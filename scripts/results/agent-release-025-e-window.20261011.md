# Cursor 回执：E 停在设置窗口打不开

时间：2026-10-11（UTC+8）。安装命令的 500 已经修好并发布。所有者接着走 E，程序装上了，设置窗口没有出现。这里停。没有改代理代码，没有跑 `init`，没有再覆盖安装目录。

同一轮已经提交的回执：

| 文件 | 内容 |
| --- | --- |
| `agent-release-025-stage2.20261011.md` | 四应用发布、identity、`application-check` |
| `agent-release-025-e-uninstall.20261011.md` | `--remove-config` 卸干净，配置目录删掉 |
| `agent-release-025-install-command.20261011.md` | 复制安装命令的 500，限速器改掉 EVAL 之后的检查 |
| 本文件 | 安装命令粘贴后的两处失败 |

## 粘贴安装命令

所有者在 PowerShell 里粘贴了网页给出的那一行。凭证不记在这里。原文（第一行的怪字符是 UTF-8 BOM）：

```
﻿$ErrorActionPreference : 无法将“﻿$ErrorActionPreference”项识别为 cmdlet、函数、脚本文件或可运行程序的名称。请检查名称的拼写，如果包括路径，请确保路径正确，然后再试一次。
所在位置 行:1 字符: 1
+ ﻿$ErrorActionPreference = 'Stop'
+ ~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (﻿$ErrorActionPreference:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CommandNotFoundException

{
  "action": "installed",
  "destination": "C:\\Users\\zymun\\AppData\\Local\\Programs\\sunmoon-agent",
  "files": 98,
  "bytes": 501009828,
  "startsAgent": false,
  "registersLogonTask": false,
  "changesUserConfig": false,
  "needsAdministrator": false
}
{"t":"2026-10-11T02:01:50.805Z","level":"error","msg":"fatal","error":"Error: 没有配置：C:\\Users\\zymun\\.sunmoon-agent\\config.json（先跑 sunmoon-agent init）     at loadConfig (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/config.js:22:15)     at main (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/cli.js:148:17)     at file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/cli.js:407:1     at ModuleJob.run (node:internal/modules/esm/module_job:439:25)     at async node:internal/modules/esm/loader:643:26     at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)"}
程序已安装，但登录自启没有打开。
所在位置 行:87 字符: 32
+     if ($LASTEXITCODE -ne 0) { throw '程序已安装，但登录自启没有打开。' }
+                                ~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (程序已安装，但登录自启没有打开。:String) [], RuntimeException
    + FullyQualifiedErrorId : 程序已安装，但登录自启没有打开。
```

`runtime` `3541410` 的 `agent/distribution/install.ps1.tmpl` 以字节 `EF BB BF` 开头。`irm | iex` 不会去掉这个 BOM，第一行的变量名变成了带 BOM 的 `﻿$ErrorActionPreference`，`Stop` 没有设上，脚本继续跑。安装本身完成了：98 个文件，目录 `C:\Users\zymun\AppData\Local\Programs\sunmoon-agent`。

模板第 86–88 行在打开窗口之前执行 `sunmoon-agent.cmd autostart enable`，失败就抛「程序已安装，但登录自启没有打开」。`Show-AgentWindow` 没跑到，开始菜单的「SunMoon 代理」也没建。自启失败是因为配置文件不在：`--remove-config` 已经把 `C:\Users\zymun\.sunmoon-agent` 删了，而 `autostart` 会先 `loadConfig`。

## 直接打开设置窗口

没有再粘贴安装命令。在同一个 PowerShell 里执行：

```
& "$env:LOCALAPPDATA\Programs\sunmoon-agent\sunmoon-agent.cmd" menu
```

原文：

```
{"action":"onboard","started":false}
{"t":"2026-10-11T02:03:55.628Z","level":"error","msg":"fatal","error":"Error: 没有配置：C:\\Users\\zymun\\.sunmoon-agent\\config.json（先跑 sunmoon-agent init）     at loadConfig (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/config.js:22:15)     at checkControlDirectory (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/resident.js:23:17)     at openDesktop (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/resident.js:224:5)     at main (file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/cli.js:136:19)     at file:///C:/Users/zymun/AppData/Local/Programs/sunmoon-agent/app/dist/cli.js:407:1     at ModuleJob.run (node:internal/modules/esm/module_job:439:25)     at async node:internal/modules/esm/loader:643:26     at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:101:5)"}
```

`menu` 选了初次设置，没有启动后台。接着 `openDesktop` → `checkControlDirectory` → `loadConfig`。源码在 `3541410`：`cli.ts` 的 `menu` 打印计划后调用 `openDesktop`；`resident.ts` 的 `openDesktop` 第一行就是 `checkControlDirectory`；这个函数无条件 `loadConfig`。`config.ts` 在文件不存在时抛「没有配置……先跑 sunmoon-agent init」。堆栈行号来自安装目录里的 `app/dist`，和源码行号不是同一套。

`pair` 在配置不存在时用默认配置，要等网页允许之后才写 `config.json`。打开窗口这条路却要求文件先在。所以卸掉配置之后，设置窗口起不来，连接码也出不来。

## 现场

程序仍在 `C:\Users\zymun\AppData\Local\Programs\sunmoon-agent`。`config.json` 仍不存在。没有 Traefik 来源，也没有后端 `source_ip`。U4 没做。
