# rename（0028）R3 回执 — Qwen（本地机）

- 手册 `docs/process/rename-2026-10-15/README.md` R3（远程机先做、`R3-opus` 完成且本节写明后本地机才做——前提已满足，HEAD `7781c38a`）。执行者：Qwen（本地机），2026-10-17 12:18–12:20。
- 命令照手册 257–258 行逐字用 bash 跑 `docs/process/rename-2026-10-15/tools/r3_checkout.sh` 两次；旧主目录与五工位旧检出整目录挪进 `~/rename-backup/`（不删）。toolboxes 的 `repos.conf` 只按脚本既定动作改工作区，不碰 toolboxes 的 git。

## 第一条：investment-app → knowbench-app（exit=0，原样输出）

```
== 备份目录 /home/zymun/rename-backup/20261017-1218-investment-app
== GH=https://github.com/sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=https://github.com/sunmoonlion/
== 旧 origin 推送地址：https://github.com/sunmoonlion/investment-app.git https://gitee.com/sunmoonlion/investment-app.git
== 旧检出已挪开
HEAD is now at 70af7cf docs: 指针跟随 k8s/sunmoonai/ 移出（文档到 k8s/docs/，镜像源码到 k8s/infrastructure/applications/component-images/）
knowbench-app        挂出 /home/zymun/worktrees/cursor/knowbench-app
HEAD is now at 70af7cf docs: 指针跟随 k8s/sunmoonai/ 移出（文档到 k8s/docs/，镜像源码到 k8s/infrastructure/applications/component-images/）
knowbench-app        挂出 /home/zymun/worktrees/fable/knowbench-app
HEAD is now at 70af7cf docs: 指针跟随 k8s/sunmoonai/ 移出（文档到 k8s/docs/，镜像源码到 k8s/infrastructure/applications/component-images/）
knowbench-app        挂出 /home/zymun/worktrees/kimi/knowbench-app
HEAD is now at 70af7cf docs: 指针跟随 k8s/sunmoonai/ 移出（文档到 k8s/docs/，镜像源码到 k8s/infrastructure/applications/component-images/）
knowbench-app        挂出 /home/zymun/worktrees/luna/knowbench-app
HEAD is now at 3fa5a54 rename（0028 R1）：investment → knowbench、runtime 仓 → sunmoon-link
knowbench-app        挂出 /home/zymun/worktrees/qwen/knowbench-app
/home/zymun/worktrees/cursor/knowbench-app branch=cursor head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=cursor up=origin/cursor head=163fdbb origin=163fdbb url=https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=cursor up=origin/cursor head=9195b1b origin=9195b1b url=https://github.com/sunmoonlion/knowbench-backend.git
      push https://github.com/sunmoonlion/knowbench-backend.git
      push https://gitee.com/sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=cursor up=origin/cursor head=25b3511 origin=25b3511 url=https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-web-frontend.git
/home/zymun/worktrees/fable/knowbench-app branch=fable head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=fable up=origin/fable head=163fdbb origin=163fdbb url=https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=fable up=origin/fable head=9195b1b origin=9195b1b url=https://github.com/sunmoonlion/knowbench-backend.git
      push https://github.com/sunmoonlion/knowbench-backend.git
      push https://gitee.com/sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=fable up=origin/fable head=25b3511 origin=25b3511 url=https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-web-frontend.git
/home/zymun/worktrees/kimi/knowbench-app branch=kimi head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=kimi up=origin/kimi head=163fdbb origin=163fdbb url=https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=kimi up=origin/kimi head=9195b1b origin=9195b1b url=https://github.com/sunmoonlion/knowbench-backend.git
      push https://github.com/sunmoonlion/knowbench-backend.git
      push https://gitee.com/sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=kimi up=origin/kimi head=25b3511 origin=25b3511 url=https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-web-frontend.git
/home/zymun/worktrees/luna/knowbench-app branch=luna head=70af7cf origin=70af7cf dirty=0
  investment-admin-frontend      branch=luna up=origin/luna head=163fdbb origin=163fdbb url=https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-admin-frontend.git
  investment-backend             branch=luna up=origin/luna head=9195b1b origin=9195b1b url=https://github.com/sunmoonlion/knowbench-backend.git
      push https://github.com/sunmoonlion/knowbench-backend.git
      push https://gitee.com/sunmoonlion/knowbench-backend.git
  investment-web-frontend        branch=luna up=origin/luna head=25b3511 origin=25b3511 url=https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-web-frontend.git
/home/zymun/worktrees/qwen/knowbench-app branch=qwen head=3fa5a54 origin=3fa5a54 dirty=0
  knowbench-admin-frontend       branch=qwen up=origin/qwen head=45fcf79 origin=45fcf79 url=https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://github.com/sunmoonlion/knowbench-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-admin-frontend.git
  knowbench-backend              branch=qwen up=origin/qwen head=cc95605 origin=cc95605 url=https://github.com/sunmoonlion/knowbench-backend.git
      push https://github.com/sunmoonlion/knowbench-backend.git
      push https://gitee.com/sunmoonlion/knowbench-backend.git
  knowbench-web-frontend         branch=qwen up=origin/qwen head=ceb3087 origin=ceb3087 url=https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://github.com/sunmoonlion/knowbench-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbench-web-frontend.git
== 主目录 remote（新）
gitee   https://gitee.com/sunmoonlion/knowbench-app.git (fetch)
gitee   https://gitee.com/sunmoonlion/knowbench-app.git (push)
origin  https://github.com/sunmoonlion/knowbench-app.git (fetch)
origin  https://github.com/sunmoonlion/knowbench-app.git (push)
origin  https://gitee.com/sunmoonlion/knowbench-app.git (push)
== 主目录 remote（旧，备份）
gitee   https://gitee.com/sunmoonlion/investment-app.git (fetch)
gitee   https://gitee.com/sunmoonlion/investment-app.git (push)
origin  https://github.com/sunmoonlion/investment-app.git (fetch)
origin  https://github.com/sunmoonlion/investment-app.git (push)
origin  https://gitee.com/sunmoonlion/investment-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/knowbench-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
9:$HOME/master/knowlab-app
10:$HOME/master/knowmart-app
```

