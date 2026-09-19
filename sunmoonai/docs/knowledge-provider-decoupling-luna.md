# Knowledge Provider 内部解耦（Luna）

## 请求与范围

2026-09-13 所有者原话：“那如果解耦，工作量大吗，现在做好点吧”。
单人 Luna 实施、自测；不宣称独立评审。只解耦现有 Knowledge 的数据面，
默认仍为 RAGFlow，不安装 WeKnora、不迁移数据、不部署、不改两份协议草案。

## 基线与写入面

独占约定工作区 `/home/zymun/worktrees/luna`，非强制 OS 隔离。
Knowledge 父仓 luna `92e310adece0b92ad81fbaa57ca693e174b8a97d`；Backend
既有分支 handoff/luna-durable-delivery `e79a71272dbcf487e2a0def6dd65a954d3ca0ed8`；
k8s luna `fd49afff3012e326ed5f4e5641525a43264650ea`，开始时均干净。
这些基线刚完成本地/云端 master、Luna 和 GitHub/Gitee 同步；不新建分支。
写入限 Knowledge Backend 的 Port、装配、适配器、摄入/检索/授权服务、引用入口、
相关测试与说明；k8s 更新本记录和指南。核查还发现既有
`app-platform/scripts/integration/test_knowledge_database_policy_pg.py` 导入了旧服务名，
因此将该文件的导入、假客户端注入点和类型化回执取值纳入兼容更新；原权限/事务断言不变，
并重新运行真实独立角色验证。Git 元数据写入按平台批准，不绕过权限。

## 决策与不变量

| 约束 | 处置 |
| --- | --- |
| D1/D2/D4/D5/D6/D8 | 原文仍为不可变 Artifact；Provider 为派生系统；不建表、不改迁移/领域主档 |
| C1/C2 | 保留 Outbox/Inbox、租约/epoch、意图/回执/未知结果阻断和持久单次轮询 |
| C3/C4/C5/C6 | 不改对外 artifact/retrieval v1、锁文件、引用 URL；跑提供方与消费者回归 |
| I1/I3/I5/I7/I8 | 原授权过滤、绑定快照和错误拒绝保留；Provider 数据不能授予权限 |
| T2/T3/R6 | Knowledge 领域 Port，不是模板公共能力；不派生新 Backend 或同步无关实例 |
| T4/T5/R1 | 候选提交及验证单列，不以源码解耦冒充 Provider 切换或业务发布 |

Port 负责类型化 dataset/document/parse/retrieval 与错误语义；适配器转换供应商协议；
业务层继续掌握事务、授权、幂等和任务生命周期。配置装配集中，默认不变，未知实现失败关闭。
RAGFlow 的端点、数字/文本 run、chunk 字段与身份范围算法不能泄漏进通用编排。
旧持久键、作用域摘要、状态名与 DTO 中的历史 ragflow 字段保留兼容，不借解耦重键。
retrieval v1 的 provider 元数据目前只允许 ragflow：未来接 WeKnora 必须正式扩展契约，
不能在当前契约中伪装身份；本包不宣称热切换、多 Provider 混检或索引可直接搬迁。

## 验收与停止条件

1. 摄入、回执恢复与检索主链使用统一 Port；架构测试阻止重新直接依赖 RAGFlow 客户端。
2. 适配器覆盖状态归一、绑定身份、检索字段/异常转换、资源关闭；非 RAGFlow 假实现
   验证业务编排只依赖 Port，不作为 WeKnora 真联调证据。
3. 原可靠投递、回执丢失、崩溃、旧游标、授权/域隔离测试保留行为断言；必要时只调整注入点。
4. Ruff/Pyright、Knowledge 完整测试及 Info/Investment 相关契约回归；真实依赖使用
   明确的一次性测试资源，不使用业务库/Secret，记录清理。
5. 最终差异、固定提交、实际执行证据与未覆盖项回填；遇到需要数据库/外部契约迁移则停下报告。

## 进度

已实现、验证并按所有者“也同步一下，之后暂停”的要求完成代码同步；Backend 固定提交
`26aa0715f15e2c8df4713559063a9a2e3215a1c8`（18 文件，含原文件拆分/移动和测试）。
2026-09-13 先将 Backend 普通快进推送到 GitHub/Gitee 既有 master，再提交父仓
gitlink `8f87061b70c2136286941efa58f0b99cc246a405`；k8s 实现说明与权限测试适配
固定内容提交 `c299c6b59dae7419e993ee9bcbe200615d217eaf`。本地 master 快进后，
通过 five-repos-sync 完成五父仓 Luna/master 向云端同步及本地 master 最终拉取。
已逐一核验两处仓库实时 master/luna 引用、本地与云端两工作区五父仓完整 SHA、
实际子模块及干净状态；本段是核验后的文档回填，随单独回执提交同步。
没有新建分支、强推、reset/realign、更新其它工位或启动本地 Opus；不构建/推送镜像，
不部署、不切换 Provider。两份协议草案内容保持不动。B7 旧账游标仍保留在
[部署清单](legacy-backlog/deployment-checklist.md)，本包不代替旧账销项。

