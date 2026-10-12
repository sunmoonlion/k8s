# Cursor 回执：卡 39 投资电脑代理 0.3.0

时间：2026-10-12 09:38（UTC+8）。A、B、C 都做完。没有 push，没有移动本待办。真人安装/浏览器配对验收由所有者做，不记为本卡通过。

完成到：C 的 `application-check APP=investment` 退出 0。回退材料在 `~/sunmoon-probe-runs/windows-agent-030/`，未使用。

## 前提

卡 38 已完成（`application-check` 退出 0，后端镜像 `9282cde9…`）。runtime Windows checkout `dbe5d01c2051f6703f18fc41d853e049e747ebf3`。`install.ps1.tmpl` 两边 SHA256 均为 `4e7619240fe9c760cab88423e6231652a1899fa478d5b96e6848e2c1ca4a7a1f`（无 BOM）。verify/upload/stage 在 PID 1 挂载命名空间注入 `AGENT_ZIP`/`OBJECT`/`APP`。

## A：组包

| 项 | 值 |
| --- | --- |
| sourceRevision | `dbe5d01c2051f6703f18fc41d853e049e747ebf3` |
| manifestSha256 | `fdcf721873a87845d0867d998bb3f1d3e7fab3ec0c4fd796ac40c3a2e54ba6b5` |
| files / bytes | 100 / 501034516（与 astra `834e4e9` 候选 files/bytes 相同） |
| windows-candidate | `result=pass`，agent `0.3.0`，codex `0.155.1`，node `24.19.0`，`launchedAgent=false` |
| ZIP 路径 | `~/sunmoon-probe-runs/windows-agent-030/sunmoon-agent-0.3.0-dbe5d01-windows-x64.zip` |
| ZIP SHA256 | `d55b344397134ee17bf4732d6770e818ee5d3c23329dff6bd66237a53c47e011` |
| size_bytes | 174270836 |
| 打 zip | Python `zipfile`，deflate、正斜杠、100 条目、无反斜杠 |

## B：校验并上传

工具要求 ZIP 摘要与 `config.yaml` 一致，故在 verify 前写入六项（见 C）。

| 步骤 | exit | 结果 |
| --- | --- | --- |
| `agent-release-verify` | 0 | `verified-local`，files 100 |
| `agent-release-upload` | 0 | `uploaded=true`，`readback_verified=true`，`writer_read_denied=true`，`reader_write_denied=true` |

对象键：`windows-x64/0.3.0/sunmoon-agent-0.3.0-dbe5d01-windows-x64.zip`。

## C：只发投资

`config.yaml` 六项：version `0.3.0`，source_revision `dbe5d01…`，object_key 如上，zip/manifest/size 同 A。`codex_version`/`enabled`/`download_available` 不变。

| 步骤 | exit |
| --- | --- |
| `application-stage APP=investment` | 0 |
| `application-deployment-plan APP=investment` | 0 |
| stage 提交 | `28527b9f`（仅 config + agent-releases.sops + workload 四处 `config-sha256`→`68b01ce6…`） |
| `flux-release` | 0；候选 digest `sha256:d6725af4…`，revision `28527b9f…` |
| 晋级提交 | `a7bac4c0`；flux-source revision 仍为 stage 摘要 |
| `flux-source-apply` / `status` | 0 / 0 |
| `application-check APP=investment` | 0 |

后端 `image.lock` 仍为 `sha256:9282cde9c6f79d371c225c290f2caab029ef19f23bf148cd14069fe671f00e9c`（卡 38 批 1，本卡未换）。

## 本地提交

`28527b9f` stage，`a7bac4c0` 晋级；本回执另提。zip/回退不入库。不 push。

exit=0
