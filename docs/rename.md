# 改名执行手册：investment → knowbench、runtime → sunmoon-link

> 为什么改、改哪些、深度为什么选乙，见 [0028](dev-investment-agent/tree-build/SDD/modules/0028-knowbench-rename.md)。本文只管**谁、按什么顺序、执行哪条命令、在哪停下等审**。做法照上一次改名（0025，手册在 Git 历史 `3951246c:docs/rename.md`），那次踩过的坑都写进了下面的规矩。
>
> 所有者 2026-10-14 定、2026-10-17 沿用：**改名只有 Opus 和 Qwen 两个人做，所有者只传话**——Opus 在远程机改全部内容、写全部命令、审每一段；Qwen 在所有者机器上做本地的一切（GitHub / gitee 仓改名、本地检出、同步配置、集群切换、浏览器核对）。只有所有者能做的几件（DNS 记录、批准边缘部署、登录、粘贴 key、重装 Windows 代理）到 R5 再说。

## 规矩（每一段都适用）

1. **只执行本文写下的命令。** 本文没写的、写得和现场对不上的，一律停下报告，不临场发挥、不「顺手修一下」。
2. **按段走，一段一停。** 每段末尾有「停点」：执行人写回执，Opus 审过、在本文该段的「状态」里写上「通过 + 日期」，下一段才开始。
3. **R5 验证通过之前不删任何旧东西。** 旧的 investment 部署、库、桶、Casdoor 应用是 R5 失败时的退路；验证通过后在 R6 按清单删（先列、再删、再核对）。R3 挪进 `~/rename-backup/` 的工位检出不能直接 `git log`（`.git` 是指向主目录的相对路径，挪开就断了）；对象都在备份的 `master/.git` 里。
4. **秘密不进回执、不进日志、不进 Git。** 口令、令牌、私钥只在本机生成、只进 SOPS。截图不截 `code=`、`token=`、`state=`。
5. **出错先停，不重试成功了再报。** 失败的输出原样（去掉秘密）贴进回执。
6. 回执统一放 `k8s/docs/rename-receipts/R<段号>-<执行人>.<时间>.md`，最后一行 `exit=<码>`。
7. **改名窗口（R1 开始到 R4 通过）里不跑同步脚本**（`human-local.sh`、`human-remote.sh`、`sync-five-repos.sh`）：它们写死了仓名与子仓路径，两台机器目录对不上时会中途退出、留下半同步状态。窗口里两台机器的往来只用下面「回执往来」的 git 命令。
8. 改名期间的推送：Opus 在远程机、Qwen 在本地机，**只推 `qwen` 分支、只推本文写明的仓**，不推别的分支、不强推（除非本文某段写明、且所有者点名同意）。
9. **命令块一律用 bash 跑**：多行的块存成文件 `bash 文件` 执行。两台机器的登录 shell 是 zsh，zsh 不拆分未加引号的 `$VAR`，`for x in $LIST` 只循环一次、退出码照样是 0（上次 R2.2 踩到）。`mb` 在 zsh 里是别名，bash 里要直接调 `model-branch.sh`。

### 回执往来（只动 k8s 的 `qwen` 分支）

Qwen 只写 `docs/rename-receipts/`，Opus 只写本文、代码与配置，所以 `--rebase` 不会冲突；万一冲突，停下报告，不手工解决。

```bash
# Qwen（本地机）交回执
cd ~/worktrees/qwen/k8s && git add docs/rename-receipts && git commit -m "rename: R<段号> 回执（Qwen）" \
  && git pull --rebase origin qwen && git push origin qwen
# Qwen 等「通过」：拉下来看本文对应段的「状态」
cd ~/worktrees/qwen/k8s && git pull --rebase origin qwen && sed -n '/^## R<段号>/,/^---/p' docs/rename.md
```

### 所有者只传话

| 谁做完了 | 所有者传给谁、传什么 |
| --- | --- |
| Qwen 交了某段回执（自己推） | 告诉 Opus：「Qwen 交了 R<段号>」 |
| Opus 写了「通过」（自己推） | Opus 会说「R<段号> 通过，Qwen 可以做 R<下一段>」；所有者转告 Qwen |

收到传话的一方先拉，看到对应内容才动手；拉不到就回一句「还没看到」，不猜。

## 谁做什么

