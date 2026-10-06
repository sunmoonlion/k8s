# luna 的分支 `platform-kind-v1`：远程的审阅（2026-10-06）

> 所有者 2026-10-04 说 luna「把整个 k8s 的部署体系改了……变得太大」，让远程先拉过来看。luna 2026-10-06 把工位推到远端（k8s `fb55eced`，四个父仓，十二个子仓）。
> 远程只读：在 `~/worktrees/platform-kind-v1/` 下用 `git worktree` 检出，没有登记进同步布局，没有改一个字，没有拿它部署任何东西。

## 一、它是什么样

| 项 | 看到的 |
| --- | --- |
| 分支的位置 | 从 `master`（`4156a8b0`）开出来，189 个提交（2026-09-30 至 10-06）。和 `fable` 的共同祖先就是 `master`：`fable` 在 `master` 之上有 184 个提交，两边互不包含 |
| 改了多少 | 710 个文件，49205 行新增，**1 行删除**。几乎全是新增 |
| 改在哪 | 新目录 `gitops/`（549 个文件，Flux 声明、SOPS 密文）、`infrastructure/`（Make + Ansible + uv 的渲染、发布、建群、宿主、仓库）、`docs/`（导航、发布链、架构、验收边界）、`CHECKPOINT.md`；改了根上的 `AGENTS.md`、`.gitignore`、`密码修改表.md` |
| **旧的 `sunmoonai/` 树** | **一个文件都没碰**。luna 把它当作冻结的旧体系；新体系是另起的一套，不是改旧的 |
| 门禁 | `.githooks`、`scripts/`、`utils/` 没有改动。发版的 doc-gate、anchor-gate 还在。新体系自己有一道 `validate-release`（工作区须等于已晋级的 Git 对象、拒绝明文 Secret） |
| 密钥 | Secret 全是 SOPS 密文；`*.agekey` 进了 `.gitignore`；没有找到私钥、kubeconfig、令牌。**例外见第三节** |
| 十二个子仓 | 每个子仓在 `master` 之上**只有一个提交**：九个前端是 `mybuild/Dockerfile`、`.nvmrc`、`mybuild/README.md`（锁定构建镜像与运行镜像，Node 24.21.0）；三个后端是 `postgres.py` 加两行 `expire_on_commit=False`。**没有 `fable` 上的任何东西** |

所以「整个部署体系改了」的准确说法是：**另建了一套部署体系（新集群 `sunmoon-kind`），旧的原样留着；应用用的是 master 版的源码**。

新体系的要点（按 luna 自己的说明）：Make → Ansible → Flux/SOPS；一个组件一个目录（`config.yaml` + 模板 + `stage.yaml` + 密文），阶段图由各组件的 `stage.yaml` 汇成；镜像按摘要、声明按 OCI 摘要、显式晋级；三节点 KIND（Kubernetes 1.36.5）、宿主上独立的 Harbor 2.15.2、HAProxy 按 SNI 分流 30443。所有者在过程中定了不少事（都记在新 `AGENTS.md` 里：配置归属、维护窗口 2 小时、容量底线 10 GiB、应用共用机制、文档原则、密码表约定、只做 Windows 之外的那些）。

## 二、和 9 月 26 日任务书的关系

| 任务书要的 | 分支里有没有 |
| --- | --- |
| 一、端到端自动测试（8 条 Playwright 用例） | 没有 |
| 二、持续集成与交付（KIND 里的 Jenkins、两条构建流水线、发版流水线设计） | 没有。新体系的 CI 定为 `make ci`，排在它的 B 阶段，还没做；Jenkins 待所有者再议 |
| 三、监控与告警（Prometheus + Alertmanager + Grafana、告警规则、高可用计划） | 没有。分支里没有这三个词 |

分支做的是另一件事：所有者 2026-09-30 批准的「独立的 KIND 部署架构」。三件任务没有做，也没有废止；要不要做、什么时候做，等所有者重新定（我的看法在第六节）。

## 三、要所有者知道的几件事

| 项 | 说明 |
| --- | --- |
| **密码表的一个真口令推到远端了** | `密码修改表.md` 在提交 `b1e58263`（10-05）里加了第 15d 行（新集群 Kibana 只读账号），「当前密码」一列是 40 位的真口令，随分支推到了 GitHub 和 Gitee。表里自己写着「本表……不 push」。`master` 上这张表本来就有 21 个开发口令，所以这是沿用的做法，不是新口子；但 15d 是这次新放进去的。建议：仓库是私有的就接受，否则把这个只读账号轮换掉 |
| 应用是 master 版 | `infrastructure/applications/sources.yaml` 钉的十二个子仓提交全是 master + luna 那一个提交。fable 上 9 月以来的后端、页面、迁移都不在新集群里 |
| 数据库迁移版本也是 master 的 | 新体系按 `expected_schema_revision` 核迁移：info `20260913_0009`（fable 是 `20260929_0013`）、knowledge `20260911_0006`（fable `20260927_0007`）、investment `20260925_0011`（fable `20260929_0012`）、tpl 相同 |
| relay 用的是旧集群的镜像 | `relay-platform/relay/image.lock.yaml` 钉的是旧 KIND 的 `relay v1-r3`。luna 工位里的 `relay.py` 和 fable 的逐字相同（9 月 28 日合过），多半就是 fable 的 relay；要 luna 确认那个镜像是从哪次提交构建的 |
| 沙箱供给器默认关 | 写了契约但 `enabled: false`：现有镜像把网络策略写死 `edge`、动态 Pod 不满足 restricted PSS，要经应用构建链重建才能开 |
| investment → knowledge 的检索身份还开着 | `investment-backend/config.yaml` 里 `knowledge_service.enabled: true`。所有者 9 月 29 日已定撤销（迁移账本第 21 行） |
| 旧体系的两处改动没进新体系 | fable 在 `sunmoonai/relay-platform`、`sunmoonai/sandbox-platform`、`sunmoonai/kind-infrastructure` 下有改动（relay 的令牌撤销、沙箱镜像入口脚本等）。新体系的 relay 靠镜像摘要带过去了（待确认），沙箱的要重建时一起 |
| 合并时会撞的只有一处 | k8s：`fable` 只改过 `密码修改表.md` 两行，`AGENTS.md`、`.gitignore` 没改，新目录和 fable 不重叠。子仓：前端的 `mybuild/` fable 没碰过，干净；三个后端的 `postgres.py` 两边各修了一遍，**以 fable 的为准**（账本 H66、迁移账本第 43 行） |

