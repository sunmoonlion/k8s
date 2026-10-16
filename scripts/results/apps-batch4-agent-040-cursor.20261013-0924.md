# Cursor 回执：卡 42 应用批 4 + 电脑代理 0.4.0

时间：2026-10-13 09:24（UTC+8）。两部分都做完。没有 push，没有移动本待办。真人安装/浏览器配对验收由所有者做，不记为本卡通过。

完成到：两部分各自的 `application-check APP=investment` 均退出 0。回退材料在 `~/sunmoon-probe-runs/apps-batch4-042/` 与 `~/sunmoon-probe-runs/windows-agent-040/`，未使用。

## 前提

`~/worktrees/fable/k8s` 分支 `fable`。投资钉：父仓 `99e92f56…`、后端 `e73ffa5e…`、网页 `27f6b9b3…`；代理 runtime `f85fe312…`。config 仍 `v7` / `'20261012_0018'`（本卡未改）。`install.ps1.tmpl` 两边 SHA256 均为 `49e62ae1519be256531555461ded173d6d8f32c27fba0909c4fd3f9f83435923`（无 BOM）。verify/upload/stage 在 PID 1 挂载命名空间注入 `AGENT_ZIP`/`APP`/`OBJECT`。

## 第一部分：应用批 4

| 步骤 | exit | 结果 |
| --- | --- | --- |
| `platform-status` | 0 | |
| 改钉（只 sources 五行） | — | admin 两行未动；schema 未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 后端锁 `sha256:6a189617…` / `e73ffa5e…`；网页 `sha256:668f539e…` / `27f6b9b3…`；管理端未换 |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 迁移 Job `investment-migrate-6a189617e8ee-v7`（仍 v7，无新 schema）；计划核到 `20261012_0018` |
| stage 提交 | `b5baa3e0` | `deploy(investment): 批 4 …（待办 42）` |
| `flux-release` | 0 | 候选 digest `sha256:33195ba0…`，revision `b5baa3e0…` |
| 晋级提交 | `768d43c3` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0 |

## 第二部分：代理 0.4.0

### A：组包

| 项 | 值 |
| --- | --- |
| sourceRevision | `f85fe3120fa1e0279d65e27b32db962e5adcd0a1` |
| manifestSha256 | `bf3b43a594d0873ecff354b2a4b8139602c222013424e253f89041efe36e38ac` |
| files / bytes | 108 / 501087161（候选目录）；zip 条目 108 |
| windows-candidate | `result=pass`，agent `0.4.0`，codex `0.155.1`，node `24.19.0`，`launchedAgent=false` |
| ZIP 路径 | `~/sunmoon-probe-runs/windows-agent-040/sunmoon-agent-0.4.0-f85fe31-windows-x64.zip` |
| ZIP SHA256 | `54ee3666b1628b89956bdb7e502c58e1e8ded3f19471d3f2cec09e9418ac800b` |
| size_bytes | 175334353 |
| 打 zip | Python `zipfile`，deflate、正斜杠、108 条目、无反斜杠 |

组包物料与 0.3.1 相同（official node v24.19.0、同一 frozen 依赖、dev-kind site/CA）。构建用 node_modules 从 0.3.1 Windows 源复制（含 `smol-toml`）。

### B：校验并上传

工具要求 ZIP 摘要与 `config.yaml` 一致，故在 verify 前写入六项（见 C）。

| 步骤 | exit | 结果 |
| --- | --- | --- |
| `agent-release-verify` | 0 | `verified-local`，files 108 |
| `agent-release-upload` | 0 | `uploaded=true`，`readback_verified=true`，`writer_read_denied=true`，`reader_write_denied=true` |

对象键：`windows-x64/0.4.0/sunmoon-agent-0.4.0-f85fe31-windows-x64.zip`。

### C：只发投资

`config.yaml` 六项：version `0.4.0`，source_revision `f85fe312…`，object_key 如上，zip/manifest/size 同 A。`codex_version`/`enabled`/`download_available` 不变。

| 步骤 | exit |
| --- | --- |
| `application-stage APP=investment` | 0 |
| `application-deployment-plan APP=investment` | 0 |
| stage 提交 | `f4919b79`（仅 config + agent-releases.sops + workload 四处 `config-sha256`→`26d195ac…`） |
| `flux-release` | 0；候选 digest `sha256:1e8a3032…`，revision `f4919b79…` |
| 晋级提交 | `1822a8fb`；flux-source revision 仍为 stage 摘要 |
| `flux-source-apply` / `status` | 0 / 0 |
| `application-check APP=investment` | 0 |

后端 `image.lock` 仍为 `sha256:6a189617e8ee0f4550f15df037f6f60cd56f6e03d424381b33571d5accccfeed`（本卡第一部分，代理段未换）。

## 本地提交

应用：`b5baa3e0` stage，`768d43c3` 晋级；代理：`f4919b79` stage，`1822a8fb` 晋级；本回执另提。zip/回退不入库。不 push。投资父仓与子模块在 `fable`（后端 `e73ffa5`、网页 `27f6b9b`）。

exit=0
