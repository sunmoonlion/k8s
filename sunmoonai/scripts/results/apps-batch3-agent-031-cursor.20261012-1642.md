# Cursor 回执：卡 41 应用批 3 + 电脑代理 0.3.1

时间：2026-10-12 16:42（UTC+8）。两部分都做完。没有 push，没有移动本待办。真人安装/浏览器配对验收由所有者做，不记为本卡通过。

完成到：两部分各自的 `application-check APP=investment` 均退出 0。回退材料在 `~/sunmoon-probe-runs/apps-batch3-041/` 与 `~/sunmoon-probe-runs/windows-agent-031/`，未使用。

## 前提

`~/worktrees/fable/k8s` 分支 `fable`。投资三个钉：父仓 `b27ed92e…`、后端 `3a702802…`、网页 `80d68331…`；代理 runtime `5ccca651…`。`install.ps1.tmpl` 两边 SHA256 均为 `4e7619240fe9c760cab88423e6231652a1899fa478d5b96e6848e2c1ca4a7a1f`（无 BOM）。verify/upload/stage 在 PID 1 挂载命名空间注入 `AGENT_ZIP`/`APP`。

## 第一部分：应用批 3

| 步骤 | exit | 结果 |
| --- | --- | --- |
| 改钉 + `v7` / `'20261012_0018'` | — | sources 五处 revision 如上；admin 两行未动 |
| `platform-build OBJECT=app-platform/investment-app` | 0 | 后端锁 `sha256:f47ea47f…` / `3a702802…`；网页 `sha256:9f97bfbe…` / `80d68331…` |
| `platform-stage` / `application-deployment-plan` | 0 / 0 | 迁移 Job `investment-migrate-f47ea47f23f7-v7`；计划核到 `20261012_0018` |
| stage 提交 | `4602b53d` | `deploy(investment): 批 3 …（待办 41）` |
| `flux-release` | 0 | 候选 digest `sha256:de14f928…`，revision `4602b53d…` |
| 晋级提交 | `93b720d2` | flux-source = 候选 |
| `flux-source-apply` / `status` | 0 / 0 | |
| `application-check APP=investment` | 0 | PLAY RECAP failed=0 |

## 第二部分：代理 0.3.1

### A：组包

| 项 | 值 |
| --- | --- |
| sourceRevision | `5ccca651452000e5e20f20c0a446886a458d54b2` |
| manifestSha256 | `ce7a0ded10c6850132cdd4e5e183b750338c6f50076dbb8e4fb3368a097a52ff` |
| files / bytes | 102 / 501042993（候选目录）；zip 条目 102 |
| windows-candidate | `result=pass`，agent `0.3.1`，codex `0.155.1`，node `24.19.0`，`launchedAgent=false` |
| ZIP 路径 | `~/sunmoon-probe-runs/windows-agent-031/sunmoon-agent-0.3.1-5ccca65-windows-x64.zip` |
| ZIP SHA256 | `8542e3156e464e909b1a29115799b77e28d946d03bb452b9ae64591f0dfead91` |
| size_bytes | 175320303 |
| 打 zip | Python `zipfile`，deflate、正斜杠、102 条目、无反斜杠 |

组包物料与 0.3.0 相同（official node v24.19.0、同一 frozen 依赖、investment 生产 site、bundled CA）。首次 tsc 缺 `smol-toml`（不完整 node_modules），从 0.3.0 Windows 源复制完整 `node_modules` 后重跑通过。

### B：校验并上传

工具要求 ZIP 摘要与 `config.yaml` 一致，故在 verify 前写入六项（见 C）。

| 步骤 | exit | 结果 |
| --- | --- | --- |
| `agent-release-verify` | 0 | `verified-local`，files 102 |
| `agent-release-upload` | 0 | `uploaded=true`，`readback_verified=true`，`writer_read_denied=true`，`reader_write_denied=true` |

对象键：`windows-x64/0.3.1/sunmoon-agent-0.3.1-5ccca65-windows-x64.zip`。

### C：只发投资

`config.yaml` 六项：version `0.3.1`，source_revision `5ccca651…`，object_key 如上，zip/manifest/size 同 A。`codex_version`/`enabled`/`download_available` 不变。

| 步骤 | exit |
| --- | --- |
| `application-stage APP=investment` | 0 |
| `application-deployment-plan APP=investment` | 0 |
| stage 提交 | `7f908cce`（仅 config + agent-releases.sops + workload 四处 `config-sha256`→`611fb180…`） |
| `flux-release` | 0；候选 digest `sha256:594583a4…`，revision `7f908cce…` |
| 晋级提交 | `f960cb7a`；flux-source revision 仍为 stage 摘要 |
| `flux-source-apply` / `status` | 0 / 0 |
| `application-check APP=investment` | 0 |

后端 `image.lock` 仍为 `sha256:f47ea47f23f75f1c5cfca9132b4adc1af819a741507b272efba2c2c41759164e`（本卡第一部分，代理段未换）。

## 本地提交

应用：`4602b53d` stage，`93b720d2` 晋级；代理：`7f908cce` stage，`f960cb7a` 晋级；本回执另提。zip/回退不入库。不 push。投资父仓与子模块已切回 `fable`。

exit=0
