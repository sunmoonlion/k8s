# luna 的开发任务：走向企业级的三件（2026-09-27 起）

> 所有者 2026-09-26 定：这三件交给本地助手 luna 开发。设计在 `k8s/sunmoonai/docs/dev-investment-agent/tree-build/SDD/architecture/engineering.md`「走向企业级：先补的三件」，先读它。
> 这是一份**开发**任务，和 inbox 的"只跑不改"不同：这里允许写代码、写清单、写脚本。其余规矩照旧（见下「规矩」）。
> 顺序固定：一 → 二 → 三。每一件做到它的「停点」就停下，写结果、本地提交，等所有者回传给远程看过再做下一件。

## 分工：谁动哪些文件

远程助手在你做这三件期间**不碰**下面这些位置；你也只在这些位置里新建或修改。要改别处（产品代码、现有部署脚本、门禁）先停下，写进结果说明为什么，等所有者定。

| 你负责 | 位置 |
| --- | --- |
| 端到端测试 | `investment-app/investment-web-frontend/app/tests/e2e/workbench/`（新建）、同仓新文件 `playwright.kind.config.ts`、`package.json` 里新增的 `test:e2e:kind` 命令。**现有的 `playwright.config.ts` 与 `tests/e2e/rendering.e2e.ts` 不改** |
| 端到端的环境与辅助 | `k8s/sunmoonai/scripts/e2e/`（新建） |
| 持续集成与交付 | `k8s/sunmoonai/cicd-platform/`（只动流水线与新增文件；Harbor 现有部署不动） |
| 监控与告警 | `k8s/sunmoonai/ops-platform/monitoring/`（新建） |

产品代码里真要改的（比如给页面元素加 `data-testid`），列清单写进结果，由远程改。

## 规矩

- 所有代码与结果都在 `~/worktrees/fable/<仓>` 的 `fable` 分支上；子仓在子仓里提交。**只本地提交，不 fetch / pull / rebase / push**，同步和推回是所有者的 `human-local.sh` / `human-remote.sh`。
- 密钥、口令、令牌、cookie、模型 key 一律不进 git、不进结果、不进对话；放 `~/private/`（0600），用文件路径或环境变量引用。
- 不绕过、不放宽任何现有门禁（发版门禁、数据库授权策略、网络策略、`doc-gate`）。
- 每件做完在 `k8s/sunmoonai/scripts/results/luna-<件名>.<时间>.md` 写结果：做了什么、改了哪些文件、怎么跑、跑出来什么、还差什么、需要所有者或远程定的事。

---

## 一、端到端自动测试（先做）

**目标**：用真浏览器把这两天人手点过的路径自动跑一遍；以后任何一个修过的问题被改回去，至少一个用例变红。

**环境**：就用本地 KIND 现在这套（投资、知识、Casdoor、沙箱池、会合点都在）。网页仓已有 Playwright：`playwright.config.ts` 跑 `tests/e2e/**/*.e2e.ts`，默认自己起一个网关，给了 `PLAYWRIGHT_BASE_URL` 就改打外部地址；已有一条 `rendering.e2e.ts`。**在它旁边新建 `playwright.kind.config.ts`**：`testDir` 指 `tests/e2e/workbench`，`baseURL` 为 `https://investment.sunmoonai.com:30443`，`ignoreHTTPSErrors: true`（KIND 自签证书），不起本地网关，超时放宽；用例文件命名 `*.e2e.ts`。

**准备（所有者配合）**：
1. 在 Casdoor 的 `sunmoonai` 组织里建一个专用测试账号（比如 `e2e-runner`，邮箱用所有者可控的），口令存 `~/private/e2e.env`（`E2E_USER`、`E2E_PASSWORD`），0600。**不用 zymun**，免得测试把所有者自己的沙箱和令牌换掉。
2. 模型：第一刀先用真的 Kimi key（所有者给一把专门给测试用的，存 `~/private/e2e.env` 的 `E2E_MODEL_KEY`），用例里的问题尽量短，控制花费。换成假模型服务（回放固定回答）是后话：Codex 0.155 走 `responses` 流式协议，假服务要实现到它能用，先调研、不在第一刀里做。

**要写的用例**（`tests/e2e/workbench/`，每条一个 `test`）：
1. 登录：首页 → 登录 → Casdoor 登录页是中文、标题「SunMoon AI 投研」→ 用测试账号登录 → 回到网页，`/api/auth/web/me` 返回测试账号。
2. 登记 key：设置页提交 key → **列表里出现尾号**、输入框清空。（2026-09-26 的"严格校验拒收"问题）
3. 拉起沙箱：点「拉起沙箱」→ 出现"正在拉起…"与完成说明、出现一次性接入命令与「复制命令」→ 状态在 3 分钟内变「运行中」。接入命令由测试自己存进 `~/private/e2e-agent-init.txt`，再用它 `init` + 后台 `start` 一个代理（家目录 `~/.sunmoon-agent-e2e`），接在 NodePort 上。
4. 会话与实时：新建会话（测试账号的机器与沙箱），发一句话 → **不刷新**，回答在 60 秒内出现。（事件流问题）
5. 委托：问专家 SMOKE（按钮现在叫「交出方向盘」，重写后叫「交给专家」，选择器两个都认）→ **不刷新**，委托卡与"委托 … → SUCCEEDED"出现。（只写库事件不实时的问题）
6. 换令牌：点「换代理令牌」→ 先出现确认框 → 确认 → 新命令出现；测试检查旧代理进程在 10 秒内因"token revoked"退出、用新命令接入后恢复在线。（会合点不断开的问题）
7. 未登录：清掉 cookie 打开设置页 → 出现"请重新登录"类提示，而不是静默没反应。（这条现在会失败——重写页面前是已知失败，标成 `test.fail` 并注明）
8. 清理：用例结束回收测试账号的沙箱，停掉测试代理。

