# rename（0028）R3 回执 — Opus（远程机）

- 手册 `docs/rename.md` R3；脚本 `docs/rename-tools/r3_checkout.sh`（k8s `1209a3f3` 版，拷到 /tmp 后用 bash 跑）。2026-10-17 12:12–12:15。
- 命令：`bash r3_checkout.sh investment-app knowbench-app`；`GITEE_PREFIX=https://gitee.com/sunmoonlion/ bash r3_checkout.sh runtime sunmoon-link`。两次 exit=0。
- **更正**：手册原写「远程机的 origin 只推 GitHub」，不对——远程机 investment-app 的 origin 也是 GitHub、gitee 两个推送地址（下面「旧，备份」可见）。所以 runtime 那次本应加 `ORIGIN_PUSH_GITEE=1`；跑完后手工补上：`git -C ~/master/sunmoon-link config --unset-all remote.origin.pushurl`，再 `remote set-url --add --push origin` 加 GitHub、gitee 各一（结果与 knowbench-app 相同，见文末）。手册已改为两台机器都加。

## 脚本输出（去掉逐条 push 行与 checkout 提示）

```
== 备份目录 /home/zym/rename-backup/20261017-1212-investment-app
== GH=git@github.com:sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=git@github.com:sunmoonlion/
== 旧 origin 推送地址：git@github.com:sunmoonlion/investment-app.git https://gitee.com/sunmoonlion/investment-app.git
== 旧检出已挪开
knowbench-app        挂出 /home/zym/worktrees/cursor/knowbench-app
knowbench-app        挂出 /home/zym/worktrees/fable/knowbench-app
knowbench-app        挂出 /home/zym/worktrees/kimi/knowbench-app
knowbench-app        挂出 /home/zym/worktrees/luna/knowbench-app
knowbench-app        挂出 /home/zym/worktrees/qwen/knowbench-app
/home/zym/worktrees/cursor/knowbench-app branch=cursor head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=cursor up=origin/cursor head=163fdbb origin=163fdbb url=git@github.com:sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=cursor up=origin/cursor head=9195b1b origin=9195b1b url=git@github.com:sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=cursor up=origin/cursor head=25b3511 origin=25b3511 url=git@github.com:sunmoonlion/knowbench-web-frontend.git
/home/zym/worktrees/fable/knowbench-app  branch=fable head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=fable up=origin/fable head=163fdbb origin=163fdbb url=git@github.com:sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=fable up=origin/fable head=9195b1b origin=9195b1b url=git@github.com:sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=fable up=origin/fable head=25b3511 origin=25b3511 url=git@github.com:sunmoonlion/knowbench-web-frontend.git
/home/zym/worktrees/kimi/knowbench-app   branch=kimi head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=kimi up=origin/kimi head=163fdbb origin=163fdbb url=git@github.com:sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=kimi up=origin/kimi head=9195b1b origin=9195b1b url=git@github.com:sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=kimi up=origin/kimi head=25b3511 origin=25b3511 url=git@github.com:sunmoonlion/knowbench-web-frontend.git
/home/zym/worktrees/luna/knowbench-app   branch=luna head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=luna up=origin/luna head=163fdbb origin=163fdbb url=git@github.com:sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=luna up=origin/luna head=9195b1b origin=9195b1b url=git@github.com:sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=luna up=origin/luna head=25b3511 origin=25b3511 url=git@github.com:sunmoonlion/knowbench-web-frontend.git
/home/zym/worktrees/qwen/knowbench-app   branch=qwen head=3fa5a54 origin=3fa5a54 dirty=0
  knowbench-admin-frontend       branch=qwen up=origin/qwen head=45fcf79 origin=45fcf79 url=git@github.com:sunmoonlion/knowbench-admin-frontend.git
  knowbench-backend              branch=qwen up=origin/qwen head=cc95605 origin=cc95605 url=git@github.com:sunmoonlion/knowbench-backend.git
  knowbench-web-frontend         branch=qwen up=origin/qwen head=ceb3087 origin=ceb3087 url=git@github.com:sunmoonlion/knowbench-web-frontend.git
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/knowbench-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowbench-app.git (push)
origin	git@github.com:sunmoonlion/knowbench-app.git (fetch)
origin	git@github.com:sunmoonlion/knowbench-app.git (push)
origin	https://gitee.com/sunmoonlion/knowbench-app.git (push)
== 主目录 remote（旧，备份）
gitee	https://gitee.com/sunmoonlion/investment-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/investment-app.git (push)
origin	git@github.com:sunmoonlion/investment-app.git (fetch)
origin	git@github.com:sunmoonlion/investment-app.git (push)
origin	https://gitee.com/sunmoonlion/investment-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/knowbench-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
9:$HOME/master/knowlab-app
10:$HOME/master/knowmart-app
exit1=0
== 备份目录 /home/zym/rename-backup/20261017-1214-runtime
== GH=git@github.com:sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=git@github.com:sunmoonlion/
== 旧 origin 推送地址：git@github.com:sunmoonlion/runtime.git
== 旧检出已挪开
sunmoon-link         挂出 /home/zym/worktrees/cursor/sunmoon-link
sunmoon-link         挂出 /home/zym/worktrees/fable/sunmoon-link
sunmoon-link         挂出 /home/zym/worktrees/kimi/sunmoon-link
sunmoon-link         挂出 /home/zym/worktrees/luna/sunmoon-link
sunmoon-link         挂出 /home/zym/worktrees/qwen/sunmoon-link
/home/zym/worktrees/cursor/sunmoon-link  branch=cursor head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zym/worktrees/fable/sunmoon-link   branch=fable head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zym/worktrees/kimi/sunmoon-link    branch=kimi head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zym/worktrees/luna/sunmoon-link    branch=luna head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zym/worktrees/qwen/sunmoon-link    branch=qwen head=130c966 origin=130c966 dirty=0
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/sunmoon-link.git (fetch)
gitee	https://gitee.com/sunmoonlion/sunmoon-link.git (push)
origin	git@github.com:sunmoonlion/sunmoon-link.git (fetch)
origin	git@github.com:sunmoonlion/sunmoon-link.git (push)
== 主目录 remote（旧，备份）
origin	git@github.com:sunmoonlion/runtime.git (fetch)
origin	git@github.com:sunmoonlion/runtime.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/knowbench-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/sunmoon-link
9:$HOME/master/knowlab-app
10:$HOME/master/knowmart-app
exit2=0
```

## 补推送地址后

```
sunmoon-link:
git@github.com:sunmoonlion/sunmoon-link.git
https://gitee.com/sunmoonlion/sunmoon-link.git
knowbench-app:
git@github.com:sunmoonlion/knowbench-app.git
https://gitee.com/sunmoonlion/knowbench-app.git
```

备份目录：`~/rename-backup/20261017-1212-investment-app`、`~/rename-backup/20261017-1214-runtime`（旧主目录与五个工位，不删）。

exit=0
