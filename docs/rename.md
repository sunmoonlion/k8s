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

**R5 要记着的连带**（R1 改了名字，R5 才会生效）：工作台的签名钥匙是平台级私有输入（`services_config_dir/workbench-signing.yaml`，`infrastructure/components/tasks/workbench-signing.yaml`），不随应用名变，R5 原样复用，knowbase 与 relay 的公钥不用换（2026-10-17 Opus 核过，更正此前「要换」的说法）；knowbase 接收工作台检索的身份、knowmart 接收「取清单」、knowlab 调「跑测试」与接收「读数据」都按新名重建；本地机 Windows hosts 加 `knowbench.`、`knowbench-admin.sunmoonai.com`。

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
**状态**：**通过** · 2026-10-17 · Opus。回执 `rename-receipts/R1-opus.*.md`：草稿上整套验过（六个后端、十个前端、k8s、runtime，改名前后对照），真工位结果与草稿逐字相同，残留 0 行；26 个仓的改名提交已推到旧名字仓的 `qwen` 分支，k8s `806e66ec`。Qwen 可以做 R2.1；R2.2 等所有者回答。

## R2 远端仓改名 — Qwen

只改名，不新建、不删。改前把 5 个仓各自 `master` 与 `qwen` 的提交号记进回执（应等于 `R1-opus` 记下的）。

### R2.1 GitHub 5 个、gitee 父仓 1 个

| 平台 | 旧 → 新 |
| --- | --- |
| GitHub `sunmoonlion/` | `investment-app` → `knowbench-app`；`investment-backend` → `knowbench-backend`；`investment-web-frontend` → `knowbench-web-frontend`；`investment-admin-frontend` → `knowbench-admin-frontend`；`runtime` → `sunmoon-link` |
| gitee `sunmoonlion/` | `investment-app` → `knowbench-app`（**名称与路径两个字段都改**，地址看的是路径） |

```bash
cat > /tmp/r2.sh <<'EOS'
set -e
OWNER=sunmoonlion
PAIRS="investment-app:knowbench-app investment-backend:knowbench-backend investment-web-frontend:knowbench-web-frontend investment-admin-frontend:knowbench-admin-frontend runtime:sunmoon-link"
for pr in $PAIRS; do old=${pr%%:*}; new=${pr##*:}
  gh repo rename -R "$OWNER/$old" "$new" --yes && echo "GitHub 改名  $old → $new"
done
read -rs GITEE_TOKEN                                                      # 粘贴令牌回车，屏幕不回显（或照 R0 的做法从 git credential 取）
code=$(printf 'access_token=%s&name=%s&path=%s' "$GITEE_TOKEN" knowbench-app knowbench-app |
       curl -sS -o /dev/null -w '%{http_code}' -X PATCH -d @- "https://gitee.com/api/v5/repos/$OWNER/investment-app")
echo "gitee 改名  investment-app → knowbench-app  HTTP $code"              # 要 200；不是 200 就停
unset GITEE_TOKEN
for pr in $PAIRS; do new=${pr##*:}
  printf '%-26s github qwen=%s master=%s\n' "$new" "$(git ls-remote "https://github.com/$OWNER/$new.git" refs/heads/qwen | cut -c1-8)" "$(git ls-remote "https://github.com/$OWNER/$new.git" refs/heads/master | cut -c1-8)"
done
printf '%-26s gitee  qwen=%s master=%s\n' knowbench-app "$(git ls-remote "https://gitee.com/$OWNER/knowbench-app.git" refs/heads/qwen | cut -c1-8)" "$(git ls-remote "https://gitee.com/$OWNER/knowbench-app.git" refs/heads/master | cut -c1-8)"
EOS
bash /tmp/r2.sh
```

要看到：5 行「GitHub 改名」；gitee `HTTP 200`；新地址都列得出分支：`qwen` 等于 `R1-opus` 的提交号（`knowbench-app 3fa5a549`、`knowbench-backend cc95605c`、`knowbench-web-frontend ceb30875`、`knowbench-admin-frontend 45fcf79a`、`sunmoon-link 130c966a`），`master` 与改名前相同。

### R2.2 gitee 上的三个子仓与 sunmoon-link（所有者 2026-10-17 定「都按建议」）

R1 时核过：gitee 上 investment 的三个子仓是旧内容（日常只推 GitHub），`runtime` 是空仓。所有者定：**三个子仓照上次（2026-10-15）做——先备份、改名、再从 GitHub 把全部分支与标签强推过去**（会覆盖 gitee 上的旧内容，所有者点名同意，备份是唯一退路，先做）；**`runtime` 空仓改名为 `sunmoon-link`，把 GitHub 的内容推上去**，以后两边一起推（R3 给它加 gitee 推送地址）。在 R2.1 通过之后做（GitHub 那边已是新名字）。

```bash
cat > /tmp/r2-2.sh <<'EOS'
set -e
read -rs GITEE_TOKEN; export GITEE_TOKEN                                   # 粘贴令牌回车，屏幕不回显
OWNER=sunmoonlion; GH=https://github.com/$OWNER/
B=~/rename-backup/gitee-old-0028-$(date +%Y%m%d-%H%M); mkdir -p "$B"
PAIRS="investment-backend:knowbench-backend investment-web-frontend:knowbench-web-frontend investment-admin-frontend:knowbench-admin-frontend runtime:sunmoon-link"
GCRED=(-c credential.helper= -c "credential.helper=!f() { echo username=$OWNER; echo password=\$GITEE_TOKEN; }; f")

# 1. 备份旧内容（每个仓一个 bundle，含全部分支；空仓只记「空」）
for pr in $PAIRS; do old=${pr%%:*}
  git clone -q --mirror "https://gitee.com/$OWNER/$old.git" "$B/$old.git"
  git -C "$B/$old.git" for-each-ref --format='%(objectname:short) %(refname)' > "$B/$old.refs"
  if [ -s "$B/$old.refs" ]; then
    git -C "$B/$old.git" bundle create "$B/$old.bundle" --all
    git bundle verify "$B/$old.bundle" >/dev/null && echo "备份  $old  $(wc -l < "$B/$old.refs") 个引用"
  else
    echo "备份  $old  空仓（没有引用）"
  fi
done

# 2. 改名：名称与路径两个字段都改
for pr in $PAIRS; do old=${pr%%:*}; new=${pr##*:}
  code=$(printf 'access_token=%s&name=%s&path=%s' "$GITEE_TOKEN" "$new" "$new" |
         curl -sS -o /dev/null -w '%{http_code}' -X PATCH -d @- "https://gitee.com/api/v5/repos/$OWNER/$old")
  echo "改名  $old → $new  HTTP $code"                                     # 要 200；不是 200 就停
  [ "$code" = 200 ] || exit 1
done

# 3. 从 GitHub 取全部分支与标签，强推到 gitee，并删掉 gitee 上 GitHub 没有的分支
M=$(mktemp -d)
for pr in $PAIRS; do new=${pr##*:}
  git clone -q --bare "${GH}$new.git" "$M/$new.git"
  git -C "$M/$new.git" fetch -q origin '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*'
  git "${GCRED[@]}" -C "$M/$new.git" push -q --force --prune "https://gitee.com/$OWNER/$new.git" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
  echo "推送  $new"
done
rm -rf "$M"

# 4. 核对：两边的分支与标签逐条相同
for pr in $PAIRS; do new=${pr##*:}
  a=$(git ls-remote --heads --tags "${GH}$new.git" | sort); b=$(git ls-remote --heads --tags "https://gitee.com/$OWNER/$new.git" | sort)
  printf '%-26s refs=%s %s\n' "$new" "$(echo "$a" | wc -l)" "$([ "$a" = "$b" ] && echo 一致 || echo 不一致)"
done
unset GITEE_TOKEN
echo "备份目录 $B"
EOS
bash /tmp/r2-2.sh
```

要看到：三个子仓各有引用数的备份、`runtime` 记「空仓」；4 个改名都是 `HTTP 200`；最后 4 行都是「一致」。gitee 若因保护分支拒绝强推 `master`，停下，把报错写进回执（不要去关保护），交 Opus 定。

**停点**：Qwen 写 `R2-qwen`（改名前后的地址、提交号对照、gitee 返回码），Opus 审过写「通过」。
**状态**：R2.1 **通过** · 2026-10-17 · Opus。回执 `R2-qwen.20261017-1200.md`：GitHub 5 仓与 gitee 父仓改名完成（gitee HTTP 200），新地址 `qwen` 均为 R1 提交、`master` 未变；Opus 在远程机独立复核相同，GitHub 旧地址已转发到新仓。**Qwen 可以做 R2.2**（所有者已同意强推三个子仓），回执写 `R2.2-qwen`。

R2.2 **通过** · 2026-10-17 · Opus。回执 `R2.2-qwen.20261017-1209.md`：备份在本地机 `~/rename-backup/gitee-old-0028-20261017-1208/`（三个子仓 bundle 校验通过，runtime 是空仓）；改名 4 个 HTTP 200；强推后两边逐条一致。Opus 在远程机独立复核：四个仓 GitHub 与 gitee 的分支与标签逐条相同；父仓 `knowbench-app` 分支相同，gitee 多一个改名前就有的旧标签 `legacy-pre-architecture-v2-20260809`（父仓不在强推范围，不处理）。**R2 通过，R3 开始（远程机 Opus 先做）。**

## R3 检出换名 — 远程机 Opus，本地机 Qwen

两台机器做同样的事，**远程机先做**（Opus），`R3-opus` 审过、本节写进远程机的实际情况后，Qwen 再做本地机。**旧目录挪到 `~/rename-backup/`，不删。** 在 R2 全部通过之后做。

为什么不用 `mb worktree remove`：git 不许摘下带子仓的工位，所以旧检出整目录挪开；R0 已证明它们都干净且已推，挪开的只是备份。

工具 `k8s/docs/rename-tools/r3_checkout.sh`（上次的工具，0028 加了两项：旧主目录没有 gitee remote 时用 `GITEE_PREFIX`；`ORIGIN_PUSH_GITEE=1` 给 origin 补 gitee 推送地址）。**必须用 bash**：

```bash
# 两台机器的 investment-app 的 origin 都推 GitHub、gitee 两个地址，sunmoon-link 照这个布局补上（ORIGIN_PUSH_GITEE=1）
# 远程机（Opus，已做，见状态）；本地机（Qwen）：
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh investment-app knowbench-app
GITEE_PREFIX=https://gitee.com/sunmoonlion/ ORIGIN_PUSH_GITEE=1 bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh runtime sunmoon-link
```

脚本做的事：先查前提（旧主目录与五个工位都在且干净、新名字的目录都不在、`repos.conf` 里恰有旧名一行），不满足就停、什么都不动 → 旧主目录与五个工位整目录挪进 `~/rename-backup/<时间>-<旧名>/` → 按新名 clone 主目录 → 父仓 remote 照旧布局只换仓名（`gitee` remote；origin 推送地址逐条照抄，runtime 新加 gitee）→ 子仓 remote 指向新仓名、推送地址 GitHub 与 gitee 各一、拨回同名分支 → 建跟踪 origin 的五个工位分支 → `repos.conf` 里旧名那一行换成新名（保持 `$HOME/...` 写法）→ 用 `model-branch.sh worktree add` 挂出五个工位（输出出现「从 master 新建」「失败」「冲突」就停）→ 打印核对。

2026-10-17 在临时家目录里按远程机的布局（主目录 + 五个工位、子仓、`repos.conf` 副本，地址是真 GitHub）演练通过：两组都是五个工位「挂出」、`dirty=0`；qwen 工位停在 R1 提交（`3fa5a54`、`130c966`），其余工位停在各自原来的提交；子仓地址都是新仓名；`repos.conf` 两行换新名。

注意：除 qwen 外，其他工位的分支此时还是改名前的内容（子仓目录仍叫 `investment-*`），但子仓 remote 已指向新仓。它们在 qwen 的改名提交并进 master 后再跟上；冻结期间不要在这些分支上提交。

核对：脚本最后打印的核对原样进回执。要看到：每个工位 `branch` = 工位名、`head` = `origin`、`dirty=0`；子仓 `url` 是新仓名、`push` 是 GitHub 与 gitee 的新仓名；主目录 remote（新）与备份的（旧）相比只有仓名变了（runtime 多一个 gitee）；`repos.conf` 里是 `$HOME/master/<新名>`。

