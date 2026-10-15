# R3-qwen — 本地机检出换名

- 执行人：Qwen（本地机）
- 时间：2026-10-15 14:03–14:10（本地机时间）
- 依据：`k8s/docs/rename.md` R3 节、工具 `k8s/docs/rename-tools/r3_checkout.sh`（k8s `7250fe10`）。
- 前提：R2「通过」、R3-opus 远程机「完成」、手册 R3 节状态「本地机 Qwen 现在可以做」。脚本前提检查（旧主目录与五个工位都在且干净、新名目录都不在、`repos.conf` 恰有旧名一行、`model-branch.sh` 在）逐条过，未停。

## 1. 真跑（bash，两组各一次）

```bash
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh info-app knowfeed-app        # exit=0
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh knowledge-app knowbase-app   # exit=0
```

备份（旧主目录 + 五个工位旧检出，整目录挪入、不删）：
- `~/rename-backup/20261015-1403-info-app`
- `~/rename-backup/20261015-1408-knowledge-app`

本地机 GitHub 走 https（`GH=https://github.com/sunmoonlion/`、`SUB=https://github.com/sunmoonlion/`），脚本从旧主目录取前缀，未改脚本；五个工位齐全，`WS` 用默认。下面两段是脚本 stdout+stderr 原样（含 git 的 `HEAD is now at` 行；远程机 R3-opus 回执把这些行去掉了，本地机按「原样」保留）。

## 2. info-app → knowfeed-app（脚本输出原样）

```text
== 备份目录 /home/zymun/rename-backup/20261015-1403-info-app
== GH=https://github.com/sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=https://github.com/sunmoonlion/
== 旧 origin 推送地址：https://github.com/sunmoonlion/info-app.git https://gitee.com/sunmoonlion/info-app.git
== 旧检出已挪开
HEAD is now at 0f85341 chore: 子仓指针跟到 luna/fable 对齐合并提交（树不变）
knowfeed-app         挂出 /home/zymun/worktrees/cursor/knowfeed-app
HEAD is now at 0f85341 chore: 子仓指针跟到 luna/fable 对齐合并提交（树不变）
knowfeed-app         挂出 /home/zymun/worktrees/fable/knowfeed-app
HEAD is now at 0f85341 chore: 子仓指针跟到 luna/fable 对齐合并提交（树不变）
knowfeed-app         挂出 /home/zymun/worktrees/kimi/knowfeed-app
HEAD is now at 0f85341 chore: 子仓指针跟到 luna/fable 对齐合并提交（树不变）
knowfeed-app         挂出 /home/zymun/worktrees/luna/knowfeed-app
HEAD is now at 1fd9da0 rename: info → knowfeed、knowledge → knowbase（0025 R1）
knowfeed-app         挂出 /home/zymun/worktrees/qwen/knowfeed-app
/home/zymun/worktrees/cursor/knowfeed-app branch=cursor head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=cursor up=origin/cursor head=27bc4c9 origin=27bc4c9 url=https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=cursor up=origin/cursor head=cbc7655 origin=cbc7655 url=https://github.com/sunmoonlion/knowfeed-backend.git
      push https://github.com/sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=cursor up=origin/cursor head=0ac00fa origin=0ac00fa url=https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
/home/zymun/worktrees/fable/knowfeed-app branch=fable head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=fable up=origin/fable head=27bc4c9 origin=27bc4c9 url=https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=fable up=origin/fable head=cbc7655 origin=cbc7655 url=https://github.com/sunmoonlion/knowfeed-backend.git
      push https://github.com/sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=fable up=origin/fable head=0ac00fa origin=0ac00fa url=https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
/home/zymun/worktrees/kimi/knowfeed-app  branch=kimi head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=kimi up=origin/kimi head=27bc4c9 origin=27bc4c9 url=https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=kimi up=origin/kimi head=cbc7655 origin=cbc7655 url=https://github.com/sunmoonlion/knowfeed-backend.git
      push https://github.com/sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=kimi up=origin/kimi head=0ac00fa origin=0ac00fa url=https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
/home/zymun/worktrees/luna/knowfeed-app  branch=luna head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=luna up=origin/luna head=27bc4c9 origin=27bc4c9 url=https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=luna up=origin/luna head=cbc7655 origin=cbc7655 url=https://github.com/sunmoonlion/knowfeed-backend.git
      push https://github.com/sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=luna up=origin/luna head=0ac00fa origin=0ac00fa url=https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
/home/zymun/worktrees/qwen/knowfeed-app  branch=qwen head=1fd9da0 origin=1fd9da0 dirty=0
  knowfeed-admin-frontend        branch=qwen up=origin/qwen head=3f01f34 origin=3f01f34 url=https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://github.com/sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  knowfeed-backend               branch=qwen up=origin/qwen head=ecce5c7 origin=ecce5c7 url=https://github.com/sunmoonlion/knowfeed-backend.git
      push https://github.com/sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  knowfeed-web-frontend          branch=qwen up=origin/qwen head=327c526 origin=327c526 url=https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://github.com/sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/knowfeed-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowfeed-app.git (push)
origin	https://github.com/sunmoonlion/knowfeed-app.git (fetch)
origin	https://github.com/sunmoonlion/knowfeed-app.git (push)
origin	https://gitee.com/sunmoonlion/knowfeed-app.git (push)
== 主目录 remote（旧，备份）
gitee	https://gitee.com/sunmoonlion/info-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/info-app.git (push)
origin	https://github.com/sunmoonlion/info-app.git (fetch)
origin	https://github.com/sunmoonlion/info-app.git (push)
origin	https://gitee.com/sunmoonlion/info-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/investment-app
6:$HOME/master/knowledge-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
```

