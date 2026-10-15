# R4-qwen — 本地机同步配置

- 执行人：Qwen（本地机）
- 时间：2026-10-15 14:29–14:39（本地机时间）
- 依据：`k8s/docs/rename.md` R4 节（k8s `6be50a41`）；前提 R3「通过」、R4-opus 远程机「完成」、手册 R4 状态「本地机 Qwen 现在可以做」。

## 1. `~/five-repos-sync/config.sh`（改两行，先备份）

改前 `cp config.sh config.sh.bak-rename`（680 字节，原本不存在、新建）。只改 `REPOS` 里两行，`diff config.sh.bak-rename config.sh`：

```text
19c19
<   "knowledge-app"
---
>   "knowbase-app"
21c21
<   "info-app"
---
>   "knowfeed-app"
```

改后 `REPOS=( "tpl-app" "knowbase-app" "k8s" "knowfeed-app" "investment-app" "runtime" )`；`bash -n config.sh` 通过（无语法错误）。与 R4-opus 远程机的 `19c19`/`21c21` 完全一致。`config.sh` 不在 Git 里、各机一份，未提交。

## 2. `repos.conf`（只 grep 核对，未碰 toolboxes 的 git）

```text
$ grep -n know ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf
4:$HOME/master/knowfeed-app
6:$HOME/master/knowbase-app
```

只有这两行（`GREP_EXIT=0`），与手册 R4 第 287 行要求一致。本地机 `toolboxes` 已由所有者拉到 `e8f584e`、`repos.conf` 工作区干净；Qwen 全程只读 `grep`/`status`，**未提交、未拉、未还原 toolboxes**。toolboxes 工作区另有一处与 R4 无关的 `Vlinux/utils/switch-sunmoon-hosts/sunmoon-hosts-schemes.txt`（M），非我造成、未触碰。

## 3. 同步脚本 `WS=qwen bash ~/switch-test/human-local.sh`（exit=0）

`~/switch-test/human-local.sh` 是转发器，`exec` 到仓里 `~/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/human-local.sh`（R1 已改新名：`FIVE="k8s knowfeed-app investment-app knowbase-app tpl-app"`、子仓 `knowfeed-app/knowfeed-backend` 等）。脚本是「拉」（`sync-five-repos.sh from-remote` + `pull --ff-only`），不 push 本地提交；第 0 步安全检查通过。输出原样：