## 四、我那 43 条迁移待办在新体系里落在哪

| 落点 | 待办行 | 在新体系里怎么做 |
| --- | --- | --- |
| 源码钉版与镜像 | 9、23、42 | `sources.yaml` 改成 fable 的十二个提交；`application-build/publish` 重建四个后端、八个前端的镜像并写 `image.lock` |
| 数据库迁移 | 1、26、2、29、16 | 各后端 `config.yaml` 的 `expected_schema_revision` 改成 fable 的最新版本，`migration_job_revision` 递增；`uuid-ossp` 看 `database_extensions` 有没有列 |
| 应用配置 | 3、4、6、13、18、27、33、36、38、40；20（删旧项） | 后端模板只渲染数据库、Celery、RabbitMQ、S3、服务身份这些共用项；应用自己的配置项全部放各后端 `config.yaml` 的 `domain_runtime_env`（现在是空的） |
| 存储权限 | 5、17 | 对象存储的桶策略：info 自己的桶读写列，knowledge 对 info 的桶只读对象 |
| 数据库权限 | 22、28、30 | 新体系给运行身份的是「表 CRUD + sequence」，不按表列清单。这三行多半不用再做，要 luna 核一句 |
| 网络 | 8、34 | 新体系默认拒绝出站，按标签放行：info 到巨潮、东方财富的出站；沙箱到 investment 的 `/api/mcp/workbench` |
| 沙箱与供给器 | 31、32、35 | 供给器开起来之前要重建镜像；重建时把 Codex 配置（关 `multi_agent`、`goals`；新的 `records_mcp_*`）一起带上 |
| 身份 | 21 | `knowledge_service.enabled` 改 false，去掉那个绑定 |
| 资源 | 7、14、15、19 | knowledge 镜像大 600 MB；info 的 Worker 内存按 1.2 GB 核 |
| 旧集成测试 | 24、25 | 是旧 `sunmoonai/` 里的测试；新体系用自己的 check。等所有者定旧树的去留 |
| 只是告知 | 10、11、12、37、39、41 | 11 等所有者；37/39/41：对齐工位时多了四个前端的 `fable` 分支和一个 `platform-kind-v1` 工位 |

## 五、合并的建议

| 步 | 做法 | 谁 |
| --- | --- | --- |
| 1 | `platform-kind-v1` 并进 `fable`（不是反过来）：k8s 直接合，三处根文件按 fable；十二个子仓各合那一个提交，前端照收，后端的 `postgres.py` 以 fable 为准；父仓的子仓指针指 fable 的头。合完四套后端测试全跑，`test_session_config.py` 必须绿 | 远程 |
| 2 | 在 fable 上把第四节「源码钉版、迁移版本、应用配置、身份」四组改到新体系的配置文件里（都是 `sources.yaml` 和各应用 `config.yaml`，不碰模板和剧本） | 远程（要所有者点头：这几份文件在 luna 的目录里） |
| 3 | 存储权限、网络、沙箱重建、资源这四组，以及构建、发布、晋级、部署 | luna |
| 4 | luna 以后继续在 `platform-kind-v1` 上做；每到一个停点就并一次 fable。`master` 仍然只在所有者说的时候动 | 所有者定节奏 |

这样第 10 步（在集群上验）就是：第 1、2 步做完，luna 按新体系的链构建、发布、部署一次 fable 的应用，再人手点一遍。

## 六、要所有者定的

1. 密码表第 15d 行推到远端这件事：接受，还是轮换。
2. 三件任务（端到端、CI、监控）重新排期。我的建议：端到端放在第 10 步之后，按新页面重写用例；CI 就用 luna 的 `make ci`；监控在新体系上做，仍按任务书的第三件。
3. 旧 `sunmoonai/` 树什么时候退役、谁来删（里面还有 fable 在用的 relay、沙箱源码和部署目录的集成测试）。
4. 第五节第 2 步让远程改 luna 目录里的配置文件，行不行。

## 七、我没有做的

- 没有读 549 个声明文件的内容，只看了结构、组件清单、relay/沙箱/四应用的配置与模板。
- 没有验证新体系能不能跑：luna 的验收记录（`docs/platform-kind-v1/verification.md`）我只读了，没有复现。
- 没有核对 `infrastructure/` 里的 Ansible 剧本逻辑。
