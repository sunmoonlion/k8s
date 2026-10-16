# 改名执行手册：info → knowfeed、knowledge → knowbase

> 为什么改、改哪些、深度为什么选乙，见 [0025](../sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0025-know-names.md)。本文只管**谁、按什么顺序、执行哪条命令、在哪停下等审**。
>
> 所有者 2026-10-14 定：**改名只有 Opus 和 Qwen 两个人做，所有者不动手**——Opus 在远程机改全部内容、写全部命令、审每一段；Qwen 在所有者机器上做本地的一切（GitHub / gitee 仓改名、本地检出、同步脚本、集群切换、浏览器核对）。Cursor 只在开工前发完卡 47、48，之后冻结。knowmart（原 advisor-app）还没有代码和部署，不在本手册，只改设计（R7）。

## 规矩（每一段都适用）

1. **只执行本文写下的命令。** 本文没写的、写得和现场对不上的，一律停下报告，不临场发挥、不「顺手修一下」。
2. **按段走，一段一停。** 每段末尾有「停点」：执行人写回执，Opus 审过、在本文该段的「状态」里写上「通过 + 日期 + 审读人」，下一段才开始。
3. **R5.3 验证通过之前不删任何旧东西。** 旧库、旧桶、旧 Casdoor 应用等是 R5 失败时退回旧应用的唯一退路。所有者 2026-10-15 定旧的不必备份（「旧库，旧桶好像也没必要备份」），所以验证通过后在 **R6 按清单删除**：先列出、再删、再核对，删前删后的清单都进回执。注意 R3 挪进 `~/rename-backup/` 的**工位**检出不能直接 `git log`：工位里父仓与子仓的 `.git` 是指向主目录的相对路径（如 `../../../../master/info-app/.git/worktrees/…`），挪开后指向断了；对象都还在备份的 `master/.git` 里，要找回时先手工改 `.git` 文件里的 `gitdir:`。备份的 `master/` 本身完整可用。
4. **秘密不进回执、不进日志、不进 Git。** 口令、令牌、私钥只在本机生成、只进 SOPS。
5. **出错先停，不重试成功了再报。** 失败的输出原样（去掉秘密）贴进回执。
6. 回执统一放 `k8s/docs/rename-receipts/R<段号>-<执行人>.<时间>.md`，最后一行 `exit=<码>`。
7. **改名窗口（R1 开始到 R4 通过）里不跑同步脚本**（`human-local.sh`、`human-remote.sh`、`sync-five-repos.sh`）：它们写死了仓名与子仓路径，两台机器目录对不上时会中途退出、留下半同步的状态。窗口里两台机器的往来只用下面「窗口内往来」写明的 git 命令。R0 之前与 R4 通过之后照常用同步脚本。
8. 所有者把改名期间的推送交给 Opus 与 Qwen：Opus 在远程机、Qwen 在本地机，**只推 `qwen` 分支、只推本文写明的仓**，不推别的分支、不强推（R2.2 往 gitee 6 个子仓的强推是所有者 2026-10-15 点名同意的例外）。
9. **命令块一律用 bash 跑**：多行的块存成文件 `bash 文件` 执行，有现成脚本的用脚本。两台机器的登录 shell 是 zsh，zsh 不拆分未加引号的 `$VAR`，`for x in $LIST` 只会循环一次、退出码照样是 0（R2.2 实际踩到，只处理了第一个仓）。`mb` 在 zsh 里是别名，bash 里要直接调 `model-branch.sh`。

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
| **Cursor** | 本地机 | **开工前发完卡 47、48**（R0 的前提）；之后**冻结**：不执行任何发布卡、不碰 info / knowledge / knowfeed / knowbase 相关的仓与集群对象。R6 通过后，Cursor 以后的卡一律用新名字 | 改名的任何一步 |
| 其他工位（fable、kimi、luna、astra） | — | 冻结期间不提交这两组仓、不改 k8s 的 gitops；R3 后各自工位按新名字重新挂出 | — |

## 名字对照（全文以此为准）

| 类 | 旧 | 新 |
| --- | --- | --- |
| 父仓（GitHub `sunmoonlion/`、gitee `sunmoonlion/`） | `info-app` | `knowfeed-app` |
|  | `knowledge-app` | `knowbase-app` |
| 子仓（GitHub `sunmoonlion/`，仅 GitHub） | `info-backend`、`info-web-frontend`、`info-admin-frontend` | `knowfeed-backend`、`knowfeed-web-frontend`、`knowfeed-admin-frontend` |
|  | `knowledge-backend`、`knowledge-web-frontend`、`knowledge-admin-frontend` | `knowbase-backend`、`knowbase-web-frontend`、`knowbase-admin-frontend` |
| 应用名（部署） | `info`、`knowledge` | `knowfeed`、`knowbase` |
| 域名 | `info.`、`info-admin.`、`knowledge.`、`knowledge-admin.sunmoonai.com` | `knowfeed.`、`knowfeed-admin.`、`knowbase.`、`knowbase-admin.sunmoonai.com` |
| 数据库 / 角色 | `info`、`info_runtime`、`info_migrator`；`knowledge`、`knowledge_runtime`、`knowledge_migrator` | `knowfeed`、`knowfeed_runtime`、`knowfeed_migrator`；`knowbase`、`knowbase_runtime`、`knowbase_migrator` |
| 对象存储 | 桶 `info-originals`——**只有这一个桶**：knowledge 没有自己的桶，它用账号 `knowledge_source_reader` 读这个桶的 `info/` 前缀（配置 `KNOWLEDGE_DATASET_ALLOWED_BUCKETS`、`source_bucket`、`source_prefix`）；`/tmp/knowledge-datasets` 只是容器里的缓存目录，不改不搬。桶内对象键前缀 `info/`（原文 `info/original/…`、登记的数据集 `info/securities/…/datasets/…`，两个库里都存着这些键） | 桶 `knowfeed-originals`；键前缀 `knowfeed/`；账号 `knowbase_source_reader`；三项配置随之改 |
| vhost、队列、Redis | vhost `info`、队列 `info.default`、键前缀 `info:*`；knowledge 侧 vhost `knowledge` 等 | `knowfeed`、`knowfeed.default`、`knowfeed:*`；knowbase 侧同理 |
| 私有目录 / 备份目录 | `/etc/sunmoon/applications/sunmoon-kind/info`、`/mnt/sunmoon-data/backups/applications/sunmoon-kind/info`；knowledge 同理 | `…/knowfeed`、`…/knowbase` |
| `source_app` 值（有两种） | `info-app`（采集服务写入，`info_crawl_service.py`）；`info`（数据集登记器默认值 `knowledge_registrar.py`，knowledge 的登记记录与样例里也是它） | `knowfeed-app`；`knowfeed`（各自对应，不顺手合并——合并是另一个改动） |

R1 的数据迁移两种 `source_app` 旧值都换，两个库里凡存它的表都覆盖；对象键前缀与库里存的对象键在 R5.2 复制桶时一起换。

**存储从空的开始**（所有者 2026-10-15 定：两个应用的现有数据都不要）：上表存储类的新名字都是**新建**的，不是把旧的改名搬过去；旧库、旧桶等原样留作备份。

「knowledge」作普通词（本地知识库、云上知识库、知识检索工具）**不改**；R1 逐处判断，拿不准的列进 R1 回执，标「保留原词」，不改。

## R1 改与留的界线（2026-10-14 远程盘点，三处由所有者同日定）

原则：**改「这个应用叫什么」，留「它管的东西叫什么」。** 盘点范围是五组仓的源码与配置（不含依赖、构建产物、历史回执、录下来的样例）：含 `knowledge` 的约 4400 行，含应用名意义的 `info` 约 1000 种写法。

