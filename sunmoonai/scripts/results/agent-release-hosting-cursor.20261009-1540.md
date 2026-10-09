# Cursor 回执：投资电脑代理安装包托管

时间：2026-10-09 15:40（UTC+8）。A、B、C 都做完。没有 push，没有移动本待办。浏览器里的人工下载、安装、填令牌、上线，以及图形确认、重启自启、提权提示、干净 Windows 电脑，都没有做，不能写成通过。

完成到：C 的未登录拒绝和已登录下载核对。回退材料已保存，未使用。

## 前提

开工时 71 个 Flux Kustomization 全部 Ready，投资 Deployment 全部 1/1。C 盘剩余约 114 GiB。没有维护标记。SOPS age 主身份与数据盘副本都在。工作区干净。investment 三仓 HEAD 与本卡一致，admin 锁仍是 `b0f4c5de8450e6e17bb8d5ef846dcb76f4d01093`。数据库迁移目标仍是 `20261007_0013`。

| 仓 | HEAD |
| --- | --- |
| investment-app | `231f305de2e0b72edb3d7cdd7c880151f8e3aaaf` |
| investment-backend | `a01db6f10f22d11116ba4421309ca676e2790f18` |
| investment-web-frontend | `2095c04927a1510efc54bef5ffd28e0c52d25558` |

## A：关闭下载并部署

source plan、构建、发布、stage、deployment plan、flux-release、显式提升、flux-source-apply、flux-source-status、platform-check、application-check、application-check-public 都是退出码 0。只构建并发布了 investment-backend 和 investment-web-frontend。

| 镜像 | digest | 源码 |
| --- | --- | --- |
| investment-backend | `sha256:4cf3a9391d0aad12a5a22da6ea07c9577de2904c68f3c8b9357114a2d9ea18f7` | `a01db6f10f22d11116ba4421309ca676e2790f18` |
| investment-web-frontend | `sha256:15be7010c8d2a5fbbde714936418a76096e16b16cbdae9e279d80b3e7af326f9` | `2095c04927a1510efc54bef5ffd28e0c52d25558` |

关闭下载时 API 内 `download_is_none=True`，对象存储配置已存在。公开描述符不提供可用下载地址。

段 A 实际应用的 Flux 候选是 revision `00191a88028bb8eee162eae6ac70ad7e8f682ded`，digest `sha256:d4f28fd0642872939815f3491d43be14a2967fb44a460c457fdcb53428a755a5`。当前分支上对应提交已被改写，关闭下载的提交是 `84659322cdcdac6a76c108f54a33381e43be5c85`，提升提交是 `1653a6fffce607b774c01d766a7235c41144267b`。`origin/luna` 停在这个提升提交。本次没有执行 push。

stage 带出的投资长期 Deployment 含 `ndots: 2`。这来自当时树上已经提交的长期负载模板，Job 没有这个选项，其他应用没有重新 stage。

## B：上传固定包并核权限

固定 ZIP：`/mnt/c/Users/zymun/sunmoon-probe-runs/windows-agent-3-20261009/sunmoon-agent-0.2.1-6de6002-windows-x64.zip`。`agent-release-verify` 与首次 `agent-release-upload` 退出码 0。

| 项 | 结果 |
| --- | --- |
| 桶 / 对象 | `agent-releases` / `windows-x64/0.2.1/sunmoon-agent-0.2.1-6de6002-windows-x64.zip` |
| 文件数 / 大小 | 90 / 174243923 |
| ZIP SHA256 | `2d5421627198b9cf2eccf15d88b726c80d46f4180e2db30606120f5bd52aea5a` |
| manifest SHA256 | `d72f5443be1fa13895a92cb97f37b9cef6ce5fe27e7707705f3ee0e56a11f1b2` |
| 首次回执 | `uploaded-and-verified`，`uploaded=true`，`readback_verified=true`，`writer_read_denied=true`，`reader_write_denied=true` |
| 同名再传 | 退出码 0，`uploaded=false`，`existing_preserved=true` |
| 版本号 | `ae737f39-95a7-40b7-868a-edcd426e0019`，再传后不变 |

匿名 GET 403。读者 GET 200，删除、列对象、列版本、策略、标签都是 403。写者 GET、删除、列对象、列版本、策略、标签都是 403。没有关 TLS，没有放宽权限，没有删除对象。

## C：开启下载并核接口

stage、plan、flux-release、显式提升、apply、status、application-check、application-check-public 都是退出码 0。没有重建镜像。

当前 Flux 源（未把 revision 改成提升提交）：

| 项 | 值 |
| --- | --- |
| revision | `f59286af48d78c2f3f13ea6f5c779b9a3a7fe55f` |
| digest | `sha256:0162e20f2d162567980a60e8429c477ab2ea137e04f6937095160fe6f9e88bc0` |
| 提升提交 | `87aadc26c5c5f932fdf4268d883d0f909e8c7da3` |
| OCIRepository | Ready，72 个 Kustomization 全部 Ready |

运行中的 Pod 镜像：

| Pod | imageID |
| --- | --- |
| `investment-api-54ff7fb96-j6mtd` | `harbor.sunmoonai.com:30443/platform/investment-backend@sha256:4cf3a9391d0aad12a5a22da6ea07c9577de2904c68f3c8b9357114a2d9ea18f7` |
| `investment-worker-d868ff5ff-ztbkl` | 同上 |
| `investment-runner-fb787cdb6-q2hkd` | 同上 |
| `investment-scheduler-d8cb49598-4frgd` | 同上 |
| `investment-web-67fb949d66-4chzz` | `harbor.sunmoonai.com:30443/platform/investment-web-frontend@sha256:15be7010c8d2a5fbbde714936418a76096e16b16cbdae9e279d80b3e7af326f9` |

接口核对退出码 0。未登录 GET `/api/workbench/agent/download`、GET 与 HEAD `/api/workbench/agent/package` 都是 401，响应里没有 ZIP 哈希。登录后描述符没有 `object_key`，地址是同源 `/api/workbench/agent/package`。HEAD 200，`content-length: 174243923`，`content-disposition: attachment; filename="windows-x64.zip"`，`cache-control: no-store`，两个校验头与固定包一致。完整下载 SHA256 与固定 ZIP 一致。`Range: bytes=0-15` 返回 206 和 `bytes 0-15/174243923`。越界 Range 返回 416、`bytes */174243923`、空正文。错误 If-Range 返回完整 200；匹配的 If-Range 返回 206。登出后 HEAD 回到 401。

## 回退点（未使用）

`infrastructure/.build/agent-release-hosting-20261009-150935`（不入库）。内容是开工前的 `flux-source.yaml` 和两份镜像锁。没有覆盖更早的停机快照。

## 本地提交

`84659322` 关闭下载并 stage，`1653a6ff` 提升该源，`f59286af` 打开下载，`87aadc26` 提升打开后的源。本回执另作一次只含本文件的本地提交。分支比 `origin/luna` 超前，本次没有 push。

exit=0
