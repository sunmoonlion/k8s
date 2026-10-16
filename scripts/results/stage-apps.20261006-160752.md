# 待办 25 回传：stage-apps

时间：2026-10-06 16:07。开始时 HEAD `84ec0a6e`，工作区干净。`encrypt.yaml` 第 9 行有 `Seed the candidate from the committed ciphertext when this worktree has none yet`。

## 一、tpl 再暂存

`platform-stage OBJECT=app-platform/tpl-app` 退出 0（16:02:40–16:03:35）。`git status` 与 `git diff --stat` 都是空的。

## 二、平台级输入

两份都在：

- `/etc/sunmoon/services/sunmoon-kind/sandbox-provisioner.yaml`
- `/etc/sunmoon/services/sunmoon-kind/relay.yaml`

## 三、三个应用暂存

| 应用 | 退出码 | 用时 |
| --- | --- | --- |
| info | 0 | 73s |
| knowledge | 2 | 26s |
| investment | 0 | 66s |

knowledge 失败任务：`Validate knowledge provider and upstream original ownership`（`provider/prepare.yaml:2`）。断言 `cfg.knowledge_provider.source_prefix == 'info/original/'`。配置 `knowledge-backend/config.yaml` 里写的是 `source_prefix: info/`。没有改配置。knowledge 的 gitops 没有新改动。

暂存后 `git status`（提交前）是 info、investment 的 workload，加上 investment 的 `runtime/kustomization.yaml` 和未跟踪的 `runtime/domain.sops.yaml`。没有已跟踪的 sops 文件被改写。

密文：`investment-app/investment-backend/runtime/domain.sops.yaml` 有 5 段 `ENC[`、1 个 `sops:` 头，文件头是 `BEGIN AGE ENCRYPTED FILE`。`BEGIN PRIVATE KEY` / `BEGIN PUBLIC KEY` 在该文件和整个 `gitops/` 里都是 0。info、knowledge 的 `runtime/domain.sops.yaml` 不存在，仓库里这个路径只有 investment 一份。

investment `runtime/workload.yaml` 新增行里有：`CROSS_APP_TARGETS_JSON`、`CROSS_APP_SOURCES_JSON`、一组 `WORKBENCH_*`（含 `WORKBENCH_PROVISIONER_URL` 指向 `sandbox-provisioner.sandbox-platform-dev`）、`kind: Deployment` / `name: investment-runner`、四条 `kind: NetworkPolicy`。

knowledge 的对应 diff 为空（暂存失败）。

info 新增行里有：`CROSS_APP_TARGETS_JSON`、`CROSS_APP_SOURCES_JSON`、`KNOWLEDGE_APP_DATASET_URL`、`memory: 1536Mi`、`kind: NetworkPolicy`、`ipBlock: {cidr: 0.0.0.0/0}`。

私有输入三份都在，属主 root，模式 0600：`/etc/sunmoon/applications/sunmoon-kind/investment/domain.yaml`、备份 `/mnt/sunmoon-data/backups/applications/sunmoon-kind/investment/domain.yaml`、`/etc/sunmoon/services/sunmoon-kind/workbench-signing.yaml`。

## 四、部署计划

四个都退出 0。核到的 schema：

- tpl `20260911_0003`
- info `20260929_0013`
- knowledge `20260927_0007`
- investment `20260929_0012`

## 五、提交

`9765b5b2 test(local): 待办 23c 暂存 info、knowledge、investment 的候选`。18 个文件。knowledge 不在其中。

## 结论

不通过。knowledge 暂存退出 2，`source_prefix` 对不上；info 和 knowledge 没有 `runtime/domain.sops.yaml`。tpl 再暂存为空，info 与 investment 已暂存，四个迁移 head 与待办一致。