| 类 | 例子 | 定 |
| --- | --- | --- |
| 应用身份 | 仓、目录、组件、镜像、k8s 对象名、域名（含测试里的 `info.example.test`）、Casdoor 应用 / 客户端 / 组织 / 服务身份名（`sunmoonai-info-web`、`sunmoonai-info-knowledge-ingest`…）、登录 cookie 名（`sunmoonai_info_web_sid`…）、跨应用键、gitops 路径、部署脚本名、`PLATFORM_INFO_*` | **改** |
| 存储名 | 上面「名字对照」表里的库、角色、桶、键前缀、vhost、队列、Redis、私有目录、备份目录、`source_app` | **改**（乙） |
| 指向应用的配置与环境变量 | 共 76 个：knowbase 自己的配置前缀 `KNOWLEDGE_MCP_*`、`KNOWLEDGE_DATASET_*`；调用方的 `KNOWLEDGE_APP_*`、`KNOWLEDGE_RETRIEVAL_*`、`INFO_*`；`CASDOOR_INFO_*`、`CASDOOR_KNOWLEDGE_*`；部署里的 `service_env_prefix` | **改名不改值**。特别是 `KNOWLEDGE_DOCUMENT_NAMESPACE` / `KNOWLEDGE_VERSION_NAMESPACE` 是生成固定 ID 用的 UUID，**值一个字都不能动**，否则已有文档的 ID 全对不上 |
| MCP 服务名（所有者定：改） | `sunmoon_knowledge`：沙箱镜像 `sandbox-platform/image/entrypoint.sh` 写进 Codex 配置；模型看到的工具名由它拼出（`sunmoon_knowledge/run_sql`）；评测提示词、单测、工具调用记录里都有 | **改**为 `sunmoon_knowbase`（它是应用身份）。R5 要多重建、多发一次沙箱镜像；改名前后的工具调用记录名字不同，历史记录不改 |
| 带应用名前缀的内部标识（所有者定：改） | 采集库的表 `info_collector`、`info_document`、`info_document_version`、`info_source`；事件类型 `info.security.ingest.v1`、`info.index.v1`；这里的 `info` 是应用名，不是领域词 | **改**为 `knowfeed_*`、`knowfeed.*`：表用迁移 `ALTER TABLE … RENAME`（连同索引、约束、序列名，带回退）；事件类型随停服切换一起换，切换前队列已排空。代价：多一组迁移和一轮核对 |
| knowledge 作领域词（所有者定：留） | 知识库的表 `knowledge_document`、`knowledge_ingestion_job`、`knowledge_dataset` 等；类名 `KnowledgeDocument`；API 路径 `/api/knowledge/…`、`/api/internal/v1/knowledge/datasets`；事件类型 `knowledge.ingest.v1`；Python 模块名 | **留**：这里的 knowledge 说的是「存的是知识文档」，改名后 knowbase 存的仍是知识。改它要改表、改所有调用方的接口与令牌作用域，代价大、收益只是字面统一 |
| 设计文档的文件名 | `0006-knowledge.md`、`0008-info*.md`、`PRD/apps/info.md` 等 | 文件名当编号用，**不改**（改了几十处链接全断）；内容在 R7 换新名 |
| 令牌作用域（所有者 2026-10-14 改定：改） | `info:admin` → `knowfeed:admin`；`knowledge:admin` / `knowledge:ingest` / `knowledge:retrieve` → `knowbase:admin` / `knowbase:ingest` / `knowbase:retrieve`。作用域是「应用名:动作」（`identity.md`：各 App 的 Admin scope 是 `info:admin` / `knowledge:admin` / `investment:admin`；验收脚本 `check-browser.py` 按「应用名 + `:admin`」检查）。远程起初把 `knowledge:*` 误归为领域词，所有者据此选过「留」，查实后改定 | **改**。R5 本来就按新名重建 Casdoor 应用与服务身份，作用域随之换。出站去重键 `knowledge:ingest:<任务>` 是库里已存的内部键，不改 |
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
**状态**：**开工** · 2026-10-14 · Opus。前提核过：卡 47（16:10）、卡 48（16:51）上线且回执已审；Qwen `R0-qwen.20261014-1629.md`（A 权限：GitHub 8 仓 admin、gitee API 令牌两仓 admin；B 两组仓五工位干净已推；补核 qwen 四仓与 investment 三子仓干净已推，k8s `343e5d0f`）；远程机同一核对 44 行全部 ahead=0、dirty=0、子仓在 origin 上，布局与 `mb`、两组父仓的 gitee remote 齐。改名窗口自此开始：不跑同步脚本，其他工位冻结，往来照「回执往来」。

---

## R1 改内容 — Opus（远程机 qwen 工位）

在 qwen 分支上改，**先推到旧名字的仓**（R2 改名后 GitHub / gitee 会接着认这些提交）。子仓 `.gitmodules` 里的地址直接写新名字；R1 到 R2 之间没有人拉子仓，所以新地址暂时不存在不碍事。

| 仓 | 改什么 |
| --- | --- |
| 6 个子仓 | 构建脚本、`mybuild/`、说明、代码里的应用名与域名、环境变量名、`source_app`；采集后端新迁移 `0014`（只改表结构：四张 `info_*` 表与相关约束、索引、序列改名，带回退；不搬数据） |
| `info-app` / `knowledge-app` 父仓 | `.gitmodules`（子仓路径与 URL 换新名，submodule 的 name 一并换）、子仓目录 `git mv`、`AGENTS.md` 等说明、`.cursor/rules` |
| `investment-app` | 跨应用键 `info` / `knowledge`、`destinations.ts`、`cross_app.py`、`KNOWLEDGE_*` 环境变量名 |
| `k8s` | gitops `info-app/` → `knowfeed-app/` 等目录、`infrastructure/applications/` 的应用名表与 `deploy.yaml` / `verify.yaml`、`sources.yaml` 两块、存储名、Casdoor 声明、域名、`switch-test/human-local.sh`、`human-remote.sh` 的仓名表、各仓 `AGENTS.md` 里「五个协作仓」的名字 |
| `tpl-app`（含三个子仓）、`runtime` | 提到这两个应用名的说明、脚本、网页的跨应用配置与测试 |

执行：工具在 `docs/rename-tools/`（用法见其 README）：`r1_apply.py` 一次做完改名计划、子仓目录与其余文件的 `git mv`、内容替换、手工补丁和下面两项 k8s 收尾；之后用改名后的知识后端重录知识库管理端的预览样例，`residual.py` 逐行过残留。

**改名后的 knowfeed、knowbase 组件目录里，旧的 `*.sops.yaml` 一律 `git rm`**：存储从空的开始、秘密按新名全新生成，而 stage 看到组件目录里已有 `database/bootstrap.sops.yaml` 就按「已有库不许换口令」拒绝生成（`common/backend/prepare.yaml`）。

**k8s 里只改真源，不手改渲染产物。** gitops 每个组件目录里，`config.yaml`、`stage.yaml`、`README.md` 是真源，R1 改；`workload.yaml`、`kustomization.yaml`、`*.sops.yaml`（加密的秘密）、`image.lock.yaml` 是 `platform-stage` / 构建链生成的，R1 只让它们跟着目录 `git mv`、内容不动——它们要靠所有者机器上的私有目录与 SOPS 私钥重新生成（远程机没有 ansible、sops，也没有私钥），新秘密也是那时按新名生成，放在 R5。所以 R1 提交后、R5 发布前，这些渲染产物里还是旧名字，属正常；R1 的提交在 R5 发布前不会进现网。

自测：各仓单测、构建全过；在改名范围内（「改与留的界线」排除的除外）扫一遍，旧名只剩例外清单里的（扫描脚本与结果进回执）。渲染比对放到 R5.2 stage 之后做（见 R5）。

写好 R5、R6 的逐条命令（填进本文对应小节），**R5 状态改成「可执行」之前，Qwen 不得开始 R5**。

推送（Opus 在远程机，**先子仓后父仓**，只推 `qwen`）：

```bash
# R1 已在父仓里 git mv 了子仓目录，父仓目录本身要到 R3 才换名，所以此刻的路径是「旧父仓/新子仓」
for d in info-app/knowfeed-backend info-app/knowfeed-web-frontend info-app/knowfeed-admin-frontend \
         knowledge-app/knowbase-backend knowledge-app/knowbase-web-frontend knowledge-app/knowbase-admin-frontend; do
  git -C ~/worktrees/qwen/$d push origin HEAD:refs/heads/qwen   # remote 仍是旧仓名，R2 后由 GitHub 认到新仓
done
git -C ~/worktrees/qwen/info-app push origin qwen
git -C ~/worktrees/qwen/knowledge-app push origin qwen
for d in investment-app/investment-backend investment-app/investment-web-frontend investment-app/investment-admin-frontend \
         tpl-app/tpl-backend tpl-app/tpl-web-frontend tpl-app/tpl-admin-frontend; do
  git -C ~/worktrees/qwen/$d push origin HEAD:refs/heads/qwen   # 只推有改名提交的（R1 回执列出）
done
for r in investment-app runtime tpl-app k8s; do git -C ~/worktrees/qwen/$r push origin qwen; done
```

**停点**：Opus 写回执 `R1-opus`（含各仓推上去的提交号）并在本节写「通过」。
**状态**：**通过** · 2026-10-15 · Opus。回执 `rename-receipts/R1-opus.20261015-1200.md`：18 个仓的改名提交已推到旧名字的仓的 `qwen` 分支（两个父仓 GitHub、gitee 都已核对）；k8s `c5905fe2`。Qwen 可以开始 R2。R5、R6 的逐条命令在 R5 前补齐。

---

## R2 远端仓改名 — Qwen

在 GitHub 与 gitee 上改名（网页的仓设置，或 `gh repo rename`；gitee 用网页或其 API）。只改名，不新建、不删。改前把 8 个仓各自默认分支与 qwen 分支的提交号记进回执。

| 平台 | 旧 → 新 |
| --- | --- |
| GitHub | `info-app` → `knowfeed-app`；`knowledge-app` → `knowbase-app`；6 个子仓按「名字对照」表 |
| gitee | `info-app` → `knowfeed-app`；`knowledge-app` → `knowbase-app`；6 个子仓见下面「R2.2」。**gitee 的「仓库名称」和「仓库路径」是两个字段，两个都要改**，地址看的是路径；gitee 不一定转发旧地址，所以改完旧地址打不开属正常 |

改完核对（地址的协议跟着本机，从旧检出里取前缀）：

```bash
GH=$(git -C ~/master/info-app remote get-url origin); GH=${GH%info-app.git}
GE=$(git -C ~/master/info-app remote get-url gitee);  GE=${GE%info-app.git}
for n in knowfeed-app knowbase-app knowfeed-backend knowfeed-web-frontend knowfeed-admin-frontend knowbase-backend knowbase-web-frontend knowbase-admin-frontend; do
  printf '%-28s github qwen=%s master=%s\n' "$n" "$(git ls-remote ${GH}$n.git refs/heads/qwen | cut -c1-8)" "$(git ls-remote ${GH}$n.git refs/heads/master | cut -c1-8)"; done
for n in knowfeed-app knowbase-app; do printf '%-28s gitee  qwen=%s\n' "$n" "$(git ls-remote ${GE}$n.git refs/heads/qwen | cut -c1-8)"; done
```

