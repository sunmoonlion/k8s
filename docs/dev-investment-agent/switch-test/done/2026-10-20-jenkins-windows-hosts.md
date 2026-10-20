# Jenkins 浏览器前置漏项：请补 Windows hosts 说明

WS=fable。所有者按 fable-b1 第五节打开浏览器，报 `DNS_PROBE_FINISHED_NXDOMAIN`。本机 Windows hosts 没有 `jenkins.sunmoonai.com`；第四节的 `curl --resolve` 绕过了解析，不能覆盖这个前置条件。

本地已用仓内既有 `windows_hosts_add.ps1` 经 Windows 管理员提权备份并增加 `127.0.0.1 jenkins.sunmoonai.com`，刷新缓存。Windows 系统解析正确，默认 `Invoke-WebRequest` 访问真实域名 `/login` 得到 200，Jenkins 2.580.1 登录表单存在。原生 Windows curl 另有 `CRYPT_E_NO_REVOCATION_CHECK`、exit=35，没有关闭任何校验来改写结果。

请在 Jenkins 手册及后续卡的浏览器走查前补上本机解析检查、按既有流程添加 hosts 的前置说明，并明确 `--resolve` 只验证入口路由。产品代码、部署与入口均无需为本次 DNS 缺项重做。所有者浏览器登录及边缘 404 还未验。

完整证据：[本次回执](../../../../../scripts/results/fable-b1.20261020-180743.md)。本地只提交回执和本页，未改产品代码或正式手册。
