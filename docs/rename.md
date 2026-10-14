# 改名执行手册：info → knowgather、knowledge → knowbase

> 为什么改、改哪些、深度为什么选乙，见 [0025](../sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0025-know-names.md)。本文只管**谁、按什么顺序、执行哪条命令、在哪停下等审**。
>
> 所有者 2026-10-14 定：**改名只有 Opus 和 Qwen 两个人做，所有者不动手**——Opus 在远程机改全部内容、写全部命令、审每一段；Qwen 在所有者机器上做本地的一切（GitHub / gitee 仓改名、本地检出、同步脚本、集群切换、浏览器核对）。Cursor 只在开工前发完卡 47、48，之后冻结。knowmart（原 advisor-app）还没有代码和部署，不在本手册，只改设计（R7）。

## 规矩（每一段都适用）

1. **只执行本文写下的命令。** 本文没写的、写得和现场对不上的，一律停下报告，不临场发挥、不「顺手修一下」。
2. **按段走，一段一停。** 每段末尾有「停点」：执行人写回执，Opus 审过、在本文该段的「状态」里写上「通过 + 日期 + 审读人」，下一段才开始。
3. **不删旧东西，只挪开。** 旧目录、旧桶、旧秘密目录、旧镜像、旧 Casdoor 应用一律保留；**删除不在本手册里**，R6 验收、下一次例行备份之后另行决定。注意 R3 挪进 `~/rename-backup/` 的**工位**检出不能直接 `git log`：工位里父仓与子仓的 `.git` 是指向主目录的相对路径（如 `../../../../master/info-app/.git/worktrees/…`），挪开后指向断了；对象都还在备份的 `master/.git` 里，要找回时先手工改 `.git` 文件里的 `gitdir:`。备份的 `master/` 本身完整可用。
4. **秘密不进回执、不进日志、不进 Git。** 口令、令牌、私钥只在本机生成、只进 SOPS。
5. **出错先停，不重试成功了再报。** 失败的输出原样（去掉秘密）贴进回执。
6. 回执统一放 `k8s/docs/rename-receipts/R<段号>-<执行人>.<时间>.md`，最后一行 `exit=<码>`。
7. **改名窗口（R1 开始到 R4 通过）里不跑同步脚本**（`human-local.sh`、`human-remote.sh`、`sync-five-repos.sh`）：它们写死了仓名与子仓路径，两台机器目录对不上时会中途退出、留下半同步的状态。窗口里两台机器的往来只用下面「窗口内往来」写明的 git 命令。R0 之前与 R4 通过之后照常用同步脚本。
8. 所有者把改名期间的推送交给 Opus 与 Qwen：Opus 在远程机、Qwen 在本地机，**只推 `qwen` 分支、只推本文写明的仓**，不推别的分支、不强推。

### 回执往来（R0 到 R6 都用这几条，只动 k8s 的 `qwen` 分支）

两边只改各自的文件——Qwen 只写 `docs/rename-receipts/`，Opus 只写本文、代码与配置——所以 `--rebase` 不会冲突；万一冲突，停下报告，不手工解决。

```bash
# Qwen（本地机）交回执
cd ~/worktrees/qwen/k8s && git add docs/rename-receipts && git commit -m "rename: R<段号> 回执（Qwen）" \
  && git pull --rebase origin qwen && git push origin qwen
# Qwen 等「通过」：拉下来看本文对应段的「状态」
cd ~/worktrees/qwen/k8s && git pull --rebase origin qwen && sed -n '/^## R<段号>/,/^---/p' docs/rename.md
# Opus（远程机）写「通过」后
cd ~/worktrees/qwen/k8s && git commit -am "rename: R<段号> 通过" && git pull --rebase origin qwen && git push origin qwen
```

### 所有者只传话，不同步（所有者 2026-10-14 定）

Opus 与 Qwen 互相发不了消息，但都直接推、直接拉 origin。所以改名期间所有者**不跑同步脚本**，只在两边之间传一句话：

