# R3-opus — 远程机检出换名

- 执行人：Opus（远程机）
- 时间：2026-10-15 12:58–13:01（远程机时间）
- 依据：`k8s/docs/rename.md` R3 节、工具 `k8s/docs/rename-tools/r3_checkout.sh`（k8s `2a60602c`）。
- 前提：R2「通过」。执行前核对：五个工位 × 两组仓都干净（`dirty=0`），没有进程的工作目录在这两组仓里。

## 1. 先演练

原手册的命令块有三处在两台机器上跑不对，改成脚本前在临时家目录里按远程机布局（旧主目录 + 五个工位、子仓、`repos.conf` 副本）演练：
- 登录 shell 是 zsh，不拆分 `$WS`，五个工位会被当成一个词（R2.2 已踩到同类问题）——脚本固定用 bash 跑；
- `mb` 是 zsh 别名，bash 里找不到——脚本直接调 `model-branch.sh`；
- `mb repo add` 往 `repos.conf` 写绝对路径，而这份文件在 `toolboxes` 仓里两台机器共用（本地机家目录不同）——脚本就地把旧名那一行换成新名，保持 `$HOME/...` 写法。

演练还抓到一处：`pipefail` 下 `submodule foreach … | head -1` 会让 foreach 在第二个子仓上失败（脚本在动任何东西之前停了），改为 `sed -n 1p`。改后演练整套通过。

## 2. 真跑

```bash
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh info-app knowfeed-app        # exit=0
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh knowledge-app knowbase-app   # exit=0
```

备份：`~/rename-backup/20261015-1258-info-app`（1.7G）、`~/rename-backup/20261015-1300-knowledge-app`（1.2G），各含 `master/` 与五个工位的旧检出。

### info-app → knowfeed-app（输出原样，去掉了 git 的 `HEAD is now at` 行）

```text
== 备份目录 ~/rename-backup/20261015-1258-info-app
== GH=git@github.com:sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=git@github.com:sunmoonlion/
== 旧 origin 推送地址：git@github.com:sunmoonlion/info-app.git https://gitee.com/sunmoonlion/info-app.git
== 旧检出已挪开
knowfeed-app         挂出 ~/worktrees/cursor/knowfeed-app
knowfeed-app         挂出 ~/worktrees/fable/knowfeed-app
knowfeed-app         挂出 ~/worktrees/kimi/knowfeed-app
knowfeed-app         挂出 ~/worktrees/luna/knowfeed-app
knowfeed-app         挂出 ~/worktrees/qwen/knowfeed-app
~/worktrees/cursor/knowfeed-app  branch=cursor head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=cursor up=origin/cursor head=27bc4c9 origin=27bc4c9 url=git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=cursor up=origin/cursor head=cbc7655 origin=cbc7655 url=git@github.com:sunmoonlion/knowfeed-backend.git
      push git@github.com:sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=cursor up=origin/cursor head=0ac00fa origin=0ac00fa url=git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
~/worktrees/fable/knowfeed-app   branch=fable head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=fable up=origin/fable head=27bc4c9 origin=27bc4c9 url=git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=fable up=origin/fable head=cbc7655 origin=cbc7655 url=git@github.com:sunmoonlion/knowfeed-backend.git
      push git@github.com:sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=fable up=origin/fable head=0ac00fa origin=0ac00fa url=git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
~/worktrees/kimi/knowfeed-app    branch=kimi head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=kimi up=origin/kimi head=27bc4c9 origin=27bc4c9 url=git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=kimi up=origin/kimi head=cbc7655 origin=cbc7655 url=git@github.com:sunmoonlion/knowfeed-backend.git
      push git@github.com:sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=kimi up=origin/kimi head=0ac00fa origin=0ac00fa url=git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
~/worktrees/luna/knowfeed-app    branch=luna head=0f85341 origin=0f85341 dirty=0
  info-admin-frontend            branch=luna up=origin/luna head=27bc4c9 origin=27bc4c9 url=git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  info-backend                   branch=luna up=origin/luna head=cbc7655 origin=cbc7655 url=git@github.com:sunmoonlion/knowfeed-backend.git
      push git@github.com:sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  info-web-frontend              branch=luna up=origin/luna head=0ac00fa origin=0ac00fa url=git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
~/worktrees/qwen/knowfeed-app    branch=qwen head=1fd9da0 origin=1fd9da0 dirty=0
  knowfeed-admin-frontend        branch=qwen up=origin/qwen head=3f01f34 origin=3f01f34 url=git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push git@github.com:sunmoonlion/knowfeed-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-admin-frontend.git
  knowfeed-backend               branch=qwen up=origin/qwen head=ecce5c7 origin=ecce5c7 url=git@github.com:sunmoonlion/knowfeed-backend.git
      push git@github.com:sunmoonlion/knowfeed-backend.git
      push https://gitee.com/sunmoonlion/knowfeed-backend.git
  knowfeed-web-frontend          branch=qwen up=origin/qwen head=327c526 origin=327c526 url=git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push git@github.com:sunmoonlion/knowfeed-web-frontend.git
      push https://gitee.com/sunmoonlion/knowfeed-web-frontend.git
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/knowfeed-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowfeed-app.git (push)
origin	git@github.com:sunmoonlion/knowfeed-app.git (fetch)
origin	git@github.com:sunmoonlion/knowfeed-app.git (push)
origin	https://gitee.com/sunmoonlion/knowfeed-app.git (push)
== 主目录 remote（旧，备份）
gitee	https://gitee.com/sunmoonlion/info-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/info-app.git (push)
origin	git@github.com:sunmoonlion/info-app.git (fetch)
origin	git@github.com:sunmoonlion/info-app.git (push)
origin	https://gitee.com/sunmoonlion/info-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/investment-app
6:$HOME/master/knowledge-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
```