## 实现与验证回执

- `KnowledgeProvider` + 类型化结果/统一异常；`RAGFlowProvider` 负责字段、状态和 scope
  转换，`provider_delivery` 负责原事务编排，Artifact 读取独立。既有配置名不改。
- RAGFlow 专用 config-check、旧 DTO/状态/metadata 字段和 completion helper 保留为
  兼容面；其它 Provider 在现行 v1 产品入口显式拒绝。没有修改契约 schema/锁文件、
  数据库模型/迁移、运行角色策略、依赖或部署声明。
- **固定 Backend 完整 450 passed / 0 skipped（71.60 秒）**，外层一次性环境检查
  1 passed（92.70 秒）。较原 418 项新增 32 项（适配器/结构/异常 29、非 RAGFlow
  Port 真实 PG 编排 3）；原行为断言保留，仅更新导入、注入点及类型化结果取值。
- Ruff/Pyright 通过；Info `tests/test_distribution_helpers.py` **6 passed**，
  Investment `tests/test_knowledge_retrieval_contract.py` **7 passed**；两消费者源码未改。
- 独立真实 PG 角色门禁 **27 passed / 0 skipped（20.78 秒）**，包括 Worker 权限下
  的上传/解析回执丢失恢复、最终写回失败回滚、API 读取已提交结果、journal 禁读、
  DDL/跨角色写入/跨库/迁移凭据拒绝。使用固定 Backend 和 k8s 权限测试文件
  SHA-256 `9c61580009c747d184f31e72a7769246ec664485b96338f9ac5a75e324069358`。

首次新增单元用例的 Principal 漏填必填字段，修正为复用完整合法服务身份 fixture；
没有放松身份校验。独立权限首轮启动遗漏后端 pytest 配置，27 个异步用例未执行，
根因是未启用项目既有 `asyncio_mode=auto`；加 `-c <Backend>/app/pyproject.toml`
后完整 27 项通过，没有改用同步假测试或删除失败断言。首轮完整 443 项为新增
测试补齐前的诊断回归，最终以固定提交的 450 项为准。

## 复跑与清理

以下全部只允许一次性测试资源，不能替换为业务连接。先切到 Luna 工作区：

```bash
cd /home/zymun/worktrees/luna
BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only \
BROKER_PERMISSION_TEST_BACKEND="$PWD/knowledge-app/knowledge-backend/app" \
BROKER_PERMISSION_TEST_AUXILIARY=s3 \
knowledge-app/knowledge-backend/app/.venv/bin/python -m pytest \
  tpl-app/k8s-deployment/integration/test_runtime_broker_policy.py::test_full_backend_gate_without_skips -q -s
```

独立角色复跑复用已有 PG 供给夹具（绑定本机 55439、核定镜像、独立随机测试账号）：

```bash
JOINT_RUNTIME_TEST_CONFIRM=disposable-b7u-only \
BROKER_PERMISSION_TEST_BACKEND="$PWD/knowledge-app/knowledge-backend/app" \
knowledge-app/knowledge-backend/app/.venv/bin/python - <<'PY'
import os, subprocess, sys
from contextlib import contextmanager
sys.path.insert(0, 'tpl-app/k8s-deployment/integration')
from test_runtime_identity_joint import postgres
with contextmanager(postgres.__wrapped__)():
    result = subprocess.run([
        sys.executable, '-m', 'pytest',
        '-c', 'knowledge-app/knowledge-backend/app/pyproject.toml',
        'k8s/sunmoonai/app-platform/scripts/integration/test_knowledge_database_policy_pg.py',
        '-q',
    ], env={**os.environ, 'RUNTIME_POLICY_TEST_CONFIRM': 'disposable-b7q-only'})
    if result.returncode:
        raise SystemExit(result.returncode)
PY
```

两轮完整回归和两轮独立权限运行共创建 8 个一次性容器、14 个匿名卷，均由夹具
按其完整 ID/标签核对后移除，仅清理可重建合成数据。最终复核不应有新增残留。
未调用真实 RAGFlow/WeKnora，未安装软件、修改业务 DB/Secret、构建镜像或部署。
这次证明内部替换边界与原 RAGFlow 行为回归，不证明 WeKnora 的回执、授权过滤和
索引/引用迁移已经验收。两份 general/pro 草案原内容不动。