| 谁做完了 | 怎么交 | 所有者传给谁、传什么 |
| --- | --- | --- |
| Qwen 交了某段回执 | Qwen 自己推（上面第一条） | 告诉 Opus：「Qwen 交了 R<段号>」 |
| Opus 审完写了「通过」 | Opus 自己推（上面第三条） | Opus 会说「R<段号> 通过，Qwen 可以做 R<下一段>」；所有者转告 Qwen |

- 传话只说是哪一段、谁交的；手册里的「状态」以 origin 上的为准，传话只是提醒对方去拉。
- 收到传话的一方先拉（上面第二条，或 Opus 那边 `git -C ~/worktrees/qwen/k8s pull --rebase origin qwen`），看到对应内容才动手；拉不到就回一句「还没看到」，不猜。
- **开工前最后一次照常同步**：卡 48 回执回来时所有者跑一次 `WS=qwen bash ~/switch-test/human-local.sh`（把 Cursor 的回执与远程的提交两边带齐）。之后到 R4 结束都不跑。
- **何时恢复同步**：R4 两台机器的仓名与同步配置都改好后，由 Qwen 跑一次 `human-local.sh` 验证能走通（见 R4）；从那以后照常同步。

## 谁做什么

| 角色 | 在哪 | 做什么 | 不做什么 |
| --- | --- | --- | --- |
| **Opus**（远程机 qwen 工位） | 远程机 | R0 核远程机、发开工令；R1 改全部代码、配置、gitops、同步脚本，写好 R5、R6 的逐条命令；R3、R4 远程机那一份；审每段回执、在各段写「通过」；R7 文档 | 不碰所有者本地集群；不替 Qwen 执行本地命令 |
| **Qwen**（所有者机器） | 本地机、GitHub、gitee | R0 核本地机；R2 在 GitHub / gitee 上改 8 个仓的名字；每段之间跑同步脚本；R3、R4 本地机那一份；R5 集群切换（备份 → 停服搬迁 → 起新服 → 浏览器核对）；R6 下线旧对象 | 不改代码、不改本文、不自己写命令；不删任何旧东西 |
| **Cursor** | 本地机 | **开工前发完卡 47、48**（R0 的前提）；之后**冻结**：不执行任何发布卡、不碰 info / knowledge / knowgather / knowbase 相关的仓与集群对象。R6 通过后，Cursor 以后的卡一律用新名字 | 改名的任何一步 |
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
| 对象存储 | 桶 `info-originals`——**只有这一个桶**：knowledge 没有自己的桶，它用账号 `knowledge_source_reader` 读这个桶的 `info/` 前缀（配置 `KNOWLEDGE_DATASET_ALLOWED_BUCKETS`、`source_bucket`、`source_prefix`）；`/tmp/knowledge-datasets` 只是容器里的缓存目录，不改不搬。桶内对象键前缀 `info/`（原文 `info/original/…`、登记的数据集 `info/securities/…/datasets/…`，两个库里都存着这些键） | 桶 `knowgather-originals`；键前缀 `knowgather/`；账号 `knowbase_source_reader`；三项配置随之改 |
| vhost、队列、Redis | vhost `info`、队列 `info.default`、键前缀 `info:*`；knowledge 侧 vhost `knowledge` 等 | `knowgather`、`knowgather.default`、`knowgather:*`；knowbase 侧同理 |
| 私有目录 / 备份目录 | `/etc/sunmoon/applications/sunmoon-kind/info`、`/mnt/sunmoon-data/backups/applications/sunmoon-kind/info`；knowledge 同理 | `…/knowgather`、`…/knowbase` |
| `source_app` 值（有两种） | `info-app`（采集服务写入，`info_crawl_service.py`）；`info`（数据集登记器默认值 `knowledge_registrar.py`，knowledge 的登记记录与样例里也是它） | `knowgather-app`；`knowgather`（各自对应，不顺手合并——合并是另一个改动） |

R1 的数据迁移两种 `source_app` 旧值都换，两个库里凡存它的表都覆盖；对象键前缀与库里存的对象键在 R5.2 复制桶时一起换。

