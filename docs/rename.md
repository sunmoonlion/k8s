# 改名执行手册：info → knowgather、knowledge → knowbase

> 为什么改、改哪些、深度为什么选乙，见 [0025](../sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0025-know-names.md)。本文只管**谁、按什么顺序、执行哪条命令、在哪停下等审**。
>
> 所有者 2026-10-14 定：改名由 Opus 亲自做；本地集群上的部分由 Qwen 在所有者机器上跑；**不经 Cursor**。knowmart（原 advisor-app）还没有代码和部署，不在本手册，只改设计（R7）。

## 规矩（每一段都适用）

1. **只执行本文写下的命令。** 本文没写的、写得和现场对不上的，一律停下报告，不临场发挥、不「顺手修一下」。
2. **按段走，一段一停。** 每段末尾有「停点」：执行人写回执，Opus 审过、在本文该段的「状态」里写上「通过 + 日期 + 审读人」，下一段才开始。
3. **不删旧东西，只挪开。** 旧目录、旧桶、旧秘密目录、旧镜像、旧 Casdoor 应用一律保留到 R6 验收后，由所有者明说才删。
4. **秘密不进回执、不进日志、不进 Git。** 口令、令牌、私钥只在本机生成、只进 SOPS。
5. **出错先停，不重试成功了再报。** 失败的输出原样（去掉秘密）贴进回执。
6. 回执统一放 `k8s/docs/rename-receipts/R<段号>-<执行人>.<时间>.md`，最后一行 `exit=<码>`；本地提交，**不 push**（推送由所有者的同步脚本做）。

## 谁做什么

| 角色 | 在哪 | 做什么 | 不做什么 |
| --- | --- | --- | --- |
| **所有者** | GitHub、gitee、本地机 | R0 冻结与开工令；R2 在 GitHub / gitee 上改 8 个仓的名字；每段之间跑同步脚本；R6 后决定何时删旧东西 | — |
| **Opus**（远程机 qwen 工位） | 远程机 | R1 改全部代码、配置、gitops、同步脚本，写好 R5 的逐条命令；R3 远程机的检出换名；审每段回执；R7 文档 | 不碰所有者本地集群 |
| **Qwen**（所有者机器） | 本地机 | R3 本地机的检出换名；R4 本地机的同步配置；R5 集群切换（备份 → 停服搬迁 → 起新服 → 验证）；R6 下线旧对象 | 不改代码、不改本文、不自己写命令 |
| **Cursor** | — | **改名期间冻结**：不执行任何发布卡、不碰 info / knowledge / knowgather / knowbase 相关的仓与集群对象。R6 通过后，Cursor 以后的卡一律用新名字 | 改名的任何一步 |
| 其他工位（fable、kimi、luna、astra） | — | 冻结期间不提交这两组仓、不改 k8s 的 gitops；R3 后各自工位按新名字重新挂出 | — |

## 名字对照（全文以此为准）

| 类 | 旧 | 新 |
| --- | --- | --- |
| 父仓（GitHub `sunmoonlion/`、gitee `sunmoonlion/`） | `info-app` | `knowgather-app` |
|  | `knowledge-app` | `knowbase-app` |
| 子仓（GitHub `sunmoonlion/`，仅 GitHub） | `info-backend`、`info-web-frontend`、`info-admin-frontend` | `knowgather-backend`、`knowgather-web-frontend`、`knowgather-admin-frontend` |
|  | `knowledge-backend`、`knowledge-web-frontend`、`knowledge-admin-frontend` | `knowbase-backend`、`knowbase-web-frontend`、`knowbase-admin-frontend` |
| 应用名（部署） | `info`、`knowledge` | `knowgather`、`knowbase` |
| 域名 | `info.`、`info-admin.`、`knowledge.`、`knowledge-admin.sunmoonai.com` | `knowgather.`、`knowgather-admin.`、`knowbase.`、`knowbase-admin.sunmoonai.com` |
| 数据库 / 角色 | `info`、`info_runtime`、`info_migrator`；`knowledge`、`knowledge_runtime`、`knowledge_migrator` | `knowgather`、`knowgather_runtime`、`knowgather_migrator`；`knowbase`、`knowbase_runtime`、`knowbase_migrator` |
| 桶、vhost、队列、Redis | `info-originals`、vhost `info`、`info.default`、`info:*`；knowledge 侧同理 | `knowgather-originals`、`knowgather`、`knowgather.default`、`knowgather:*`；knowbase 侧同理 |
| 私有目录 / 备份目录 | `/etc/sunmoon/applications/sunmoon-kind/info`、`/mnt/sunmoon-data/backups/applications/sunmoon-kind/info`；knowledge 同理 | `…/knowgather`、`…/knowbase` |
| `source_app` 值 | `info-app` | `knowgather-app` |

「knowledge」作普通词（本地知识库、云上知识库、知识检索工具）**不改**；R1 逐处判断，拿不准的列进 R1 回执交所有者。

---

## R0 冻结与前提 — 所有者

