# fable-b1 浏览器前置：Windows hosts 缺项已补

2026-10-20，Asia/Shanghai；WS=fable，k8s 分支 fable。所有者在浏览器访问 Jenkins 时报告 `DNS_PROBE_FINISHED_NXDOMAIN`。

## 原因与处置

Windows hosts 原来没有 `jenkins.sunmoonai.com`；既有平台内网域名均指向 `127.0.0.1`。之前第四节的 `curl --resolve` 验证绕过了 DNS，未覆盖 Windows 浏览器的解析前置条件，第三、四节入口通过不能代表浏览器可达。

调用仓内既有 `docs/dev-investment-agent/switch-test/windows_hosts_add.ps1 jenkins.sunmoonai.com`，经 Windows `Start-Process -Verb RunAs` 提权执行。脚本自动备份到 `C:\Windows\System32\drivers\etc\hosts.bak-add-20261020-180754`，补入 `127.0.0.1 jenkins.sunmoonai.com` 并刷新 DNS 缓存，退出 0。没有修改产品代码、部署声明、证书信任或其它域名映射，没有重启入口或 Jenkins，也没有配置公网 DNS。

## 验证与原始输出

| 原始输出 | 结果 |
| --- | --- |
| [01-windows-hosts](fable-b1.20261020-180743.01-windows-hosts.txt) | 既有脚本执行成功，备份路径及新增域名有记录，exit=0 |
| [02-windows-check](fable-b1.20261020-180743.02-windows-check.txt) | Windows 系统解析得到 `127.0.0.1`；原生 curl 在 TLS 阶段报 `CRYPT_E_NO_REVOCATION_CHECK`，HTTP 000、exit=35，保留失败原文 |
| [03-windows-webrequest](fable-b1.20261020-180743.03-windows-webrequest.txt) | Windows `Invoke-WebRequest -UseBasicParsing` 默认校验、无证书回调或 TLS 覆盖，直接请求域名 `/login`，StatusCode=200、X-Jenkins=2.580.1、登录表单存在，exit=0 |

curl 的失败没有用 `-k`、关闭吊销检查或修改系统策略绕过；改用另一个系统默认客户端单独验证 Windows 解析与登录页可达。不能将此写成 Windows curl 通过，也不能据此声称浏览器已由所有者验收。

已告知所有者刷新 `https://jenkins.sunmoonai.com:30443/`。所有者亲自登录及空实例走查、边缘 404 仍待验，没有读取、抄写或代填口令。

同步时正常 `git pull --ff-only origin fable` 到 `91e38f9574c7142276c8345a26d34f99cb781acb`，新到的其它工位同步卡不属于本次 DNS 修复，未执行。本轮只提交新回执、原始日志及给远程的手册补项请求，旧回执与失败证据均保留。
