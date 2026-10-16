# Cursor 回执：卡 46 会合点补上 `/service` 服务流

时间：2026-10-14 12:35（UTC+8）。`platform-check OBJECT=relay-platform/relay` 与 `application-check APP=investment` 均为 0。没有 push，没有移动本待办。真人服务流通路验收由所有者做，不记为本卡通过。

完成到：晋级 `e9fd5285`；现网 `relay.py` sha256 = `cd42e245…`。回退材料在 `~/sunmoon-probe-runs/relay-service-046/`，未使用。

## 前提 / 现网核对

`~/worktrees/qwen/k8s` 分支 `qwen`；`4028d32d` 是 HEAD 后代（`descendant=0`）。改钉前：源码锁与镜像锁均为 `4d0ff043…` / `sha256:04421137…`。现网：

| 文件 | sha256 |
| --- | --- |
| `relay.py` | `1dfe7ff41c9f6422a6c0ef5586deed7b63755b0d51dd9e04446ef0439078012d` |
| `permission_reports.py` | `d223ea71c51b565007beb0edd4214ebf7bc967d6e72a726e7d7e85a589f7933f` |

与卡预期一致（即 `1d01771f` 那份）。`git -C ~/worktrees/luna/k8s cat-file -t 4d0ff043` → `commit`（本地 luna 仍有该提交）。`platform-status` 0。

## 步骤

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改源码锁一行 | — | `4d0ff043…` → `4028d32d…`；sandbox/供给器未动 |
| `platform-build OBJECT=relay-platform/relay` | 0 | 锁 `sha256:54955c8a…` / `4028d32d…` |
| `platform-stage` | 0 | 仅 `component-images.yaml`、`image.lock.yaml`、`workload.yaml`（镜像摘要一行） |
| stage 提交 | `9c62c313` | `deploy(relay): 会合点补上 /service 服务流，源码锁 4d0ff04 → 4028d32d（待办 46）` |
| `flux-release` | 0 | 候选 digest `sha256:53779992…`，revision `9c62c313…` |
| 晋级提交 | `e9fd5285` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `platform-check OBJECT=relay-platform/relay` | 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0 |
| 现网 `relay.py` | — | `cd42e245039628a61add166e24a570efff93714ed3468f0f6ac4de9137a21ef0` |
| 代理重连日志（去令牌） | — | `agent up … software=0.4.0` |

## 本地提交

`9c62c313` stage，`e9fd5285` 晋级；本回执另提。不 push。

exit=0