「knowledge」作普通词（本地知识库、云上知识库、知识检索工具）**不改**；R1 逐处判断，拿不准的列进 R1 回执，标「保留原词」，不改。

## R1 改与留的界线（2026-10-14 远程盘点，三处由所有者同日定）

原则：**改「这个应用叫什么」，留「它管的东西叫什么」。** 盘点范围是五组仓的源码与配置（不含依赖、构建产物、历史回执、录下来的样例）：含 `knowledge` 的约 4400 行，含应用名意义的 `info` 约 1000 种写法。

| 类 | 例子 | 定 |
| --- | --- | --- |
| 应用身份 | 仓、目录、组件、镜像、k8s 对象名、域名（含测试里的 `info.example.test`）、Casdoor 应用 / 客户端 / 组织 / 服务身份名（`sunmoonai-info-web`、`sunmoonai-info-knowledge-ingest`…）、登录 cookie 名（`sunmoonai_info_web_sid`…）、跨应用键、gitops 路径、部署脚本名、`PLATFORM_INFO_*` | **改** |
| 存储名 | 上面「名字对照」表里的库、角色、桶、键前缀、vhost、队列、Redis、私有目录、备份目录、`source_app` | **改**（乙） |
| 指向应用的配置与环境变量 | 共 76 个：knowbase 自己的配置前缀 `KNOWLEDGE_MCP_*`、`KNOWLEDGE_DATASET_*`；调用方的 `KNOWLEDGE_APP_*`、`KNOWLEDGE_RETRIEVAL_*`、`INFO_*`；`CASDOOR_INFO_*`、`CASDOOR_KNOWLEDGE_*`；部署里的 `service_env_prefix` | **改名不改值**。特别是 `KNOWLEDGE_DOCUMENT_NAMESPACE` / `KNOWLEDGE_VERSION_NAMESPACE` 是生成固定 ID 用的 UUID，**值一个字都不能动**，否则已有文档的 ID 全对不上 |
| MCP 服务名（所有者定：改） | `sunmoon_knowledge`：沙箱镜像 `sandbox-platform/image/entrypoint.sh` 写进 Codex 配置；模型看到的工具名由它拼出（`sunmoon_knowledge/run_sql`）；评测提示词、单测、工具调用记录里都有 | **改**为 `sunmoon_knowbase`（它是应用身份）。R5 要多重建、多发一次沙箱镜像；改名前后的工具调用记录名字不同，历史记录不改 |
| 带应用名前缀的内部标识（所有者定：改） | 采集库的表 `info_collector`、`info_document`、`info_document_version`、`info_source`；事件类型 `info.security.ingest.v1`、`info.index.v1`；这里的 `info` 是应用名，不是领域词 | **改**为 `knowgather_*`、`knowgather.*`：表用迁移 `ALTER TABLE … RENAME`（连同索引、约束、序列名，带回退）；事件类型随停服切换一起换，切换前队列已排空。代价：多一组迁移和一轮核对 |
| knowledge 作领域词（所有者定：留） | 知识库的表 `knowledge_document`、`knowledge_ingestion_job`、`knowledge_dataset` 等；类名 `KnowledgeDocument`；API 路径 `/api/knowledge/…`、`/api/internal/v1/knowledge/datasets`；令牌作用域 `knowledge:ingest`、`knowledge:retrieve`、`knowledge:admin`；事件类型 `knowledge.ingest.v1`；Python 模块名 | **留**：这里的 knowledge 说的是「存的是知识文档」，改名后 knowbase 存的仍是知识。改它要改表、改所有调用方的接口与令牌作用域，代价大、收益只是字面统一 |
| 设计文档的文件名 | `0006-knowledge.md`、`0008-info*.md`、`PRD/apps/info.md` 等 | 文件名当编号用，**不改**（改了几十处链接全断）；内容在 R7 换新名 |
| 冻结的旧体系与历史记录 | `k8s/sunmoonai/` 下的旧体系目录 `app-platform`、`cicd-platform`、`data-platform`、`deploy-sunmoonai-all`、`infrastructure`、`ingress-platform`、`kind-infrastructure`、`messaging-platform`、`operations`、`ops-platform`、`registry-platform` 与 `CHECKPOINT-old-system-*.md`（2026-10-06 起冻结，只作查阅；新体系只引用 `sunmoonai/relay-platform`、`sunmoonai/sandbox-platform`）；各处的 `results/`、`thread/`、`history/`、`switch-test/done/`、`hold/`、评测报告 `eval/reports/`、录下来的样例 `preview/fixtures/` | **不改**。去掉这些后要改的约 720 个文件 |
| 无关的 info | `logger.info`、`component_info`、`st_mode`、**`cninfo` / `CNINFO`（巨潮资讯网，数据来源）** | **不碰** |