**停点**：Opus 写 `R3-opus`（远程机）、Qwen 写 `R3-qwen`（本地机），Opus 审。
**状态**：远程机**完成** · 2026-10-17 · Opus，回执 `R3-opus.*.md`：两组 exit=0；五个工位都「挂出」、`dirty=0`；qwen 工位在 R1 提交（`3fa5a54`、`130c966`），其余工位在各自原提交；子仓 url 都是新仓名、推送 GitHub 与 gitee；`repos.conf` 两行换新名；备份 `~/rename-backup/20261017-1212-investment-app`、`…-1214-runtime`。更正：远程机原来的 investment-app origin 也推两个地址，runtime 那次漏了 `ORIGIN_PUSH_GITEE=1`，跑完后已手工补齐（与 knowbench-app 相同），上面的命令已改。**Qwen 可以做本地机 R3**，回执写 `R3-qwen`。

本地机 **通过** · 2026-10-17 · Opus。回执 `R3-qwen.20261017-1220.md`：两组 exit=0；五个工位都「挂出」、`dirty=0`，qwen 工位在 R1 提交、其余在各自原提交，与远程机相同；子仓 url 与推送是新仓名（GitHub + gitee）；sunmoon-link 的 remote 与 knowbench-app 布局一致；`repos.conf` 两行换新名（脚本改的是工作区，本地机 `toolboxes` 由所有者先还原这两行再拉 `a558370`）；备份 `~/rename-backup/20261017-1218-investment-app`、`…-1219-runtime`。**R3 通过，Qwen 可以做 R4（本地机）。**

## R4 同步配置 — 远程机 Opus，本地机 Qwen

两台机器各核对两个文件：

1. `~/five-repos-sync/config.sh` 的 `REPOS=(…)`：`"investment-app"` → `"knowbench-app"`，`"runtime"` → `"sunmoon-link"`。改前 `cp config.sh config.sh.bak-rename-0028`。这份文件不在 Git 里，各机一份。

```bash
cd ~/five-repos-sync && cp config.sh config.sh.bak-rename-0028 && \
  sed -i -e 's/^  "investment-app"$/  "knowbench-app"/' -e 's/^  "runtime"$/  "sunmoon-link"/' config.sh && \
  diff config.sh.bak-rename-0028 config.sh; sed -n '/^REPOS=/,/^)/p' config.sh
```

2. `mb` 的 `repos.conf`：R3 脚本已改好，这里只核对 `grep -n "master/" ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf`，应有 `$HOME/master/knowbench-app`、`$HOME/master/sunmoon-link`，没有 `investment-app`、`runtime`。这份文件在 `toolboxes` 仓里受版本管理：**远程机由所有者提交推送**（上次也是，`e8f584e`）；**本地机的 `toolboxes` 由所有者自己拉，Qwen 不提交、不拉、不还原**。R3 脚本两种状态都认（还是旧名就改，已是新名就跳过），所以所有者在 Qwen 跑 R3 之前或之后拉都行——之后拉的话先还原这两行再拉（`git -C ~/toolboxes checkout -- Vlinux/utils/set-up-tools/model-switch/repos.conf`）。

`~/switch-test/human-*.sh` 是转发器，不用改；它转发到的 k8s 仓里那两份已在 R1 改好（子仓名、`sunmoon-link`）。

两台机器都改完、Opus 核过远程机之后，改名窗口结束：Qwen 跑一次 `WS=qwen bash ~/switch-test/human-local.sh`，要能正常走完（不报找不到仓），本地 qwen 工位各仓随之对齐。

**停点**：Opus、Qwen 各写回执（Qwen 的含同步脚本最后一句），Opus 写「通过」。
**状态**：远程机 `config.sh` 已改（2026-10-17，Opus；备份 `config.sh.bak-rename-0028`），`repos.conf` 已是新名，所有者让 Opus 代提交推送 `toolboxes` `a558370`（GitHub、gitee 两边一致，只改这两行）。本地机在 Qwen 的 R3 通过后做。

**通过** · 2026-10-17 · Opus。本地机回执 `R4-qwen.20261017-1228.md`：`config.sh` 两个仓名已改（备份 `config.sh.bak-rename-0028`），`repos.conf` 是新名（所有者已拉 toolboxes `a558370`），`WS=qwen bash ~/switch-test/human-local.sh` exit=0、八仓两端都认。**改名窗口结束**，同步脚本照常使用。接着做「R4 之后」。

## R4 之后：并 master、两台机器对齐、解除冻结（所有者 2026-10-17 同意「R4 通过就做」）

上次是 R6 之后才并（「冻结解除之后」第 1、2 条），这次 R5 要和 P6 一起部署、可能拖几天，所以提前：集群按 `sources.yaml` 钉的提交部署，不看 master；R5 里要修的照样在 qwen 上改、改完再快进一次 master。

2026-10-17 只读核过：26 个仓（8 父仓 + 18 子仓）的 `origin/master` 都是 `origin/qwen` 的祖先（可快进）；`origin/cursor`、`fable`、`kimi`、`luna` 都没有 qwen 之外的提交。

1. **master 快进到 qwen**（Opus，远程机 qwen 工位）：每个仓 `git push origin origin/qwen:refs/heads/master`（先子仓后父仓；推送地址带 gitee 的一起推），推后 GitHub 与 gitee 的 `master` 逐个核对等于 `qwen`。回执 `master-ff-opus`。
2. **工位分支跟上**（Opus，远程机跑一次）：`bash ~/worktrees/qwen/k8s/docs/dev-investment-agent/switch-test/align_workstations.sh push-branches` 预演，再 `--apply`：26 个仓的 `origin/cursor`、`fable`、`kimi`、`luna` 快进到 master。
3. **远程机对齐**（Opus）：同一工具 `align` 预演 → `align --apply` → `list`。父仓快进到 master；子仓按新的 `.gitmodules` 初始化、接回工位分支、照 qwen 工位配推送地址；父仓里留下的旧名子仓目录（`investment-*`）挪进 `~/rename-backup/<时间>-old-subrepos/`。工具已加上 `investment-` → `knowbench-` 的对应。回执 `align-opus`。
4. **本地机对齐**（Qwen）：同样 `align` 预演 → `--apply` → `list`，**结果先写到仓外**（`/tmp/align-*.txt`），再拷进回执目录（上次写进 qwen/k8s 自己把自己拦下了）。回执 `align-qwen`。
5. 两台都 `list` 全 ok，Opus 写「冻结解除」：各工位照常工作，Cursor 恢复接卡（用新名字）。

**状态**：第 1–3 步 **已做** · 2026-10-17 · Opus（回执 `align-opus.*.md`）：26 个仓 master 快进到 qwen，GitHub 与 gitee 逐个核对；104 个工位分支快进到 master；远程机 `align --apply` 40 个快进、15 个旧名子仓目录挪进 `~/rename-backup/20261017-125143-old-subrepos/`，0 HOLD，`list` 156 项全 ok。**Qwen 做第 4 步（本地机对齐）**。

第 4 步 **已做** · 2026-10-17 · Qwen（回执 `align-qwen.20261017-1321.md`）：预演与执行都是 40 个快进、0 HOLD、0 FAIL，15 个旧名子仓目录挪进备份；`list` 155 项 ok、`qwen/k8s` 1 项 ahead-pushed（比 master 多出回执提交，预期）。Opus 审过。

**冻结解除** · 2026-10-17 · Opus：两台机器 × `~/master` 与五个工位 × 八组仓都在 master 上（新名字）。各工位照常工作，Cursor 恢复接卡，一律用新名字（`knowbench-app`、`knowbench-*`、`sunmoon-link`）。两台机器 `~/rename-backup/` 保留，删除另行决定。R5 等 Opus 把命令写好、状态写「可执行」后才开始。

## R5 集群（并进 0027 P6）— Qwen（本地机），所有者在几处亲手做

> **状态写「可执行」之前不得开始。** 分四段，一段一停：R5.1 应用与共用组件（改钉已由 Opus 提交）→ R5.2 提交、发布、晋级、入口、hosts、边缘 → R5.3 本地代理 0.5.0（Windows 与 Linux 包）、开测试电脑 → R5.4 测试账号、kimi key、测试电脑配对、浏览器走查。R5 期间 Opus 不往 k8s 推任何东西（回执直接推，被拒就停）。
>
> 命令块都在 **bash** 里跑（规矩 9）；任何一步 `exit` 不是 0 就停在那一步，输出原样进回执，不重试、不退回。远程机资源小，Qwen 在本地机跑不受影响，但**构建、暂存一个一个来**。

**这一轮动什么**（Opus 2026-10-17 核过）：
- **六个应用都改钉**到改名后的 qwen/master 头（`infrastructure/applications/sources.yaml`，Opus 已提交）：带 0027 P1b–P5（单点登录、knowmart、knowlab 的受理测试交付与「我的数据」、knowbench 的请分身、有人值守的测试、读用户数据）与本地代理命令改名后的网页。knowbench 从空库起（库、角色、Redis、vhost、私有目录都是新名、新建）；knowlab、knowmart 在已有的空应用上升级迁移。
- **迁移头**（Opus 已改）：knowbench `20261017_0020`、knowlab `20261016_0006`、knowmart `20261016_0004`，其余三个不变。迁移 Job 名里带后端镜像摘要，镜像一换名字就换，不撞不可变 Job。
- **测试电脑先关**（`knowbot_test_computer.enabled: false`）：它要 0.5.0 的 Linux 包，R5.3 上传、换钉之后再开。
- **自研镜像不重建**：沙箱、供给器、会合点的现行镜像里没有写死应用名（Opus 查过钉住的源码），记录 MCP 的地址由工作台按配置给。
- **签名钥匙不变**：它是平台级私有输入 `services_config_dir/workbench-signing.yaml`，不随应用名变，暂存时原样复用；knowbase、relay 的公钥不用换，relay 不重新暂存。
- **要重新暂存的共用组件**：`ingress-platform/traefik`（内部入口新增 knowmart、knowbench、knowlab 三条路由与各自证书，0027 P1、P5）、`ingress-platform/frpc`（公网域名 `knowbench`）、`data-platform/elk/collector`（应用名单）、`app-platform/auth-app/casdoor`（0027 P1b：会话 12 小时、单点退出）。
- **旧对象不会被自动删**：Flux 根与各阶段都是 `prune: false`。晋级后改名前的 investment 的 Deployment / Job / Secret 留在集群里，旧阶段 `investment-*` 的 Flux Kustomization 因路径不在了会显示失败——**属预期，R5 不碰**，R6 按清单删。入口与边缘换成新域名后，旧应用从浏览器就打不开了；退路是退回晋级前的发布源（库、桶、私有目录都还在）。

### R5.0 前提（只读）

```bash
cat > /tmp/r5-0.sh <<'EOS'
WS=qwen bash ~/switch-test/human-local.sh > /tmp/r5-0-sync.txt 2>&1; echo "sync exit=$?"; tail -3 /tmp/r5-0-sync.txt
cd ~/worktrees/qwen/k8s && git log --oneline -1 && git status --short | head -3
python3 - <<'PY'
import re, subprocess, pathlib
s = pathlib.Path("infrastructure/applications/sources.yaml").read_text()
bad = 0
for app in ("tpl", "knowfeed", "knowbase", "knowbench", "knowlab", "knowmart"):
    block = re.search(rf"(?m)^  {app}:\n(?:(?!^  \S).*\n?)*", s).group(0)
    pin = dict(re.findall(r"(?m)^    (\w+): (\w+)", block))
    for field, d in (("parent_revision", f"{app}-app"), ("backend_revision", f"{app}-app/{app}-backend"),
                     ("web_revision", f"{app}-app/{app}-web-frontend"), ("admin_revision", f"{app}-app/{app}-admin-frontend")):
        repo = pathlib.Path.home() / "worktrees/qwen" / d
        ok = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", pin[field], "HEAD"]).returncode == 0
        bad += not ok
        print(f"{d:42} {pin[field][:10]} {'在本地 HEAD 里' if ok else '!! 本地没有或不是祖先'}")
print("pins bad =", bad)
PY
make -C infrastructure platform-status > /tmp/r5-0-status.txt 2>&1; echo "status exit=$?"; tail -5 /tmp/r5-0-status.txt
systemctl cat sunmoon-platform.target | grep -E '^(Requires|Wants)='
grep -n "sunmoonai" /mnt/c/Windows/System32/drivers/etc/hosts
make -C infrastructure preflight > /tmp/r5-0-preflight.txt 2>&1; echo "preflight exit=$?"; tail -5 /tmp/r5-0-preflight.txt
EOS
bash /tmp/r5-0.sh
```

