# Windows 上的 exec-server（D11）

```text
被测仓：runtime，本地路径 ~/worktrees/fable/runtime
跑：scripts/probe-windows-exec-server.ps1（Windows PowerShell；先 $env:ORCH_HOME 指向有登录态的 CODEX_HOME）
仓与提交：runtime cdef671
预计：5 分钟；要联网（模型调用）；要 Codex 0.155.1 与登录态；不要 Docker
看什么：1) exec-server 在 Windows 上起得来、监听 47001；2) workspace-write 沙箱生效：VERDICT L2 与 L3 都 True 为 pass，出现 "sandbox intent cannot be enforced" 为 fail；环境段里要有杀毒软件名
前提：第一次回传（runtime 98b58d8，结论 undecidable）查明 Windows 机上没有 Codex、Node、可用的 Python，也没有有登录态的 ORCH_HOME。所有者先在 Windows 机上装 Node 20+、`npm i -g @openai/codex@0.155.1`、Python 3.10+，并在 `%USERPROFILE%\.codex-probe` 登录一次 Codex；装好后再跑。本地助手不装软件、不复制凭据
回传：scripts/results/probe-windows-exec-server.<时间>.txt（写下即可，提交与推回由所有者做）
```
