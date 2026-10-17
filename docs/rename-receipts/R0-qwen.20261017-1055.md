# rename（0028）R0 回执 — Qwen（本地机）

- 手册：`docs/rename.md`（investment → knowbench、runtime → knowlink，0028）， HEAD `76685f52`。执行者：Qwen（本地机），2026-10-17 10:53–10:55。
- 范围：R0 第 3 条（本地机核对）与第 4 条（R2 权限），命令块照手册 70–81、89–96 行逐字用 bash 跑（`/tmp/r0.sh`、`/tmp/r0-perm.sh`）。只读核对，未改任何仓、未跑同步脚本。

## 第 3 条 本地机核对（原样输出）

```
/home/zymun/worktrees/cursor/investment-app branch=cursor ahead=0 dirty=0
  investment-admin-frontend          branch=cursor on_remote=7 dirty=0
  investment-backend                 branch=cursor on_remote=7 dirty=0
  investment-web-frontend            branch=cursor on_remote=7 dirty=0
/home/zymun/worktrees/cursor/runtime     branch=cursor ahead=0 dirty=0
/home/zymun/worktrees/fable/investment-app branch=fable ahead=0 dirty=0
  investment-admin-frontend          branch=fable on_remote=7 dirty=0
  investment-backend                 branch=fable on_remote=7 dirty=0
  investment-web-frontend            branch=fable on_remote=7 dirty=0
/home/zymun/worktrees/fable/runtime      branch=fable ahead=0 dirty=0
/home/zymun/worktrees/kimi/investment-app branch=kimi ahead=0 dirty=0
  investment-admin-frontend          branch=kimi on_remote=7 dirty=0
  investment-backend                 branch=kimi on_remote=7 dirty=0
  investment-web-frontend            branch=kimi on_remote=7 dirty=0
/home/zymun/worktrees/kimi/runtime       branch=kimi ahead=0 dirty=0
/home/zymun/worktrees/luna/investment-app branch=luna ahead=0 dirty=0
  investment-admin-frontend          branch=luna on_remote=7 dirty=0
  investment-backend                 branch=luna on_remote=7 dirty=0
  investment-web-frontend            branch=luna on_remote=7 dirty=0
/home/zymun/worktrees/luna/runtime       branch=luna ahead=0 dirty=0
/home/zymun/worktrees/qwen/investment-app branch=qwen ahead=0 dirty=0
  investment-admin-frontend          branch=qwen on_remote=1 dirty=0
  investment-backend                 branch=qwen on_remote=1 dirty=0
  investment-web-frontend            branch=qwen on_remote=1 dirty=0
/home/zymun/worktrees/qwen/runtime       branch=qwen ahead=0 dirty=0
/home/zymun/worktrees/qwen/k8s           ahead=0 dirty=0
/home/zymun/worktrees/qwen/knowlab-app   ahead=0 dirty=0
/home/zymun/worktrees/qwen/knowmart-app  ahead=0 dirty=0
/home/zymun/worktrees/qwen/tpl-app       ahead=0 dirty=0
/home/zymun/worktrees/qwen/knowfeed-app  ahead=0 dirty=0
/home/zymun/worktrees/qwen/knowbase-app  ahead=0 dirty=0
/home/zymun/master:
investment-app
k8s
knowbase-app
knowfeed-app
knowlab-app
knowmart-app
runtime
tpl-app

/home/zymun/worktrees:
cursor
fable
kimi
luna
qwen
gitee   https://gitee.com/sunmoonlion/investment-app.git (fetch)
gitee   https://gitee.com/sunmoonlion/investment-app.git (push)
origin  https://github.com/sunmoonlion/investment-app.git (fetch)
origin  https://github.com/sunmoonlion/investment-app.git (push)
origin  https://gitee.com/sunmoonlion/investment-app.git (push)
origin  https://github.com/sunmoonlion/runtime.git (fetch)
origin  https://github.com/sunmoonlion/runtime.git (push)
```

核对「要看到」：

- 五个工位 × investment-app/runtime 全部 `ahead=0 dirty=0`，工位行 `branch` 等于工位名 ✅
- 子仓 `on_remote` ≥ 1（cursor/fable/kimi/luna 为 7，qwen 为 1）、`dirty=0` ✅
- qwen 工位六仓（k8s/knowlab-app/knowmart-app/tpl-app/knowfeed-app/knowbase-app）`ahead=0 dirty=0` ✅
- 布局：`~/master` 八仓、`~/worktrees` 五工位 ✅
- 主目录 remote 照实：`master/investment-app` 有独立 `gitee` remote，且 `origin` 带 GitHub+gitee 双 push 地址；`master/runtime` **只有 origin（GitHub 单地址），无 gitee remote** ✅（照实记录）

## 第 4 条 R2 权限（原样输出）

```
github.com
  ✓ Logged in to github.com account sunmoonlion (/home/zymun/.config/gh/hosts.yml)
  - Active account: true
  - Git operations protocol: https
  - Token: gho_************************************
  - Token scopes: 'delete_repo', 'gist', 'read:org', 'repo', 'workflow'
investment-app               github admin=true
investment-backend           github admin=true
investment-web-frontend      github admin=true
investment-admin-frontend    github admin=true
runtime                      github admin=true
investment-app               gitee=有
investment-backend           gitee=有
investment-web-frontend      gitee=有
investment-admin-frontend    gitee=有
runtime                      gitee=有
```

核对「要看到」：

- GitHub 5 仓 `admin=true` ✅
- gitee 存在情况照实：**5 仓全有**（investment-app、三个子仓、runtime 均在 gitee 上存在，匿名 ls-remote HEAD 可取）。注意与第 3 条合看：runtime 在 gitee 上有仓，但本地 `master/runtime` 未配 gitee remote——R2 改 gitee 仓名后是否补 remote，听 Opus 在 R2 段安排。
- **gitee 改名方式：API 令牌**（同上次 R2/R2.2 的做法：`git credential fill` 取 `~/.git-credentials` 里的 oauth2 令牌、stdin 传 curl PATCH，同时改 name 与 path）。令牌只放 Qwen 本机，不进回执、不进日志、不进 Git。本轮全程未触发登录交互。

## 其他

- 改名窗口未开（R1 未过），未跑任何同步脚本；未碰两组仓的内容与远端。
- 口令、令牌、私钥未出现在本回执（gh auth status 的 Token 行本身是掩码形式，原样保留）。
- 临时脚本 `/tmp/r0.sh`、`/tmp/r0-perm.sh` 为手册指定落点（/tmp，非工位目录），保留备 Opus 复核命令逐字性。

exit=0