要看到：`sync exit=0`；k8s 干净、含本节；`pins bad = 0`（24 行都在本地 HEAD 里）；`platform-status` 0；`sunmoon-platform.target` 是 **`Wants=`**；`preflight` 0（C 盘余量够，`infrastructure/host/README.md`「容量如何计算」）。Windows hosts 里现有的 `sunmoonai` 行原样贴进回执（R5.2 要按它加新域名）。

### R5.1 构建、暂存、计划、渲染比对

**1. 构建**（六个应用；时间长，挨个来，哪个不是 0 就停）：

```bash
cd ~/worktrees/qwen/k8s
for o in app-platform/tpl-app app-platform/knowfeed-app app-platform/knowbase-app app-platform/knowbench-app app-platform/knowlab-app app-platform/knowmart-app; do
  echo "===== build $o"; make -C infrastructure platform-build OBJECT=$o 2>&1 | tail -n 12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
```

要看到：六个都是 `exit=0`；变了的镜像锁 18 个（六个应用各后端、网页、管理端），`source_revision` 等于 `sources.yaml` 里对应的提交。

**2. 暂存**（先排齐拓扑，再逐个 stage；上次改名踩过的三处已写在前面：缺 `chart-source.yaml` 先跑 `services-tools`、`services-chart`；拓扑先 `topology-stage OBJECT=all` 单独排齐；**不要** `platform-stage OBJECT=all`——ragflow 的 prepare 顺序隐患还没修，待办账 97）：

```bash
make -C infrastructure services-tools; echo "tools exit=$?"
make -C infrastructure services-chart; echo "chart exit=$?"; ls -l infrastructure/.build/components/chart-source.yaml
make -C infrastructure topology-stage OBJECT=all; echo "topology exit=$?"
for o in app-platform/tpl-app app-platform/knowfeed-app app-platform/knowbase-app app-platform/knowbench-app app-platform/knowlab-app app-platform/knowmart-app \
         ingress-platform/traefik ingress-platform/frpc data-platform/elk/collector app-platform/auth-app/casdoor; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
ls gitops/components/app-platform/knowbench-app/knowbench-backend/database/ gitops/components/app-platform/knowbench-app/knowbench-backend/runtime/
sudo ls /etc/sunmoon/applications/sunmoon-kind/
```

要看到：`tools`、`chart`、`topology` 与十个 stage 都是 `exit=0`；改动只在六个应用、`ingress-platform/traefik`、`ingress-platform/frpc`、`data-platform/elk`、`app-platform/auth-app`、`clusters/kind`（别处也有改动不必停，照贴，第 4 步的比对会逐个对象列出来）；没有 PEM；knowbench 的 `database/`、`runtime/` 下重新有了 `*.sops.yaml`（按新名全新生成，含 `knowmart-summon-service.sops.yaml`、`knowlab-read-service.sops.yaml`）；私有目录多出 `knowbench`（旧的 `investment` 还在，不动）。

**3. 部署计划**：

```bash
for a in tpl knowfeed knowbase knowbench knowlab knowmart; do
  echo "===== plan $a"; make -C infrastructure application-deployment-plan APP=$a 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
done
```

要看到：六个 `exit=0`；迁移头 knowbench `20261017_0020`、knowlab `20261016_0006`、knowmart `20261016_0004`、knowfeed `20261015_0014`、knowbase `20260927_0007`、tpl `20260911_0003`。

**4. 渲染比对**（改名前的渲染产物 vs 这次 stage 的，逐个 k8s 对象；基准 `8204fd7a` 是 R1 之前的 k8s 提交，P1–P5 一直没暂存过，那时 Git 里的渲染产物就是现网跑的那一版）：

```bash
T=$(date +%Y%m%d-%H%M)
infrastructure/.venv/bin/python docs/rename-tools/r5_render_diff.py 8204fd7a > docs/rename-receipts/R5.1-render-diff.$T.txt; echo "exit=$?"
sed -n '/^== 1/,/^== 3/p' docs/rename-receipts/R5.1-render-diff.$T.txt
```

要看到：第 1 节「不可变 Job」**0 条**（有一条就停）。报告整份随回执提交，Opus 逐条审第 3–6 节。

**这一段不提交 k8s 的工作区改动**（stage 产物留在工作区，Opus 审过渲染比对后在 R5.2 提交）。只提交回执与比对报告：`git add docs/rename-receipts && git commit -m "rename: R5.1 回执（Qwen）" && git push origin qwen`。

**停点**：Qwen 写 `R5.1-qwen`（R5.0 的核对、构建与暂存的各 `exit`、改动分布、计划、比对第 1–2 节），Opus 审。
**状态**：**通过** · 2026-10-17 · Opus（回执 `R5.1-qwen.20261017-1705.md`，三次执行、两处停点已处理；渲染比对逐条审过，见本节末「Opus 审渲染比对」）。

> 2026-10-17 第一次执行（`R5.1-qwen.20261017-1629.md`）：R5.0 全过、六个构建全过；暂存 tpl、knowfeed、knowbase 都 0，**停在 knowbench**：安装包发布配置 `download_available: true`，暂存要求平台私有目录里有按应用名存的上传读回回执 `knowbench-agent-release-published.json`，而改名前的那份叫 `investment-…`，knowbench 名下还没有（R5.3 才上传 0.5.0）。Opus 漏看了这道检查。改法：`agent-releases/config.yaml` 先改 `download_available: false`（已提交），R5.3 上传、读回校验后再开并重新暂存 knowbench；**不复制旧回执改名**（那等于伪造校验）。R5.3 之前「接入电脑」页暂时不给下载，不影响别的。
>
> **第二次只续跑剩下的**（tpl、knowfeed、knowbase 不重来，产物都在工作区；knowbench 重新 stage 一遍，它是幂等的）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> for o in app-platform/knowbench-app app-platform/knowlab-app app-platform/knowmart-app ingress-platform/traefik ingress-platform/frpc data-platform/elk/collector app-platform/auth-app/casdoor; do
>   echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
> done
> ```
>
> 要看到：七个都是 `exit=0`。然后照跑第 2 步块里 `done` 之后的核对，再做第 3、4 步。注意 `git pull` 前工作区有 stage 产物：`--ff-only` 只要没有冲突会照常快进（Opus 这次只改了 `agent-releases/config.yaml` 与本文，stage 产物不在其中）；拉不下来就停，原样贴进回执。
>
> 2026-10-17 第二次执行（`R5.1-qwen.20261017-1646.md`）：knowbench、knowlab、knowmart、traefik、frpc 都 0，**停在 `data-platform/elk/collector`**：`prepare.yaml` 断言 `elk_collector_applications | sort == [...]`，右边的字面量原本按字母序写（`…,'investment','knowbase',…`），R1 整词替换后成了 `'knowbench','knowbase'`，不再是排好序的，排序后的实际值对不上。Qwen 的根因判断对。R1 的规则只换词、不重排；全仓带应用名的排序断言只有这一处（Opus 已搜）。改法：字面量改成 `['casdoor','knowbase','knowbench','knowfeed','tpl']`（已提交）。knowlab、knowmart 不在日志采集名单里是改名前就有的，不在 R5 加，记待办账 120。
>
> **第三次只续跑剩下的两个**（前八个的产物都在工作区，不重来）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> grep -n "elk_collector_applications | sort" gitops/components/data-platform/elk/collector/prepare.yaml   # 要看到 'knowbase','knowbench' 的次序
> for o in data-platform/elk/collector app-platform/auth-app/casdoor; do
>   echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
> done
> ```
>
> 要看到：两个都是 `exit=0`。然后照跑第 2 步块里 `done` 之后的核对，再做第 3、4 步，回执照第一次的格式写全（含第 3 步六个迁移头、第 4 步比对第 1–2 节），比对报告随回执提交。这次 Opus 推上去的除了本处，还有几份分身设计文档（0029、0030、knowbot-todolist、术语），都不在 `gitops/` 下，不碰工作区的 stage 产物。

> **Opus 审渲染比对**（`R5.1-render-diff.20261017-1705.txt`，2026-10-17）：
> - 第 1 节不可变 Job 0 条；第 6 节加密文件两边各 144 个，新多 13 个都是 0027 P1–P5 的服务身份、knowlab 存储与三张内部入口证书。
> - 第 3、4 节：六个应用的 identity 从 v3 换成 v4（新 Job 名，不撞旧的；旧的 v3 留着，`prune: false`）。v4 是待办 98（`2e564bb0`，10-16）：注册脚本在 Casdoor 的 built-in 里保证 `admin`、`operator` 两个角色并把 built-in/admin 放进 `admin`，浏览器身份加 `ADMIN_AUTH_ROLE_ALLOWLIST=admin,operator`。**六个后端都认这个开关**，所以晋级后六个管理端的业务页只给这两个角色看——R5.2 第 5 步要核 admin 仍进得去。其余新对象都是 P1–P5 的关系（knowmart summon、knowlab read、testrun、deliver）、knowlab 存储与三条内部入口。
> - 第 5 节：casdoor 的 Deployment 多了 `ndots: 2` 与输入摘要注解——`92a7c0d2`、`c10c216c`（10-09）早在基准之前就进了 Git，只是 casdoor 一直没重新暂存，这次带上；**晋级时 casdoor 会滚动重启一次**，登录会断几十秒。knowlab 的内存 768Mi→1536Mi、临时盘 64Mi→256Mi 是 P5 抽文字要的。各运行时配置多出的项与 0027 P1–P5 一一对得上；knowbench 没有 `KNOWBOT_TEST_SUBJECT`（R5.4 才填），测试电脑关着。
> - 结论：通过。

### R5.2 提交、发布、晋级、入口、hosts、检查、边缘

> 第 1–5 步 Qwen（本地机）；第 4 步的 UAC 与第 5 步的登录由所有者亲手做；第 6 步边缘由 **Opus 在远程机**做，要所有者另行批准（远程机的 traefik、frps 只在批准后动）。一步不是 0 就停。

