# Cursor 回执：E 全程，卸载这一步

时间：2026-10-11（UTC+8）。U3 账号段所有者已验通过。这里只做到 `--remove-config` 卸干净。安装、输码、允许、选目录、自启、在线、碰文件夹、重启、过期码、拒绝码还没做，Traefik 来源和后端 `source_ip` 也还没有可看的配对请求。

## onboard-ready.json

`C:\Users\zymun\.sunmoon-agent\onboard-ready.json` 在，18 字节，内容 `{"pid":29644}`。没有 `desktop.ps1`、`onboard-window`、`open-desktop.vbs` 进程。29644 现在是 `explorer.exe`，不是设置窗口。已只删这个标记。删后目录里只剩 `codex-home` 和 `config.json`。

删之前配置仍是 984 字节，令牌长度 386，令牌 SHA256 `f3255049f2cb743745f61891b22bcdbf064bf2a842fef5a999f1ab0c6267e585`。

## 卸载

外部包是 `C:\Users\zymun\sunmoon-probe-runs\windows-agent-c2-20261010\sunmoon-agent-c0c185f`，不是安装目录里的那份。清单 `df9b659fef058d3b5f016e02846b6895af27e56ce604c8309db724df3e5c9615`，与恢复后的安装目录一致。

预览原文：

```
{"action":"preview","target":"C:\\Users\\zymun\\AppData\\Local\\Programs\\sunmoon-agent","preserveConfig":false,"stopsOnlyThisAgent":true}
EXIT 0
```

执行原文：

```
{"action":"uninstall","target":"C:\\Users\\zymun\\AppData\\Local\\Programs\\sunmoon-agent","preserveConfig":false,"stopsOnlyThisAgent":true,"result":"removed"}
EXIT 0
```

卸完：

| 路径 | 还在 |
| --- | --- |
| `C:\Users\zymun\AppData\Local\Programs\sunmoon-agent` | 否 |
| `C:\Users\zymun\.sunmoon-agent` | 否 |
| 开始菜单 `SunMoon 代理.lnk` | 否 |
| 名称里带 `sunmoon-agent` 或 `desktop.ps1` 的进程 | 0 个 |

`C:\Users\zymun\AppData\Local\sunmoon-agent\tmp\executor-PgulQm` 还在，里面是空目录。卸载器只删程序、默认状态目录和它认的日志，不删这个临时目录。

## 还没做

网页复制安装命令、设置窗口、输码允许、选文件夹、自启、在线、碰一次所选文件夹、重启、过期码、拒绝码。配对发生后再看 Traefik 访问日志来源和后端 `source_ip`。