### knowledge-app → knowbase-app

```text
== 备份目录 ~/rename-backup/20261015-1300-knowledge-app
== GH=git@github.com:sunmoonlion/ GE=https://gitee.com/sunmoonlion/ SUB=git@github.com:sunmoonlion/
== 旧 origin 推送地址：git@github.com:sunmoonlion/knowledge-app.git https://gitee.com/sunmoonlion/knowledge-app.git
== 旧检出已挪开
knowbase-app         挂出 ~/worktrees/cursor/knowbase-app
knowbase-app         挂出 ~/worktrees/fable/knowbase-app
knowbase-app         挂出 ~/worktrees/kimi/knowbase-app
knowbase-app         挂出 ~/worktrees/luna/knowbase-app
knowbase-app         挂出 ~/worktrees/qwen/knowbase-app
~/worktrees/cursor/knowbase-app  branch=cursor head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=cursor up=origin/cursor head=df64aa5 origin=df64aa5 url=git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=cursor up=origin/cursor head=e30525f origin=548e84a url=git@github.com:sunmoonlion/knowbase-backend.git
      push git@github.com:sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=cursor up=origin/cursor head=71e5b2e origin=71e5b2e url=git@github.com:sunmoonlion/knowbase-web-frontend.git
      push git@github.com:sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
~/worktrees/fable/knowbase-app   branch=fable head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=fable up=origin/fable head=df64aa5 origin=df64aa5 url=git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=fable up=origin/fable head=e30525f origin=e30525f url=git@github.com:sunmoonlion/knowbase-backend.git
      push git@github.com:sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=fable up=origin/fable head=71e5b2e origin=71e5b2e url=git@github.com:sunmoonlion/knowbase-web-frontend.git
      push git@github.com:sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
~/worktrees/kimi/knowbase-app    branch=kimi head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=kimi up=origin/kimi head=df64aa5 origin=df64aa5 url=git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=kimi up=origin/kimi head=e30525f origin=548e84a url=git@github.com:sunmoonlion/knowbase-backend.git
      push git@github.com:sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=kimi up=origin/kimi head=71e5b2e origin=71e5b2e url=git@github.com:sunmoonlion/knowbase-web-frontend.git
      push git@github.com:sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
~/worktrees/luna/knowbase-app    branch=luna head=d049070 origin=d049070 dirty=0
  knowledge-admin-frontend       branch=luna up=origin/luna head=df64aa5 origin=df64aa5 url=git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowledge-backend              branch=luna up=origin/luna head=e30525f origin=548e84a url=git@github.com:sunmoonlion/knowbase-backend.git
      push git@github.com:sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowledge-web-frontend         branch=luna up=origin/luna head=71e5b2e origin=71e5b2e url=git@github.com:sunmoonlion/knowbase-web-frontend.git
      push git@github.com:sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
~/worktrees/qwen/knowbase-app    branch=qwen head=ba6c77c origin=ba6c77c dirty=0
  knowbase-admin-frontend        branch=qwen up=origin/qwen head=1ae7ed7 origin=1ae7ed7 url=git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push git@github.com:sunmoonlion/knowbase-admin-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-admin-frontend.git
  knowbase-backend               branch=qwen up=origin/qwen head=1d8fa10 origin=1d8fa10 url=git@github.com:sunmoonlion/knowbase-backend.git
      push git@github.com:sunmoonlion/knowbase-backend.git
      push https://gitee.com/sunmoonlion/knowbase-backend.git
  knowbase-web-frontend          branch=qwen up=origin/qwen head=3fd9312 origin=3fd9312 url=git@github.com:sunmoonlion/knowbase-web-frontend.git
      push git@github.com:sunmoonlion/knowbase-web-frontend.git
      push https://gitee.com/sunmoonlion/knowbase-web-frontend.git
== 主目录 remote（新）
gitee	https://gitee.com/sunmoonlion/knowbase-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowbase-app.git (push)
origin	git@github.com:sunmoonlion/knowbase-app.git (fetch)
origin	git@github.com:sunmoonlion/knowbase-app.git (push)
origin	https://gitee.com/sunmoonlion/knowbase-app.git (push)
== 主目录 remote（旧，备份）
gitee	https://gitee.com/sunmoonlion/knowledge-app.git (fetch)
gitee	https://gitee.com/sunmoonlion/knowledge-app.git (push)
origin	git@github.com:sunmoonlion/knowledge-app.git (fetch)
origin	git@github.com:sunmoonlion/knowledge-app.git (push)
origin	https://gitee.com/sunmoonlion/knowledge-app.git (push)
== repos.conf
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/investment-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/runtime
```