| 角色 | 在哪 | 做什么 | 不做什么 |
| --- | --- | --- | --- |
| **Opus**（远程机 qwen 工位） | 远程机 | R0 核远程机、发开工令；R1 改全部内容、写好 R5、R6 的命令；R3、R4 远程机那一份；审每段回执；R7 文档 | 不碰所有者本地集群；不替 Qwen 执行本地命令 |
| **Qwen**（所有者机器） | 本地机、GitHub、gitee | R0 核本地机与权限；R2 改 9 个远端仓的名字；R3、R4 本地机那一份；R5 集群（并进 0027 P6）；R6 下线旧对象 | 不改代码、不改本文、不自己写命令；不删任何旧东西（R6 之前） |
| **Cursor**、其他工位（fable、kimi、luna） | — | **冻结**：不提交 `investment-app`（含三个子仓）、`runtime`，不改 k8s 的 gitops。R6 写「改名完成」后，以后一律用新名字 | 改名的任何一步 |

## 名字对照（全文以此为准）

| 类 | 旧 | 新 |
| --- | --- | --- |
| 父仓（GitHub、gitee `sunmoonlion/`） | `investment-app` | `knowbench-app` |
| 子仓（GitHub；gitee 有没有，R0 由 Qwen 核） | `investment-backend`、`investment-web-frontend`、`investment-admin-frontend` | `knowbench-backend`、`knowbench-web-frontend`、`knowbench-admin-frontend` |
| 客户端仓（GitHub；gitee 有没有，R0 核） | `runtime` | `sunmoon-link` |
| 本地代理的命令、安装包、Windows 计划任务（R5 发新包时改，2026-10-16 决定） | `sunmoon-agent`、`SunMoonAgent-*` | `sunmoon-link`、`SunMoonLink-*`（安装时清掉旧任务） |
| 应用名（部署） | `investment` | `knowbench` |
| 域名 | `investment.`、`investment-admin.sunmoonai.com`（公网边缘只有前者） | `knowbench.`、`knowbench-admin.sunmoonai.com` |
| 存储（新建，不搬；所有者 2026-10-17 定从空的开始） | 库 `investment`、角色 `investment_runtime` / `investment_migrator`、Redis、vhost、桶 `investment-agent-releases`、私有目录 `…/sunmoon-kind/investment` | 同名换成 `knowbench…` |

**不改**（0028 第一节、第六节）：「runtime」作普通词（清单 `runtime` 字段的字段名、`*_runtime` 角色后缀、gitops 的 `runtime/` 目录、`knowbot-runtime` 契约名）；relay；代理的 npm 包名 `@sunmoon/agent`、协议字段（握手 `role=agent`）、代码内部命名、页面上的「本地代理」；文档目录 `dev-investment-agent/`；分身内容里的投资用语；历史回执、冻结原件、Git 历史。清单 `runtime` 字段的**值** `investment` 要改成 `knowbench`。

---

## R0 冻结与前提 — 所有者传话，Qwen 与 Opus 核对

1. **所有者**告诉 Cursor 与其他工位（fable、kimi、luna）：从现在起冻结，不提交 `investment-app`（含三个子仓）、`runtime`，不改 k8s 的 gitops，直到 R6 写「改名完成」。Cursor 手上有没发完的卡，先告诉 Opus。
2. **Qwen 当前没有在跑的步骤**（所有者确认）。之后 Opus 先把远程机 qwen 工位还没推的提交推上去（P5 与 0028 的提交），所有者照常跑一次 `WS=qwen bash ~/switch-test/human-local.sh` 把两边带齐——**这是改名窗口前最后一次同步**。
3. **Qwen 核本地机**（结果进 `R0-qwen`）：两组仓在五个工位都干净且已推。

```bash
cat > /tmp/r0.sh <<'EOF'
for ws in cursor fable kimi luna qwen; do for r in investment-app runtime; do
  d=~/worktrees/$ws/$r; [ -d "$d" ] || { echo "$d 不存在"; continue; }; git -C "$d" fetch -q origin
  printf '%-40s branch=%s ahead=%s dirty=%s\n' "$d" "$(git -C "$d" branch --show-current)" \
    "$(git -C "$d" rev-list --count "origin/$ws..HEAD")" "$(git -C "$d" status --porcelain --ignore-submodules=none | wc -l)"
  git -C "$d" submodule foreach --quiet 'git fetch -q origin; printf "  %-34s branch=%s on_remote=%s dirty=%s\n" "$sm_path" "$(git branch --show-current)" "$(git branch -r --contains HEAD | wc -l)" "$(git status --porcelain | wc -l)"'
done; done
for r in k8s knowlab-app knowmart-app tpl-app knowfeed-app knowbase-app; do d=~/worktrees/qwen/$r; git -C "$d" fetch -q origin
  printf '%-40s ahead=%s dirty=%s\n' "$d" "$(git -C "$d" rev-list --count origin/qwen..HEAD)" "$(git -C "$d" status --porcelain --ignore-submodules=none | wc -l)"; done
ls ~/master ~/worktrees; git -C ~/master/investment-app remote -v; git -C ~/master/runtime remote -v
EOF
bash /tmp/r0.sh
```

   要看到：每行 `ahead=0`、`dirty=0`；子仓 `on_remote` ≥ 1；工位行的 `branch` 等于工位名（子仓的 `branch` 可以为空，只要 `on_remote` ≥ 1）。最后几行写明两个主目录有哪些 remote（有没有 `gitee`）。任何一项不符就停。

