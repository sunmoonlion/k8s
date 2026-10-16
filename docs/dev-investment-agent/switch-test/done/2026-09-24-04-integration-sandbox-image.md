# 沙箱镜像形态的最小对联调（本地机 WSL，要 Docker）

```text
被测仓：runtime，本地路径 ~/worktrees/fable/runtime（脚本读并列的 k8s 仓 ../k8s）
跑：cd ../k8s/sunmoonai/sandbox-platform && docker build --build-arg NODE_IMAGE=harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc -t sunmoon/sandbox:dev -f image/Dockerfile . && cd ~/worktrees/fable/runtime && RELAY_PORT=47110 bash scripts/integration-sandbox-image.sh   （基础镜像用 KIND Harbor 里已有的 node 24.18.0，不碰 Docker Hub；47100 被 Cursor 占用时用 47110）
仓与提交：runtime 60120a5；k8s 本条待办所在的 fable 头（沙箱 Dockerfile 换了基础镜像；联调脚本端口可用环境变量覆盖）
预计：镜像构建 3 到 5 分钟（基础镜像本地已有，只下 Codex 包），联调 3 分钟；要联网；要 Docker；要 Kimi key 在 ~/.codex-probe-kimi/auth.json（所有者放，本地助手不复制不打印）
看什么：输出末行「结论：pass」；七个 VERDICT 全 pass；结果文件里不得出现 sk- 开头的字符串
前提：03 号先 pass；~/.codex-probe-kimi/auth.json 由所有者放好（600）
回传：scripts/results/integration-sandbox-image.<时间>.txt（写下即可，提交与推回由所有者做）
```
