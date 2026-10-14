# R0-qwen — 本地机（所有者机器）冻结与前提核对

- 执行人：Qwen（本地机）
- 时间：2026-10-14 16:29（本机时间）
- 依据：`k8s/docs/rename.md` R0 节；只执行手册写明的命令，未做任何变更（本段全部为只读核对）。

## 1. 五工位 × info-app / knowledge-app（含 6 子仓）干净且已推

手册 R0 第 3 条第一段命令原样执行，输出原样如下（全部 `ahead=0`、`dirty=0`、子仓 `on_remote≥1`、工位行 branch=工位名；子仓 branch 为空 = 游离在父仓记的提交上，手册已允许）：

```text
/home/zymun/worktrees/cursor/info-app    branch=cursor ahead=0 dirty=0
  info-admin-frontend                branch= on_remote=5 dirty=0
  info-backend                       branch= on_remote=5 dirty=0
  info-web-frontend                  branch= on_remote=5 dirty=0
/home/zymun/worktrees/cursor/knowledge-app branch=cursor ahead=0 dirty=0
  knowledge-admin-frontend           branch= on_remote=5 dirty=0
  knowledge-backend                  branch= on_remote=2 dirty=0
  knowledge-web-frontend             branch= on_remote=5 dirty=0
/home/zymun/worktrees/fable/info-app     branch=fable ahead=0 dirty=0
  info-admin-frontend                branch=fable on_remote=5 dirty=0
  info-backend                       branch=fable on_remote=5 dirty=0
  info-web-frontend                  branch=fable on_remote=5 dirty=0
/home/zymun/worktrees/fable/knowledge-app branch=fable ahead=0 dirty=0
  knowledge-admin-frontend           branch=fable on_remote=5 dirty=0
  knowledge-backend                  branch=fable on_remote=2 dirty=0
  knowledge-web-frontend             branch=fable on_remote=5 dirty=0
/home/zymun/worktrees/kimi/info-app      branch=kimi ahead=0 dirty=0
  info-admin-frontend                branch= on_remote=5 dirty=0
  info-backend                       branch= on_remote=5 dirty=0
  info-web-frontend                  branch= on_remote=5 dirty=0
/home/zymun/worktrees/kimi/knowledge-app branch=kimi ahead=0 dirty=0
  knowledge-admin-frontend           branch= on_remote=5 dirty=0
  knowledge-backend                  branch= on_remote=2 dirty=0
  knowledge-web-frontend             branch= on_remote=5 dirty=0
/home/zymun/worktrees/luna/info-app      branch=luna ahead=0 dirty=0
  info-admin-frontend                branch= on_remote=5 dirty=0
  info-backend                       branch= on_remote=5 dirty=0
  info-web-frontend                  branch= on_remote=5 dirty=0
/home/zymun/worktrees/luna/knowledge-app branch=luna ahead=0 dirty=0
  knowledge-admin-frontend           branch= on_remote=5 dirty=0
  knowledge-backend                  branch= on_remote=2 dirty=0
  knowledge-web-frontend             branch= on_remote=5 dirty=0
/home/zymun/worktrees/qwen/info-app      branch=qwen ahead=0 dirty=0
  info-admin-frontend                branch=qwen on_remote=5 dirty=0
  info-backend                       branch=qwen on_remote=5 dirty=0
  info-web-frontend                  branch=qwen on_remote=5 dirty=0
/home/zymun/worktrees/qwen/knowledge-app branch=qwen ahead=0 dirty=0
  knowledge-admin-frontend           branch=qwen on_remote=5 dirty=0
  knowledge-backend                  branch=qwen on_remote=2 dirty=0
  knowledge-web-frontend             branch=qwen on_remote=5 dirty=0
```

## 2. qwen 工位其余四仓干净且已推

手册 R0 第 3 条第二段命令原样执行：

```text
/home/zymun/worktrees/qwen/k8s           ahead=0 dirty=0
/home/zymun/worktrees/qwen/investment-app ahead=0 dirty=0
/home/zymun/worktrees/qwen/runtime       ahead=0 dirty=0
/home/zymun/worktrees/qwen/tpl-app       ahead=0 dirty=0
```

investment-app 三个子仓（手册未要求，顺手核了，命令同第 1 节的 submodule foreach）：

```text
  investment-admin-frontend          branch=qwen on_remote=5 dirty=0
  investment-backend                 branch=qwen on_remote=1 dirty=0
  investment-web-frontend            branch=qwen on_remote=1 dirty=0
```

## 3. 本地机布局与 gitee remote

- `ls ~/master`：`info-app investment-app k8s knowledge-app runtime tpl-app` —— 六仓并列，与手册一致。
- `ls ~/worktrees`：`cursor fable kimi luna qwen` —— 五工位齐全，与手册 R3 的 `WS` 一致，无需去掉任何工位。
- `type mb`：`mb is an alias for /home/zymun/toolboxes/Vlinux/utils/set-up-tools/model-switch/model-branch.sh`。
- 两组父仓 remote（`git -C ~/master/<仓> remote -v`）：

