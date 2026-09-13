# B7a：公共 SQL / HTTP 日志降噪（Luna）

日期：2026-09-13。状态：源码候选已验证，待完成集成同步。单人实施、自测，不宣称独立验收。

## 1. 冻结范围

所有者原话“继续”，沿用[逐步处置清单](v5-backlog-disposition-luna.md)的授权。
旧 M1-203 要求减少 INFO SQL/HTTP 日志，M1-503 要求关闭非 debug SQL echo；
这不是完整结构化观测、指标、脱敏或生产发布的验收。

本地/云端 master、Luna 五父仓 HEAD 已只读核对一致；云端干净，本地只保留两份既有
general/pro 未跟踪协议草案。子仓基线：模板 `30a1066`、Info `6a2be57`、
Knowledge `2212e46`、Investment `8228a0f`；k8s `937f1e7d`。

冻结路径（每个后端）：`app/app/infrastructure/logging/logging.py`、
`app/app/infrastructure/storage/postgres.py`、`app/app/worker.py`、
`app/tests/test_logging_policy.py`、`docs/logging-policy.md`。
加本证据、处置清单、模板项目指南及三个实例父仓模板对齐报告，
不修改前端、模型、迁移、配置字段或契约。

| 规则 | 处置 |
| --- | --- |
| R6、T3 | 模板先验证，再串行 Info → Knowledge → Investment；API 与 Celery 入口都覆盖 |
| D1/D8、C3/C4 | 不新增主档/迁移，不改服务契约；完整回归包含既有契约向量 |
| T4/T5、R1 | 子仓先推、父仓后推；固定提交自测和源码集成分开记，不冒充镜像/部署 |
| 用户指定单路 | Luna 一人实施、复核；保留领域 Worker 注册及队列扩展，不覆盖整份 Worker |

## 2. 已核实的缺口与实现边界

- 四后端共用的 Postgres 包装器仍按 `ENV=development` 自动打开 SQL echo，与 LOG_LEVEL 无关。
- API 调用 `setup_logging`；Worker/Scheduler 使用 Celery 自己的日志初始化，不调用该函数。
- 迁移独立使用 Alembic 配置：SQLAlchemy WARN / Alembic INFO，无 echo；不把 API 日志器塞进迁移。
- 本包固定将 `sqlalchemy.engine`、`sqlalchemy.pool`、`httpx`、`httpcore` 限为 WARNING，
  即使应用 DEBUG 也不自动开启第三方 SQL/HTTP wire 日志；应用、审计及 Celery 正常日志级别不变。
- Postgres 禁用 echo、隐藏 SQL 绑定参数；这不能隐藏 SQL 字面量或任意应用异常中的秘密。
  不宣称完整脱敏，也不清理既有日志。库的 WARNING/ERROR 仍保留，排障须使用受控手段。
- Celery 在自身日志初始化之后应用库级策略，保留其 handler、格式及任务上下文。
  重复初始化不能叠加输出；不接管 Celery 的 setup_logging 信号。

验收先冻结：API / Worker / Scheduler 真入口、INFO / DEBUG、重复初始化、HTTP 请求日志、
SQL 参数隐藏、保留应用/审计/库告警和 Celery 任务日志；Ruff、Pyright 及四后端全套（真实
一次性 PG；Info S3、Investment Redis；契约向量）均无跳过。测试资源不连业务数据。
回滚使用反向提交，无数据回滚；代码集成后仍未部署，运行态 B7b 继续核验。

## 3. 执行证据

按模板 → Info → Knowledge → Investment 串行完成源码及静态/全量门禁。
每个后端恰好 5 个文件，Ruff/Pyright 均通过；固定提交再次全量回归如下：

| 后端 | 固定 commit | 测试 | 时间 |
| --- | --- | --- | --- |
| tpl-backend | `553c36bec883d60620a24043cdffce3b7adca514` | 88 passed / 0 skipped | 8.93 秒 |
| info-backend | `f2c400142d5c055891b1c409678ca40a834f0788` | 301 passed / 0 skipped | 25.56 秒 |
| knowledge-backend | `e99a89477efff1025ce1c1b4b751bec60b5827ab` | 243 passed / 0 skipped | 25.04 秒 |
| investment-backend | `9622af0ffd4e740aacd2a78d098d0a0800a7c3b0` | 223 passed / 0 skipped | 22.93 秒 |

总计 855 项（各仓均包含共享测试，不是 855 个不同场景），每仓新增 8 项专项。
专项在独立 Python 进程导入实际 API factory / Worker / Scheduler / 直接 Worker 入口，
实际调用 Celery 日志初始化；HTTP 使用 httpx MockTransport，PG 包装器构造真实 engine
但专项不连库。它不等于运行了真实 Worker/MQ/容器；数据库/进程故障等由全量既有回归覆盖。
API lifespan、真实 Casdoor、业务 Provider、KIND、发布回滚本包未重跑。

四仓 `logging.py`、`postgres.py`、专项测试及后端说明逐字相同（SHA-256 已核对）。
Worker 只做相同的导入/信号注册增量，各仓领域任务与调度保持原状。没有修改依赖锁，
版本提示不触发随手升级。模板专项初次 Ruff 发现一处测试长行，修正后门禁全过。

无业务数据库/桶/Secret 访问，无镜像构建、Harbor 推送或部署。源码通过并不闭合各实例
R6 的新版本 KIND/身份/回滚发布门禁；旧证据只代表其旧版本。

## 4. B7b 继续点（尚未验收）

旧 M1-105 的指标/告警/保留归档、M1-501～504 的角色健康与发布可追踪、B4～B6
的业务环境切换仍需逐子项核验，不能因本包日志改善而销账。本次只读源码另确认：

- 模板 API `bootstrap/api.py` 的 ready 仅 Redis ping / PostgreSQL SELECT 1，
  未检查 schema revision；应核三个实例与迁移门禁，决定最小公共补齐。
- Info 声明式 Worker readiness 使用 Celery inspect ping；不能仅凭 pong 证明业务
  consumer 正常、正确队列已订阅或消息可以完成，需核消费与调度活性证据。
- 2026-08 R7 清单是固定旧版本发布证据；不得直接运行其中带 apply/权限重建的脚本
  来完成只读核验，也不得把其 DONE 投影到 B2～B7 新源码的部署状态。

完整 B7b 子项矩阵尚未完成；N1～N6 尚未被新 dev-plan 接收，B8 不提前标完成。
