# Cursor 回执：卡 48 电脑代理 0.4.1 + 新建项目对话框与登记前核目录

时间：2026-10-14 16:51（UTC+8）。两部分各自的 `application-check APP=investment` 均退出 0。没有 push，没有移动本待办。真人安装/新建项目验收由所有者做。

完成到：代理晋级 `d3ee6ef5`、应用晋级 `f267ba2a`。回退材料在 `~/sunmoon-probe-runs/windows-agent-041-release/` 与 `~/sunmoon-probe-runs/new-project-agent-048/`，未使用。

## 前提

`~/worktrees/qwen/k8s` 分支 `qwen`。卡 47 已上线（改钉前父仓 `cf7dfaaa…` / 后端 `e937bbaa…` / 网页 `6321e7c8…`）。config 仍 `v7` / `'20261012_0018'`。`install.ps1.tmpl` 两边 SHA256 均为 `49e62ae1519be256531555461ded173d6d8f32c27fba0909c4fd3f9f83435923`（无 BOM）。verify/upload/stage 在 PID 1 挂载命名空间注入 `AGENT_ZIP`/`APP`/`OBJECT`。`platform-status` 0。

## 第一部分：代理 0.4.1

### A：组包

| 项 | 值 |
| --- | --- |
| sourceRevision | `76832a8da4e65a8692fac453c35b5ef2081d0090` |
| manifestSha256 | `7f72f68103d7c0d84237d8a3573ac0f2fd1cb6e796f75db321ea94cc8563a205` |
| files / bytes | 109 / 501103153（候选目录）；zip 条目 109 |
| windows-candidate | `result=pass`，agent `0.4.1`，codex `0.155.1`，node `24.19.0`，`launchedAgent=false` |
| ZIP 路径 | `~/sunmoon-probe-runs/windows-agent-041/sunmoon-agent-0.4.1-76832a8-windows-x64.zip` |
| ZIP SHA256 | `a2b52c052180988b43f8f6a999a5190d7f99a1cb4a26eddcdfd70fdf38424695` |
| size_bytes | 175339288 |
| 打 zip | Python `zipfile`，deflate、正斜杠、109 条目；含 `localProjects.js` |

组包物料与 0.4.0 相同（official node v24.19.0、同一 frozen 依赖、dev-kind site/CA）。构建用 `node_modules` 从 0.4.0 Windows 源复制（含 `smol-toml`）。Windows checkout：`…/windows-agent-041-release/src-76832a8`。

### B：校验并上传

工具要求 ZIP 摘要与 `config.yaml` 一致，故在 verify 前写入六项（见 C）。

| 步骤 | exit | 结果 |
| --- | --- | --- |
| `agent-release-verify` | 0 | `verified-local`，files 109 |
| `agent-release-upload` | 0 | `uploaded=true`，`readback_verified=true`，`writer_read_denied=true`，`reader_write_denied=true` |

对象键：`windows-x64/0.4.1/sunmoon-agent-0.4.1-76832a8-windows-x64.zip`。

### C：只发投资

`config.yaml` 六项：version `0.4.1`，source_revision `76832a8…`，object_key 如上，zip/manifest/size 同 A。`codex_version`/`enabled`/`download_available` 不变。

| 步骤 | exit |
| --- | --- |
| `application-stage APP=investment` | 0 |
| `application-deployment-plan APP=investment` | 0 |
| stage 提交 | `9791fa77`（仅 config + agent-releases.sops + workload 四处 `config-sha256`→`147e9797…`） |
| `flux-release` | 0；候选 digest `sha256:55ed5d32…`，revision `9791fa77…` |
| 晋级提交 | `d3ee6ef5` |
| `flux-source-apply` / `status` | 0 / 0 |
| `application-check APP=investment` | 0 |

后端镜像本段未换（仍卡 47 的 `02f1054f…`）。

## 第二部分：应用

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改钉（父仓 + 后端两行 + 网页两行） | — | admin 未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 后端 `sha256:68f4a7e7…` / `260c3d90…`；网页 `sha256:bce18c29…` / `9337a290…`；管理端「已是这一份」 |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 迁移 `investment-migrate-68f4a7e7ded7-v7`；schema `20261012_0018` |
| stage 提交 | `58a3c45e` | `deploy(investment): 新建项目先请代理建好文件夹或拉好仓库、登记前核目录（待办 48 应用）` |
| `flux-release` | 0 | 候选 digest `sha256:a58c8d94…`，revision `58a3c45e…` |
| 晋级提交 | `f267ba2a` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0；迁移 Job Complete |

## 本地提交

代理：`9791fa77` stage，`d3ee6ef5` 晋级；应用：`58a3c45e` stage，`f267ba2a` 晋级；本回执另提。zip/回退不入库。不 push。

exit=0