**1. 提交、发布、晋级**：

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
git status --short | grep -v ' gitops/' ; echo "-----"   # 横线前应当什么都没有（只有 gitops/ 下的 stage 产物）
git add gitops && git -c core.editor=true commit -m "deploy: 0028 改名（investment → knowbench）+ 0027 P1b–P5 上线（rename R5.2）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff --stat infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（rename R5.2）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -v '/investment-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "wait exit=$?"
$K -n flux-system get kustomizations | grep -v True
$K -n app-platform-dev get jobs | grep -E 'identity-.*-v4|identity-.*-v1|migrate' | grep -E 'know|tpl'
$K -n data-platform-dev get jobs | grep knowlab-storage
for j in $($K -n app-platform-dev get jobs -o name | grep -E 'identity-[0-9a-f]+-v4$'); do echo "$j $($K -n app-platform-dev logs $j | tail -n 1 | jq -c '{admin_roles_created, admin_role_members_added}')"; done
$K -n app-platform-dev get deploy casdoor knowbench-api knowbench-worker knowlab-api knowmart-api
git push origin qwen
```

要看到：`release`、`apply`、`wait` 都是 0；`get kustomizations | grep -v True` 只剩表头和 `investment-*` 那几行（旧阶段的路径不在了，失败属预期，R6 删）；新的 identity v4、各服务身份 v1、迁移、`knowlab-storage` 的 Job 都是 `Complete`；六行 identity 输出里 `admin_roles_created` 合起来恰好建过一次 `admin` 和 `operator`（谁先跑谁建，其余是空列表），`admin_role_members_added` 至多一行有 `admin`；那几个 Deployment 都 `READY` 满。**只贴 jq 取出的两个字段，不贴整段日志。**

**2. 入口**（HAProxy 的 investment 两条分流换成 knowbench 两条，其余不变；会停几秒）：

```bash
make -C infrastructure entry-plan 2>&1 | grep -E "knowbench|investment" | head
make -C infrastructure entry-preview; echo "preview exit=$?"
make -C infrastructure entry-stop; echo "stop exit=$?"
make -C infrastructure entry-deploy; echo "deploy exit=$?"
make -C infrastructure entry-status; echo "status exit=$?"
```

要看到：`entry-plan` 里有 `knowbench.sunmoonai.com`、`knowbench-admin.sunmoonai.com`，没有 investment；四个都是 0。

**3. 检查**：

```bash
for a in tpl knowfeed knowbase knowbench knowlab knowmart; do echo "===== check $a"; make -C infrastructure application-check APP=$a; echo "exit=$?"; done
make -C infrastructure platform-status; echo "status exit=$?"
```

要看到：六个 `application-check` 与 `platform-status` 都是 0。

**4. Windows hosts 加两个域名**（R5.0 回执里第 25 行的 investment 几个名字不删，R6 一起清；先在副本上演练，真改弹 UAC，所有者点「是」）：

```bash
cp docs/dev-investment-agent/switch-test/windows_hosts_add.ps1 /mnt/c/Users/zymun/hosts-add.ps1
N="'knowbench.sunmoonai.com','knowbench-admin.sunmoonai.com'"
cat /mnt/c/Windows/System32/drivers/etc/hosts > /mnt/c/Users/zymun/hosts-add-rehearsal
powershell.exe -NoProfile -Command "\$env:HOSTS_FILE='C:\Users\zymun\hosts-add-rehearsal'; \$env:HOSTS_OUT='C:\Users\zymun\hosts-add-rehearsal.txt'; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\zymun\hosts-add.ps1 knowbench.sunmoonai.com knowbench-admin.sunmoonai.com; 'exit=' + \$LASTEXITCODE"
iconv -f GBK -t UTF-8 /mnt/c/Users/zymun/hosts-add-rehearsal.txt; diff /mnt/c/Windows/System32/drivers/etc/hosts /mnt/c/Users/zymun/hosts-add-rehearsal
# 演练 exit=0、diff 只多一行「127.0.0.1 knowbench.sunmoonai.com knowbench-admin.sunmoonai.com」，才做真改：
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zymun\hosts-add.ps1',$N"
iconv -f GBK -t UTF-8 "/mnt/c/Users/zymun/AppData/Local/Temp/hosts-add-result.txt"
rm -f /mnt/c/Users/zymun/hosts-add-rehearsal /mnt/c/Users/zymun/hosts-add-rehearsal.bak-add-* /mnt/c/Users/zymun/hosts-add-rehearsal.txt
grep -n "knowbench" /mnt/c/Windows/System32/drivers/etc/hosts
```

**5. 浏览器**（所有者自己登录，Qwen 只核截图；截图不截地址栏里的 `code=`、`state=` 等回跳参数）：

| 地址 | 用谁登录 | 要看到 |
| --- | --- | --- |
| `https://knowbench.sunmoonai.com:30443` | sunmoonai 账号 | 进得去工作台（空库，没有项目是正常的）；「接入电脑」页暂时没有下载按钮（R5.3 才开） |
| `https://knowbench-admin.sunmoonai.com:30443` | admin | 进得去治理控制台，看得到业务页（不是「没有权限」） |
| `https://knowbase-admin.sunmoonai.com:30443` | admin | 同上——管理端角色这次对老应用也生效，核一个老应用 |
| `https://knowlab.sunmoonai.com:30443` | sunmoonai 账号 | 进得去，「我的数据」页打得开 |
| `https://knowmart.sunmoonai.com:30443` | sunmoonai 账号 | 进得去 |
| 在 knowbench 点退出，再开 knowlab | — | knowlab 也要求重新登录（0027 P1b 单点退出） |

**回执**：`docs/rename-receipts/R5.2-qwen.<时间>.md`（各步 `exit`、`get kustomizations` 剩下的行、Job 状态、jq 两个字段、entry-plan 那几行、hosts 的 diff、截图描述），`git add docs/rename-receipts && git commit -m "rename: R5.2 回执（Qwen）" && git push origin qwen`。第 1 步的两个提交在第 1 步末尾已推。

**6. 边缘**（Opus，远程机；所有者批准后，在 Qwen 的第 1–5 步回执审过之后做）：现网边缘还只认 `investment.sunmoonai.com`（`/api/logout` 已在放行清单里），改的只是域名换成 knowbench、为它签一张 Let's Encrypt 正式证书（DNS 10-17 已指向边缘）。

```bash
cd ~/worktrees/qwen/k8s && make -C infrastructure tools
make -C infrastructure edge-plan       # 只看：Host 换成 knowbench.sunmoonai.com，别的不变
make -C infrastructure edge-deploy; echo "deploy exit=$?"
make -C infrastructure edge-status; echo "status exit=$?"
curl -sS -o /dev/null -w '%{http_code} verify=%{ssl_verify_result}\n' https://knowbench.sunmoonai.com:30443/
```

要看到：`deploy`、`status` 都是 0；`curl` 的 `verify=0`（正式证书），状态码 200 或 30x（经 frp 到了集群）。Opus 写 `R5.2-opus.<时间>.md`。之后所有者可用手机流量打开 `https://knowbench.sunmoonai.com:30443` 再看一眼。**不跑 `make edge-smoke`**（会替换现网单元）。

> 2026-10-17 第一次执行（`R5.2-qwen.20261017-1821.md`）：提交、发布、晋级都成了（`b6405df6` → `2b6a6600`），`flux-source-apply` 等根 Kustomization 600 秒超时，`wait` 不全 Ready。卡在 **四个服务身份注册 Job 失败**（`knowbench-service-identity`、`knowbench-knowlab-read-identity`、`knowbench-knowmart-summon-identity`、`knowlab-knowbench-testrun-identity`，日志都是 `Service registration failed: ConnectError`），knowbench 的运行时与 knowbase 的运行时都在等它们（依赖链）。六个应用的 identity v4、各迁移、knowlab 存储的 Job 都成了。
>
> **Opus 只读核过**：这四个 Job 与成功了的 `knowlab-knowmart-deliver-identity` 渲染出来**完全同构**——同一个注册脚本、同一个地址（`casdoor-tls` → traefik 8443）、同样的出站策略与标签；注册脚本只连 Casdoor。所以不是配置写错。identity v4 直连 casdoor 的 8000 口都成了，失败的都要经 traefik 的内部入口，且这类 Job **只试一次**（`backoffLimit: 0`）。最像的解释是：晋级时一下子起几十个对象（新库、迁移、casdoor 滚动重启、六个 identity），这几个 Job 正好撞上入口或 DNS 一时连不上。注册 Job 只试一次是模板的老问题，记待办账 123（改模板要换 Job 的版本号，不在 R5 动）。
>
> **第一次停点处理：先只读取证，现在通了再删掉这四个失败的 Job 让 Flux 照原样重建**（Job 名与内容都不变；已完成的 Job 一个不碰）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl); NS=app-platform-dev
> FAILED="knowbench-service-identity-f38d8ddcbb06-v1 knowbench-knowlab-read-identity-f38d8ddcbb06-v1 knowbench-knowmart-summon-identity-f38d8ddcbb06-v1 knowlab-knowbench-testrun-identity-2845ca9fa055-v1"
> # 1）取证（只读）
> for j in $FAILED knowlab-knowmart-deliver-identity-2845ca9fa055-v1; do
>   echo "== $j $($K -n $NS get job $j -o jsonpath='{.status.startTime} → {.status.completionTime} failed={.status.failed} succeeded={.status.succeeded}')"
>   $K -n $NS logs job/$j --tail=5 2>&1 | grep -viE 'secret|password|token' | tail -3
> done
> $K -n $NS get events --sort-by=.lastTimestamp | grep -E 'identity|casdoor|knowlab-api' | tail -30
> $K -n $NS get pods -l app.kubernetes.io/name=casdoor; $K -n ingress-platform-dev get pods; $K -n kube-system get pods -l k8s-app=kube-dns
> $K -n $NS get deploy knowlab-api knowmart-api casdoor
> $K -n $NS describe pod -l app.kubernetes.io/name=knowlab-api | sed -n '/^Events:/,$p' | tail -15
> $K -n $NS logs deploy/knowlab-api --tail=40 | grep -iE 'error|exception|fail' | grep -viE 'secret|password|token' | tail -10
> # 2）现在通不通：在一个本来就能出站到入口的在跑 Pod 里，只读地要一次 Casdoor 的公开 OIDC 配置
> $K -n $NS exec deploy/knowmart-api -- python -c "import httpx; r = httpx.get('https://casdoor-tls.app-platform-dev.svc.cluster.local/.well-known/openid-configuration', verify='/etc/sunmoon/service/ca.crt', headers={'Host': 'casdoor.sunmoonai.com:30443'}, timeout=10); print('casdoor-tls', r.status_code)"
> ```
>
> 要看到：最后一行 `casdoor-tls 200`。**不是 200 就停**（原样贴回执，不删任何东西）。是 200 才接着做：
>
> ```bash
> for j in $FAILED; do echo "$j failed=$($K -n $NS get job $j -o jsonpath='{.status.failed}') succeeded=$($K -n $NS get job $j -o jsonpath='{.status.succeeded}')"; done
> # 上面每行都要是 failed=1 succeeded=（空）；有一个不是就停
> for j in $FAILED; do $K -n $NS delete job $j; done
> make -C infrastructure flux-source-apply; echo "apply exit=$?"
> $K -n flux-system get kustomizations -o name | grep -v '/investment-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "wait exit=$?"
> $K -n flux-system get kustomizations | grep -v True
> for j in $FAILED; do echo "$j $($K -n $NS get job $j -o jsonpath='{.status.succeeded}')"; done
> $K -n $NS get deploy casdoor knowbench-api knowbench-worker knowlab-api knowmart-api
> ```
>
> 要看到：四个 Job 重建后 `succeeded` 都是 1；`wait exit=0`；`get kustomizations | grep -v True` 只剩表头与 `investment-*`；那几个 Deployment 都满。`apply` 若又是等根 Kustomization 超时、但随后 `wait` 全 Ready，算过（它只是等根的那 600 秒），照实写进回执。重建的 Job 又失败就停（贴它的日志与事件）。之后接着做第 1 步块末尾的 identity 两个字段核对与 `git push`（没有新提交时 push 什么也不做），再做第 2–5 步。回执写新的 `R5.2-qwen.<时间>.md`，取证那段整段贴上。

> 2026-10-17 第二次（`R5.2-qwen.20261017-1830.md`）：取证推翻了「一时连不上」——**五个**服务身份注册 Job 都失败（`knowlab-knowmart-deliver` 也是，Opus 先前看漏）；在 knowmart-api 里连 `casdoor-tls` 报 `CERTIFICATE_VERIFY_FAILED: self-signed certificate`。内部入口的证书都由平台 CA 签（`infrastructure/components/tasks/tls-identity.yaml`），客户端带的也是平台 CA，所以出示「自签」证书说明 **traefik 对这个域名没用上我们的证书、出示的是它自带的默认证书**。另一件：knowlab-api 一直 `SchemaNotReady`，库的版本不等于这一版要的 `20261016_0006`，即 knowlab 的迁移没在现网库上跑到头。**都要看集群里的实情，Opus 远程看不到。没删任何东西是对的。**
>
> **第二次取证（只读，什么都不改；证书只看公开的那一半，不碰 `tls.key`）**：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl); NS=app-platform-dev
> echo "===== A1 traefik 日志里的证书与入口错误"
> $K -n ingress-platform-dev logs deploy/traefik --since=3h | grep -iE 'error|tls|certificate|secret' | tail -40
> echo "===== A2 内部入口的密文与 Ingress"
> $K -n $NS get secret | grep service-access
> $K -n $NS get ingress | grep service-access
> echo "===== A3 每张内部入口证书是谁签的、给哪些域名"
> for s in service-access-tls service-access-knowbench-tls service-access-knowlab-tls service-access-knowmart-tls; do
>   echo "== $s"; $K -n $NS get secret $s -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -enddate -ext subjectAltName 2>&1
> done
> echo "===== A4 traefik 实际出示的证书（不校验，只看是谁）"
> for h in casdoor-tls knowbase-tls knowmart-tls knowlab-tls; do
>   echo "== $h"
>   $K -n $NS exec deploy/knowmart-api -- python -c "import ssl, socket; h = '$h.app-platform-dev.svc.cluster.local'; c = ssl.create_default_context(); c.check_hostname = False; c.verify_mode = ssl.CERT_NONE; s = c.wrap_socket(socket.create_connection((h, 443), timeout=10), server_hostname=h); print(ssl.DER_cert_to_PEM_cert(s.getpeercert(True)))" | openssl x509 -noout -subject -issuer 2>&1
> done
> echo "===== A5 客户端带的 CA"
> $K -n $NS get configmap knowmart-service-ca -o jsonpath='{.data.ca\.crt}' | openssl x509 -noout -subject -issuer
> echo "===== A6 traefik 的入口类与它认的 Ingress 类"
> $K get ingressclass
> $K -n ingress-platform-dev get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -iE 'ingress|kubernetes|provider' 
> echo "===== B1 knowlab 的迁移"
> $K -n $NS get jobs | grep -E 'knowlab-(migrate|storage)'
> $K -n flux-system get kustomizations | grep -E 'NAME|knowlab'
> for j in $($K -n $NS get jobs -o name | grep knowlab-migrate); do echo "== $j"; $K -n $NS get $j -o jsonpath='{.metadata.creationTimestamp} {.status.completionTime} {.spec.template.spec.containers[0].image}{"\n"}'; $K -n $NS logs $j --tail=8 2>&1 | grep -viE 'password|secret|token'; done
> $K -n $NS get deploy knowlab-api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
> ```
>
> 全部原样贴进回执 `R5.2-qwen.<时间>.md` 推上来，然后停。Opus 看了再定怎么修。

