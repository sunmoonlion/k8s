# B7m：实例渲染保留模板运行契约（Luna）

2026-09-13；单人实施、自测。承接 [B7l 运行预检](v5-backlog-runtime-preflight-luna.md)。
状态：本地源码与渲染测试通过；没有部署或实际凭据切换。

## 1. 范围、根因与修复

基线：tpl-app `ee0978a253a5fadd2f5049d8877d4e9f7f42782b`，
k8s `334eb587ceba87e0bd1de763b1f3344571a76892`。四后端源码不变。
本包先修模板 Worker 发布注解并通过模板部署测试，再串行 Info → Knowledge →
Investment 修实例覆盖、测试最终产物；无新分支、master 更新或中间同步。

问题有两处：模板 Worker 自己遗漏 release-id；三个实例的旧迁移期覆盖直接重写 env，
将模板分角色 DB/broker 键退回旧共享引用。后者不是数据库代码缺少用户类型，也不是
仅换 ServiceAccount 就能修好。

| 载体 | 修复与保留边界 |
| --- | --- |
| tpl-app/k8s-deployment/templates/20-runtime.yaml.tpl | Worker 补与其他运行角色相同的 release-id 注解；既有就绪探针/资源/退出策略不变 |
| k8s 的 app-platform/scripts/render_info_release_base.py | 新增 runtime_role_env，在领域 env 覆盖前保存并校验模板的 DB/broker 引用；缺失、重复、内联值、错角色键、必需键可选化、不一致 Secret 等拒绝，不退回共享凭据 |
| 三个 render_*_release_base.py | 都保留模板角色引用；Worker 的可选结果后端也保留 WORKER 前缀；独立 Migration 和各领域的额外身份/Redis/存储/Provider 配置不动 |
| 三个 App 的 deployment/render.py | 外部依赖清单改为对应 backend-runtime Secret，不再列旧共享 DB/broker 为这些角色所需；旧 migration Secret 保留 |
| tests/test_runtime_rendering.py | 实际运行完整 scaffold → 实例覆盖 → 最终 bundle，并再过开发发布 finalizer；对缺陷做负例和最终产物断言，而非只读模板文本 |

修改集中于模板父仓三个文件、k8s 七个 Python 文件及本包文档；不改后端、数据库迁移、
权限供给脚本、现有 bundle/release.json、development-input/source-lock 或正式版本。
代码沿用现有每 App 一个 backend-runtime Secret、仅按角色引用指定 key 的模板设计，
**不在本轮创建这个 Secret，也不把旧密码复制进多个键**。

| 规则 | 本包落实 |
| --- | --- |
| D1～D4/D8、I3 | 没有新增数据主档/跨域数据库访问；模板角色键保留；不读/创建凭据，不改变迁移运行角色 |
| R1～R5、T3～T5 | 保留旧发布用于其历史版本；新源码不冒充当前镜像；父仓只提交本包内容，不更新 backend gitlink、不 push |
| R6 | 模板先验；Info 通过后才改 Knowledge，Knowledge 通过后才改 Investment；用既有 bundle 比较领域 env/envFrom/挂载，保留显式领域差异 |
| C3/C4 | 无业务 DTO/provider schema 变化；本轮为渲染回归，不冒称重新执行后端契约或业务 E2E |

## 2. 渲染后的接口与部署前置

对最终稳定 App 名称，运行 Secret 为 `<app>-backend-runtime`：API、Worker、Scheduler
仍按模板分别读取 API/WORKER/SCHEDULER_DATABASE_URL 与相应 CELERY_BROKER_URL；
Worker 的 WORKER_CELERY_RESULT_BACKEND 继续可选。迁移仍只读
`<app>-backend-migration-postgresql-conn/MIGRATION_DATABASE_URL`，不获得浏览器或
Worker 下游凭据。R5 临时资源名在 base 渲染阶段有 -r5 前缀，由现有稳定化步骤转换。

这是**引用契约**而非实际隔离证明。新 Secret 存在、键名不同，也不能证明其值不是
同一个用户/密码；后续必须独立 principal、最小权限、旧写路径停用与独立撤销实测。
本包不会删除旧共享 Secret，旧集群依然依赖它们。

最终 Worker 必须含 `python -m app.cli.worker_readiness` 和 release-id。新探针模块已在
当前后端源码中，但旧镜像不一定提供。因此不能把本包临时渲染产物直接 apply：需新
固定源码/镜像/source-lock、业务预检、备份恢复、授权凭据供给和排空切换。原渲染器的
固定历史镜像/默认 formal 模式不是本轮新发布证明；测试只验证声明转换，不认证其镜像
包含当前代码。开发发布仍走明确 KIND 的既有入口及其备份/排空门禁。

Scheduler 本机活动观测接线、live/startup 策略、真实 Worker drain、Knowledge 的批准
Dataset 映射和旧任务调查、Info 0008/0009 数据迁移仍未由此实现；不顺带增加自动重启。

## 3. 验证

本轮部署脚本层测试，不启动容器、KIND 或 Provider，不读业务数据。新增 11 个测试方法：
2 个共享引用正反例、每 App 3 个完整渲染/依赖与迁移边界/开发 finalizer 场景。

- 缺必需键、重复 env、内联值、API 键给 Worker、旧无角色前缀键、旧共享 Secret 名称、
  必需键 optional=true、同角色引用不同 Secret、未知角色均拒绝；输出与输入不共享
  可变对象。错误只给角色/变量名，不打印引用内容或凭据。
- 三实例的最终运行角色键唯一；Migration 仍只引用独立迁移 Secret；旧共享运行
  DB/broker 不残留于其外部依赖清单。最终产物通过已有 bundle 校验。
- 与当前已提交 bundle 比较非本包 credential 字段的 env、envFrom、volumeMounts 和
  volumes：领域配置与挂载保持一致，避免大段替换清空领域功能。
- 实际调用开发 finalizer 后再次验收 Pod spec 不变、源码注解存在、发布注解保持及
  bundle hash 正确。**该场景仅模拟 Git attestation**，镜像用测试输入；不能据它宣称
  新真实源码 lock、镜像来源或部署已验收。

最终串行工作区回归：模板 8 tests OK（0.186 秒），Info 阶段 17（0.756 秒）、Knowledge
阶段 20（1.401 秒）、Investment 阶段 23（2.210 秒），均无跳过。阶段包含累计公共测试，
不把 17+20+23 当作独立场景数。七个 Python 变更文件 Ruff 通过；diff 检查通过。
后续固定提交复验单独回填，不以工作区结果冒称固定版本验收。

开发期仅发现新测试 import 排序不合 Ruff，已修正；一次检查从 tests 目录使用仓根
相对工具路径而失败，改在 k8s 根执行后正常。没有安装依赖、放宽断言、跳过测试或
调整业务超时；没有新增后端测试失败。临时渲染目录由测试 TemporaryDirectory 清理。

## 4. 剩余处置

本包关闭的是“新渲染继续覆盖掉模板角色引用/遗漏 Worker 发布标识”的源码缺口，
不是 B7 身份与部署总验收。下一步应准备精确的角色权限/凭据供给与拒绝矩阵，结合
B7l 的真实旧任务/版本状态安排数据切换；执行外部变更前另列目标、授权、回滚条件。
原 B7k 归档欠账及 B8 的正式任务接收仍保留，B9 继续等待最终一次性集成同步。