1. 卡 47、48 已上线（或所有者明说先改名、卡 48 按新名字重写）。
2. 通知所有工位冻结（见上表）。Cursor 收到「改名冻结」后，手上的卡停在当前步。
3. 两台机器上，五个工位 × `info-app`、`knowledge-app`（含 6 个子仓）都**干净且已推**、各工位指向同一提交。远程机由 Opus 核，本地机由 Qwen 核，命令：

```bash
for ws in cursor fable kimi luna qwen; do for r in info-app knowledge-app; do
  d=~/worktrees/$ws/$r; printf '%-40s %s %s\n' "$d" "$(git -C $d rev-parse --short HEAD)" "$(git -C $d status --porcelain --ignore-submodules=none | wc -l)"
  git -C $d submodule foreach --quiet 'printf "  %-36s %s %s\n" "$sm_path" "$(git rev-parse --short HEAD)" "$(git status --porcelain | wc -l)"'
done; done
```

   要看到：每行最后一列是 0；同一仓各工位的提交号相同。

**停点**：所有者在本节「状态」写「开工」。
**状态**：

---

## R1 改内容 — Opus（远程机 qwen 工位）

在 qwen 分支上改，**先推到旧名字的仓**（R2 改名后 GitHub / gitee 会接着认这些提交）：

| 仓 | 改什么 |
| --- | --- |
| 6 个子仓 | 构建脚本、`mybuild/`、说明、代码里的应用名与域名、环境变量名、`source_app` 与桶名的数据迁移（带回退） |
| `info-app` / `knowledge-app` 父仓 | `.gitmodules`（子仓路径与 URL 换新名，submodule 的 name 一并换）、子仓目录 `git mv`、`AGENTS.md` 等说明、`.cursor/rules` |
| `investment-app` | 跨应用键 `info` / `knowledge`、`destinations.ts`、`cross_app.py`、`KNOWLEDGE_*` 环境变量名 |
| `k8s` | gitops `info-app/` → `knowgather-app/` 等目录、`infrastructure/applications/` 的应用名表与 `deploy.yaml` / `verify.yaml`、`sources.yaml` 两块、存储名、Casdoor 声明、域名、`switch-test/human-local.sh`、`human-remote.sh` 的仓名表、各仓 `AGENTS.md` 里「五个协作仓」的名字 |
| `tpl-app`、`runtime` | 只改提到这两个应用名的说明与脚本 |

自测：各仓单测、构建全过；k8s 渲染比对——改名前后渲染出的对象，除了名字逐项相同（比对脚本与结果进回执）。

写好 R5 的逐条命令（填进本文 R5 各小节），**R5 状态改成「可执行」之前，Qwen 不得开始 R5**。

**停点**：Opus 写回执 `R1-opus`，所有者看过。推到旧名字的仓由所有者跑同步脚本完成。
**状态**：

---

## R2 远端仓改名 — 所有者

在 GitHub 与 gitee 网页上改名（仓设置 → 仓名）。只改名，不新建、不删。

| 平台 | 旧 → 新 |
| --- | --- |
| GitHub | `info-app` → `knowgather-app`；`knowledge-app` → `knowbase-app`；6 个子仓按「名字对照」表 |
| gitee | `info-app` → `knowgather-app`；`knowledge-app` → `knowbase-app`（子仓在 gitee 上没有，不用管） |

改完各开一次新地址的网页确认能打开、默认分支与提交号没变。

**停点**：所有者在本节「状态」写「已改」。
**状态**：

---

## R3 检出换名 — 远程机 Opus，本地机 Qwen

两台机器做同样的事，**远程机先做**（Opus），`R3-opus` 审过、本节写进远程机的实际情况后，Qwen 再做本地机。**旧目录挪到 `~/rename-backup/`，不删。** 以 `info-app` → `knowgather-app` 为例，`knowledge-app` → `knowbase-app` 同样做一遍：

```bash
set -e
OLD=info-app NEW=knowgather-app        # 第二遍：OLD=knowledge-app NEW=knowbase-app
mkdir -p ~/rename-backup
# 1. 先摘下五个工位的 worktree（要求干净，否则 mb 会拒绝——那就停）
for ws in cursor fable kimi luna qwen; do mb worktree remove "$ws" "$OLD"; done
mb repo remove "$OLD"
# 2. 旧主目录挪开（连同里面的 worktree 元数据与子仓 git 目录）
mv ~/master/$OLD ~/rename-backup/$OLD-$(date +%Y%m%d-%H%M)
# 3. 用新名字重新 clone（子仓按新 .gitmodules 一起拉）
git clone --recurse-submodules git@github.com:sunmoonlion/$NEW.git ~/master/$NEW
# 4. remote 照旧布局：父仓 origin 双推（GitHub + gitee）、另有 gitee；子仓只有 GitHub
git -C ~/master/$NEW remote add gitee https://gitee.com/sunmoonlion/$NEW.git
git -C ~/master/$NEW remote set-url --add --push origin git@github.com:sunmoonlion/$NEW.git
git -C ~/master/$NEW remote set-url --add --push origin https://gitee.com/sunmoonlion/$NEW.git
git -C ~/master/$NEW submodule foreach 'git remote set-url origin "git@github.com:sunmoonlion/$(basename "$sm_path").git"'
# 5. 先建跟踪远端的本地分支——mb 只认本地分支，没有就「从 master 新建」，会丢掉工位上的提交
git -C ~/master/$NEW fetch origin
for ws in cursor fable kimi luna qwen; do git -C ~/master/$NEW branch --track "$ws" "origin/$ws"; done
# 6. 重新注册并挂出五个工位；mb 不管子仓，挂出后逐个初始化
mb repo add ~/master/$NEW
for ws in cursor fable kimi luna qwen; do
  mb worktree add "$ws" "$NEW"
  git -C ~/worktrees/$ws/$NEW submodule update --init --recursive
done
```