> 2026-10-17 第三次（`R5.2-qwen.20261017-1845.md`）：**根因找到了，是暂存脚本的 bug**。A3：共用的内部入口密文 `service-access-tls`（本该是 `casdoor-tls`、`knowbase-tls` 那张）里装的是 **knowlab 的证书**；A4：traefik 对 `casdoor-tls`、`knowbase-tls` 只能出示默认自签证书，`knowmart-tls`、`knowlab-tls` 正常。原因在 `traefik/service-access/prepare.yaml`：先给共用证书跑 `tls-identity`（结果记在变量 `app_tls`），再给每条应用入口各跑一次（**每次都重写 `app_tls`**，最后一条是 knowlab），最后才拿 `app_tls` 加密共用证书。0027 P1 加应用入口时埋下，P1–P5 攒着没暂存，R5.1 第一次暂存才发作；渲染比对对加密文件只比在不在，抓不到。knowlab-api 的 `SchemaNotReady` 是连带的：新迁移已跑到 `20261016_0006`，但 knowlab-runtime 被失败的注册 Job 卡住，Deployment 还是旧镜像。**私有目录里共用证书本身是对的，只是加密进 Git 的那份装错了。** 顺带：knowfeed 往 knowbase 灌数据也走 `knowbase-tls`，晋级后一直不通，修完一起恢复。
>
> **Opus 已修**（本提交）：共用证书紧跟它自己的 `tls-identity` 加密；两处加密前都断言读到的就是自己那份私钥与证书（`app_tls` 的 `source` 路径），读错了 stage 直接停。断言的写法在远程机用 Ansible 实跑过：读对了过、照旧 bug 的顺序读错了停。
>
> **第三次处理：重新暂存 traefik、发布晋级，核证书，再删五个失败的注册 Job 让 Flux 重建**：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl); NS=app-platform-dev
> make -C infrastructure platform-stage OBJECT=ingress-platform/traefik; echo "stage exit=$?"
> git status --short gitops     # 只应是 traefik/service-access 下的 tls*.sops.yaml（加密文件每次重写，四个都变是正常的）
> grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
> git add gitops && git -c core.editor=true commit -m "fix(traefik): 共用内部入口证书按它自己的身份重新加密（rename R5.2 第三次）"
> make -C infrastructure flux-release; echo "release exit=$?"
> sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
> sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
> git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（rename R5.2 第三次）"
> make -C infrastructure flux-source-apply; echo "apply exit=$?"      # 注册 Job 还没重建，根可能照旧等超时，先不管
> $K -n flux-system wait kustomization/traefik --for=condition=Ready --timeout=10m; echo "traefik wait exit=$?"
> # 核：共用密文是不是 casdoor/knowbase 那张、traefik 出示的是不是它
> $K -n $NS get secret service-access-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -ext subjectAltName
> for h in casdoor-tls knowbase-tls; do
>   echo "== $h"; $K -n $NS exec deploy/knowmart-api -- python -c "import ssl, socket; h = '$h.app-platform-dev.svc.cluster.local'; c = ssl.create_default_context(); c.check_hostname = False; c.verify_mode = ssl.CERT_NONE; s = c.wrap_socket(socket.create_connection((h, 443), timeout=10), server_hostname=h); print(ssl.DER_cert_to_PEM_cert(s.getpeercert(True)))" | openssl x509 -noout -subject -issuer
> done
> $K -n $NS exec deploy/knowmart-api -- python -c "import httpx; r = httpx.get('https://casdoor-tls.app-platform-dev.svc.cluster.local/.well-known/openid-configuration', verify='/etc/sunmoon/service/ca.crt', headers={'Host': 'casdoor.sunmoonai.com:30443'}, timeout=10); print('casdoor-tls', r.status_code)"
> ```
>
> 要看到：`stage`、`release`、`traefik wait` 都是 0；共用密文的 SAN 里有 `casdoor-tls…` 与 `knowbase-tls…`；两个 `==` 下面的 issuer 都是 `SunMoon Registry Local CA`；最后一行 `casdoor-tls 200`。**有一项不对就停**（不删 Job）。都对了接着：
>
> ```bash
> FAILED="knowbench-service-identity-f38d8ddcbb06-v1 knowbench-knowlab-read-identity-f38d8ddcbb06-v1 knowbench-knowmart-summon-identity-f38d8ddcbb06-v1 knowlab-knowbench-testrun-identity-2845ca9fa055-v1 knowlab-knowmart-deliver-identity-2845ca9fa055-v1"
> for j in $FAILED; do echo "$j failed=$($K -n $NS get job $j -o jsonpath='{.status.failed}') succeeded=$($K -n $NS get job $j -o jsonpath='{.status.succeeded}')"; done   # 每行都要 failed=1 succeeded=（空）
> for j in $FAILED; do $K -n $NS delete job $j; done
> make -C infrastructure flux-source-apply; echo "apply exit=$?"
> $K -n flux-system get kustomizations -o name | grep -v '/investment-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "wait exit=$?"
> $K -n flux-system get kustomizations | grep -v True
> for j in $FAILED; do echo "$j $($K -n $NS get job $j -o jsonpath='{.status.succeeded}')"; done
> $K -n $NS get deploy casdoor knowbench-api knowbench-worker knowlab-api knowmart-api
> $K -n $NS get deploy knowlab-api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
> git push origin qwen
> ```
>
> 要看到：五个 Job 重建后 `succeeded` 都是 1；`wait exit=0`；`get kustomizations | grep -v True` 只剩表头与 `investment-*`；Deployment 都满；knowlab-api 的镜像是 `…@sha256:2845ca9f…`。`apply` 若又只是等根超时、而随后 `wait` 全 Ready，算过（照实写）。然后做第 1 步块末尾的 identity 两个字段核对，再做第 2–5 步。回执写新的 `R5.2-qwen.<时间>.md`。

> 2026-10-17 第四次（`R5.2-qwen.20261017-1956.md`）：第三次处理全对——共用证书修好（SAN 有 `casdoor-tls`、`knowbase-tls`，traefik 出示的是平台 CA 签的证书，`casdoor-tls 200`），五个注册 Job 重建后都 `Complete`，knowbench-api、knowbench-worker 起来了，knowlab-api 换上新镜像就绪。还卡着的是 **`knowfeed-service-identity-b9c9628ec5b9-v1`**：同一次晋级、同一个原因（当时证书错）失败的第六个注册 Job，**Opus 列清单时漏了**（第一次回执只贴了 knowbench、knowlab 的，knowfeed 那条只以「依赖没就绪」出现）；knowfeed 与 knowbase 的运行时都在等它。Qwen 没扩大删除范围是对的。
>
> **第四次处理：先列出三个命名空间里所有没成功的 Job，只有恰好是这一个时才删它**：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl); NS=app-platform-dev
> for n in app-platform-dev data-platform-dev messaging-platform-dev; do $K -n $n get jobs -o json | python3 -c "import json, sys; [print(sys.argv[1] + '/' + j['metadata']['name'], 'failed=' + str(j['status'].get('failed', 0))) for j in json.load(sys.stdin)['items'] if not j['status'].get('succeeded')]" $n; done
> ```
>
> 要看到：**只有一行** `app-platform-dev/knowfeed-service-identity-b9c9628ec5b9-v1 failed=1`（`investment-*` 旧阶段留下的旧 Job 若也在列，原样贴出、不删，R6 处理；除此之外还有别的就停）。是这样才接着：
>
> ```bash
> J=knowfeed-service-identity-b9c9628ec5b9-v1
> $K -n $NS logs job/$J --tail=3 2>&1 | grep -viE 'secret|password|token'
> $K -n $NS delete job $J
> make -C infrastructure flux-source-apply; echo "apply exit=$?"
> $K -n flux-system get kustomizations -o name | grep -v '/investment-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "wait exit=$?"
> $K -n flux-system get kustomizations | grep -v True
> echo "$J $($K -n $NS get job $J -o jsonpath='{.status.succeeded}')"
> $K -n $NS get deploy knowfeed-api knowbase-api casdoor knowbench-api knowlab-api knowmart-api
> ```
>
> 要看到：日志末行是 `Service registration failed: ConnectError`（同一原因）；重建后 `succeeded` 是 1；`wait exit=0`；`get kustomizations | grep -v True` 只剩表头与 `investment-*`（`platform` 也要 True）；Deployment 都满。然后接着做第 1 步块末尾的 identity 两个字段核对（那段 `for j in …identity-…-v4` 与 `get deploy`），再做第 2–5 步。回执写新的 `R5.2-qwen.<时间>.md`。

> 2026-10-17 第五次（`R5.2-qwen.20261017-2016.md`）：第四次处理全过——第六个注册 Job 重建成功，**Kustomization 全 Ready（`platform` 也 True）**，各 Deployment 都满；第 1 步末尾 identity 核对过（`admin`、`operator` 两个角色恰好建了一次）；第 2 步入口四步全 0、knowbench 两个域名在、investment 没了。停在第 3 步：六个 `application-check` 都 2。**两个原因都是检查脚本没跟上这次上线的代码，不是集群的问题：**
> - **knowlab**：对象存储的检查只认 `knowfeed|knowbase|knowbench`，knowlab 的「我的数据」桶是 0027 P5 才开的，第一次被检查（`gitops/components/data-platform/object-storage/verify.py`）。knowlab 后端带着这个检查要用的存储接口，补进白名单即可。
> - **其余五个**：浏览器检查 `check-browser.py` 要求退出回 204；0027 P1b 起退出改成单点退出——本地会话结束后回 200 并带上去 Casdoor 结束会话的地址（`/api/logout`）。knowbench 还多一处：「接入电脑」的安装命令在下载开关关着时（R5.3 之前）明确回 404 `agent_download_unavailable`，检查却要求 200。
>
> **Opus 已改**（本提交）：存储白名单加 knowlab；浏览器检查的退出接受 204，或 200 且地址必须是 Casdoor 的 `/api/logout`（其后照旧核会话已失效）；安装命令接受 200（照旧核命令与过期时间），或 404 `agent_download_unavailable`（报告里记 `install_command_issued: false`，R5.3 开了下载后这里会变回 true）。都是仓里的检查脚本，**不用重新构建、暂存或晋级**。
>
> **第五次处理：重跑检查，过了接着第 4、5 步**：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> for a in tpl knowfeed knowbase knowbench knowlab knowmart; do echo "===== check $a"; make -C infrastructure application-check APP=$a 2>&1 | grep -E "install_command_issued|pkce_callback|actual_application_storage|failed=|FAILED|ok=" | tail -4; echo "exit=${PIPESTATUS[0]}"; done
> make -C infrastructure platform-status; echo "status exit=$?"
> ```
>
> 要看到：六个 `exit=0`、`status exit=0`；knowbench 那行报告 `install_command_issued` 是 false（下载还关着，正常）。有不是 0 的就停，原样贴（检查任务带 `no_log`，不要为了看细节手动去跑它）。都过了接着做第 4 步（Windows hosts）、第 5 步（浏览器）。回执写新的 `R5.2-qwen.<时间>.md`。

> 2026-10-17 第六次（`R5.2-qwen.20261017-2041.md`）：**第 1–5 步全过**——六个检查全 0、hosts 加好、浏览器六项全过（knowbench 空库能进、下载暂未开放；两个管理端 admin 看得到业务页；knowlab「我的数据」打得开；单点退出生效）。第 6 步边缘 Opus 做了（`R5.2-opus.*.md`）：证书签好了，但 frpc 没重启、仍按 investment 注册（它的滚动标识没算域名），边缘对 knowbench 回 404。Opus 已修滚动标识。
>
> **第六次处理（快的做法）：只重启 frpc，让它重读已经是 knowbench 的配置**（Git 与集群里的 ConfigMap 都已是新域名，差的只是重启；滚动标识的修复随下一次小发布 `qwen-005` 暂存上线，不在这里走一整轮暂存晋级）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
> $K -n ingress-platform-dev get configmap frpc -o jsonpath='{.data.frpc\.toml}' | grep -E 'customDomains'   # 要看到 knowbench、casdoor、relay，没有 investment
> $K -n ingress-platform-dev rollout restart deploy/frpc; $K -n ingress-platform-dev rollout status deploy/frpc --timeout=5m; echo "rollout exit=$?"
> $K -n ingress-platform-dev get pods -l app.kubernetes.io/name=frpc
> $K -n ingress-platform-dev logs deploy/frpc --tail=40 | grep -E 'knowbench|investment|start proxy|login' | head
> ```
>
> 要看到：ConfigMap 里没有 investment；`rollout exit=0`；两个 frpc Pod 是新起的；日志里有 knowbench 的代理启动。不用提交（没有改 Git），回执 `R5.2-qwen.<时间>.md` 推上来就停，Opus 从远程机再 curl 核边缘。

