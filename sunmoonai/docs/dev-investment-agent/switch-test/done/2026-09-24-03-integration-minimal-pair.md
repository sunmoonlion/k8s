# 最小对一机联调（本地机 WSL 上独立复核）

```text
被测仓：runtime，本地路径 ~/worktrees/fable/runtime（脚本还会读并列的 k8s 仓 ../k8s）
跑：cd agent && pnpm install && pnpm build && pnpm test && cd .. && bash scripts/integration-minimal-pair.sh
仓与提交：runtime 51b7a85；k8s 9a09b59c（被测脚本自 2eb5d4f 起未改，只是仓的头提交前进了）
预计：5 分钟；要联网（模型调用）；要 Codex 登录态在 ~/.codex-probe（编排端）；要 uv、pnpm、Node 20+；不要 Docker
看什么：1) pnpm test 27 个用例过；2) 联调输出末行「结论：pass」，六个 VERDICT 全 pass；特别看「exec-server 在外沙箱里启动」——WSL2 内核下 bwrap 嵌套是否成立
前提：runtime/.venv 先建好（uv venv .venv && uv pip install --python .venv/bin/python websockets）；~/.codex-probe 有登录态
回传：scripts/results/integration-minimal-pair.<时间>.txt（写下即可，提交与推回由所有者做）
```