```text
info-app:
  gitee   https://gitee.com/sunmoonlion/info-app.git (fetch/push)
  origin  https://github.com/sunmoonlion/info-app.git (fetch)
  origin  https://github.com/sunmoonlion/info-app.git (push)
  origin  https://gitee.com/sunmoonlion/info-app.git (push)   ← origin 有两条 push 地址
knowledge-app:
  gitee   https://gitee.com/sunmoonlion/knowledge-app.git (fetch/push)
  origin  https://github.com/sunmoonlion/knowledge-app.git (fetch)
  origin  https://github.com/sunmoonlion/knowledge-app.git (push)
  origin  https://gitee.com/sunmoonlion/knowledge-app.git (push)   ← 同上
```

提请注意（R3 第 4 步相关，不改动作）：本地机 origin 各带 **两条** push 地址（GitHub + gitee），协议都是 https。R3 脚本的 `remote get-url --push --all origin` 照抄两条、只换仓名即可覆盖；核对标准「推送地址个数相同」应按 2 条对 2 条。

## 4. R2 权限

### GitHub

`gh auth status`：已登录 `github.com`，账号 `sunmoonlion`，Active account: true，Git operations protocol: https，Token scopes 含 `repo`（令牌值不进回执）。

8 仓管理员核对（手册命令原样）：

```text
info-app                   admin=true
knowledge-app              admin=true
info-backend               admin=true
info-web-frontend          admin=true
info-admin-frontend        admin=true
knowledge-backend          admin=true
knowledge-web-frontend     admin=true
knowledge-admin-frontend   admin=true
```

### gitee

用哪种：**API 令牌**。本机 `~/.git-credentials` 存有 gitee.com 的 oauth2 令牌（32 位，值不进回执），已实测可调 gitee API v5：

- `GET /api/v5/user` → HTTP 200，`login=sunmoonlion`；
- `GET /api/v5/repos/sunmoonlion/info-app` → HTTP 200，`permission.admin=True`、`push=True`；
- `GET /api/v5/repos/sunmoonlion/knowledge-app` → HTTP 200，`permission.admin=True`、`push=True`。

即 R2 的 gitee 改名可走 API（PATCH `/api/v5/repos/{owner}/{repo}`，`name` 与 `path` 两个字段都改，对应手册「仓库名称和仓库路径是两个字段」）。令牌只在本机使用。

## 5. R0 前提：0024 Windows 真机回执状态

- runtime qwen 分支 HEAD `16af3e4`，`git status -sb` 为 `## qwen...origin/qwen` 无领先——段 2 回执（`778d857`，探针 12 项全过、exit=1）与第四节补跑回执（`16af3e4`，337 过 / 19 败 / 1 跳、34 文件全加载、exit=1）**均已推到 origin**。
- k8s 侧 Opus 已审段 2 第一份回执（k8s 提交 `9be105fb`，要求补跑后才发卡 48）；补跑回执即上述 `16af3e4`。
- 卡 48 已由 Cursor 发出（`inbox/cursor/2026-10-14-48-new-project-agent-041.md`），卡 47 回执已在（k8s `a5993dc8`）。

## 结论

R0 本地机各项全部符合手册要求，无停报项。等 Opus 核完远程机、在 R0 节「状态」写「开工」后，我再动 R2（GitHub / gitee 改名）。R1 开始到 R4 通过的改名窗口内不跑同步脚本。

## 补核（卡 48 之后）

按派活卡 `switch-test/inbox/qwen/2026-10-14-rename-R0.md` 末尾「还差一步」执行，只读，未改任何仓。前置：`git -C ~/worktrees/qwen/k8s pull --ff-only` → `Already up to date.`，HEAD `56056b93`（卡 48 回执已核过、归档）。

手册 R0 第 3 条第二段 + investment-app 三个子仓，输出原样：

```text
/home/zymun/worktrees/qwen/k8s           ahead=0 dirty=0
/home/zymun/worktrees/qwen/investment-app ahead=0 dirty=0
/home/zymun/worktrees/qwen/runtime       ahead=0 dirty=0
/home/zymun/worktrees/qwen/tpl-app       ahead=0 dirty=0
  investment-admin-frontend          branch=qwen on_remote=5 dirty=0
  investment-backend                 branch=qwen on_remote=1 dirty=0
  investment-web-frontend            branch=qwen on_remote=1 dirty=0
```

结论：四仓全部 `ahead=0`、`dirty=0`；三个子仓 `on_remote≥1`、`dirty=0`、branch=qwen。卡 48 在本地留下的提交都已推上去，无停报项。

exit=0