**停点**：Qwen 的 `R5.2-qwen` 与 Opus 的 `R5.2-opus` 都审过，在本节写「通过」。
**状态**：**通过** · 2026-10-17 · Opus。第 1 步经六次处理（证书装错、漏列的注册 Job、检查脚本没跟上 P1b/P5、frpc 没重启——都是 Opus 这边的漏洞，已修并记待办账 123、125）后全过；第 2–5 步过（`R5.2-qwen.20261017-2041.md`）；第 6 步边缘过（`R5.2-opus.*.md` 含复核）。

### R5.3 本地代理 0.5.0（Windows 与 Linux 包）、开测试电脑

> 前提：R5.2 **含第 6 步边缘**已通过（测试电脑像用户的电脑一样经公网边缘的 `knowbench.sunmoonai.com` 连进来，边缘还认旧域名时它连不上）。第 1–5 步 Qwen（本地机）；第 6 步所有者亲手装。一步不是 0 就停。
>
> 源码：sunmoon-link `1d8e838`（`1d8e838cd46a262494387604f3d7f00cf3771b8e`，0.5.0）。比改名那版 `ca9784c` 多一处修复（2026-10-17 所有者的工作对话生成 pptx 时中文文件名变成问号）：代理给 PowerShell 也设了往外部程序管道的编码 `$OutputEncoding`（UTF-8、无 BOM），第 1 步在 Windows 上用探针核。和 0.4.1（`76832a8`）比，进 Windows 包的文件只有 `sunmoon-agent.cmd` 改名 `sunmoon-link.cmd`，`pnpm-lock.yaml` 没变，所以**文件数仍是 109**、依赖在新检出里由 pnpm 10.24.0 按锁文件冻结安装（锁文件从 0.4.1 起没变，按校验和装出来就是同一套）。以前那份复制来的冻结目录丢了 pnpm 的链接结构、解析不出 `@openai/codex-win32-x64`（2026-10-17 Qwen 打包时撞上），不再用。安装脚本 `install.ps1.tmpl` 两边摘要都是 `f6219d61392a259de44379627c2d9706d5243aa90ce69812c644991af06ca125`（R1 已同步）。
>
> **Linux 包以清单为准**：Opus 在远程机从同一提交打过一次，清单摘要 `4c059af55ff48ef4a2f2b20947659ce11d8691fa53b32018e8ba9c4a52eaca7f`、133 个文件，本地机打的必须与它一致。压缩包摘要随机器的 umask 不同（见下面第一次执行的说明），上传用本地机那份：`cd93d5a1d2ebb3fb1506c7cda3dc177997b7f3349361dc8a011a795e1dec1766`、`139171755` 字节。


> 2026-10-17 第一次执行（`R5.3-qwen.20261017-2121.md`）：Windows 包全过（109 个文件、自检 pass、编码探针 `probe ok`；依赖改为在新检出里冻结安装）。Linux 包**清单摘要 `4c059af5…`、133 个文件、源码提交都与 Opus 打的一致**，只有压缩包摘要与大小不同。Opus 查明：不是工具版本（两边都是 tar 1.35、gzip 1.12），是**文件权限位**——远程机 umask 是 002（文件带组写），WSL 是 022，tar 把权限记在每个文件头里；Opus 把自己那份去掉组写重新归档，得到的正是 Qwen 的 `cd93d5a1…`、139171755 字节。内容同一由清单保证（上传与测试电脑都按清单逐个文件核）。**改用本地机打的这份**：上面的压缩包摘要与大小已换成 Qwen 的值，清单摘要不变。打包脚本没把权限归一，记待办账 128。
>
> **第二次只续跑第 3–5 步**（第 1、2 步的产物都在本地机原处，不重打）。

> 2026-10-17 第二次（第 5 步中）：测试电脑的 Pod 卡在 `Init:ImagePullBackOff`。原因：测试电脑的 Pod 用的是命名空间的默认服务账号，没带 Harbor 的拉取凭据（应用的 Pod 都用 `<应用>-runtime` 服务账号带 `registry-puller`，沙箱是显式带）。Opus 已在 `test-computer/workload.yaml.j2` 里给 Pod 显式加 `imagePullSecrets: [{name: registry-puller}]`（`app-platform-dev` 里有这个凭据）。同时预先补了一处：测试电脑按公网名（`knowbench.sunmoonai.com`、`relay.sunmoonai.com`）经边缘连进来，而集群 DNS 最终经 WSL 走到 Windows，Windows hosts 把这两个名字指到 127.0.0.1，所以给这个 Pod 加了 `hostAliases`，把两个名字钉到边缘地址（出站策略放行的同一个地址），不改集群 DNS。
>
> **处理**：正在等的那段可以 Ctrl-C 停掉（集群里不会坏，旧的 Pod 只是拉不到镜像）。然后：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git status --short | head; git log --oneline origin/qwen..HEAD   # 看你本地还有哪些没推的提交
> git pull --rebase origin qwen     # Opus 这次只改了 test-computer 的模板与本文，不碰你的改动
> make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage exit=$?"
> git diff gitops/components/app-platform/knowbench-app/knowbench-backend/test-computer/workload.yaml | grep '^[-+] '   # 只应多 imagePullSecrets 与 hostAliases 几行（加密文件变了正常）
> git add gitops && git -c core.editor=true commit -m "fix(test-computer): Pod 带上 Harbor 拉取凭据（rename R5.3）"
> make -C infrastructure flux-release; echo "release exit=$?"
> sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
> sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
> git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（rename R5.3 测试电脑拉取凭据）"
> make -C infrastructure flux-source-apply; echo "apply exit=$?"
> export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
> $K -n flux-system wait kustomization/knowbench-test-computer --for=condition=Ready --timeout=15m; echo "wait exit=$?"
> $K -n app-platform-dev get pods | grep knowbench-test-computer
> $K -n app-platform-dev logs deploy/knowbench-test-computer -c fetch --tail=20
> $K -n app-platform-dev exec deploy/knowbench-test-computer -- getent hosts knowbench.sunmoonai.com relay.sunmoonai.com   # 要是 43.153.135.74
> $K -n app-platform-dev logs deploy/knowbench-test-computer --tail=30 | sed -E 's/[A-Z0-9]{4}-?[A-Z0-9]{4}/<码>/g'
> git push origin qwen
> ```
>
> 要看到：`stage`、`release`、`apply`、`wait` 都是 0；Pod `Running`；`fetch` 的日志里摘要核对 `OK`、包按清单核过；主容器日志在等配对（码已抹）。然后接着第 5 步块里剩下的核对与第 6 步，回执 `R5.3-qwen.<时间>.md`。

> 2026-10-17 第三次（`R5.3-qwen.20261017-2214.md`，Qwen 本地领先 6 个提交未推）：拉取凭据修好后镜像能拉、包核对通过，但主容器 `CrashLoopBackOff`，日志 `SITE_LAUNCH: 代理没有按安装包的方式启动`。原因：代理要求按安装包入口的方式起（`node --use-system-ca`；Linux 包的站点是 `edge-public` 系统信任，**不许**设 `NODE_EXTRA_CA_CERTS`），测试电脑的启动脚本直接 `node …/cli.js`。Opus 已改 `test-computer/workload.yaml.j2` 的 `run.sh`：三处（`init`、`pair`、`start`）都带 `--use-system-ca`，并清掉 `NODE_EXTRA_CA_CERTS`、`NODE_OPTIONS`；用 Opus 自己打的同一提交的 Linux 包在远程机核过——不带旗标复现 `SITE_LAUNCH`，带上后 `init` 正常写出配置。
>
> **处理（Qwen 选项 1）**：`git pull --rebase origin qwen`（Opus 只改了 test-computer 模板与本文）→ 照上面「第二次（第 5 步中）」那段从 `make … platform-stage OBJECT=app-platform/knowbench-app` 起再走一遍（提交信息写「fix(test-computer): 按安装包方式起代理」）→ 要看到 Pod `Running`、`getent hosts` 两个域名是 43.153.135.74、主容器日志在等配对（码抹掉）→ 接着第 5 步剩下的核对与第 6 步 → 最后一次 `git push origin qwen`（这 6 个提交连同新的一起推）。

**1. Windows 包**（照卡 48 的 A，Windows 侧，官方 node.exe 24.19.0、在新检出里冻结安装的依赖、dev-kind 站点与 CA）：

- 新目录检出：`…\sunmoon-probe-runs\windows-agent-050-release\src-1d8e838`，`git rev-parse HEAD` = `1d8e838cd46a262494387604f3d7f00cf3771b8e`，`git status --porcelain` 空。
- 冻结安装：在 `src-1d8e838\agent` 下用官方 node 24.19.0 自带的 corepack：`corepack pnpm@10.24.0 install --frozen-lockfile --ignore-scripts`；`node_modules\.pnpm\` 里要有 `@openai+codex@0.155.1-win32-x64`。
- 组包：`node agent/distribution/build.mjs --node-exe <官方 node.exe> --dependencies <src-1d8e838\agent> --site agent/distribution/sites/dev-kind.json --ca-pem agent/distribution/sites/dev-kind-ca.pem --output <新目录>\sunmoon-link-1d8e838`。
- 要看到：`sourceRevision` = `1d8e838c…`、`files` = **109**（不是就停，把 `app/dist` 与根目录的文件名列进回执）；包内 Node 跑 `windows-candidate.mjs`：`result: pass`、agent `0.5.0`、codex `0.155.1`、node `24.19.0`、`launchedAgent=false`；根目录有 `sunmoon-link.cmd`、没有 `sunmoon-agent.cmd`。
- **编码探针**（这次的修复只能在真 Windows 上核）：用包内 node 跑 `node <k8s>\docs\rename-tools\r53_encoding_probe.mjs <新目录>\sunmoon-link-1d8e838\app`。要看到最后一行 `probe ok`（PowerShell 把带中文的 Python 经管道交给 python，中文文件名建得出来）；`probe FAILED` 就停，整段输出贴进回执。要本机装着 python（所有者那台有）。
- 打 zip（Python `zipfile`、deflate、正斜杠，同 0.4.1）：`sunmoon-link-0.5.0-1d8e838-windows-x64.zip`，放 `~/sunmoon-probe-runs/windows-agent-050/`；记 ZIP SHA256、`size_bytes`、`manifestSha256`。

**2. Linux 包**（WSL）：

```bash
cd ~/worktrees/qwen/sunmoon-link && git fetch -q origin && git checkout -q 1d8e838cd46a262494387604f3d7f00cf3771b8e && git status --porcelain | head -3; echo "-----"
mkdir -p ~/sunmoon-probe-runs/linux-050
node agent/distribution/build-linux.mjs --dependencies agent --site agent/distribution/sites/edge-public.json --output ~/sunmoon-probe-runs/linux-050/sunmoon-link-0.5.0-1d8e838-linux-x64; echo "build exit=$?"
sha256sum ~/sunmoon-probe-runs/linux-050/sunmoon-link-0.5.0-1d8e838-linux-x64.tar.gz
git checkout -q qwen
```

要看到：横线前空；`build exit=0`；`manifestSha256`、`files`、`sourceRevision` 与上面一致（不一致就停）；压缩包摘要与大小以本地机这份为准（第一次执行得到 `cd93d5a1…`、139171755）。

**3. 改发行配置、校验、上传**（工具要求包的摘要与 `config.yaml` 一致，所以先写配置再校验；`download_available` 这一步还保持 `false`）：

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
WZIP=~/sunmoon-probe-runs/windows-agent-050/sunmoon-link-0.5.0-1d8e838-windows-x64.zip
LTGZ=~/sunmoon-probe-runs/linux-050/sunmoon-link-0.5.0-1d8e838-linux-x64.tar.gz
W_SHA=<第 1 步的 ZIP SHA256> W_SIZE=<第 1 步的 size_bytes> W_MAN=<第 1 步的 manifestSha256> python3 - <<'PY'
import os, re, pathlib
p = pathlib.Path('gitops/components/app-platform/knowbench-app/knowbench-backend/agent-releases/config.yaml'); s = p.read_text()
win, linux = s.split('\n  linux:\n')
rev = '1d8e838cd46a262494387604f3d7f00cf3771b8e'
def put(block, key, value):
    new, n = re.subn(rf'(?m)^(\s+{key}: ).*$', lambda m: m.group(1) + value, block, count=1); assert n == 1, key; return new
for k, v in [('version', '0.5.0'), ('source_revision', rev), ('object_key', 'windows-x64/0.5.0/sunmoon-link-0.5.0-1d8e838-windows-x64.zip'),
             ('zip_sha256', os.environ['W_SHA']), ('manifest_sha256', os.environ['W_MAN']), ('size_bytes', os.environ['W_SIZE'])]:
    win = put(win, k, v)
for k, v in [('version', '0.5.0'), ('source_revision', rev), ('object_key', 'linux-x64/0.5.0/sunmoon-link-0.5.0-1d8e838-linux-x64.tar.gz'),
             ('tarball_sha256', 'cd93d5a1d2ebb3fb1506c7cda3dc177997b7f3349361dc8a011a795e1dec1766'),
             ('manifest_sha256', '4c059af55ff48ef4a2f2b20947659ce11d8691fa53b32018e8ba9c4a52eaca7f'), ('size_bytes', '139171755')]:
    linux = put(linux, k, v)
p.write_text(win + '\n  linux:\n' + linux)
PY
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/agent-releases/config.yaml | grep '^[-+] ' 
AGENT_ZIP="$WZIP" make -C infrastructure agent-release-verify; echo "win verify exit=$?"
AGENT_ZIP="$WZIP" make -C infrastructure agent-release-upload; echo "win upload exit=$?"
AGENT_LINUX_TGZ="$LTGZ" make -C infrastructure agent-release-linux-verify; echo "linux verify exit=$?"
AGENT_LINUX_TGZ="$LTGZ" make -C infrastructure agent-release-linux-upload; echo "linux upload exit=$?"
sudo ls -l /etc/sunmoon/services/sunmoon-kind/ | grep -E 'knowbench-agent-release(-linux)?-published'
```