**怎么跑**：`k8s/sunmoonai/scripts/e2e/run-e2e.sh` 一条命令：读 `~/private/e2e.env`、检查集群可达、跑 Playwright、把报告与失败截图放 `scripts/results/e2e-<时间>/`（截图里不能出现 key 与令牌：接入命令框在截图前用样式遮住）。

**停点**：8 条用例写完，在当前 KIND 上跑一遍（第 7 条预期失败），结果写好、本地提交，停。再故意回滚一个修复验证"会变红"是加分项：比如在测试命名空间里临时部署旧的网页镜像跑第 2 条——做之前先问所有者。

---

## 二、持续集成与交付（第一件过了再做）

**先问所有者 `D22`**（`tree-build/decisions.md`）：自建（Jenkins + Kaniko，仓里已有配置；部署用 Argo CD）还是托管服务；代码源以 GitHub 为准还是 Gitee（旧方案写 Gitee 全链路，所有者 2026-09-26 说 GitHub 为主）。**没定就按默认：自建，代码源 GitHub**，只做原型，不接生产。

**先读**：`k8s/sunmoonai/cicd-platform/cicd总体架构及实施详细方案.md`、`jenkins/`、`harbor/`；正式发版的步骤看 `k8s/sunmoonai/app-platform/scripts/README.md` 与 `switch-test/done/` 里的 06、07b 和 inbox 12（它们就是现在手工发版的完整步骤）。

**第一刀要做**：
1. 在 KIND 里起 Jenkins（用仓里现有部署脚本；缺的配置补在 `cicd-platform/` 里）。
2. 一条流水线：investment-backend 的 `fable` 有新提交 → 跑 ruff、pyright、pytest（带一次性 Postgres）→ Kaniko 构建镜像按摘要推 Harbor → 把摘要写进流水线产物。
3. 同样一条给 investment-web-frontend（vitest、tsc、构建镜像）。
4. 发版流水线**只写设计、不实现**：把 inbox 12 的每一步对应成流水线的阶段，标出哪里要人批（维护窗口、生产），哪里原样调用现有脚本（锁、渲染、门禁、plan、备份回执、deploy、drift），写成 `cicd-platform/release-pipeline.md`。

**停点**：两条构建流水线在 KIND 的 Jenkins 里各成功跑一次（贴流水线日志的末尾与镜像摘要，过滤口令），发版流水线设计写好，停。

---

## 三、多副本与告警（第二件过了再做）

**先问所有者 `D23`**：告警发到哪（企业微信、邮件…）；没定就先只在监控界面里看，不发外部通知。

**第一刀要做**：
1. 监控栈：在 KIND 里部署 Prometheus + Alertmanager + Grafana（kube-prometheus-stack 一类，钉版本，镜像走 Harbor 代理缓存），清单放 `ops-platform/monitoring/`。
2. 采集：节点与 Pod 资源、Postgres、Redis、RabbitMQ（它的 chart 已带 PrometheusRule）、Traefik；工作台和会合点暂时没有指标端点，先用"Pod 是否就绪、重启次数"覆盖。
3. 告警规则（至少这些，写成 PrometheusRule）：任一关键 Deployment 就绪副本为 0；沙箱 Pod CrashLoopBackOff；Pod 5 分钟内重启超过 3 次；PVC 使用率超过 85%；证书 14 天内到期（有 cert-manager 就用它的指标）；Postgres 连接数接近上限。
4. 在 KIND 里人为制造两次告警（比如把 relay 缩到 0、把一个沙箱改坏镜像），截图 Alertmanager 里告警出现与恢复。
5. 多副本**只写清单与验证计划、不改正式开发包**：列出每个服务要几副本、反亲和怎么写、会合点多实例要怎么分流（按用户哈希或共享配对表，写两种方案的利弊），写成 `ops-platform/monitoring/ha-plan.md`。正式开发包的副本数与会合点改造由远程改。

**停点**：监控栈跑起来、规则加载、两次演练有截图，高可用计划写好，停。

---

## 需要所有者做的事（汇总）

- 建测试账号 `e2e-runner`，口令写进 `~/private/e2e.env`。
- 给一把测试专用的 Kimi key，写进同一个文件。
- 定 `D22`、`D23`（或同意用默认）。
- 每件停点后跑 `human-remote.sh` 回传，远程看过再继续。
