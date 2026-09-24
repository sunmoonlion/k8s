# 沙箱镜像形态的最小对联调（本地机 WSL，要 Docker）

```text
被测仓：runtime，本地路径 ~/worktrees/fable/runtime（脚本读并列的 k8s 仓 ../k8s）
跑：cd ../k8s/sunmoonai/sandbox-platform && docker build -t sunmoon/sandbox:dev -f image/Dockerfile . && cd ~/worktrees/fable/runtime && bash scripts/integration-sandbox-image.sh
仓与提交：runtime 51b7a85；k8s 9a09b59c（被测脚本自 2eb5d4f 起未改，只是仓的头提交前进了）
预计：镜像构建 5 到 10 分钟（下载 node 基础镜像与 Codex 包），联调 3 分钟；要联网；要 Docker；要 Kimi key 在 ~/.codex-probe-kimi/auth.json（所有者放，本地助手不复制不打印）
看什么：输出末行「结论：pass」；七个 VERDICT 全 pass；结果文件里不得出现 sk- 开头的字符串
前提：03 号先 pass；~/.codex-probe-kimi/auth.json 由所有者放好（600）
回传：scripts/results/integration-sandbox-image.<时间>.txt（写下即可，提交与推回由所有者做）
```