4. **R2 的权限**（Qwen 核，结果进 `R0-qwen`）：

```bash
cat > /tmp/r0-perm.sh <<'EOF'
gh auth status
for n in investment-app investment-backend investment-web-frontend investment-admin-frontend runtime; do
  printf '%-28s github admin=%s\n' "$n" "$(gh api "repos/sunmoonlion/$n" --jq .permissions.admin)"; done
for n in investment-app investment-backend investment-web-frontend investment-admin-frontend runtime; do
  printf '%-28s gitee=%s\n' "$n" "$(git ls-remote "https://gitee.com/sunmoonlion/$n.git" HEAD >/dev/null 2>&1 && echo 有 || echo 没有或不公开)"; done
EOF
bash /tmp/r0-perm.sh
```

   要看到 GitHub 5 个 `admin=true`；gitee 上哪几个仓存在照实写。gitee 改名用网页（sunmoonlion 登录）还是 API 令牌，写明用哪种；上次用的是 API 令牌，令牌只放 Qwen 本机，不进回执。遇到登录就停，请所有者自己输入。

**停点**：Opus 收到 `R0-qwen` 并核完远程机，在本节「状态」写「开工」。
**状态**：**开工** · 2026-10-17 · Opus。所有者确认其他工位不提交、Qwen 空着；Opus 推了 qwen 工位的本地提交（k8s `76685f52`、investment `287da3b`、knowlab `779058a` 及子仓），所有者跑了最后一次同步。Qwen `R0-qwen.20261017-1055.md`：本地机五工位两组仓与三个子仓全部 `ahead=0 dirty=0`、子仓在 origin 上；qwen 工位其余六仓干净；GitHub 5 仓 `admin=true`；gitee 5 仓都存在（含 runtime），改名用 API 令牌。远程机同一核对：五工位两组仓 `ahead=0 dirty=0`。记下待 R2 处理：gitee 上有 `runtime`，但两台机器的 runtime 都没配 gitee remote（gitee 那份可能是旧的）。改名窗口自此开始：不跑同步脚本，其他工位冻结，往来照「回执往来」。

---

## R1 改内容 — Opus（远程机 qwen 工位）

在 qwen 分支上改，**先推到旧名字的仓**（R2 改名后 GitHub / gitee 会接着认这些提交）。子仓 `.gitmodules` 里的地址直接写新名字；R1 到 R2 之间没有人拉子仓，新地址暂时不存在不碍事。

| 仓 | 改什么 |
| --- | --- |
| `investment-app` 父仓与三个子仓 | 子仓目录 `git mv` 成 `knowbench-*`，`.gitmodules`（路径、URL、name）；代码与配置里的应用名、域名、Casdoor 应用与客户端名、登录 cookie 名、作用域 `knowbench:*`、Redis 前缀、队列名、环境变量 `PLATFORM_KNOWBENCH_*` 等、清单 `runtime` 的值；说明与 `.cursor/rules` |
| tpl、knowfeed、knowbase、knowlab、knowmart（父仓与子仓） | 跨应用键 `investment` → `knowbench`、跨应用测试、契约与服务身份里指工作台的名字（knowlab 调运行方的 `knowbench:testrun`、knowmart 接收的 `summon` 调用方） |
| `runtime` | 站点文件的域名 `knowbench.sunmoonai.com`、说明里的仓名 `sunmoon-link`、脚本里的工位路径 |
| `k8s` | gitops `investment-app/` → `knowbench-app/` 等目录、`infrastructure/applications/` 的应用名表与 `deploy.yaml` / `verify.yaml`、`sources.yaml`、存储名、Casdoor 声明、边缘与 frpc 的域名、traefik 内部入口、Makefile、`switch-test` 三个同步脚本的仓名、现行文档；`repos/investment-app.md` → `repos/knowbench-app.md` |

**不改**：见「名字对照」下的「不改」；另外 `dev-investment-agent/` 目录、PRD 文件名 `apps/investment.md` / `investment-expert.md`（文件名当编号用）、引号里的原话、`decisions.md`、0025 / 0028 与本手册、历史记录（`done/`、`inbox/`、`results/`、`review-log.md`、`CHECKPOINT*.md`、`runtime/probe/`）、已有迁移文件。