要看到：diff 只有 Windows 六行、Linux 六行（`codex_version`、`enabled`、`download_available`、`site` 不变）；四个都是 0；两次 upload 都是 `uploaded:true`（或已存在时 `412` 读回一致）、`readback_verified:true`、`writer_read_denied:true`、`reader_write_denied:true`；私有目录里有 `knowbench-agent-release-published.json` 与 `knowbench-agent-release-linux-published.json`。**不复制、不改名任何旧回执**；失败就停，不删桶、不覆盖对象、不关 TLS。

**4. 开下载、开测试电脑，重新暂存 knowbench**：

```bash
sed -i 's/^  download_available: false$/  download_available: true/' gitops/components/app-platform/knowbench-app/knowbench-backend/agent-releases/config.yaml
python3 - <<'PY'
import pathlib
p = pathlib.Path('gitops/components/app-platform/knowbench-app/knowbench-backend/config.yaml'); s = p.read_text()
old = '  knowbot_test_computer:\n    enabled: false\n'; assert s.count(old) == 1; p.write_text(s.replace(old, '  knowbot_test_computer:\n    enabled: true\n'))
PY
git diff --stat
make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git status --short gitops | head -20
make -C infrastructure application-deployment-plan APP=knowbench 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "plan exit=${PIPESTATUS[0]}"
```

要看到：`stage`、`plan` 都是 0；`key-check-done` 前没有文件名；改动在 knowbench 后端的 `agent-releases/`、`runtime/`（`agent-releases.sops.yaml` 与 `config-sha256`）、新出现的 `test-computer/`（`workload.yaml`、`download.sops.yaml`、`kustomization.yaml`）与 `clusters/kind`（测试电脑的阶段）；镜像锁不变；迁移头仍 `20261017_0020`。

**5. 提交、发布、晋级、检查**：

```bash
git add gitops && git -c core.editor=true commit -m "deploy(knowbench): 本地代理 0.5.0（Windows 与 Linux 包）、开下载、开测试电脑（rename R5.3）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（rename R5.3）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep '/knowbench-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
make -C infrastructure application-check APP=knowbench; echo "check exit=$?"
$K -n app-platform-dev get pods | grep -E 'knowbench-(test-computer|api)'
$K -n app-platform-dev logs deploy/knowbench-test-computer --tail=30 | grep -E 'verified|0\.5\.0|连接码|pair' | sed -E 's/[A-Z0-9]{4}-?[A-Z0-9]{4}/<码>/g'
git push origin qwen
```

要看到：`release`、`apply`、`wait`、`check` 都是 0；测试电脑的 Pod `Running`；日志里看得到包核对通过、版本 0.5.0、在等配对（连接码一律抹成 `<码>`，配对在 R5.4）。

**6. 所有者的电脑升到 0.5.0 并重新接入**（所有者亲手做；新工作台是空库，旧的接入不认了，本来就要重新接入）：在 `https://knowbench.sunmoonai.com:30443` 的「接入电脑」页照着装 0.5.0。安装脚本会先卸下旧名字 `sunmoon-agent` 的代理与它的登录自启（旧配置 `.sunmoon-agent` 留着不删），再装 `sunmoon-link`，然后打开接入页；在网页上确认连接码。要看到：「我的电脑」里这台电脑在线、版本 0.5.0；开始菜单里是新名字；新建一个项目让工作对话写一个 `hello.txt`，一次写成。

**回执**：`docs/rename-receipts/R5.3-qwen.<时间>.md`（Windows 包的 A 项表、Linux 输出与 Opus 值的逐项对照、配置 diff、四次 verify/upload 的结果字段、stage 改动、各 `exit`、Pod 与抹过码的日志行、所有者那台电脑的结果）。zip、tar.gz 不进库。

**停点**：Opus 审回执，在本节写「通过」。
**状态**：**通过** · 2026-10-17 · 第 6 步所有者做完：「我的电脑」里 `zymun` 在线、本地代理 0.5.0、Codex 0.155.1；代理令牌到期显示「11月16日 15:08」是网页按协调世界时显示（北京时间 23:08，即重新接入那一刻起 30 天；网页时区问题记账 131）。第 1–5 步 Opus 审 `R5.3-qwen.20261017-2243.md`：两包摘要、清单、上传回读、开关、暂存范围、晋级摘要逐条对得上；测试电脑 `1/1 Running`、域名钉到 `43.153.135.74`、包核对通过、在等配对。第三次的 `flux-source-apply` 首跑超时（exit=2）后幂等重跑为 0：根因是改了 `run.sh` 而 Pod 模板没变，旧 Pod 要崩到下次重启才读到新脚本（11 次），600 秒没等到——不是新问题，Opus 已让 Pod 带上脚本摘要（`e2499661`，随 R5.4 第 4 步暂存）。

### R5.4 测试账号、kimi key、测试电脑配对、走查（0027 P6 的浏览器部分）

> 前提：R5.3 通过（测试电脑在跑、等配对；所有者的电脑已是 0.5.0、接入了新工作台）。账号、密码、key、连接码都由所有者亲手输；**密码与 key 不进对话、回执、日志、git**，连接码只在对话里念给所有者、不进回执。Qwen 遇到登录就停，等所有者。

**1. 建测试账号**（所有者）：在 `https://casdoor.sunmoonai.com:30443` 用 admin 登录 Casdoor 管理界面，在 **sunmoonai** 组织里新建用户 `knowbot-tester`（显示名「分身测试」），密码自己定、自己记进 `密码修改表.md`。建好后打开这个用户的详情页，把 **ID**（一串 UUID，这就是令牌里的 `sub`）告诉 Qwen——只要 ID，不要密码。

**2. 测试账号登录工作台、填 key、拉沙箱**（所有者）：退出自己的账号，用 `knowbot-tester` 登录 `https://knowbench.sunmoonai.com:30443` → 设置 → 模型：厂商 `kimi`、接入地址 `https://api.moonshot.cn/v1`、模型 `kimi-k3`（本地集成脚本一直用的这一套），粘贴 kimi 的 key → 拉起沙箱，等它显示就绪。

**3. 配对测试电脑**（Qwen 看日志、所有者确认）：

```bash
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev logs deploy/knowbench-test-computer --tail=20
```

Qwen 把日志里最新的连接码**只在对话里**告诉所有者；所有者仍用 `knowbot-tester`，在工作台「接入电脑」里输入并确认（码过期了，容器会自己再要一个，再看一次日志）。要看到：日志里出现已连接；`knowbot-tester` 的「我的电脑」里有一台 `knowbot-test` 在线、版本 0.5.0。