R1 的替换脚本按这张表逐类写规则，每一类替换后单独列出改了哪些文件、多少处，进 `R1-opus` 回执；拿不准的不改、列出来。

---

## R0 冻结与前提 — Cursor 收尾，Qwen 与 Opus 核对

1. Cursor 发完卡 47、48，两份回执已由 Opus 审过（卡 48 要先等 Qwen 的 0024 Windows 真机回执）。之后 Cursor 不再接卡，直到 R6 写「改名完成」。
2. 其他工位（fable、kimi、luna、astra）冻结（见上表）。
3. 两台机器上，五个工位 × `info-app`、`knowledge-app`（含 6 个子仓）都**干净且已推到 origin**；qwen 工位的 `k8s`、`investment-app`（含两个子仓）、`runtime`、`tpl-app` 也干净且已推。R3 会把前两组的旧检出整个挪开、从 origin 重新 clone，没推的提交会丢在备份目录里。远程机由 Opus 核，本地机由 Qwen 核：

```bash
for ws in cursor fable kimi luna qwen; do for r in info-app knowledge-app; do
  d=~/worktrees/$ws/$r; git -C $d fetch -q origin
  printf '%-40s branch=%s ahead=%s dirty=%s\n' "$d" "$(git -C $d branch --show-current)" \
    "$(git -C $d rev-list --count origin/$ws..HEAD)" "$(git -C $d status --porcelain --ignore-submodules=none | wc -l)"
  git -C $d submodule foreach --quiet 'git fetch -q origin; printf "  %-34s branch=%s on_remote=%s dirty=%s\n" "$sm_path" "$(git branch --show-current)" "$(git branch -r --contains HEAD | wc -l)" "$(git status --porcelain | wc -l)"'
done; done
for r in k8s investment-app runtime tpl-app; do d=~/worktrees/qwen/$r; git -C $d fetch -q origin
  printf '%-40s ahead=%s dirty=%s\n' "$d" "$(git -C $d rev-list --count origin/qwen..HEAD)" "$(git -C $d status --porcelain --ignore-submodules=none | wc -l)"; done
```

   要看到：每行 `ahead=0`、`dirty=0`；子仓 `on_remote` ≥ 1（当前提交在 origin 的某个分支上）；工位行的 `branch` 等于工位名。子仓的 `branch` 可以为空（游离在父仓记的提交上，2026-10-14 远程机 fable 工位就有 4 个），只要 `on_remote` ≥ 1 就行，R3 会把它拨回同名分支。任何一项不符就停，先把那个工位推干净（窗口外，照常用同步脚本）。本地机还要核：`~/master`、`~/worktrees`、`mb` 与本文写的布局一致（`ls ~/master ~/worktrees`、`type mb`），两组父仓都有 `gitee` 这个 remote（`git -C ~/master/info-app remote -v`）。
4. **R2 的权限**（Qwen 核，结果进 `R0-qwen`）：GitHub 要 `gh` 已登录、对 8 个仓都是管理员——

```bash
gh auth status
for n in info-app knowledge-app info-backend info-web-frontend info-admin-frontend knowledge-backend knowledge-web-frontend knowledge-admin-frontend; do
  printf '%-26s admin=%s\n' "$n" "$(gh api repos/sunmoonlion/$n --jq .permissions.admin)"; done
```

   要看到 8 个 `admin=true`。gitee 要能在网页上以 sunmoonlion 登录、或有带 projects 权限的 API 令牌，写明用哪种。任何一样没有就停下，请所有者给权限（这是全程唯一可能要所有者出手的地方）；令牌只放 Qwen 本机，不进回执。