要看到：每个新地址都能列出分支，`qwen` 等于 `R1-opus` 记下的提交号，`master` 与改名前相同。

### R2.2 gitee 上的 6 个子仓与 GitHub 一致（所有者 2026-10-15 定）

gitee 上原有 6 个同名旧子仓（`info-backend` 等）：只有 `master`（5 个与 GitHub 的 `master` 相同，`knowledge-backend` 不同）和 4 个仓里 GitHub 上已没有的 `opus` 分支，没有 `qwen` 与各工位分支——子仓日常只推 GitHub。所有者定：以后子仓也和父仓一样两边都有、两边一样。做法：先备份旧内容，再改名，再从 GitHub 把全部分支与标签强推过去（**会覆盖 gitee 上这 6 个仓的旧内容，所有者已同意；备份是唯一的退路，先做**）。R3 里子仓的推送地址再加上 gitee（见 R3 `fix_subs`），以后同步脚本推子仓时两边一起推。

令牌照改父仓时的做法：只放本机环境变量、从标准输入读，不进命令行参数、不进日志与回执。

```bash
set -e
read -rs GITEE_TOKEN; export GITEE_TOKEN                                   # 粘贴令牌回车，屏幕不回显
GH=$(git -C ~/master/info-app remote get-url origin); GH=${GH%info-app.git}   # GitHub 前缀（本机协议）
OWNER=sunmoonlion
B=~/rename-backup/gitee-old-subrepos-$(date +%Y%m%d-%H%M); mkdir -p "$B"
PAIRS="info-backend:knowfeed-backend info-web-frontend:knowfeed-web-frontend info-admin-frontend:knowfeed-admin-frontend
       knowledge-backend:knowbase-backend knowledge-web-frontend:knowbase-web-frontend knowledge-admin-frontend:knowbase-admin-frontend"
# 推 gitee 用的凭据：从环境变量取，令牌不出现在命令行
GCRED=(-c credential.helper= -c "credential.helper=!f() { echo username=$OWNER; echo password=\$GITEE_TOKEN; }; f")

# 1. 备份旧内容（每个仓一个 bundle，含全部分支；另记一份分支清单）
for pr in $PAIRS; do old=${pr%%:*}
  git clone -q --mirror "https://gitee.com/$OWNER/$old.git" "$B/$old.git"
  git -C "$B/$old.git" bundle create "$B/$old.bundle" --all
  git -C "$B/$old.git" for-each-ref --format='%(objectname:short) %(refname)' > "$B/$old.refs"
  git bundle verify "$B/$old.bundle" >/dev/null && echo "备份  $old  $(wc -l < "$B/$old.refs") 个引用"
done

# 2. 改名：名称与路径两个字段都改
for pr in $PAIRS; do old=${pr%%:*} new=${pr##*:}
  code=$(printf 'access_token=%s&name=%s&path=%s' "$GITEE_TOKEN" "$new" "$new" |
         curl -sS -o /dev/null -w '%{http_code}' -X PATCH -d @- "https://gitee.com/api/v5/repos/$OWNER/$old")
  echo "改名  $old → $new  HTTP $code"                                     # 要 200；不是 200 就停
done

# 3. 从 GitHub 取全部分支与标签，强推到 gitee，并删掉 gitee 上 GitHub 没有的分支（旧 opus）
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
```

要看到：6 个备份各有引用数；6 个改名都是 `HTTP 200`；最后 6 行都是「一致」。gitee 若因保护分支拒绝强推 `master`，停下，把报错写进回执（不要去关保护），交 Opus 定。

**停点**：Qwen 写 `R2-qwen`（改名前后的地址、提交号对照；R2.2 的备份目录、改名返回码、核对结果），Opus 审过写「通过」。
**状态**：**通过** · 2026-10-15 · Opus。GitHub 8 仓、gitee 2 个父仓改名（`R2-qwen.20261015-1211.md`）与 R2.2 gitee 6 个子仓（`R2.2-qwen.20261015-1248.md`：备份在本地机 `~/rename-backup/gitee-old-subrepos-20261015-1241/`，6 个 bundle 校验通过；改名 6 个 HTTP 200；强推后两边分支与标签逐条一致）均由 Opus 在远程机独立复核：`qwen` 均为 R1 提交、`master` 未变，6 个子仓 GitHub 与 gitee 引用逐条相同，gitee 旧地址已转到新仓。R2.2 执行时 zsh 不拆分 `$PAIRS` 只处理了第一个仓，Qwen 发现后补齐——已加规矩 9。R3 可以开始（远程机 Opus 先做）。

---

## R3 检出换名 — 远程机 Opus，本地机 Qwen

两台机器做同样的事，**远程机先做**（Opus），`R3-opus` 审过、本节写进远程机的实际情况后，Qwen 再做本地机。**旧目录挪到 `~/rename-backup/`，不删。** 以 `info-app` → `knowfeed-app` 为例，`knowledge-app` → `knowbase-app` 同样做一遍：

为什么不用 `mb worktree remove`：它底层是 `git worktree remove`，而 git 不允许摘下带子仓的工位（`working trees containing submodules cannot be moved or removed`，2026-10-14 实测）。所以旧检出整目录挪开；R0 已证明它们都干净且已推，挪开的只是备份。以下流程 2026-10-14 已在草稿仓里演练通过（旧内容分支与新内容分支各一个，结果见 `R1-opus`）。

执行：工具 `k8s/docs/rename-tools/r3_checkout.sh`（两组各跑一次，**必须用 bash**）：

```bash
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh info-app knowfeed-app
bash ~/worktrees/qwen/k8s/docs/rename-tools/r3_checkout.sh knowledge-app knowbase-app
```

脚本做的事：先查前提（旧主目录与五个工位都在且干净、新名字的目录都不在、`repos.conf` 里恰有旧名一行），不满足就停、什么都不动 → 旧主目录与五个工位整目录挪进 `~/rename-backup/<时间>-<旧名>/` → 地址从旧主目录取、只换仓名（不写死协议）→ 按新名 clone 主目录（`master`）→ 父仓 remote 照旧布局（gitee remote；origin 推送地址逐条照抄）→ 子仓 remote 指向新仓名、推送地址 GitHub 与 gitee 各一（R2.2）、拨回同名分支 → 建跟踪 origin 的五个工位分支 → `repos.conf` 里旧名那一行换成新名（保持 `$HOME/...` 写法与位置：这份文件在 `toolboxes` 仓里、两台机器共用，不能写绝对路径；所以不用 `mb repo remove/add`，它会写成绝对路径）→ 用 `model-branch.sh worktree add` 挂出五个工位（输出出现「从 master 新建」「失败」「冲突」就停）、初始化子仓、拨回同名分支 → 打印核对。某台机器没有哪个工位：`WS="fable kimi luna qwen" bash …`，并写进回执。

2026-10-15 在临时家目录里按远程机的布局（主目录 + 五个工位、子仓、`repos.conf` 副本）演练通过；演练抓到一处 `pipefail` 下 `| head -1` 让 `submodule foreach` 失败的问题，已改。

注意：除 qwen 外，其他工位的分支此时还是改名前的内容（子仓目录仍叫 `info-backend` 等），但子仓 remote 已指向新仓。它们在 qwen 的改名提交并进 master 后再跟上（见文末「冻结解除之后」）；冻结期间不要在这些分支上提交。

核对：脚本最后打印的核对原样进回执。

要看到：每个工位 `branch` = 工位名、`head` = `origin`、`dirty=0`；子仓 `branch` = 工位名、`up` = `origin/<工位>`、`url` 是新仓名、下面两行 `push` 分别是 GitHub 与 gitee 的新仓名，`head` 与 `origin` 相同（不同说明父仓记的子仓提交不是该分支的头，照实写进回执交 Opus 判断，不要动）；主目录 remote（新）与备份的（旧）相比只有仓名变了（协议、主机、推送地址个数都相同）；`repos.conf` 里是 `$HOME/master/<新名>`。

**停点**：Opus 写 `R3-opus`（远程机）、Qwen 写 `R3-qwen`（本地机），Opus 审。
**状态**：**通过** · 2026-10-15 · Opus。远程机 `R3-opus.20261015-1302.md`、本地机 `R3-qwen.20261015-1410.md`：两台机器各两组 `exit=0`，二十个工位全部「挂出」、`dirty=0`，子仓推送地址 GitHub + gitee，`repos.conf` 两行换新名；两台机器的 `knowledge-backend` 在 cursor、kimi、luna 上都是 `head=e30525f`、`origin=548e84a`（父仓记的更新、可快进），不处理。本地机脚本用的是 `7250fe10` 版，在「repos.conf 还是旧名」时与新版行为相同。

---

## R4 同步配置 — 远程机 Opus，本地机 Qwen

两台机器各核对两个文件：

1. `~/five-repos-sync/config.sh` 的 `REPOS=(…)`：`"knowledge-app"` → `"knowbase-app"`，`"info-app"` → `"knowfeed-app"`。改前 `cp config.sh config.sh.bak-rename`。
2. `mb` 的 `repos.conf`：R3 脚本已改好，这里只核对：`grep -n know ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf` 应只有 `$HOME/master/knowfeed-app`、`$HOME/master/knowbase-app` 两行。这份文件在 `toolboxes` 仓里受版本管理。所有者 2026-10-15 已在远程机提交推送（`toolboxes` `e8f584e`，只改这两行）。**本地机的 `toolboxes` 由所有者自己拉，Qwen 不提交、不拉、不还原 `toolboxes`**；R3 脚本两种状态都认（还是旧名就改这两行，已是新名就跳过），所以所有者在 Qwen 跑 R3 之前或之后拉都行——之后拉的话先还原这两行再拉（`git -C ~/toolboxes checkout -- Vlinux/utils/set-up-tools/model-switch/repos.conf`）。Qwen 在 R4 只核对上面那条 `grep`。`~/five-repos-sync/config.sh` 不在 Git 里，各机一份。