**4. 填测试账号、重新暂存 knowbench**：

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
TESTER_ID=<第 1 步的 ID> python3 - <<'PY'
import os, re, pathlib
tid = os.environ['TESTER_ID'].strip(); assert re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', tid), tid
p = pathlib.Path('gitops/components/app-platform/knowbench-app/knowbench-backend/config.yaml'); s = p.read_text()
old = '    # 测试账号 KNOWBOT_TEST_SUBJECT 在 P6 建好 knowbot-tester 后填；不填时推进器不启动、测试接口回 503\n'
assert s.count(old) == 1
p.write_text(s.replace(old, "    # 测试账号 knowbot-tester 的 Casdoor 用户 id（0028 R5.4 建）\n    KNOWBOT_TEST_SUBJECT: '" + tid + "'\n"))
PY
git diff gitops/components/app-platform/knowbench-app/knowbench-backend/config.yaml | grep '^[-+] '
make -C infrastructure platform-stage OBJECT=app-platform/knowbench-app; echo "stage exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3; echo key-check-done
git add gitops && git -c core.editor=true commit -m "deploy(knowbench): 填测试账号，分身测试开始受理（rename R5.4）"
make -C infrastructure flux-release; echo "release exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（rename R5.4）"
make -C infrastructure flux-source-apply; echo "apply exit=$?"
$K -n flux-system get kustomizations -o name | grep '/knowbench-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=30m; echo "wait exit=$?"
make -C infrastructure application-check APP=knowbench; echo "check exit=$?"
$K -n app-platform-dev get configmap knowbench-runtime -o jsonpath='{.data.KNOWBOT_TEST_SUBJECT}'; echo
git push origin qwen
```

要看到：diff 只有注释一行换成注释加 `KNOWBOT_TEST_SUBJECT` 一行；各步都是 0；最后一行打出的是那个 ID。暂存出的改动里还会有 `test-computer/workload.yaml` 多一条 `sunmoonai.com/scripts` 注解（Opus `e2499661`：改了脚本就换 Pod，R5.3 那次的超时就是它），别的行有变就停；晋级后测试电脑重启一次，配对凭据在卷上——再看主容器日志，**不该再出连接码**，「我的电脑」里 `knowbot-test` 仍在线（出了连接码就停，写进回执）。

**5. 走查：一个用假数据的分身从提交到在工作台里跑**（所有者以普通用户——自己的 sunmoonai 账号——操作，Qwen 核截图；截图不截 `code=`、`state=`）。材料在 `docs/rename-tools/r54-walk/`：`data.csv`（三行的小表）、`request.json`（要填的种子）、`manifest.json`（方法包；Opus 已用这次部署的代码核过——knowbench `cc95605` 收得下、knowlab `8731c9d` 受理与建草稿前的核对通过、knowmart `bfeb2ae` 外层校验通过；只用 `list_my_data`、`read_my_data`，计算工具随下一次小发布）。

| 步 | 在哪 | 做什么 | 要看到 |
| --- | --- | --- | --- |
| a | knowlab web端「我的数据」 | 上传 `data.csv` | 列表里有它；页上有「数字类尽量传表格」的提示要等下一次发布，这次没有是对的 |
| b | knowlab web端「我在做的分身」 | 新建一条，照 `request.json` 填：标题、六问、运行方 knowbench、一条用例（问题「2024 年的营业收入是多少？」，期望：交回物 `answer`、路径 `answer`、包含 `100`）、勾同意测试 | 「我在做的分身」里出现这条，状态已提交 |
| c | knowlab 管理端（admin）「分身草稿」 | 打开这条请求，复制「数据」那一行的 JSON，替换 `manifest.json` 里 `data_bindings` 的占位，整份贴进「建草稿」→ 逐条核对出处后点「已逐条核对出处」（三条都是用户原文）→「发起测试」（预算用默认） | 草稿建成、状态测试中 |
| d | 同上 | 隔一两分钟点「刷新结果」（自动轮询是待办 117） | 通过；用例「revenue-2024」期望满足 1/1；有问题转给用户时按提示答 |
| e | knowmart web端 | 看「我的分身」 | 有「读表报营收」第 1 版 |
| f | **从工作台出发**（「请这位」只在从工作台过去时出现）：自己的账号在新工作台是空库，先在设置里填自己的 key、拉起沙箱、让自己的电脑连到这个账号；然后进专家页 `/zh-CN/workbench/expert`，点「专家」栏右边的「请我的分身」→ knowmart 里点「读表报营收」的「请这位」→ 回到工作台；在主页「专家」的「请哪一位」里选它，建一个项目，问「2024 年的营业收入是多少？」（qwen-006 起主页「请哪一位」旁边就有「请我的分身」） | 分身读了你的表，回答里有 100 和出处（数据 id、版本、sha256、页）；结论栏空 |
| g | 工作台「接入电脑」（测试账号那边） | 看 `knowbot-test` 的委托记录 | 测试那次委托在测试电脑的 `/workspace` 里跑过 |

**回执**：`docs/rename-receipts/R5.4-qwen.<时间>.md`（第 3 步日志里连接成功的那几行——**抹掉连接码**；第 4 步各 `exit` 与 diff；走查每一步的截图描述；测试报告的用例结果）。

**停点**：Opus 审回执，在本节写「通过」；之后 R6。
**状态**：**第 1–4 步通过，第 5 步做到 b** · 2026-10-18 · 第 3 步配对时所有者的电脑先误配进了测试账号（账 133），测试电脑重配后正常、`/workspace` 已报上来；第 4 步 Opus 核过（只多 `KNOWBOT_TEST_SUBJECT` 与测试电脑的脚本摘要注解）。第 5 步 a、b 做完（`data.csv` 上传、提交想法，后端两条 201）；**c 卡住**：knowlab 管理端两个列表 403，原因是管理端接口只认没人发的权限（账 134）。所有者定先做 qwen-005（含修复），之后从 c 接着走 · Opus。

## R6 下线旧对象 — Qwen（本地机）

只在 **R5.4 写了「通过」之后**做（所有者 2026-10-17 定「从空的开始」，旧的在新应用验收通过前原样保留作退路，通过后按清单删除，不备份，0028 第四节）。删完就没有退路了。做法照上次改名跑通的 R6（Git 历史 `3951246c:docs/rename.md`）：清单写死、默认只列、一次删一类、删前核归属记号。

工具 `docs/rename-tools/r6_cleanup.py`（Opus 2026-10-17 由上次的工具改成本次清单，从改名前的配置 `8204fd7a` 逐个抄出；在远程机核过：清单里的旧阶段名与现行 `stages.yaml` 没有重叠，knowbench 的名字与共用桶 `agent-releases` 都不会被认成旧名字）。列出来但不在清单里的标 `?? 不在清单，不删`，交 Opus 看。不打印口令、令牌、哈希。

| 类 | 删什么 | 说明 |
| --- | --- | --- |
| `k8s` | 旧阶段的 Flux Kustomization `investment-*` 10 个（R5.2 后显示失败）与它们留下的对象（按阶段标签，先 Deployment/Job 后其余），等旧 Pod 退净 | 共享组件里没有改了名的 investment 对象（`8204fd7a` 的渲染产物里查过）；没带旧标签、名字以 `investment` 开头的其余对象只列不删 |
| `job-history` | 三个命名空间里**已完成、且现行声明里已没有**的历史 Job | 现行声明的 Job 一个不删 |
| `postgresql` | 库 `investment`；角色 `investment_runtime`、`investment_migrator` | 核注释 `sunmoon-kind/investment` |
| `redis` | 用户 `investment_runtime` 与键 `investment:*` | |
| `rabbitmq` | vhost `investment`（说明 `sunmoon:investment:managed-by-gitops`）与用户 `investment_runtime` | |
| `object-storage` | 用户 `investment_release_reader`、`investment_release_writer`；策略 `investment-agent-releases-reader`、`-writer` | **桶 `agent-releases` 不删**：名字没改，knowbench 接着用（新身份 `knowbench_release_*`）。桶里 0.4.1 的旧包留着 |
| `casdoor` | 应用 `sunmoonai-investment-web`、`-admin`、服务身份 `sunmoonai-investment-knowbase-retrieve`（以及 0027 P4/P5 当时只在 Git 里的 `…-knowlab-read`、`…-knowmart-summon`、`sunmoonai-knowlab-investment-testrun`，从没暂存过，找到 0 个是正常的）；对应的 `sunmoon-workload-*` 组织（里面不能有用户） | 核 clientId 与说明记号 |
| `private` | 目录 `/etc/sunmoon/applications/sunmoon-kind/investment`、备份目录、构建候选；平台私有输入里的 `investment-agent-releases.yaml`、两个 `investment-agent-release*-published.json` 与备份 | |
| `harbor` | `platform` 项目的 `investment-backend`、`-web-frontend`、`-admin-frontend` 三个仓库 | 必须在 `k8s` 之后 |
| `harbor-gc` | 上一步删掉的镜像层 | `delete_untagged=false`，前后报占用 |
| Windows hosts | `investment.`、`investment-admin.`、`investment-api.`、`investment-admin-api.sunmoonai.com` | `docs/rename-tools/r6_windows_hosts.ps1`：要求对应的新名字已在某一行（R5.2 加的那行），否则不改；只剩地址的行整行去掉；先备份 |

不在 R6 里：**旧沙箱**（`sandbox` 命名空间里改名前的工作台给用户拉起的沙箱，不带旧阶段标签，回收归 SDD 0014 U4，同上次）；会合点里旧代理的登记（改名后的代理重新接入，旧登记不再用）；ELK 里旧应用的历史日志（按时间滚动）；阿里云 DNS 的 `investment.sunmoonai.com` 记录（边缘已不认它，删不删所有者定）。

### R6.1 列清单（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1
R6='sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- infrastructure/.venv/bin/python docs/rename-tools/r6_cleanup.py'
T=$(date +%Y%m%d-%H%M); $R6 list > docs/rename-receipts/R6.1-list.$T.txt 2>&1; echo "exit=$?"
grep -E "^=====|\?\?" docs/rename-receipts/R6.1-list.$T.txt
```

要看到：`exit=0`（哪一类 `STOP` 就停）。清单整份随回执提交：`git add docs/rename-receipts/R6.1-* && git -c core.editor=true commit -m "rename: R6.1 清单（Qwen）" && git push origin qwen`。**停点**：Opus 逐类审（尤其 `??`），所有者确认删除后写「R6.1 通过」才删。

### R6.2 删（按顺序，一类一类）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
R6='sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- infrastructure/.venv/bin/python docs/rename-tools/r6_cleanup.py'
T=$(date +%Y%m%d-%H%M)
for c in k8s job-history postgresql redis rabbitmq object-storage casdoor private harbor harbor-gc; do
  $R6 delete $c --confirm $c 2>&1 | tee -a docs/rename-receipts/R6.2-delete.$T.txt; rc=${PIPESTATUS[0]}; echo "== $c exit=$rc"; [ "$rc" = 0 ] || break
done
```

要看到：十个 `exit=0`；每类「删后」里清单内的项都没了。任何一类不是 0 就停。

**Windows hosts**（先在副本上演练，再真改；真改弹 UAC，所有者点「是」）：

```bash
chmod u+w /mnt/c/Users/zymun/hosts-r6-rehearsal* 2>/dev/null; rm -f /mnt/c/Users/zymun/hosts-r6-rehearsal*
cp docs/rename-tools/r6_windows_hosts.ps1 /mnt/c/Users/zymun/rename-hosts-r6.ps1
cat /mnt/c/Windows/System32/drivers/etc/hosts > /mnt/c/Users/zymun/hosts-r6-rehearsal   # 用 cat 新建，cp 会照搬只读
test -w /mnt/c/Users/zymun/hosts-r6-rehearsal && echo writable
powershell.exe -NoProfile -Command '$env:RENAME_HOSTS_FILE="C:\Users\zymun\hosts-r6-rehearsal"; $env:RENAME_HOSTS_OUT="C:\Users\zymun\hosts-r6-rehearsal.txt"; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\zymun\rename-hosts-r6.ps1; "exit=$LASTEXITCODE"'
iconv -f GBK -t UTF-8 /mnt/c/Users/zymun/hosts-r6-rehearsal.txt; diff /mnt/c/Windows/System32/drivers/etc/hosts /mnt/c/Users/zymun/hosts-r6-rehearsal
# 上面 exit=0、diff 只是那一行少了四个 investment 名字，才真改（弹 UAC）
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zymun\rename-hosts-r6.ps1'"
iconv -f GBK -t UTF-8 "/mnt/c/Users/zymun/AppData/Local/Temp/rename-hosts-r6-result.txt"
grep -nE 'sunmoonai' /mnt/c/Windows/System32/drivers/etc/hosts | grep -v '^[0-9]*:\s*#'
rm -f /mnt/c/Users/zymun/hosts-r6-rehearsal /mnt/c/Users/zymun/hosts-r6-rehearsal.bak-r6-* /mnt/c/Users/zymun/hosts-r6-rehearsal.txt
```

要看到：`writable`；演练 `exit=0`、`diff` 只有 R5.0 回执里第 25 行那一行少了四个 investment 名字（harbor、www、casdoor 还在）；真改第一行 `OK backup …`，有效行里没有 `investment`。是 `STOP:` 就停。

**删后核对**：

```bash
$R6 list 2>&1 | tee docs/rename-receipts/R6.2-after.$T.txt | grep -E "^=====|\?\?|exit="
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations | grep -v True     # 只剩表头
for a in tpl knowfeed knowbase knowbench knowlab knowmart; do echo "===== check $a"; make -C infrastructure application-check APP=$a; echo "exit=$?"; done
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：清单只剩 R6.1 审过的 `??` 项；Kustomization 全 Ready（`investment-*` 已没了）；六个 `application-check` 与 `platform-status` 都是 0。

**停点**：回执 `R6.2-qwen.<时间>.md` 连同 `R6.2-*.txt` 提交推送，Opus 审过在本节写「改名完成」。
**状态**：**已写好，待 R5.4 通过** · 2026-10-17 · Opus。

## R7 文档 — Opus