**停点**：Opus 收到 Qwen 的 `R0-qwen`（本地机核对）并自己核完远程机，在本节「状态」写「开工」。
**状态**：

---

## R1 改内容 — Opus（远程机 qwen 工位）

在 qwen 分支上改，**先推到旧名字的仓**（R2 改名后 GitHub / gitee 会接着认这些提交）。子仓 `.gitmodules` 里的地址直接写新名字；R1 到 R2 之间没有人拉子仓，所以新地址暂时不存在不碍事。

| 仓 | 改什么 |
| --- | --- |
| 6 个子仓 | 构建脚本、`mybuild/`、说明、代码里的应用名与域名、环境变量名、`source_app` 与桶名的数据迁移（带回退） |
| `info-app` / `knowledge-app` 父仓 | `.gitmodules`（子仓路径与 URL 换新名，submodule 的 name 一并换）、子仓目录 `git mv`、`AGENTS.md` 等说明、`.cursor/rules` |
| `investment-app` | 跨应用键 `info` / `knowledge`、`destinations.ts`、`cross_app.py`、`KNOWLEDGE_*` 环境变量名 |
| `k8s` | gitops `info-app/` → `knowgather-app/` 等目录、`infrastructure/applications/` 的应用名表与 `deploy.yaml` / `verify.yaml`、`sources.yaml` 两块、存储名、Casdoor 声明、域名、`switch-test/human-local.sh`、`human-remote.sh` 的仓名表、各仓 `AGENTS.md` 里「五个协作仓」的名字 |
| `tpl-app`、`runtime` | 只改提到这两个应用名的说明与脚本 |

**k8s 里只改真源，不手改渲染产物。** gitops 每个组件目录里，`config.yaml`、`stage.yaml`、`README.md` 是真源，R1 改；`workload.yaml`、`kustomization.yaml`、`*.sops.yaml`（加密的秘密）、`image.lock.yaml` 是 `platform-stage` / 构建链生成的，R1 只让它们跟着目录 `git mv`、内容不动——它们要靠所有者机器上的私有目录与 SOPS 私钥重新生成（远程机没有 ansible、sops，也没有私钥），新秘密也是那时按新名生成，放在 R5。所以 R1 提交后、R5 发布前，这些渲染产物里还是旧名字，属正常；R1 的提交在 R5 发布前不会进现网。

自测：各仓单测、构建全过；在改名范围内（「改与留的界线」排除的除外）扫一遍，旧名只剩例外清单里的（扫描脚本与结果进回执）。渲染比对放到 R5.2 stage 之后做（见 R5）。

写好 R5、R6 的逐条命令（填进本文对应小节），**R5 状态改成「可执行」之前，Qwen 不得开始 R5**。

推送（Opus 在远程机，**先子仓后父仓**，只推 `qwen`）：

```bash
# R1 已在父仓里 git mv 了子仓目录，父仓目录本身要到 R3 才换名，所以此刻的路径是「旧父仓/新子仓」
for d in info-app/knowgather-backend info-app/knowgather-web-frontend info-app/knowgather-admin-frontend \
         knowledge-app/knowbase-backend knowledge-app/knowbase-web-frontend knowledge-app/knowbase-admin-frontend; do
  git -C ~/worktrees/qwen/$d push origin HEAD:refs/heads/qwen   # remote 仍是旧仓名，R2 后由 GitHub 认到新仓
done
git -C ~/worktrees/qwen/info-app push origin qwen
git -C ~/worktrees/qwen/knowledge-app push origin qwen
for d in investment-app/investment-backend investment-app/investment-web-frontend; do git -C ~/worktrees/qwen/$d push origin HEAD:refs/heads/qwen; done
for r in investment-app runtime tpl-app k8s; do git -C ~/worktrees/qwen/$r push origin qwen; done
```