## 3. 核对结论

- 十个工位（五个 × 两组）`branch` = 工位名、`head` = `origin`、`dirty=0`；`mb` 都是「挂出」（没有「从 master 新建」）。
- 子仓：`branch` = 工位名、`up` = `origin/<工位>`、`url` 是新仓名，推送地址 GitHub 与 gitee 各一（新仓名）。
- 主目录 remote 与备份的旧 remote 相比只有仓名变了（协议、主机、推送地址个数相同）。`repos.conf` 是 `$HOME/master/knowfeed-app`、`$HOME/master/knowbase-app`，位置不变。
- 一处 `head` ≠ `origin`（手册要求照实报、不动）：cursor、kimi、luna 三个工位的 `knowledge-backend` 子仓 `head=e30525f`、`origin=548e84a`。查明：父仓这三个分支记的是 `e30525f`，它比 GitHub 上子仓同名分支的头 `548e84a` **新两个提交**（`94a3a72`、`e30525f`，0023 Olist 样例，2026-10-13）——那三个工位冻结前子仓分支没往前推过，R0 时它们的子仓本来就游离在 `e30525f`。现在本地分支比 origin 超前 2 个提交、可快进，什么都没丢，不用处理；下次那三个工位推送时子仓分支会跟上。
- 新布局下 k8s 按 `<名>-app` 找后端的测试（`test_python_sources.py`）通过（R1 时要模拟目录名才过）。

## 4. 给本地机（Qwen）的说明

照手册 R3 用同一个脚本跑两次（必须 `bash …`）。本地机 GitHub 走 https，脚本从旧主目录取前缀，不需要改。本地机若缺哪个工位，用 `WS="…" bash …` 去掉并写进回执。脚本前提检查不过会停、不动任何东西，把输出贴进回执即可。

exit=0