## 3. knowledge-app → knowbase-app（脚本输出原样）

```text
== 备份目录 /home/zymun/rename-backup/20261015-1408-knowledge-app
== GH=https://github.com/sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=https://github.com/sunmoonlion/
== 旧 origin 推送地址：https://github.com/sunmoonlion/knowledge-app.git https://gitee.com/sunmoonlion/knowledge-app.git
== 旧检出已挪开
HEAD is now at d049070 chore: 子模块前移（knowledge-backend 样例改 1/20 抽样，账 96）
knowbase-app         挂出 /home/zymun/worktrees/cursor/knowbase-app
HEAD is now at d049070 chore: 子模块前移（knowledge-backend 样例改 1/20 抽样，账 96）
knowbase-app         挂出 /home/zymun/worktrees/fable/knowbase-app
HEAD is now at d049070 chore: 子模块前移（knowledge-backend 样例改 1/20 抽样，账 96）
knowbase-app         挂出 /home/zymun/worktrees/kimi/knowbase-app
HEAD is now at d049070 chore: 子模块前移（knowledge-backend 样例改 1/20 抽样，账 96）
knowbase-app         挂出 /home/zymun/worktrees/luna/knowbase-app
HEAD is now at ba6c77c rename: info → knowfeed、knowledge → knowbase（0025 R1）
knowbase-app         挂出 /home/zymun/worktrees/qwen/knowbase-app
/home/zymun/worktrees/cursor/knowbase-app branch=cursor head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=cursor up=origin/cursor head=df64aa5 origin=df64aa5 url=https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=cursor up=origin/cursor head=e30525f origin=548e84a url=https://github.com/sunmoonlion/knowbase-backend.git
      push https://github.com/sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=cursor up=origin/cursor head=71e5b2e origin=71e5b2e url=https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
/home/zymun/worktrees/fable/knowbase-app branch=fable head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=fable up=origin/fable head=df64aa5 origin=df64aa5 url=https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=fable up=origin/fable head=e30525f origin=e30525f url=https://github.com/sunmoonlion/knowbase-backend.git
      push https://github.com/sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=fable up=origin/fable head=71e5b2e origin=71e5b2e url=https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
/home/zymun/worktrees/kimi/knowbase-app  branch=kimi head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=kimi up=origin/kimi head=df64aa5 origin=df64aa5 url=https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=kimi up=origin/kimi head=e30525f origin=548e84a url=https://github.com/sunmoonlion/knowbase-backend.git
      push https://github.com/sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=kimi up=origin/kimi head=71e5b2e origin=71e5b2e url=https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
/home/zymun/worktrees/luna/knowbase-app  branch=luna head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=luna up=origin/luna head=df64aa5 origin=df64aa5 url=https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=luna up=origin/luna head=e30525f origin=548e84a url=https://github.com/sunmoonlion/knowbase-backend.git
      push https://github.com/sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=luna up=origin/luna head=71e5b2e origin=71e5b2e url=https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
/home/zymun/worktrees/qwen/knowbase-app  branch=qwen head=ba6c77c origin=ba6c77c dirty=0
  knowbase-admin-frontend        branch=qwen up=origin/qwen head=1ae7ed7 origin=1ae7ed7 url=https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://github.com/sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowbase-backend               branch=qwen up=origin/qwen head=1d8fa10 origin=1d8fa10 url=https://github.com/sunmoonlion/knowbase-backend.git
      push https://github.com/sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowbase-web-frontend          branch=qwen up=origin/qwen head=3fd9312 origin=3fd9312 url=https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://github.com/sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/knowbase-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowbase-app.git (push)
origin	https://github.com/sunmoonlion/knowbase-app.git (fetch)
origin	https://github.com/sunmoonlion/knowbase-app.git (push)
origin	https://gitee.com/sunmoonlion/knowbase-app.git (push)
== 主目录 remote（旧，备份）
gitee	https://gitee.com/sunmoonlion/knowledge-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowledge-app.git (push)
origin	https://github.com/sunmoonlion/knowledge-app.git (fetch)
origin	https://github.com/sunmoonlion/knowledge-app.git (push)
origin	https://gitee.com/sunmoonlion/knowledge-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/investment-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
```