**停点**：Opus 写回执 `R1-opus`（含各仓推上去的提交号）并在本节写「通过」。
**状态**：

---

## R2 远端仓改名 — Qwen

在 GitHub 与 gitee 上改名（网页的仓设置，或 `gh repo rename`；gitee 用网页或其 API）。只改名，不新建、不删。改前把 8 个仓各自默认分支与 qwen 分支的提交号记进回执。

| 平台 | 旧 → 新 |
| --- | --- |
| GitHub | `info-app` → `knowgather-app`；`knowledge-app` → `knowbase-app`；6 个子仓按「名字对照」表 |
| gitee | `info-app` → `knowgather-app`；`knowledge-app` → `knowbase-app`（子仓在 gitee 上没有，不用管）。**gitee 的「仓库名称」和「仓库路径」是两个字段，两个都要改**，地址看的是路径；gitee 不一定转发旧地址，所以改完旧地址打不开属正常 |

改完核对（地址的协议跟着本机，从旧检出里取前缀）：

```bash
GH=$(git -C ~/master/info-app remote get-url origin); GH=${GH%info-app.git}
GE=$(git -C ~/master/info-app remote get-url gitee);  GE=${GE%info-app.git}
for n in knowgather-app knowbase-app knowgather-backend knowgather-web-frontend knowgather-admin-frontend knowbase-backend knowbase-web-frontend knowbase-admin-frontend; do
  printf '%-28s github qwen=%s master=%s\n' "$n" "$(git ls-remote ${GH}$n.git refs/heads/qwen | cut -c1-8)" "$(git ls-remote ${GH}$n.git refs/heads/master | cut -c1-8)"; done
for n in knowgather-app knowbase-app; do printf '%-28s gitee  qwen=%s\n' "$n" "$(git ls-remote ${GE}$n.git refs/heads/qwen | cut -c1-8)"; done
```

要看到：每个新地址都能列出分支，`qwen` 等于 `R1-opus` 记下的提交号，`master` 与改名前相同。

**停点**：Qwen 写 `R2-qwen`（改名前后的地址、提交号对照），Opus 审过写「通过」。
**状态**：

---

## R3 检出换名 — 远程机 Opus，本地机 Qwen

两台机器做同样的事，**远程机先做**（Opus），`R3-opus` 审过、本节写进远程机的实际情况后，Qwen 再做本地机。**旧目录挪到 `~/rename-backup/`，不删。** 以 `info-app` → `knowgather-app` 为例，`knowledge-app` → `knowbase-app` 同样做一遍：

为什么不用 `mb worktree remove`：它底层是 `git worktree remove`，而 git 不允许摘下带子仓的工位（`working trees containing submodules cannot be moved or removed`，2026-10-14 实测）。所以旧检出整目录挪开；R0 已证明它们都干净且已推，挪开的只是备份。以下流程 2026-10-14 已在草稿仓里演练通过（旧内容分支与新内容分支各一个，结果见 `R1-opus`）。

