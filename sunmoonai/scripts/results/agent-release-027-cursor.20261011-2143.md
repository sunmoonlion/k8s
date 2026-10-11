# Cursor 回执：投资电脑代理 0.2.7（卡 37）

时间：2026-10-11 21:43（UTC+8）。A、B、C 都做完。没有 push，没有移动本待办。浏览器真人 UI 重验（重新连接出码 → 网页允许 → 已在线 → 过期码 → 网页点拒绝）由所有者亲自验收，不在本卡，不得记为本卡通过。

完成到：C 的 `application-check APP=investment` 退出 0。回退材料已保存，未使用。

## 前提

回退点：`sunmoonai/scripts/results/_rollback-027-20261011/`（原 `agent-releases/config.yaml`、`flux-source.yaml`、`image.lock.yaml`、`source.yaml`；不入库）。另有 `_rollback-027-20261011-2059/`。开工时投资后端镜像锁仍是 `b09a366f3d71…`，本卡未重建镜像。

操作约定：verify / upload / stage 须先进 PID 1 挂载命名空间；Makefile 的 `sudo env` / nsenter 包装会丢掉未注入的 `AGENT_ZIP`、`OBJECT`——本次在 nsenter 后的 `env` 里显式注入。ZIP 须 POSIX `/` 路径（`Compress-Archive` 的 `\` 导致首次 verify 失败，已用 Python `zipfile` 重打）。

## A：组包

Windows 侧干净克隆 `C:\Users\zymun\sunmoon-probe-runs\windows-agent-027-20261011\src-d90cef3`，`HEAD=d90cef3e9114c6a336758ceb9b8e3a46b9872e27`。物料与 0.2.6 同：node.exe v24.19.0、frozen 依赖 `windows-agent-2-20261008\agent`、investment 生产 site / bundled CA。

`build.mjs` 输出：

| 项 | 值 |
| --- | --- |
| output | `…\windows-agent-027-20261011\sunmoon-agent-d90cef3` |
| sourceRevision | `d90cef3e9114c6a336758ceb9b8e3a46b9872e27` |
| manifestSha256 | `14c456a1d748d38e768cd0df613fd141a6efc84205d7e5ae25b120bef969d94e` |
| files / bytes | 98 / 501017242 |

`windows-candidate.mjs`（包内 Node，退出 0）：`result=pass`，agent `0.2.7`，codex `0.155.1`，node `24.19.0`，files 98，`launchedAgent=false`，隔离安装已删。

正式 ZIP（Python zipfile，deflate、正斜杠、无外层目录）：

| 项 | 值 |
| --- | --- |
| 路径 | `~/sunmoon-probe-runs/windows-agent-027/sunmoon-agent-0.2.7-d90cef3-windows-x64.zip` |
| ZIP SHA256 | `c17d10d0f7359c626e27028c8217119fa845858bfffa281db1011b3d8044f437` |
| size_bytes | 174263794 |

（首次 `Compress-Archive` 得到 `8fe5eee1…` / 175310527，verify 因路径分隔符失败，未上传该包。）

`install.ps1.tmpl` 未改：runtime 与 k8s 均为 SHA256 `c797221de5dc9304d722771d38f40093712c2b6e568c2d1a05e75106a4a1b5a1`，无 BOM。

## B：校验并上传

`AGENT_ZIP=<POSIX zip 绝对路径>`，经 nsenter 注入后：

| 步骤 | 退出码 | 结果 |
| --- | --- | --- |
| `agent-release-verify`（重打后） | 0 | `verified-local`，files 98，摘要与上表一致 |
| `agent-release-upload` | 0 | 见下表 |

上传回执（`/etc/sunmoon/services/sunmoon-kind/investment-agent-release-published.json`）：

| 项 | 结果 |
| --- | --- |
| action | `uploaded-and-verified` |
| bucket / key | `agent-releases` / `windows-x64/0.2.7/sunmoon-agent-0.2.7-d90cef3-windows-x64.zip` |
| uploaded / readback_verified | true / true |
| existing_preserved | false |
| writer_read_denied / reader_write_denied | true / true |
| zip / manifest / size / files | 与 A 段正式 ZIP 一致 |

未关 TLS、未扩权、未覆盖他对象、未删桶。

## C：换 0.2.7 并只发投资

`agent-releases/config.yaml` 六项：

| 项 | 值 |
| --- | --- |
| version | `0.2.7` |
| codex_version | `0.155.1`（不变） |
| source_revision | `d90cef3e9114c6a336758ceb9b8e3a46b9872e27` |
| object_key | `windows-x64/0.2.7/sunmoon-agent-0.2.7-d90cef3-windows-x64.zip` |
| zip_sha256 | `c17d10d0f7359c626e27028c8217119fa845858bfffa281db1011b3d8044f437` |
| manifest_sha256 | `14c456a1d748d38e768cd0df613fd141a6efc84205d7e5ae25b120bef969d94e` |
| size_bytes | 174263794 |

`enabled: true`、`download_available: true` 保持。

| 步骤 | 退出码 | 说明 |
| --- | --- | --- |
| `application-stage APP=investment` | 0（首次缺 `OBJECT` 曾为 2，注入 `OBJECT=app-platform/investment-app` 后重跑为 0） | 只动三文件 |
| `application-deployment-plan APP=investment` | 0 | 四处 `config-sha256` → `7b945dfa8c439f8b27dae7af6771d232c86fea06eb9a56b164120e74d50af956`；后端镜像未换 |
| stage 本地提交 | — | `8dad0af4` stage: 投资代理包换成 0.2.7（config + agent-releases.sops + workload） |
| `flux-release` | 0 | 候选 digest `sha256:a214e804d58f6c675a016272f8f05193e6536288ec03365ab6fa4e58e7f7188d`，revision `8dad0af432c1a845ccce534b1156d7b2b321aafe` |
| 晋级提交 | — | `32773d9e` 晋级 8dad0af4 的声明包（`flux-source.yaml` 完整字段，revision 仍为 stage 摘要，不是晋级 HEAD） |
| `flux-source-apply` | 0 | PLAY RECAP failed=0 |
| `flux-source-status` | 0 | OCIRepository / Kustomization Ready，digest 与晋级一致 |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0；迁移/身份 Job 仍带 `b09a366f3d71`；image.lock 仍为 `sha256:b09a366f3d71ff175c48a0259f1a7f20793be8bd746e26ca876af04c49f7a379` |

当前 Flux 源：

| 项 | 值 |
| --- | --- |
| revision | `8dad0af432c1a845ccce534b1156d7b2b321aafe` |
| digest | `sha256:a214e804d58f6c675a016272f8f05193e6536288ec03365ab6fa4e58e7f7188d` |
| 晋级提交 | `32773d9eb3652c63d0d2f1b77d5cf02875392277` |

## 本地提交

`8dad0af4` stage，`32773d9e` 晋级。本回执另作一次只含本文件的本地提交。分支比 `origin/luna` 超前，本次没有 push。ZIP 与回退目录不入库。

exit=0