## 第二条：runtime → sunmoon-link（GITEE_PREFIX + ORIGIN_PUSH_GITEE=1，exit=0，原样输出）

```
== 备份目录 /home/zymun/rename-backup/20261017-1219-runtime
== GH=https://github.com/sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=https://github.com/sunmoonlion/
== 旧 origin 推送地址：https://github.com/sunmoonlion/runtime.git https://gitee.com/sunmoonlion/runtime.git
== 旧检出已挪开
HEAD is now at 0e4b1c8 docs: 补改不带斜杠的旧路径（sunmoonai/sandbox-platform、sunmoonai/scripts/results）
sunmoon-link         挂出 /home/zymun/worktrees/cursor/sunmoon-link
HEAD is now at 0e4b1c8 docs: 补改不带斜杠的旧路径（sunmoonai/sandbox-platform、sunmoonai/scripts/results）
sunmoon-link         挂出 /home/zymun/worktrees/fable/sunmoon-link
HEAD is now at 0e4b1c8 docs: 补改不带斜杠的旧路径（sunmoonai/sandbox-platform、sunmoonai/scripts/results）
sunmoon-link         挂出 /home/zymun/worktrees/kimi/sunmoon-link
HEAD is now at 0e4b1c8 docs: 补改不带斜杠的旧路径（sunmoonai/sandbox-platform、sunmoonai/scripts/results）
sunmoon-link         挂出 /home/zymun/worktrees/luna/sunmoon-link
HEAD is now at 130c966 rename（0028 R1）：investment → knowbench、runtime 仓 → sunmoon-link
sunmoon-link         挂出 /home/zymun/worktrees/qwen/sunmoon-link
/home/zymun/worktrees/cursor/sunmoon-link branch=cursor head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zymun/worktrees/fable/sunmoon-link branch=fable head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zymun/worktrees/kimi/sunmoon-link  branch=kimi head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zymun/worktrees/luna/sunmoon-link  branch=luna head=0e4b1c8 origin=0e4b1c8 dirty=0
/home/zymun/worktrees/qwen/sunmoon-link  branch=qwen head=130c966 origin=130c966 dirty=0
== 主目录 remote（新）
gitee   https://gitee.com/sunmoonlion/sunmoon-link.git (fetch)
gitee   https://gitee.com/sunmoonlion/sunmoon-link.git (push)
origin  https://github.com/sunmoonlion/sunmoon-link.git (fetch)
origin  https://github.com/sunmoonlion/sunmoon-link.git (push)
origin  https://gitee.com/sunmoonlion/sunmoon-link.git (push)
== 主目录 remote（旧，备份）
origin  https://github.com/sunmoonlion/runtime.git (fetch)
origin  https://github.com/sunmoonlion/runtime.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/knowbench-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/sunmoon-link
9:$HOME/master/knowlab-app
10:$HOME/master/knowmart-app
```

## 核对「要看到」

- 每个工位 `branch` = 工位名、`head` = `origin`、`dirty=0`：两组各五工位全符 ✅
- qwen 工位停在 R1 提交（knowbench-app `3fa5a54`、sunmoon-link `130c966`），其余四工位停在各自 master（`70af7cf`、`0e4b1c8`）——与 `R3-opus` 相同 ✅
- 子仓 `url` 是新仓名、`push` 是 GitHub 与 gitee 的新仓名各一 ✅（qwen 工位子仓目录名已是 knowbench-*；四个冻结工位子仓目录名仍是 investment-*、内容为改名前，属手册 265 行预期，冻结期间不提交）
- 主目录 remote（新）与备份（旧）相比只有仓名变了；**runtime（sunmoon-link）多一个 gitee**（GITEE_PREFIX 新建 gitee remote、ORIGIN_PUSH_GITEE=1 给 origin 补 gitee 推送地址，与 knowbench-app 布局一致）✅
- `repos.conf` 两条已是 `$HOME/master/knowbench-app`（第 5 行）、`$HOME/master/sunmoon-link`（第 8 行），保持 `$HOME/...` 写法 ✅
- 备份不删：`~/rename-backup/20261017-1218-investment-app`、`~/rename-backup/20261017-1219-runtime`

## 其他

- 改名窗口内未跑同步脚本；R4（config.sh 等）等本回执通过后再做。
- 口令、令牌未出现在输出与本回执（两条命令均不需要 gitee 令牌）。

exit=0
