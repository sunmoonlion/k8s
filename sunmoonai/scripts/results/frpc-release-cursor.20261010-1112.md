# Cursor 回执：集群侧 frpc 发布

时间：2026-10-10 11:12（UTC+8）。发布停在镜像中转之前。没有 push，没有移动本待办，没有改集群里的 Flux 源，没有重写 `edge-frp.yaml`。

完成到：镜像锁、prepare 断言、README、发布卡摘要已改为 amd64 平台清单，并重新 stage。`skopeo inspect --raw` 取不到 `sha256:8dd029fa…`，按发布卡停止，没有跑 `services-materials` / `services-publish`，没有晋级。

## 前提

| 项 | 结果 |
| --- | --- |
| 分支 / 父提交 | `luna` / `3ab76558` |
| 声明提交 | `340ef8c22589af0ed4fb7df7507ca1f4780011e6` |
| 集群 | `kind-sunmoon-kind`，三个节点 Ready |
| 容量 | `/` 可用 627 GiB，`/mnt/sunmoon-data` 可用 204 GiB |
| SOPS | 主身份与数据盘副本都在 |
| 令牌文件 | 主本与备份 mtime 仍是 `1791598000`，模式 `0600`，属主 root。stage 跳过了生成和重新加密 |
| 回退材料 | `infrastructure/.build/frpc-release-20261010-105815/flux-source.yaml`。现场源仍是 digest `sha256:0162e20f2d162567980a60e8429c477ab2ea137e04f6937095160fe6f9e88bc0`，revision `f59286af48d78c2f3f13ea6f5c779b9a3a7fe55f` |

## 声明

锁、prepare 和 stage 后的工作负载都是 `sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`。`config_digest` 为 `sha256:33f4aecae1ecfa322004e3d88fcacf10538fe65b57ab94db1b196c0495c94c89`，`compressed_layer_bytes` 为 `10463177`。索引 `sha256:99ece6a2…` 只留在 `selection_note`。

`platform-stage OBJECT=ingress-platform/frpc` 退出码 0。工作负载镜像换成平台清单；rollout 注解随之变化，因为 `frpc_input_digest` 把清单摘要算进去。私有输入没有重写。

## 停在哪里

发布卡第 1 步要求发布前执行：

`skopeo inspect --raw docker://docker.io/fatedier/frpc@sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`

经 `~/.config/sunmoon-network/env.sh` 的代理 `http://192.168.32.1:7890` 重试后仍然失败。`registry-1.docker.io` 返回 EOF。同一代理上 `curl` 是 `SSL_ERROR_SYSCALL`。不走代理时连接超时。Docker 守护进程的 `docker manifest inspect` 同样是 EOF。没有拿到原始清单，没有核对 sha256。

未执行：镜像中转、第二次 stage、`flux-release`、源晋级、`flux-source-apply`、`flux-source-status`。没有 frpc Pod imageID。没有看 frps 日志，没有看手机流量登录页。

exit=1