注意：除 qwen 外，其他工位的分支此时还是改名前的内容（子仓路径仍是 `info-backend` 等、`.gitmodules` 里是旧地址，GitHub 会把旧地址转到新仓）。它们在 qwen 的改名提交并进 master 后，由各工位照常合并；冻结解除前不要在这些分支上提交。

核对（结果进回执）：

```bash
for ws in cursor fable kimi luna qwen; do d=~/worktrees/$ws/$NEW
  printf '%-40s %s %s\n' "$d" "$(git -C $d branch --show-current)" "$(git -C $d rev-parse --short HEAD)"
  git -C $d submodule status; done
git -C ~/master/$NEW remote -v; git -C ~/master/$NEW submodule foreach --quiet 'git remote -v | head -1'
```

要看到：每个工位在同名分支（**不能出现「从 master 新建分支」**，出现就停）、提交号与 R0 记录（qwen 工位是 R1 的新提交）一致；子仓都已检出；remote 只有名字变了，布局和旧目录 `git remote -v` 一样。

**停点**：Opus 写 `R3-opus`（远程机）、Qwen 写 `R3-qwen`（本地机），Opus 审。
**状态**：

---

## R4 同步配置 — 远程机 Opus，本地机 Qwen

两台机器各改两个文件（都不在 Git 里，各机一份）：

1. `~/five-repos-sync/config.sh` 的 `REPOS=(…)`：`"knowledge-app"` → `"knowbase-app"`，`"info-app"` → `"knowgather-app"`。改前 `cp config.sh config.sh.bak-rename`。
2. `mb` 的 `repos.conf`：R3 的 `mb repo remove` / `add` 已经改好，这里只核对：`grep -n know ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf` 应只有 `knowgather-app`、`knowbase-app` 两行。

`~/switch-test/human-*.sh` 是转发器，不用改；它转发到的 k8s 仓里那两份已在 R1 改好。

然后所有者跑一次 `WS=qwen bash ~/switch-test/human-local.sh`，要能正常走完（不报找不到仓）。

**停点**：Opus、Qwen 各写回执，所有者贴同步脚本最后一句。
**状态**：

---

## R5 集群切换 — Qwen（本地机）

> **逐条命令由 Opus 在 R1 完成后填入下面各小节。本段状态写成「可执行」之前，不得开始。** 顺序与核对标准已定（0025 第四节 4.1）：

### R5.1 备份（不停服）

两个库 `pg_dump`、两个桶的对象清单与校验和、私有目录打包（不出机器）；记各表行数、对象数、总字节。

**停点**：Opus 审备份完整。

### R5.2 停服与搬迁

旧名字的 API / Worker / Scheduler 停到 0 副本 → 等队列排空 → 库与角色改名 → 桶复制并逐对象核对 → 建新 vhost、Redis 用户 → 生成新秘密进 SOPS → 跑数据迁移。

**停点**：Opus 审行数、对象数、校验和一致。

### R5.3 起新服与验证

构建新镜像 → 部署新名字（新 Casdoor 应用与客户端、新服务身份）→ `application-check APP=knowgather`、`APP=knowbase`、`APP=investment` → 浏览器打开两个新域名能登录、能看到原有数据 → 投资里跨应用跳转与知识检索可用。

**停点**：Opus 审回执；所有者在浏览器上亲手看一遍。

回退（任一小节失败）：见 0025 第四节「回退」；Qwen 只执行 Opus 在本节写好的回退命令。

**状态**：

---

## R6 下线旧对象 — Qwen（本地机）

旧 Deployment / Job / Secret、旧 Casdoor 应用与客户端、旧 vhost 与 Redis 用户下线（命令由 Opus 填）。**旧桶、旧私有目录、Harbor 旧镜像仓库、`~/rename-backup/` 下的旧检出保留**，等下一次例行备份之后由所有者明说再删。

**停点**：Opus 审回执；所有者在本节写「改名完成」，冻结解除。
**状态**：

---

## R7 文档 — Opus

PRD / SDD / 决策 / 总览 / 各仓 `AGENTS.md` 换名；0018 改写为 knowmart（知识市场；吸收《专家市场架构对比分析和借鉴》第二、五、七节）；`docs/竞品比较分析.md`、`docs/专家市场架构对比分析和借鉴.md` 里的应用名换新；历史回执与冻结原件不改。

**状态**：
