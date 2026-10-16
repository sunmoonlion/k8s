# Cursor 回执：集群侧 frpc 发布

时间：2026-10-10 11:30（UTC+8）。镜像已进 Harbor，两个 frpc Pod 在跑。没有 push，没有移动本待办，没有重写 `edge-frp.yaml`。

先前 11:12 的回执停在清单取不到。这次按现有代理重试，第三次 `skopeo inspect --raw` 取到原始清单，sha256 等于 `sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`，864 字节。config `sha256:33f4aecae1ecfa322004e3d88fcacf10538fe65b57ab94db1b196c0495c94c89`，三层压缩合计 `10463177`。

## 步骤

| 步骤 | 退出码 |
| --- | --- |
| `services-materials SERVICE_IMAGES=frpc` | 前三次 EOF，第四次 0。归档已按锁校验 |
| `services-publish SERVICE_IMAGES=frpc` | 0。Harbor `platform/frpc` 读回摘要是 `sha256:8dd029fa…` |
| `platform-stage OBJECT=ingress-platform/frpc` | 0。声明无新 diff。令牌主本与备份 mtime 仍是 `1791598000` |
| `flux-release` | 0 |
| `flux-source-apply` | 0 |
| `flux-source-status` | 0 |

只中转了 frpc。Flux 候选原样写入 `infrastructure/environments/kind/flux-source.yaml`：

| 字段 | 值 |
| --- | --- |
| repository | `oci://harbor.sunmoonai.com:30443/platform/deployments-kind` |
| digest | `sha256:45b1c6549660df4685a036d322a76b3cdd09ad05825b43c685a6560be102ae25` |
| revision | `36db18c4a74c01dc0d59d985954e5bdb558e42db` |
| path | `./clusters/kind` |
| requires_sops | `true` |

晋级提交是 `e4c09a4f`，没有把 revision 改成它。开工前回退材料在 `infrastructure/.build/frpc-release-20261010-105815/flux-source.yaml`，当时是 digest `sha256:0162e20f…`、revision `f59286af…`。没有覆盖更早的回退材料，也没有使用这份回退。

## 集群

OCIRepository `platform` Ready。`artifact.revision` 是 `sha256:45b1c654…`。`artifact.digest` 是 `sha256:ebf70963cba5c08b92157149fa0a54a6da8b44ef00ae6ec8ffcc5c1c9901630b`。Kustomization `frpc` Ready，`lastAppliedRevision` 是 `sha256:45b1c654…`。当时列出的 Kustomization 没有未 Ready 的。

| Pod | 状态 | imageID |
| --- | --- | --- |
| `frpc-67c5f945-925lk` | Running，Ready，重启 0 | `harbor.sunmoonai.com:30443/platform/frpc@sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191` |
| `frpc-67c5f945-cnrpk` | Running，Ready，重启 0 | 同上 |

两个客户端日志都是 login success。run id `46b6bdf7aa4c1f6d` 与 `54851c842756a72a` 各自把 `casdoor`、`investment`、`relay` start proxy success。这是客户端日志，不是边缘 frps 上的组成员。frps 三个组是否各有两个成员，这次没看，不能写成通过。

手机流量打开 `https://investment.sunmoonai.com:30443` 没有做，不能写成通过。

## 本地提交

`340ef8c2` 钉上平台清单，`36db18c4` 是第一次停下的回执，`e4c09a4f` 提升源。本回执另作一次只含本文件的本地提交。没有 push。

exit=0
