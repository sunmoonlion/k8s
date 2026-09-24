# Windows 上的 exec-server（D11）

```text
跑：runtime/scripts/probe-windows-exec-server.ps1（Windows PowerShell；先 $env:ORCH_HOME 指向有登录态的 CODEX_HOME）
仓与提交：runtime 2572f78
预计：5 分钟；要联网（模型调用）；要 Codex 0.155.1 与登录态；不要 Docker
看什么：1) exec-server 在 Windows 上起得来、监听 47001；2) workspace-write 沙箱生效：VERDICT L2 与 L3 都 True 为 pass，出现 "sandbox intent cannot be enforced" 为 fail；环境段里要有杀毒软件名
前提：无
回传：runtime/scripts/results/probe-windows-exec-server.<时间>.txt；提交并 git push origin fable
```