`~/switch-test/human-*.sh` 是转发器，不用改；它转发到的 k8s 仓里那两份已在 R1 改好。

两台机器都改完、Opus 核过远程机之后，改名窗口结束：Qwen 跑一次 `WS=qwen bash ~/switch-test/human-local.sh`，要能正常走完（不报找不到仓），本地 qwen 工位的 `investment-app`、`runtime`、`tpl-app`、`k8s` 也随之拉到 R1 的提交。

**停点**：Opus、Qwen 各写回执（Qwen 的含同步脚本最后一句），Opus 写「通过」。
**状态**：**通过** · 2026-10-15 · Opus。远程机 `R4-opus.20261015-1425.md`、本地机 `R4-qwen.20261015-1439.md`：两台机器 `config.sh` 改法相同，`repos.conf` 为新名（`toolboxes` `e8f584e`），`WS=qwen bash ~/switch-test/human-local.sh` `exit=0`、六仓两端都认、只有快进，本地 qwen 工位各仓到了 R1 提交。**改名窗口结束**：同步脚本照常使用；其他工位仍冻结到 R6。R5 等 Opus 把命令填好、状态写「可执行」后才开始。

---

## R5 集群切换 — Qwen（本地机）

> **状态写「可执行」之前不得开始。** 所有者 2026-10-15 定现有数据都不要：不备份、不改库名、不搬桶，knowfeed、knowbase 按新名从空的开始；investment、tpl 的数据不动。R5 期间 Opus 不往 k8s 推任何东西（回执直接 `git push`，不用先拉；被拒就停）。
>
> 命令块都在 **bash** 里跑（先敲 `bash` 进去再贴，规矩 9）；任何一步 `exit` 不是 0 就停在那一步，输出原样进回执，不重试、不退回。

**这一轮动什么**（Opus 2026-10-15 核过）：
- 四个应用都改钉到 R1 的提交（tpl 也要：R1 改了它的跨应用配置与后端配置）。除改名外只多带了两样已审过的东西：0014 U2「按令牌所属组织把关两个入口」（investment 现网早已有，`WEB_CASDOOR_ORGANIZATIONS` 由共用身份模板给全部应用）与 knowbase 的 Olist 样例数据集代码（只是定义与脚本，不跑）。
- 沙箱镜像与沙箱供给器重建：MCP 服务名 `sunmoon_knowbase`、环境变量 `KNOWBASE_MCP_URL` / `KNOWBASE_MCP_TOKEN` 两边要一起换。会合点不动。
- 重新 stage 的共享组件：traefik（内部访问的键 `knowbase`）、elk 日志采集（应用名单）、沙箱供给器。
- 宿主入口 HAProxy 按新域名分流（`entry-deploy`）；Windows hosts 加四个新域名。
- **旧对象不会被自动删**：Flux 根与各阶段都是 `prune: false`。晋级后旧应用的 Deployment / Job / Secret 照常留在集群里继续跑（这正是退路），旧阶段 `info-*` / `knowledge-*` 的 Flux Kustomization 因路径不在了会显示失败——**属预期，R5 不碰**，R6 按清单删。

### R5.0 前提（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1 && git status --short | head -3
for d in knowfeed-app knowfeed-app/knowfeed-backend knowfeed-app/knowfeed-web-frontend knowfeed-app/knowfeed-admin-frontend \
         knowbase-app knowbase-app/knowbase-backend knowbase-app/knowbase-web-frontend knowbase-app/knowbase-admin-frontend \
         investment-app investment-app/investment-backend investment-app/investment-web-frontend investment-app/investment-admin-frontend \
         tpl-app tpl-app/tpl-backend tpl-app/tpl-web-frontend tpl-app/tpl-admin-frontend; do
  printf '%-42s %s\n' "$d" "$(git -C ~/worktrees/qwen/$d rev-parse HEAD)"; done
make -C infrastructure platform-status; echo "exit=$?"
systemctl cat sunmoon-platform.target | grep -E '^(Requires|Wants)='
grep -n "sunmoonai" /mnt/c/Windows/System32/drivers/etc/hosts
df -h / | tail -1
```

> 磁盘：`df -h /` 看的是 WSL 根，构建前的守卫看的是 **Windows C 盘**（`infrastructure/host/README.md`「容量如何计算」，扣掉数据盘长到 230 GiB 上限的余量后要留 10 GiB）。2026-10-15 第一次构建就在这里被拦（`R5.1-qwen.20261015-1557.md`），所有者清出空间后通过。以后照此前提，先用 `make -C infrastructure preflight` 或构建本身的守卫看 C 盘。

要看到：k8s 干净、含本节；十六个提交号等于 R5.1 第 1 步脚本里的值（R1 提交）；`platform-status` 0；`sunmoon-platform.target` 那一行是 **`Wants=`**（是 `Requires=` 就停——那时单独停入口会把 Harbor 和集群一起停掉，见 `infrastructure/entry/README.md`）；Windows hosts 里含 `info.sunmoonai.com`、含 `knowledge.sunmoonai.com` 的有效行**各恰好一行**（不是就停，把这几行贴进回执）。

### R5.1 改钉、构建、暂存、渲染比对

**1. 改钉**（四个应用各七行）：

```bash
cd ~/worktrees/qwen/k8s
python3 - <<'PY'
import re, pathlib
pins = {
  "tpl":        ["af00d65906a993dbaa7166b54ff9133b2ceab45b", "3c3d252be417a52b2e2bfb0a3cb09e68c6d1cb0f", "3b83285eeac599af5779276d2de7ba3bed3d4364", "8f8338e8685bd4d0b1bc17d472687b7d2e630045"],
  "knowfeed":   ["1fd9da0f3d8fa23255eca669abe8d34afce69a3b", "ecce5c797d69565c1d24b903d4d4d61615e99a63", "327c5260af227aed664ae8cfca7a5f9a08a093d4", "3f01f34bb308c2c7d200d2ffa18847386490c3d2"],
  "knowbase":   ["ba6c77cdd2e8da59e60fa97ddc72d93d99ff8d21", "1d8fa105cf4469df507c50664ba4c2ead37cac1a", "3fd93126052b6519b9a34c4e956b9784852b1499", "1ae7ed73d576290558a31a0d20ec28eb57125b54"],
  "investment": ["eb1f80074c1a3d15b24018c002edd9812d0e34c8", "a6e6ceb2c0c70204ec11295fa9088e5eb53701ac", "0dd55a564615a29c43e394890b427c0886352f8c", "c3c1e1d0524816df006acf250d8767282d8d8ac7"],
}
p = pathlib.Path("infrastructure/applications/sources.yaml"); s = p.read_text()
for app, (parent, backend, web, admin) in pins.items():
    m = re.search(rf"(?m)^  {app}:\n(?:(?!^  \S).*\n?)*", s); assert m, app
    block = new = m.group(0)
    for field, value in [("parent_revision", parent), ("backend_parent_revision", backend), ("backend_revision", backend),
                         ("web_parent_revision", web), ("web_revision", web), ("admin_parent_revision", admin), ("admin_revision", admin)]:
        new, n = re.subn(rf"(?m)^(    {field}: )\w+", rf"\g<1>{value}", new); assert n == 1, (app, field, n)
    s = s.replace(block, new, 1)
p.write_text(s)
PY
echo "第 1 步 python exit=$?"
git diff --stat infrastructure/applications/sources.yaml
```

要看到：`第 1 步 python exit=0`（不是 0 就停：末行的 `git diff` 会把整段的退出码盖成 0，以这一行为准）；只动 `sources.yaml`，28 行（tpl、knowfeed、knowbase、investment 各 7 行）。

**2. 沙箱与供给器改钉到 R1 的 k8s 提交**（会合点不动）：

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("infrastructure/applications/component-images.yaml"); s = p.read_text()
R1 = "c5905fe2e8ab16a0bc2deddd57bd3fee30907578"
for name in ("sandbox-provisioner", "sandbox"):
    m = re.search(rf"(?m)^  {name}:\n(?:(?!^  \S).*\n?)*", s); assert m, name
    block = m.group(0); new, n = re.subn(r"(?m)^(    revision: )\w+", rf"\g<1>{R1}", block); assert n == 1, (name, n)
    s = s.replace(block, new, 1)
p.write_text(s)
PY
echo "第 2 步 python exit=$?"
git diff infrastructure/applications/component-images.yaml | grep '^[-+] ' ; git merge-base --is-ancestor c5905fe2 HEAD && echo "HEAD 是 R1 的后代"
```

要看到：`第 2 步 python exit=0`；只有 `sandbox-provisioner`、`sandbox` 两行 `revision` 变；`relay` 与顶层 `revision` 不变。

**3. 构建**（六个对象；时间长，挨个来，哪个不是 0 就停）：