执行：工具在 `docs/rename-tools/`——`rename_rules.py`（替换规则与保留清单）、`r1_apply.py`（改名计划 → 父仓里 `git mv` 子仓目录 → 其余 `git mv` → 内容替换 → 手工补丁 → k8s 收尾）、`manual_patch.py`、`residual.py`（残留盘点，应为 0 行）。先在 `~/rename-lab` 里从 origin 复刻的八组仓（含子仓）上整套跑过、各仓测试全过，再在真工位上跑：

```bash
cp -r ~/worktrees/qwen/k8s/docs/rename-tools /tmp/rename-tools
python3 /tmp/rename-tools/r1_apply.py ~/worktrees/qwen
python3 /tmp/rename-tools/residual.py ~/worktrees/qwen
```

**改名后的 knowbench 组件目录里，旧的 `*.sops.yaml` 一律 `git rm`**（15 个）：存储从空的开始、秘密按新名全新生成，而 stage 看到已有 `database/bootstrap.sops.yaml` 就按「已有库不许换口令」拒绝生成。

**k8s 里只改真源，不手改渲染产物**：`workload.yaml`、`kustomization.yaml`、`image.lock.yaml` 只随目录 `git mv`，内容在 R5 由 stage 与构建链按新名重新生成；R1 提交后、R5 发布前，它们里面还是旧名字，属正常，R1 的提交在 R5 发布前不会进现网。

**R5 要记着的连带**（R1 改了名字，R5 才会生效）：工作台的签名钥匙按新名重新生成后，knowbase 与 relay 持有的公钥要换成新的（`infrastructure/components/tasks/workbench-signing.yaml`）；knowbase 接收工作台检索的身份、knowmart 接收「取清单」、knowlab 调「跑测试」与接收「读数据」都按新名重建；本地机 Windows hosts 加 `knowbench.`、`knowbench-admin.sunmoonai.com`。

推送（Opus 在远程机，**先子仓后父仓**，只推 `qwen`）：

```bash
# R1 已在父仓里 git mv 了子仓目录，父仓目录本身要到 R3 才换名，所以此刻的路径是「旧父仓/新子仓」
for d in investment-app/knowbench-backend investment-app/knowbench-web-frontend investment-app/knowbench-admin-frontend \
         tpl-app/tpl-backend tpl-app/tpl-web-frontend knowfeed-app/knowfeed-backend knowfeed-app/knowfeed-web-frontend \
         knowfeed-app/knowfeed-admin-frontend knowbase-app/knowbase-backend knowbase-app/knowbase-web-frontend \
         knowbase-app/knowbase-admin-frontend knowlab-app/knowlab-backend knowlab-app/knowlab-web-frontend \
         knowlab-app/knowlab-admin-frontend knowmart-app/knowmart-backend knowmart-app/knowmart-web-frontend; do
  git -C ~/worktrees/qwen/$d push origin HEAD:refs/heads/qwen   # 只推有改名提交的（R1 回执列出）；investment 三个子仓的 remote 仍是旧仓名
done
for r in investment-app tpl-app knowfeed-app knowbase-app knowlab-app knowmart-app runtime k8s; do git -C ~/worktrees/qwen/$r push origin qwen; done
```

**停点**：Opus 写回执 `R1-opus`（含各仓推上去的提交号）并在本节写「通过」。
**状态**：进行中。2026-10-17 草稿（`~/rename-lab`）上整套跑过：改内容 418 个文件、k8s 路径改名 64 个、旧 sops 15 个、残留 0 行；各仓测试进行中（远程机资源小，一个仓一个仓串行跑）。

## R2 远端仓改名 — Qwen

待写（R1 通过后填命令）：GitHub 5 个、gitee 上存在的几个，名称与路径两个字段都改；核对新地址的分支等于 `R1-opus` 记下的提交号。

## R3 检出换名 — 远程机 Opus，本地机 Qwen

待写：用 `docs/rename-tools/r3_checkout.sh`（上次的工具，按本次名字改过、先在草稿里演练）。

## R4 同步配置 — 远程机 Opus，本地机 Qwen

待写：`~/five-repos-sync/config.sh` 与 `mb` 的 `repos.conf` 换两个仓名；Qwen 跑一次 `human-local.sh` 验证，改名窗口结束。

## R5 集群（并进 0027 P6）— 所有者 + Qwen

待写：DNS、边缘、新安装包、按新名字部署、P6 其余各步、浏览器走查。

## R6 下线旧对象 — Qwen

待写：R5 走查通过后，先列、再删、再核对。

## R7 文档 — Opus