## 4. 核对结论

- 十个工位（五个 × 两组）`branch` = 工位名、`dirty=0`，`mb` 都是「挂出」（无「从 master 新建」「失败」「冲突」）。
- 子仓 `branch` = 工位名、`up` = `origin/<工位>`、`url` 是新仓名，推送地址 GitHub（https）与 gitee 各一（新仓名）。
- 主目录 remote（新）与备份的（旧）相比只有仓名变了：协议 https、主机、推送地址个数（origin fetch/push GitHub + origin push gitee + gitee fetch/push）都相同。
- `repos.conf`：第 4 行 `$HOME/master/knowfeed-app`、第 6 行 `$HOME/master/knowbase-app`，`$HOME` 写法与位置不变（k8s / investment-app / tpl-app / runtime 未动）。
- `head` ≠ `origin` 一处（照实报、不动，与远程机 R3-opus 同）：cursor、kimi、luna 三个工位的 `knowledge-backend` 子仓 `head=e30525f`、`origin=548e84a`；fable（`e30525f`=`e30525f`）、qwen（`1d8fa10`=`1d8fa10`）一致。即父仓这三个分支记的提交比 GitHub 子仓同名分支头新两个提交（冻结前没推），可快进、无丢失。手册 R3 节状态已预告「本地机若出现同样情况照写即可」，与 R3-opus 第 3 节结论一致，不处理。
- info-app 组十个子仓引用 `head`=`origin` 全部一致，无上述情况。
- 本地机与远程机 R3-opus 的唯一布局差异：本地机 GitHub 走 https（远程机走 ssh `git@github.com:`），脚本自动从旧主目录取前缀；各工位与子仓的提交号两台机器一致（同一 GitHub 源）。另：脚本核对行的 `${d/#$HOME/~}` 在本地机 bash 下未把 `$HOME` 缩写成 `~`，输出为完整路径 `/home/zymun/...`（远程机为 `~/...`），仅显示差异，实际目录正确。

## 5. 收尾

- 本地机 `~/master` 现为 `knowfeed-app`、`knowbase-app`（旧 `info-app`、`knowledge-app` 已整目录挪入备份、未删）；`~/worktrees/{cursor,fable,kimi,luna,qwen}` 五个工位同步换成新名。
- 改名窗口内不跑同步脚本。等 Opus 审 `R3-qwen`、在手册 R3 节状态写「通过」后，再进 R4。

exit=0