```bash
for o in app-platform/tpl-app app-platform/knowfeed-app app-platform/knowbase-app app-platform/investment-app sandbox-platform/sandbox sandbox-platform/provisioner; do
  echo "===== build $o"; make -C infrastructure platform-build OBJECT=$o 2>&1 | tail -n 12; rc=${PIPESTATUS[0]}; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
for f in $(git diff --name-only gitops | grep image.lock); do echo "$f: $(grep -E '^source_revision' $f)"; done
```

要看到：六个都是 `exit=0`；变了的镜像锁 14 个——四个应用各后端、网页、管理端（`source_revision` 等于第 1 步对应的提交）、沙箱与供给器（`source_revision` = `c5905fe2…`）。

**4. 暂存**（先排齐拓扑，再逐个 stage 七个对象）：

> 2026-10-15 第二次执行停在这里（`R5.1-qwen.20261015-1641.md`）：逐个对象 stage 时，阶段图里带着各阶段的镜像摘要，四个应用与供给器都换了镜像，只选一个对象时其余变了的阶段落在「未选中」里，拓扑守卫（`infrastructure/components/topology.yaml`「Require unselected stage declarations to remain unchanged」）拦下。第三次改成 `OBJECT=all`，停在 ragflow（`R5.1-qwen.20261015-1704.md`）：`infrastructure/components/stages.py` 按目录字母序排 prepare，`data-platform/ragflow` 排在 `data-platform/valkey` 前面，ragflow 要用的 `valkey_credentials` 还没备好——ragflow 自 10-05 换渲染器后从没重新 stage 过，这是既有隐患，与改名无关（记在「冻结解除之后」第 5 条）；而且 `OBJECT=all` 会把本轮不动的组件都重新渲一遍，超出范围。
>
> 现在的做法：拓扑图（`gitops/clusters/kind/stages.yaml`）只由各 `stage.yaml`、配置和镜像锁算出，不看各组件 stage 出来的文件，与选了哪个对象无关；守卫比的是**工作区里的** `stages.yaml`。所以先 `topology-stage OBJECT=all` 单独把拓扑排齐（它不跑任何组件的 prepare），之后逐个 stage 七个对象时「未选中」部分就与工作区一致，守卫通过。上两次留下的产物（tpl 的 7 个声明、`/etc/sunmoon/applications/sunmoon-kind/` 下新建的 `knowfeed`、`knowbase`）不用清：前者会被覆盖，后者是这次要用的私有输入，会被原样读回。
>
> traefik 的 prepare 读 `infrastructure/.build/components/chart-source.yaml`（固定图表的来源与摘要），它由 `services-chart` 生成；`.build` 不进 Git，R3 按新名重新检出后就没了，所以第四次执行停在 traefik（`R5.1-qwen.20261015-1726.md`）。`services-tools` 从本地物料装好工作区自己的 `helm` 并核字节，`services-chart` 用只读身份从 Harbor 拉回已发布的 traefik 图表、核哈希后写出这个文件——**不连外网**，Harbor 里已有该版本时不推送。两条都不碰集群。
>
> traefik 的内部访问证书（`service-access`，给 investment、沙箱经 `https://knowbase-tls…` 访问 knowbase 用）是 10-04 签的，SAN 是 `casdoor-tls`、`knowledge-tls`。签发任务（`infrastructure/components/tasks/tls-identity.yaml`）只在证书不存在时签，主机名变了不会自动重签，于是第五次执行停在「Verify all certificate hostnames」（`R5.1-qwen.20261015-1735.md`）——这是 R1 漏掉的一处。`docs/rename-tools/r5_reissue_service_access_tls.sh` 做这次显式重签：沿用原私钥，按任务里同样的参数重出 CSR、用平台 CA 重签，SAN 换成 `casdoor-tls`、`knowbase-tls`；私有目录与备份两份一起换，旧证书改名留在原处；已含新名就什么都不做。之后 traefik 的 stage 会读到新证书，只对它重新加密。其余用这个任务的证书都不受改名影响（knowfeed、knowbase 的是这次新建的）。

```bash
make -C infrastructure services-tools; echo "tools exit=$?"
make -C infrastructure services-chart; echo "chart exit=$?"; ls -l infrastructure/.build/components/chart-source.yaml
sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- bash docs/rename-tools/r5_reissue_service_access_tls.sh; echo "tls exit=$?"
make -C infrastructure topology-stage OBJECT=all; echo "topology exit=$?"
for o in app-platform/tpl-app app-platform/knowfeed-app app-platform/knowbase-app app-platform/investment-app sandbox-platform/provisioner ingress-platform/traefik data-platform/elk/collector; do
  echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
done
git status --short gitops | awk '{print $2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\1#' | sort | uniq -c
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
ls gitops/components/app-platform/knowfeed-app/knowfeed-backend/database/ gitops/components/app-platform/knowbase-app/knowbase-backend/database/
sudo ls /etc/sunmoon/applications/sunmoon-kind/
for a in tpl knowfeed knowbase investment; do
  echo "===== plan $a"; make -C infrastructure application-deployment-plan APP=$a 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
done
```

要看到：`tools`、`chart`、`tls`、`topology` 都是 `exit=0`（`tls` 那段新证书的 SAN 是 `casdoor-tls`、`knowbase-tls`）、七个 stage 都是 `exit=0`；改动的组件目录只在这几处：四个应用、`sandbox-platform/provisioner`、`sandbox-platform/sandbox`（镜像锁）、`ingress-platform/traefik`、`data-platform/elk`、`clusters/kind`（别处也有改动不必停，照贴，第 5 步的比对会逐个对象列出来）；没有 PEM；knowfeed、knowbase 的 `database/` 下重新有了 `bootstrap.sops.yaml`、`runtime.sops.yaml`（按新名全新生成）；私有目录多出 `knowfeed`、`knowbase` 两个（旧的 `info`、`knowledge` 还在，不动）；计划：knowfeed 核到 `20261015_0014`、迁移 Job 结尾 `-v3`，knowbase 核到 `20260927_0007`，investment 核到 `20261012_0018`，tpl 核到 `20260911_0003`。

**5. 渲染比对**（改名前的渲染产物 vs 这次 stage 的，逐个 k8s 对象）：

```bash
T=$(date +%Y%m%d-%H%M)
infrastructure/.venv/bin/python docs/rename-tools/r5_render_diff.py 4be661df > docs/rename-receipts/R5.1-render-diff.$T.txt; echo "exit=$?"
sed -n '/^== 1/,/^== 3/p' docs/rename-receipts/R5.1-render-diff.$T.txt
```

要看到：第 1 节「不可变 Job」**0 条**（有一条就停：Flux 套用时会被拒）。报告整份随回执提交，Opus 逐条审第 3–6 节。

> 2026-10-15 第六次执行：重签脚本没跑起来（`tls exit=127`，`R5.1-qwen.20261015-1748.md`）——`nsenter --mount` 进去后工作目录是 `/`，Opus 漏了 `--wd`（`infrastructure/Makefile` 与 R6 的写法都带着），已补；证书未动。**第七次照下面第五次那段的续跑块重跑**（命令已带 `--wd`）。
> 2026-10-15 第五次执行：`tools`、`chart` 都过，停在 traefik 的证书主机名核对（见第 4 步说明）。**第六次只续跑这几条**（`services-tools`、`services-chart` 已做过，前五个对象不重来）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- bash docs/rename-tools/r5_reissue_service_access_tls.sh; echo "tls exit=$?"
> for o in ingress-platform/traefik data-platform/elk/collector; do
>   echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
> done
> ```
>
> 要看到：`tls exit=0`，「新证书」的 SAN 是 `casdoor-tls…`、`knowbase-tls…`；两个 stage 都是 0。再照跑第 4 步块里 `done` 之后的核对与四个计划，然后做第 5 步。
> 2026-10-15 第四次执行：拓扑与前五个对象（四个应用、供给器）都 `exit=0`，停在 traefik（缺 `chart-source.yaml`，见第 4 步说明）。**第五次只续跑剩下的**（前五个不重来，产物都在工作区）：
>
> ```bash
> cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
> make -C infrastructure services-tools; echo "tools exit=$?"
> make -C infrastructure services-chart; echo "chart exit=$?"; ls -l infrastructure/.build/components/chart-source.yaml
> for o in ingress-platform/traefik data-platform/elk/collector; do
>   echo "===== stage $o"; make -C infrastructure platform-stage OBJECT=$o; rc=$?; echo "exit=$rc"; [ "$rc" = 0 ] || break
> done
> ```
>
> 再照跑第 4 步块里 `done` 之后的核对与四个计划，然后做第 5 步。
> 2026-10-15 第三次执行：停在第 4 步的 ragflow（见第 4 步说明），已改为先排齐拓扑再逐个 stage，从第 4 步续跑，第 1–3 步不重来。
> 2026-10-15 第二次执行：第 1–3 步通过（14 个镜像锁正确），停在第 4 步，已改为整套 stage，从第 4 步续跑。
> 2026-10-15 第一次执行停在第 1 步（`R5.1-qwen.20261015-1531.md`）：块正则带了 `s`（dotall），第一个块吞掉了全部四个应用，`assert` 拦住、文件未改。已改为 `(?m)`，第 1、2 步在 `sources.yaml`、`component-images.yaml` 的副本上实跑核过（28 行、两行，各应用各自的提交）。从第 1 步重跑。

**停点**：**不提交 stage 结果**（工作区保持原样，R5.2 再提交）。回执 `R5.1-qwen.<时间>.md`（R5.0 与 1–5 步的输出）连同比对报告只把这两个文件提交、直接推：`git add docs/rename-receipts/R5.1-* && git -c core.editor=true commit -m "rename: R5.1 回执（Qwen）" && git push origin qwen`。Opus 审过在本节写「R5.1 通过」才做 R5.2。

**R5.1 通过** · 2026-10-15 · Opus（`R5.1-qwen.20261015-1800.md`、`R5.1-render-diff.20261015-1758.txt`）。逐条审过：第 1 节不可变 Job 0 条；只在旧 / 只在新各 2 条是 knowfeed 迁移校验 ConfigMap 与迁移 Job 从 `-v2` 换到 `-v3`（新名新 Job，不撞旧的）；31 处差异全是改名带来的——`APP_SLUG`、`AUTH_APP`、`part-of`、跨应用键、数据库引导 SQL 的库名与归属注释、Redis/RabbitMQ 的记号与探针名、Casdoor 应用说明、日志采集路径——加上随镜像变的 `DEPLOYMENT_ID`；迁移 Job 的 `DEPLOYMENT_ID` 等于 R1 提交，改钉生效。两处核过：knowbase 读 `knowfeed-originals` 的 `knowfeed/` 前缀，与 knowfeed 后端写入的 `knowfeed/original/…` 一致；`INGESTION_DATASET_BINDINGS` 换成新数据集 `sunmoon-kind-knowbase-default`（stage 时 knowbase provider 的 prepare 已在 RAGFlow 里建好，旧数据集 R6 删）。共享组件里改了名、R5.2 后会留在集群里的 3 个对象（`knowledge-tls`、`knowledge-service-access`、`investment-knowledge-service`）已列入 R6。可以做 R5.2。

### R5.2 hosts、提交、发布、晋级、入口、检查

**0. 拉到最新**（Opus 审 R5.1 时可能推了修正；工作区里 stage 的结果不动，只快进）：

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -3 && git status --short | wc -l
```