```bash
set -e
OLD=info-app NEW=knowgather-app        # 第二遍：OLD=knowledge-app NEW=knowbase-app
WS="cursor fable kimi luna qwen"   # 某台机器上没有哪个工位，就从这里去掉，并写进回执
B=~/rename-backup/$(date +%Y%m%d-%H%M)-$OLD; mkdir -p "$B"
newname() { basename "$1" | sed -e 's/^info-/knowgather-/' -e 's/^knowledge-/knowbase-/'; }
# 子仓：remote 指向新仓名（前缀 $SUB 取自旧检出）；拨回给定分支（与工位同名）并设上游——现在的子仓就是这样，同步脚本按此推 HEAD:<工位>
fix_subs() { local top=$1 branch=$2 p
  for p in $(git -C "$top" submodule foreach --quiet 'echo $sm_path'); do
    git -C "$top/$p" remote set-url origin "${SUB}$(newname "$p").git"
    git -C "$top/$p" fetch -q origin
    git -C "$top/$p" checkout -q -B "$branch"
    git -C "$top/$p" branch -q --set-upstream-to="origin/$branch"
  done; }

# 1. 挪开五个工位的旧检出与旧主目录，注销旧仓
for ws in $WS; do mv ~/worktrees/$ws/$OLD "$B/$ws"; done
mb repo remove "$OLD"
mv ~/master/$OLD "$B/master"
# 2. 地址一律从旧主目录取、只换仓名，不写死协议（远程机 GitHub 走 ssh，本地机走 https）
GH=$(git -C "$B/master" remote get-url origin); GH=${GH%$OLD.git}                    # GitHub 前缀
GE=$(git -C "$B/master" remote get-url gitee);  GE=${GE%$OLD.git}                    # gitee 前缀
S1=$(git -C "$B/master" submodule foreach --quiet 'echo $sm_path' | head -1)
SUB=$(git -C "$B/master/$S1" remote get-url origin); SUB=${SUB%/*}/                  # 子仓前缀（备份的 master 里子仓完整可用）
CFG=(); case "$SUB" in git@*) CFG=(-c "url.${SUB}.insteadOf=https://github.com/sunmoonlion/");; esac   # 子仓走 ssh 的机器上，.gitmodules 里的 https 地址也改走 ssh
echo "GH=$GH GE=$GE SUB=$SUB"                                                       # 进回执
# 3. 用新名字重新 clone 主目录（检出默认分支 master）
git "${CFG[@]}" clone --recurse-submodules "${GH}$NEW.git" ~/master/$NEW
test "$(git -C ~/master/$NEW branch --show-current)" = master
# 4. 父仓 remote 照旧布局：gitee remote 照抄；origin 的推送地址逐条照抄旧仓的、只换仓名
git -C ~/master/$NEW remote add gitee "${GE}$NEW.git"
git -C "$B/master" remote get-url --push --all origin | while read -r u; do
  git -C ~/master/$NEW remote set-url --add --push origin "${u%$OLD.git}$NEW.git"; done
fix_subs ~/master/$NEW master
# 5. 先建跟踪 origin 的本地工位分支——mb 只认本地分支，没有就「从 master 新建」，会丢掉工位上的提交
for ws in $WS; do git -C ~/master/$NEW branch -q --track "$ws" "origin/$ws"; done
# 6. 注册并挂出五个工位；mb 不管子仓，挂出后逐个初始化、拨回同名分支
mb repo add ~/master/$NEW
for ws in $WS; do
  mb worktree add "$ws" "$NEW"
  git "${CFG[@]}" -C ~/worktrees/$ws/$NEW submodule update --init --recursive
  fix_subs ~/worktrees/$ws/$NEW "$ws"
done
```

`mb worktree add` 每个工位应输出「挂出 …」；**出现「从 master 新建分支」就停**（说明第 4 步没建好分支）。

注意：除 qwen 外，其他工位的分支此时还是改名前的内容（子仓目录仍叫 `info-backend` 等），但子仓 remote 已指向新仓。它们在 qwen 的改名提交并进 master 后再跟上（见文末「冻结解除之后」）；冻结期间不要在这些分支上提交。

核对（结果进回执）：

```bash
for ws in $WS; do d=~/worktrees/$ws/$NEW
  printf '%-40s branch=%s head=%s origin=%s dirty=%s\n' "$d" "$(git -C $d branch --show-current)" \
    "$(git -C $d rev-parse --short HEAD)" "$(git -C $d rev-parse --short origin/$ws)" "$(git -C $d status --porcelain --ignore-submodules=none | wc -l)"
  git -C $d submodule foreach --quiet 'printf "  %-34s branch=%s up=%s head=%s origin=%s url=%s\n" "$sm_path" "$(git branch --show-current)" "$(git rev-parse --abbrev-ref @{u})" "$(git rev-parse --short HEAD)" "$(git rev-parse --short @{u})" "$(git remote get-url origin)"'
done
git -C ~/master/$NEW remote -v
```

