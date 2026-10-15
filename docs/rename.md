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
**状态**：

---

## R5 集群切换 — Qwen（本地机）

> **逐条命令由 Opus 在 R1 完成后填入下面各小节。本段状态写成「可执行」之前，不得开始。** 所有者 2026-10-15 定现有数据都不要，所以本段不备份、不改库名、不搬桶，新应用从空的开始。

### R5.1 渲染与渲染比对

`platform-stage` 依次处理 knowfeed、knowbase、investment（以及沙箱镜像，MCP 服务名改了）：新私有目录 `/etc/sunmoon/applications/sunmoon-kind/knowfeed`、`…/knowbase` 与备份目录由 stage 全新生成；渲染出全部新声明 → **渲染比对**：把改名前（R0 时的提交）与 stage 后的渲染产物逐个对象比对，列出除名字以外的差异（比对命令由 Opus 填）。

**停点**：Opus 审比对结果。

### R5.2 构建、发布、晋级

构建新镜像（knowfeed、knowbase 的后端与两个网页，investment 的后端与网页，沙箱镜像）→ 提交 → `flux-release` → 晋级 → `flux-source-apply`。晋级后 Flux 随旧目录消失自动删除旧应用的 k8s 对象；新应用的库初始化、开通（Casdoor 应用与服务身份、桶、vhost、Redis 用户）、迁移任务按新名在空的基础上跑。

**停点**：Opus 审回执（各任务完成、迁移头 = `20261015_0014` / knowbase 现头）。

### R5.3 验证

`application-check APP=knowfeed`、`APP=knowbase`、`APP=investment` → 浏览器打开两个新域名能登录（管理员作用域 `knowfeed:admin` / `knowbase:admin`）→ 投资里跨应用跳转可用、知识检索工具能连上（此时还没有数据集，查不到内容属正常）。

**停点**：Qwen 在浏览器上逐项核对（截图只截页面，不截令牌与口令），Opus 审回执。

回退：R5.2 失败或 R5.3 不过——把 `sources.yaml`、应用名表等回到 R0 的提交重新发布即可回到旧应用；旧库、旧桶、旧 Casdoor 应用都没动过，旧应用起来后数据还在。

**状态**：

---

## R6 下线旧对象 — Qwen（本地机）

只在 R5.3 写了「通过」之后做（所有者 2026-10-15 定旧的不必备份）。命令由 Opus 填；每一类**先列出、再删、再列出核对**，删前删后的清单进回执：

| 类 | 删什么 |
| --- | --- |
| k8s 对象 | 核对旧应用的对象已在 R5.2 被 Flux 删干净；有残留按清单删 |
| PostgreSQL | 库 `info`、`knowledge`；角色 `info_runtime`、`info_migrator`、`knowledge_runtime`、`knowledge_migrator`、`knowledge_source_reader` 等旧角色 |
| 对象存储 | 桶 `info-originals`（含开发环境前缀那个）及其旧用户、旧策略 |
| RabbitMQ、Redis | 旧 vhost `info`、`knowledge` 与旧用户；旧 Redis 用户及其 ACL |
| Casdoor | 旧应用 `sunmoonai-info-web/admin`、`sunmoonai-knowledge-web/admin`，旧服务身份与组织 |
| 秘密 | 旧私有目录 `/etc/sunmoon/applications/sunmoon-kind/info`、`…/knowledge` 与旧备份目录 |
| 镜像 | Harbor 里 `info-*`、`knowledge-*` 镜像仓库 |
| 检出 | 两台机器上 `~/rename-backup/` 下的旧检出（都已推送过） |

**停点**：Opus 审回执，在本节写「改名完成」，冻结解除，Cursor 恢复接卡（用新名字）。
**状态**：

---

## R7 文档 — Opus

PRD / SDD / 决策 / 总览 / 各仓 `AGENTS.md` 换名；0018 改写为 knowmart（知识市场；吸收《专家市场架构对比分析和借鉴》第二、五、七节）；`docs/竞品比较分析.md`、`docs/专家市场架构对比分析和借鉴.md` 里的应用名换新；历史回执与冻结原件不改。

**状态**：

---

## 冻结解除之后（不属于改名，但要有人做）

1. fable 照常把 `qwen` 的改名提交并进 `master`（五组仓都要：knowfeed-app、knowbase-app 及子仓、investment-app、k8s、runtime、tpl-app 里 R1 改过的）。
2. 其他工位（cursor、fable、kimi、luna）各自把 `master` 并进自己的分支，或用 `mb worktree add --from-master <工位> <仓>` 拨回 master——拨回会丢掉该工位相对 master 的提交，用前确认已并进 master。
3. 远程机 `~/rename-backup/` 与本地机同名目录保留，删除另行决定。