要看到：快进成功（不能快进就停，贴输出）；`git status` 仍是 R5.1 留下的那些改动。

**0.5 补工作区工具**（`.tools` 不进 Git，R3 重新检出后可能缺——R5.1 就缺过 `helm`。`flux-release` 要 `flux`，`entry-deploy` 要 `docker-compose`，检查要 `mc`；两条都从本地物料装、核字节、不连外网，已装好的照样核一遍）：

```bash
ls infrastructure/.tools/bin/
make -C infrastructure install-flux; echo "flux exit=$?"
make -C infrastructure install-binaries BINARIES=kubectl,compose,mc; echo "binaries exit=$?"
ls infrastructure/.tools/bin/
```

要看到：两个 `exit=0`；`.tools/bin/` 里有 `flux`、`kubectl`、`docker-compose`、`mc`。

**1. Windows hosts**（四个新域名跟旧名同一行；会弹一次 UAC，请所有者点「是」）：

```bash
cp docs/rename-tools/r5_windows_hosts.ps1 /mnt/c/Users/zymun/rename-hosts.ps1
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zymun\rename-hosts.ps1'"
cat "/mnt/c/Users/zymun/AppData/Local/Temp/rename-hosts-result.txt"
```

要看到：第一行 `OK backup …`，`active sunmoonai lines now:` 下面四个新名字都在、旧名字还在。是 `STOP:` 就停。

**2. 提交、发布、晋级**：

```bash
git add infrastructure/applications/sources.yaml infrastructure/applications/component-images.yaml gitops
git -c core.editor=true commit -m "deploy: 改名上线——knowfeed、knowbase 新名从空的开始，investment、tpl 改钉，沙箱与供给器重建（0025 R5）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（0025 R5）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
```

**3. 等新阶段就绪、看旧阶段**：

```bash
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations -o name | grep -E '/(knowfeed|knowbase)-' | xargs $K -n flux-system wait --for=condition=Ready --timeout=40m; echo "exit=$?"
$K -n flux-system get kustomizations | grep -E '^(knowfeed|knowbase|investment|tpl|sandbox|traefik|elk)'
$K -n flux-system get kustomizations | grep -E '^(info|knowledge)-'     # 预期失败（路径不在了），不碰
$K -n app-platform-dev get pods | grep -E '^(knowfeed|knowbase|investment)-' | head -30
```

**4. 应用检查**：

```bash
for a in tpl knowfeed knowbase investment; do echo "===== check $a"; make -C infrastructure application-check APP=$a; echo "exit=$?"; done
```

**5. 宿主入口**（会断一下所有经入口的访问，含 Harbor——构建已在前面做完）：

```bash
make -C infrastructure entry-plan 2>&1 | grep -E "knowfeed|knowbase|info\.|knowledge\." | head
make -C infrastructure entry-preview; echo "exit=$?"
make -C infrastructure entry-stop; echo "exit=$?"
make -C infrastructure entry-deploy; echo "exit=$?"
make -C infrastructure entry-status; echo "exit=$?"
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：计划里出现四个新域名、不再有 `info.` / `knowledge.`；四个 `exit=0`；`platform-status` 0（Harbor、集群都在）。

**停点**：回执 `R5.2-qwen.<时间>.md`（各步输出；旧阶段那几行照贴），提交推送同上，Opus 审过写「R5.2 通过」。

**R5.2 通过** · 2026-10-15 · Opus（`R5.2-qwen.20261015-1833.md`）。上线提交 `82dc36b3`（83 个文件，只在四个应用、沙箱与供给器、traefik 内部访问、elk 采集、`clusters/kind` 与两个钉文件里，无私钥）→ 发布 `sha256:55b6c265…` → 晋级 `78dca771`；新阶段全 Ready，旧 `info-*`、`knowledge-*` 19 个阶段如预期显示失败；四个 `application-check` 与 `platform-status` 都是 0；入口只剩新域名。可以做 R5.3。

### R5.3 验证（浏览器，Qwen 做；截图只截页面，不截令牌与口令）

1. `https://knowfeed-admin.sunmoonai.com:30443`：能登录（admin），进得去「采集」「证券」「需求」等页面（空的属正常）。
2. `https://knowbase-admin.sunmoonai.com:30443`：能登录，「数据集登记」「数据目录」页面打开（空的属正常）。
3. `https://knowfeed.sunmoonai.com:30443`、`https://knowbase.sunmoonai.com:30443`：首页打开、能登录。
4. investment 管理端「缺数据的需求」页：发起采集的链接指向 `knowfeed-admin.sunmoonai.com`。
5. investment 工作台开一个新对话，让模型「列出能用的数据集」：工具调用显示 `sunmoon_knowbase`（没有数据集，回答「没有」属正常）。然后看沙箱用的是新镜像：

```bash
$K -n sandbox-platform-dev get deploy -l app=sandbox -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}'
grep -E '^digest' gitops/components/sandbox-platform/sandbox/image.lock.yaml
$K -n sandbox-platform-dev get deploy -l app=sandbox -o yaml | grep -E 'name: (KNOWBASE|KNOWLEDGE)_MCP' | sort -u
```

   要看到：**刚才开对话的那个用户**的沙箱（`sandbox-u-<该用户>`）镜像摘要等于锁里的、环境变量是 `KNOWBASE_MCP_*`（没有 `KNOWLEDGE_MCP_*`）。其他用户的沙箱还是旧镜像、旧变量属正常：供给器只在该用户点「设置 → 云端与模型 → 拉起 / 更新沙箱」时整份替换他的沙箱（investment 后端 `provisioning.py` → 供给器 `PUT /sandboxes/<用户>`），开工作台、开对话都不会换，也不批量升级；照贴即可，不必停。

**停点**：回执 `R5.3-qwen.<时间>.md`，Opus 审过写「R5 通过」，再做 R6。

**R5.3 通过** · 2026-10-16 · Opus（`R5.3-qwen.20261016-1006.md`）。第 1、2、4 项：admin 登录、治理控制台正常；三个管理端的业务页（采集 / 证券 / 需求、数据集登记 / 数据目录、缺数据的需求）按应用角色 `admin`/`operator` 显示，而部署从没配 `ADMIN_AUTH_ROLE_ALLOWLIST`、Casdoor 也没给 admin 角色，改名前 `4be661df` 即如此，不是改名回归，未核（补法记入「冻结解除之后」第 6 条）；子代理那几个 403/404 是它猜地址撞的。第 3 项两个网页端登录后进 dashboard。第 5 项：所有者点「更新沙箱」后，`sandbox-u-5cdfe57e345f` generation 6→7、镜像 `sha256:8fac3fdf…` 与 `image.lock.yaml` 相同、变量只有 `KNOWBASE_MCP_TOKEN`/`KNOWBASE_MCP_URL`（供给器配置指向 `knowbase-api`），供给器日志有那次 `PUT`；`list_datasets` 返回空——新 knowbase 从空库开始，属预期。回执里「更新前一轮返回 knowbase 2 个数据集」要更正：那一轮走的是未更新的旧沙箱（`KNOWLEDGE_MCP_*`），`olist-ecommerce`、`sh600009-financials` 是旧 knowledge 库里的登记，前后对照正好说明切换生效。另一用户的 `sandbox-u-f1cee6277692` 仍是旧镜像旧变量，见 R6 开头。子代理往密码框打进指令残文、未提交一事已照实记，此后登录一律所有者手动。**R5 通过。**

