# 两机公网延迟（本地侧）

```text
跑：RELAY=ws://43.153.135.74:47100 USER_ID=luna DURATION=600 bash runtime/scripts/probe-two-machine-latency.sh
仓与提交：runtime 2572f78
预计：10 分钟内结束；要联网；要 Codex 0.155.1（执行端不要登录态）；不要 Docker
看什么：本地侧连上会合点并桥接（输出末行 pass）；RTT 表在远程侧，远程对照回环数据出结论
```

前提：**所有者同意远程临时开放 47100，且远程已起 `probe-two-machine-latency-remote.sh`**。远程没说「起好了」之前不要跑（会连不上，直接 undecidable）。
回传：输出落 `runtime/scripts/results/probe-two-machine-latency.<时间>.txt`，提交并 `git push origin fable`。