要看到：每个工位 `branch` = 工位名、`head` = `origin`、`dirty=0`；子仓 `branch` = 工位名、`up` = `origin/<工位>`、`url` 是新仓名，`head` 与 `origin` 相同（不同说明父仓记的子仓提交不是该分支的头，照实写进回执交 Opus 判断，不要动）；主目录 remote 与备份目录里 `git -C "$B/master" remote -v` 相比只有仓名变了（协议、主机、推送地址个数都相同）。

**停点**：Opus 写 `R3-opus`（远程机）、Qwen 写 `R3-qwen`（本地机），Opus 审。
**状态**：

---

## R4 同步配置 — 远程机 Opus，本地机 Qwen

两台机器各改两个文件（都不在 Git 里，各机一份）：

1. `~/five-repos-sync/config.sh` 的 `REPOS=(…)`：`"knowledge-app"` → `"knowbase-app"`，`"info-app"` → `"knowgather-app"`。改前 `cp config.sh config.sh.bak-rename`。
2. `mb` 的 `repos.conf`：R3 的 `mb repo remove` / `add` 已经改好，这里只核对：`grep -n know ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf` 应只有 `knowgather-app`、`knowbase-app` 两行。

`~/switch-test/human-*.sh` 是转发器，不用改；它转发到的 k8s 仓里那两份已在 R1 改好。

两台机器都改完、Opus 核过远程机之后，改名窗口结束：Qwen 跑一次 `WS=qwen bash ~/switch-test/human-local.sh`，要能正常走完（不报找不到仓），本地 qwen 工位的 `investment-app`、`runtime`、`tpl-app`、`k8s` 也随之拉到 R1 的提交。

**停点**：Opus、Qwen 各写回执（Qwen 的含同步脚本最后一句），Opus 写「通过」。
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

`platform-stage` 按新名重新生成全部渲染产物 → **渲染比对**：Qwen 把改名前（R0 时的提交）与 stage 后的渲染产物逐个对象比对，列出除名字以外的差异（比对命令由 Opus 填），**Opus 审过才部署**；→ 构建新镜像（knowgather、knowbase 的后端与两个网页，**以及 investment 的后端与网页**——它的跨应用键与环境变量名也改了）→ 部署新名字（新 Casdoor 应用与客户端、新服务身份）→ `application-check APP=knowgather`、`APP=knowbase`、`APP=investment` → 浏览器打开两个新域名能登录、能看到原有数据 → 投资里跨应用跳转与知识检索可用。

**停点**：Qwen 在浏览器上逐项核对（截图只截页面，不截令牌与口令），Opus 审回执。

回退（任一小节失败）：见 0025 第四节「回退」；Qwen 只执行 Opus 在本节写好的回退命令。

**状态**：

---

## R6 下线旧对象 — Qwen（本地机）

旧 Deployment / Job / Secret、旧 Casdoor 应用与客户端、旧 vhost 与 Redis 用户下线（命令由 Opus 填）。**旧桶、旧私有目录、Harbor 旧镜像仓库、`~/rename-backup/` 下的旧检出保留**，删除不在本手册里。

**停点**：Opus 审回执，在本节写「改名完成」，冻结解除，Cursor 恢复接卡（用新名字）。
**状态**：

---

## R7 文档 — Opus

PRD / SDD / 决策 / 总览 / 各仓 `AGENTS.md` 换名；0018 改写为 knowmart（知识市场；吸收《专家市场架构对比分析和借鉴》第二、五、七节）；`docs/竞品比较分析.md`、`docs/专家市场架构对比分析和借鉴.md` 里的应用名换新；历史回执与冻结原件不改。

**状态**：

---

## 冻结解除之后（不属于改名，但要有人做）

1. fable 照常把 `qwen` 的改名提交并进 `master`（五组仓都要：knowgather-app、knowbase-app 及子仓、investment-app、k8s、runtime、tpl-app 里 R1 改过的）。
2. 其他工位（cursor、fable、kimi、luna）各自把 `master` 并进自己的分支，或用 `mb worktree add --from-master <工位> <仓>` 拨回 master——拨回会丢掉该工位相对 master 的提交，用前确认已并进 master。
3. 远程机 `~/rename-backup/` 与本地机同名目录保留，删除另行决定。