**回退**（R5.2 或 R5.3 不过时，由 Opus 写具体命令后再做，Qwen 不自行回退）：旧应用的对象一直在跑、旧库旧桶旧 Casdoor 应用都没动，所以回退是：把 `infrastructure/environments/kind/flux-source.yaml` 退回上一次晋级的提交再 `flux-source-apply`（旧阶段回来、接上还在跑的旧对象），入口按上一次的配置重新 `entry-deploy`，Windows hosts 用 `hosts.bak-rename-*` 还原。

**状态**：**通过** · 2026-10-16 · Opus。R5.1、R5.2、R5.3 各自审过（见上面三条「通过」）。可以做 R6。

---

## R6 下线旧对象 — Qwen（本地机）

只在 R5 写了「通过」之后做（所有者 2026-10-15 定旧的不必备份）。删完就没有退路了（R5 的回退靠的正是这些旧对象），所以 R5.3 浏览器验证过了才做。

**旧沙箱**：`sandbox-u-f1cee6277692` 还是旧镜像、`KNOWLEDGE_MCP_URL` 指向旧 `knowledge-api`。所有者 2026-10-17 查 investment 库：它属于 `admin`（built-in 组织），10-06 网页端按组织把关之前拉起的；admin 现在登不进网页端，没人用、也没人能点「更新沙箱」。它不带旧阶段标签，R6 不动它，`knowledge-api` 删掉后它连不上也不影响任何人；回收见「冻结解除之后」第 7 条。（`sig-am` 的 `sandbox-u-5cdfe57e345f` 已在 R5.3 换新。）

工具 `docs/rename-tools/r6_cleanup.py`：清单是写死的旧名字（Opus 2026-10-15 从改名前的配置 `4be661df` 逐个抄出），默认只列不删；删一次只删一类，要 `--confirm <类>`；每类删前先核归属记号（PostgreSQL 的注释 `sunmoon-kind/info`、RabbitMQ vhost 的说明、Casdoor 服务应用的说明与 clientId、k8s 对象的旧阶段标签），对不上整类不删；列出来但不在清单里的标 `?? 不在清单，不删`，交 Opus 看。不打印口令、令牌、哈希。

| 类（工具里的名字） | 删什么 | 怎么删 |
| --- | --- | --- |
| `k8s` | 旧阶段的 Flux Kustomization（`info-*` 10 个、`knowledge-*` 9 个，R5.2 后显示失败）与它们留下的对象 | 先删 Kustomization（各阶段 `deletionPolicy: Orphan`，对象留下），再按标签 `kustomize.toolkit.fluxcd.io/name` 删对象（先 Deployment/Job，后其余），等旧 Pod 退净。另点名删共享组件阶段里改了名的 3 个：traefik 的 Service `knowledge-tls`、Ingress `knowledge-service-access`，investment-runtime 的 Secret `investment-knowledge-service`（现行声明里已没有这个名字、标签是预期阶段才删）。没带旧标签、名字以 `info-`/`knowledge-` 开头的其余对象只列不删 |
| `job-history` | （所有者 2026-10-15 要求顺带清）`app-platform-dev`、`data-platform-dev`、`messaging-platform-dev` 里**已完成、且现行声明里已没有**的历史 Job（investment、tpl 等每次发布留下的旧摘要 Job，连同它们的已完成 Pod） | 现行 `gitops/components/**/workload.yaml` 里声明的 Job 一个不删（Flux 会重建并重跑，阶段健康检查与 `application-check` 也看它们）；没完成的只列不删 |
| `postgresql` | 库 `info`、`knowledge`；角色 `info_runtime`、`info_migrator`、`knowledge_runtime`、`knowledge_migrator` | `DROP DATABASE … WITH (FORCE)`、`DROP ROLE` |
| `redis` | 用户 `info_runtime`、`knowledge_runtime` 与键 `info:*`、`knowledge:*` | 扫描后 `UNLINK`、`ACL DELUSER`、`ACL SAVE` |
| `rabbitmq` | vhost `info`、`knowledge`（连同队列 `*.default`）与用户 `info_runtime`、`knowledge_runtime` | `rabbitmqctl delete_vhost / delete_user` |
| `object-storage` | 桶 `info-originals`（全部版本）；用户 `info_storage`、`knowledge_source_reader`；策略 `info-originals`、`knowledge-source-read` | 宿主 `mc` 经 port-forward（同 `object-storage/verify.py`） |
| `ragflow` | 数据集 `sunmoon-kind-knowledge-default` | RAGFlow 官方 API（在 `ragflow-api` 里跑，同 knowbase provider 的 prepare） |
| `casdoor` | 应用 `sunmoonai-info-web/admin`、`sunmoonai-knowledge-web/admin`、服务身份 `sunmoonai-info-knowledge-ingest`、`sunmoonai-investment-knowledge-retrieve`；组织 `sunmoon-workload-info-knowledge`、`sunmoon-workload-investment-knowledge`（里面不能有用户） | Casdoor 管理 API |
| `private` | 私有目录 `/etc/sunmoon/applications/sunmoon-kind/{info,knowledge}`、备份 `/mnt/sunmoon-data/backups/applications/sunmoon-kind/{info,knowledge}`、构建候选 `infrastructure/.build/components/app-platform/{info,knowledge}-app` | 删目录 |
| `harbor` | `platform` 项目里的 `info-backend`、`info-web-frontend`、`info-admin-frontend`、`knowledge-*` 三个仓库 | Harbor API；必须在 `k8s` 之后（否则还在跑的旧对象拉不到镜像） |
| `harbor-gc` | 上一步删掉的镜像层 | 手动触发一次垃圾回收，`delete_untagged=false`（investment、tpl 等按摘要部署、多半没有标签，不能顺手清掉），前后报 `/data/harbor/platform-kind-v1` 占用。investment、tpl、沙箱、供给器的旧版本是它们的回退版本，不在范围，等所有者定 Harbor 保留策略再说（所有者 2026-10-15 定） |
| Windows hosts | 旧域名 `info.`、`info-admin.`、`knowledge.`、`knowledge-admin.sunmoonai.com` | `docs/rename-tools/r6_windows_hosts.ps1`：只从有效行里去掉这四个名字，且要求同一行已有对应新名字，否则不改；先备份 |

不在 R6 里：两台机器的 `~/rename-backup/`（「冻结解除之后」第 3 条：保留，删除另行决定）；ELK 里旧应用的历史日志（按时间滚动，不按应用分）。

### R6.1 列清单（只读）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen && git log --oneline -1
R6='sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- infrastructure/.venv/bin/python docs/rename-tools/r6_cleanup.py'
T=$(date +%Y%m%d-%H%M); $R6 list > docs/rename-receipts/R6.1-list.$T.txt 2>&1; echo "exit=$?"
grep -E "^=====|\?\?" docs/rename-receipts/R6.1-list.$T.txt
```

要看到：`exit=0`（哪一类 `STOP` 就停，原样进回执）。清单整份随回执提交：`git add docs/rename-receipts/R6.1-* && git -c core.editor=true commit -m "rename: R6.1 清单（Qwen）" && git push origin qwen`。**停点**：Opus 逐类审（尤其 `??` 那几行），写「R6.1 通过」才删。

### R6.2 删（按顺序，一类一类）

```bash
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen
R6='sudo -n nsenter --target 1 --mount --wd=/home/zymun/worktrees/qwen/k8s -- infrastructure/.venv/bin/python docs/rename-tools/r6_cleanup.py'
T=$(date +%Y%m%d-%H%M)
for c in k8s job-history postgresql redis rabbitmq object-storage ragflow casdoor private harbor harbor-gc; do
  $R6 delete $c --confirm $c 2>&1 | tee -a docs/rename-receipts/R6.2-delete.$T.txt; rc=${PIPESTATUS[0]}; echo "== $c exit=$rc"; [ "$rc" = 0 ] || break
done
```

要看到：十一个 `exit=0`；每类「删后」里清单内的项都没了（`??` 项原样还在）。任何一类不是 0 就停，后面的不做。

**Windows hosts**（先在副本上演练，再真改；真改会弹一次 UAC，请所有者点「是」）：

```bash
cp docs/rename-tools/r6_windows_hosts.ps1 /mnt/c/Users/zymun/rename-hosts-r6.ps1
cp /mnt/c/Windows/System32/drivers/etc/hosts /mnt/c/Users/zymun/hosts-r6-rehearsal
powershell.exe -NoProfile -Command '$env:RENAME_HOSTS_FILE="C:\Users\zymun\hosts-r6-rehearsal"; $env:RENAME_HOSTS_OUT="C:\Users\zymun\hosts-r6-rehearsal.txt"; powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\zymun\rename-hosts-r6.ps1; "exit=$LASTEXITCODE"'
cat /mnt/c/Users/zymun/hosts-r6-rehearsal.txt; diff /mnt/c/Windows/System32/drivers/etc/hosts /mnt/c/Users/zymun/hosts-r6-rehearsal
powershell.exe -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\Users\zymun\rename-hosts-r6.ps1'"
cat "/mnt/c/Users/zymun/AppData/Local/Temp/rename-hosts-r6-result.txt"
rm /mnt/c/Users/zymun/hosts-r6-rehearsal /mnt/c/Users/zymun/hosts-r6-rehearsal.bak-r6-* /mnt/c/Users/zymun/hosts-r6-rehearsal.txt
```

要看到：演练 `exit=0`，`diff` 只有那一行少了四个旧名字；真改第一行 `OK backup …`，新名字都在、旧名字没了。是 `STOP:` 就停。

**删后核对**（新应用不受影响）：

```bash
$R6 list 2>&1 | tee docs/rename-receipts/R6.2-after.$T.txt | grep -E "^=====|\?\?|exit="
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n flux-system get kustomizations | grep -v True     # 只剩表头
for a in tpl knowfeed knowbase investment; do echo "===== check $a"; make -C infrastructure application-check APP=$a; echo "exit=$?"; done
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：清单只剩 R6.1 审过的 `??` 项；没有不 Ready 的 Kustomization；四个 `application-check` 与 `platform-status` 都是 0。