```text
===== 0. 先看本地有没有没推回的东西
  干净，可以拉
===== 1. 同步全部（工位 qwen）

==> 检查远程五仓
  OK  tpl-app
  OK  knowbase-app
  OK  k8s
  OK  knowfeed-app
  OK  investment-app
  OK  runtime

==> 检查本地五仓（目标端）
  OK  tpl-app
  OK  knowbase-app
  OK  k8s
  OK  knowfeed-app
  OK  investment-app
  OK  runtime

==> 远程 tpl-app：git push
Everything up-to-date

==> 远程 knowbase-app：git push
Everything up-to-date
Everything up-to-date
Everything up-to-date

==> 远程 k8s：git push
Everything up-to-date
Everything up-to-date

==> 远程 knowfeed-app：git push
Everything up-to-date
Everything up-to-date

==> 远程 investment-app：git push
Everything up-to-date
Everything up-to-date

==> 远程 runtime：git push
Everything up-to-date

==> 本地 tpl-app：git pull
From https://github.com/sunmoonlion/tpl-app
 * branch            qwen       -> FETCH_HEAD
Updating 0dc186b..af00d65
Fast-forward
 .cursor/rules/sunmoonai-architecture.mdc | 2 +-
 AGENTS.md                                | 2 +-
 tpl-admin-frontend                       | 2 +-
 tpl-backend                              | 2 +-
 tpl-web-frontend                         | 2 +-
 5 files changed, 5 insertions(+), 5 deletions(-)
Synchronizing submodule url for 'tpl-admin-frontend'
Synchronizing submodule url for 'tpl-backend'
Synchronizing submodule url for 'tpl-web-frontend'
Submodule path 'tpl-admin-frontend': checked out '8f8338e8685bd4d0b1bc17d472687b7d2e630045'
Submodule path 'tpl-backend': checked out '3c3d252be417a52b2e2bfb0a3cb09e68c6d1cb0f'
Submodule path 'tpl-web-frontend': checked out '3b83285eeac599af5779276d2de7ba3bed3d4364'

==> 本地 knowbase-app：git pull
From https://github.com/sunmoonlion/knowbase-app
 * branch            qwen       -> FETCH_HEAD
Already up to date.
Synchronizing submodule url for 'knowbase-admin-frontend'
Synchronizing submodule url for 'knowbase-backend'
Synchronizing submodule url for 'knowbase-web-frontend'

==> 本地 k8s：git pull
From https://github.com/sunmoonlion/k8s
 * branch              qwen       -> FETCH_HEAD
Already up to date.

==> 本地 knowfeed-app：git pull
From https://github.com/sunmoonlion/knowfeed-app
 * branch            qwen       -> FETCH_HEAD
Already up to date.
Synchronizing submodule url for 'knowfeed-admin-frontend'
Synchronizing submodule url for 'knowfeed-backend'
Synchronizing submodule url for 'knowfeed-web-frontend'

==> 本地 investment-app：git pull
From https://github.com/sunmoonlion/investment-app
 * branch            qwen       -> FETCH_HEAD
Updating dad0041..eb1f800
Fast-forward
 .cursor/rules/sunmoonai-architecture.mdc                            | 2 +-
 AGENTS.md                                                           | 2 +-
 contracts/README.md                                                 | 6 +++---
 ...val-provider-lock.json => knowbase-retrieval-provider-lock.json} | 4 ++--
 docs/template-alignment-durable-delivery.md                         | 2 +-
 investment-admin-frontend                                           | 2 +-
 investment-backend                                                  | 2 +-
 investment-web-frontend                                             | 2 +-
 8 files changed, 11 insertions(+), 11 deletions(-)
 rename contracts/{knowledge-retrieval-provider-lock.json => knowbase-retrieval-provider-lock.json} (66%)
Synchronizing submodule url for 'investment-admin-frontend'
Synchronizing submodule url for 'investment-backend'
Synchronizing submodule url for 'investment-web-frontend'
Submodule path 'investment-admin-frontend': checked out 'c3c1e1d0524816df006acf250d8767282d8d8ac7'
Submodule path 'investment-backend': checked out 'a6e6ceb2c0c70204ec11295fa9088e5eb53701ac'
Submodule path 'investment-web-frontend': checked out '0dd55a564615a29c43e394890b427c0886352f8c'

==> 本地 runtime：git pull
From https://github.com/sunmoonlion/runtime
 * branch            qwen       -> FETCH_HEAD
Updating 76832a8..8cac5ab
Fast-forward
 CHECKPOINT.md         | 2 +-
 scripts/env-header.sh | 2 +-
 2 files changed, 2 insertions(+), 2 deletions(-)

==> 同步完成：远程 -> 本地
  k8s                          6be50a41
  knowfeed-app                 1fd9da0
  investment-app               eb1f800
  knowbase-app                 ba6c77c
  tpl-app                      af00d65
  investment-app/investment-backend a6e6ceb
  knowbase-app/knowbase-backend 1d8fa10
  runtime                      8cac5ab
===== 1b. 子仓接回 qwen 分支
  investment-app/investment-backend            a6e6ceb
  investment-app/investment-web-frontend       0dd55a5
  investment-app/investment-admin-frontend     c3c1e1d
  tpl-app/tpl-backend                          3c3d252
  tpl-app/tpl-web-frontend                     3b83285
  tpl-app/tpl-admin-frontend                   8f8338e
===== 2. 刷新 ~/switch-test：两个脚本只是转发器，永远跑仓里当前工位的最新版（副本没有内容可过期）
===== 3. 待办：astra（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/astra）
  （空）
===== 3. 待办：cursor（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/cursor）
  （空）
===== 3. 待办：fable（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/fable）
  （空）
===== 3. 待办：kimi（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/kimi）
  （空）
===== 3. 待办：luna（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/luna）
  （空）
===== 3. 待办：opus（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/opus）
  （空）
===== 3. 待办：qwen（/home/zymun/worktrees/qwen/k8s/sunmoonai/docs/dev-investment-agent/switch-test/inbox/qwen）
  - 2026-10-14-rename-R0.md：Qwen 卡：改名 R0——本地机的两项只读检查

===== 同步完成。对哪个助手说「请看 inbox/<它的名字>」，它就只看那个箱子。（每条做完自己本地提交；推回用 human-remote.sh）
```

同步脚本最后一句（手册 R4 停点要求原样记录）：

> ===== 同步完成。对哪个助手说「请看 inbox/<它的名字>」，它就只看那个箱子。（每条做完自己本地提交；推回用 human-remote.sh）

## 4. 核对结论

- 手册 R4 第 291 行两个「要看到」都满足：① 同步脚本正常走完、`exit=0`、**不报找不到仓**（第 1 步远程/本地各六仓全 `OK`，说明 `config.sh` 新名生效）；② 本地 qwen 工位的 `investment-app`（`dad0041..eb1f800`，含 `knowledge-retrieval-provider-lock.json → knowbase-retrieval-provider-lock.json` 改名）、`runtime`（`76832a8..8cac5ab`）、`tpl-app`（`0dc186b..af00d65`）、`k8s`（`6be50a41`）都拉到了 R1 的提交；`knowfeed-app`（`1fd9da0`）、`knowbase-app`（`ba6c77c`）本就是 R1 提交，`Already up to date`。
- 全部 `git push` 均 `Everything up-to-date`（无本地未推提交）；pull 均 `Fast-forward` 或 `Already up to date`，无分叉、无冲突。
- 第 1b 子仓接回 qwen 分支：`investment-app`、`tpl-app` 各三子仓；`knowfeed-app`/`knowbase-app` 子仓 R3 已在 qwen 分支，脚本按第 67 行跳过（未列出即已在 qwen 分支）。
- 第 2 步刷新后 `~/switch-test` 只剩 `human-local.sh`、`human-remote.sh` 两个转发器（14:37 重新生成），旧副本已清。
- `inbox/qwen` 还留着 `2026-10-14-rename-R0.md`（改名 R0 的派活卡，任务已完成、未移 `done/`；不影响同步，改名收尾时一并处理）。
- **改名窗口到此结束**（手册第 45 行：R4 两台机器的仓名与同步配置都改好后，由 Qwen 跑一次 `human-local.sh` 验证能走通；从那以后照常同步）。等 Opus 审 `R4-qwen`、在手册 R4 节状态写「通过」后，再进 R5（集群切换，须等 R5 状态写成「可执行」）。

exit=0