**停点**：回执 `R6.2-qwen.<时间>.md` 连同 `R6.2-*.txt` 提交推送，Opus 审过在本节写「改名完成」，冻结解除，Cursor 恢复接卡（用新名字）。

**状态**：**可执行（R6.1）** · 2026-10-17 · Opus。R5 通过后按现场核过一遍：清单、归属记号、私有文件键名（RAGFlow 仍是 `knowledge_token`）与现行配置一致；RAGFlow 一类只报带旧名的数据集。R6.1 只列不删，交回执后停；R6.2 等 Opus 写「R6.1 通过」。

---

## R7 文档 — Opus

PRD / SDD / 决策 / 总览 / 各仓 `AGENTS.md` 换名；0018 改写为 knowmart（知识市场；吸收《专家市场架构对比分析和借鉴》第二、五、七节）；`docs/竞品比较分析.md`、`docs/专家市场架构对比分析和借鉴.md` 里的应用名换新；历史回执与冻结原件不改。

**状态**：**完成** · 2026-10-15 · Opus。PRD / SDD / 决策 / 总览 / 各仓 `AGENTS.md` 的应用名在 R1 已随内容替换换新；R7 另做：0018 改写为 knowmart（k8s `a4ac8202`），两份讨论稿换名（`17fdb464`），其余 41 份活文档里剩下作应用名的旧名换新（`486b7ce7`，四个应用仓各父仓、子仓同名提交）；历史回执、冻结原件、领域词（如 Knowledge provider、`info.request`）、代码名（wheel `advisor`）与 PRD 文件名不动。

---

## 冻结解除之后（不属于改名，但要有人做）

1. fable 照常把 `qwen` 的改名提交并进 `master`（五组仓都要：knowfeed-app、knowbase-app 及子仓、investment-app、k8s、runtime、tpl-app 里 R1 改过的）。
2. 其他工位（cursor、fable、kimi、luna）各自把 `master` 并进自己的分支，或用 `mb worktree add --from-master <工位> <仓>` 拨回 master——拨回会丢掉该工位相对 master 的提交，用前确认已并进 master。
3. 远程机 `~/rename-backup/` 与本地机同名目录保留，删除另行决定。
4. **把 `k8s/sunmoonai/` 整体移出**（所有者 2026-10-15 定）：它大部分是 10-06 起冻结的旧体系，计划删掉。先把还活着的四块搬出去，再 `git rm` 其余（历史在 Git 里）：
   - `sunmoonai/docs/dev-investment-agent/`（手册、回执、派活卡、同步脚本、门禁工具）→ `k8s/docs/dev-investment-agent/`：连带改 k8s 里 26 个、runtime 里 6 个引用；`.githooks` 的 `doc-gate.py`、`anchor-gate.py` 路径与「只查 `sunmoonai/docs/`」的范围；两台机器的 `~/switch-test/human-*.sh` 转发器（跑一次 `human-local.sh` 自动重新生成）；
   - `sunmoonai/docs/project-guide/` → `k8s/docs/project-guide/`：连带改各仓 `AGENTS.md` 的指针；
   - 所有者 2026-10-15 挑定的通用参考资料原样搬进 `k8s/docs/reference/`：`行业/` ← `docs/ai-tools/mcp-touyan-comparison.md`；`采集与数据/` ← `app-platform/info-app/docs/spider-reference/`（三份）、`app-platform/info-app/docs/仿wind的数据库报表体系设计.md`；`技术笔记/` ← `docs/Celery监控机制说明.md`、`ops-platform/flower/Flower使用文档.md`、`docs/文档转换服务技术栈对比.md`（文首加一句「这两个服务新体系里没有，仅作选型参考」）；`运维笔记/` ← `ingress-platform/traefik/KUBERNETES-PORT-FORWARDING-GUIDE.md`。WSL 三份已改写并入 `infrastructure/host/`，三份原则已吸收进 `rules/constraints.md`（`C-D12`–`C-D15`、`C-C9`–`C-C11`、`C-R10`）与总览，原件随目录删；云上 kubeadm 那几份不搬，到做云端建群时按新体系另写；
   - `sunmoonai/kind-infrastructure/mount/wsl_interop.py`（新体系的开机服务 `sunmoon-wsl-interop.service` 还靠它，源码目前只在这里）**必须**收进 `infrastructure/host/`；同目录的扩盘、备份、压缩脚本（`resize_data.py`、`resize_backup.py`、`system_compaction.py`）评估后决定是否一并收进；
   - `sunmoonai/relay-platform/`、`sunmoonai/sandbox-platform/`（三个自研镜像的源码）→ 新位置：`infrastructure/applications/component-images.yaml` 的 `context` 与钉的提交要一起改，在下一次重建这几个镜像时生效；
   - `sunmoonai/scripts/` 里还在用的（本地联调脚本、发布卡回执目录 `results/`）挑出来搬，其余随目录删；
   - **`k8s/utils/` 整个删**（所有者 2026-10-15 定，Opus 逐项核过：新体系的 `infrastructure/`、`gitops/` 没有引用它，内容全是旧体系的配套——`./sunmoon` 命令行、共享部署函数库、旧密钥与证书生成、旧镜像清单与门禁脚本、SSH 隧道连接工具）。其中 `packages-management` 的脚本与配置在 `toolboxes/Vlinux/utils/packages-management/` 有逐字节相同的备份（只多的 `export-component-image-tars.sh` 依赖旧镜像清单）；`db-provisioner` 各后端各有自己的一份（`<后端>/db-provisioner/`），被引用的是那几份，`utils/` 里这份没人引用；OIDC 接入模板已被 `tpl-app` 取代；没有通用到要留的；
   - 根目录随之删：`sunmoon`（只是转调 `sunmoonai/operations/cli.py`）、`legacy/`（自述「达到退出条件后删除」）、`image-management-design.md`（旧体系镜像管理设计）；`k8s持久化方式及本项目持久化方案设计.md` 先把仍成立、新文档里没有的内容并进 `infrastructure/host/README.md` 与 `gitops/components/foundations/README.md` 再删；根 `README.md`、`AGENTS.md` 里指向 `utils/`、`./sunmoon` 的话改掉。保留 `CHECKPOINT.md`；`scripts/test_switch_test_sync.py` 保留，随 `dev-investment-agent` 搬家改它里面的路径；
   - 冻结的旧体系目录（`app-platform`、`cicd-platform`、`data-platform`、`deploy-sunmoonai-all`、`infrastructure`、`ingress-platform`、`kind-infrastructure`、`messaging-platform`、`operations`、`ops-platform`、`registry-platform`、`CHECKPOINT-old-system-*.md`）直接 `git rm`。
5. **组件 prepare 的先后顺序**（R5.1 第三次执行撞上，`R5.1-qwen.20261015-1704.md`）：`infrastructure/components/stages.py` 收集 prepare 按目录字母序，`render.yaml` 也只跑「选中对象」的 prepare。`data-platform/ragflow` 的 prepare 要用 `data-platform/valkey` 的 prepare 备下的 `valkey_credentials`，所以 `OBJECT=all`（ragflow 排在 valkey 前）与 `OBJECT=data-platform/ragflow`（valkey 根本不跑）都会报 `'valkey_credentials' is undefined`。ragflow 自 10-05 换渲染器后没再 stage 过，一直没暴露。修法二选一，修后用 `OBJECT=data-platform/ragflow` 实跑一次核对：ragflow 的 prepare 自己读 valkey 的私有输入（同 `component-input.yaml`，只读不新建）；或 prepare 按阶段依赖排序并带上依赖对象的 prepare。修之前别跑 `platform-stage OBJECT=all`。
6. **管理端角色**（R5.3 发现，改名前就有）：knowfeed、knowbase、investment 三个管理端的业务页与导航要应用角色 `admin` 或 `operator`（前端 `lib/navigation.ts` 的 `requiredRoles`、页面里的 `requireAnyRole`），角色取自 Casdoor 令牌的 `roles` 并经后端 `ADMIN_AUTH_ROLE_ALLOWLIST` 过滤；现行部署没设这个白名单（空 = 谁都没有角色），Casdoor 里也没给 admin 分配角色，所以 admin 只看得到「治理控制台」「设置」。补法：身份模板给各应用设 `ADMIN_AUTH_ROLE_ALLOWLIST=admin,operator`（网页端 `WEB_AUTH_ROLE_ALLOWLIST` 一并定），Casdoor 里建角色并分给管理员、确认令牌带 `roles`；补完把 R5.3 第 1、2、4 项的业务页（含「缺数据的需求」里发起采集的链接指向 `knowfeed-admin`）补核一遍。
7. **admin 的孤儿沙箱** `sandbox-u-f1cee6277692`（见 R6 开头）：走正路回收，不手删 k8s 对象——investment 后端的回收会同时改库里 `workbench_sandboxes` 的状态、收回令牌，只删 Deployment 会让库里还记着「已拉起」。admin 登不进网页端，所以要么给后端加一个运维入口按用户回收，要么在补管理端角色（第 6 条）时一并定 admin 是否该有工作台；定之前它留着只占一个 Pod。
