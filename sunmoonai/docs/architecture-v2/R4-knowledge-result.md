# Architecture v2 R4 Knowledge 同步结果

状态：`DONE / RESEARCH MAY START`

日期：2026-08-08

模板唯一来源：`architecture-v2-r3.2-20260808`

## 1. 结论

Knowledge 已完整继承 R3.2 共同底座，同时保留摄取、索引、RAGFlow 绑定、检索和既有规范
Alembic 链。Admin 与 Web 两个 Next.js 表面均调用同一个 `knowledge-backend`，并在隔离 KIND
namespace 中通过真实 PostgreSQL、Redis、Casdoor、严格 TLS、原生回滚和 Calico 报文门禁。

本轮没有切换 `app-platform-dev` 现有流量，没有删除旧数据库、Secret、PVC 或旧 Web Backend
远端仓库，也没有开始 R5 数据归并。Knowledge R4 候选仍不是正式 `2.0.0` 发布。

## 2. 源码与镜像锁

| 组件 | 源码 commit | tree | 候选镜像 digest |
| --- | --- | --- | --- |
| `knowledge-backend` | `2e2710e6d1ae192f6cf7b6dbcca070b22acecb32` | `221bf8f72d7d9ee160a18af8102147257ea07e11` | `sha256:a5db9fab89bd131992c205d61294c27d2511be14bf6d50cfb9cb5bce75e8367a` |
| `knowledge-admin-frontend` | `351ffd94a5af088345073d60732ce46b0d432200` | `5155d7b988eb02d3c317eea659b40d475ad5bc29` | `sha256:07130d859a89b18842ce043178b5477bbb67a3ab183aadfe18baed039bd0b9c2` |
| `knowledge-web-frontend` | `8541dcad668deaf5b67727a1ac3eca2a842f5180` | `9623f3034a47e66b5235c50a0cc49dfe07f414d2` | `sha256:7bdd329bf24e479d1c8f859ef6ed909958bc1479b7296b3b212c2293c7601148` |

原生回滚使用同一 Next.js standalone 运行合同的前一 Knowledge Web 不可变摘要
`sha256:597193f3d16334e2d81b24c6cd00b54e361fa810f284ba7c11db72f5f34a7cd4`。旧 revision
所需 `WEB_BACKEND_INTERNAL_URL` 只在回滚时注入，前滚后显式删除；不得把该兼容变量带入新架构。

## 3. 源码与配对门禁

- 三组件 clean-room 同步的 `prohibited-drift=0`；
- 最终稳态 plan 均为 `writes=0`、`deletes=0`、`prohibited-drift=0`；
- Backend 保留 Knowledge ingestion、provider binding、retrieval 与 RAGFlow adapter；
- Backend：Ruff、Pyright、89 个测试通过，2 个环境依赖测试跳过；
- Admin/Backend 和 Web/Backend 均使用同一 FastAPI Backend 配对合同；
- Backend 改名后失效的本地 `.venv` 已从锁文件重建，未进入版本库；
- 模板公共文件的 Ruff 格式差异已恢复到验收模板基线，没有用宽泛分类掩盖漂移；
- 仅为 Knowledge DTO、检索、迁移链及 pair fixture 的实例标识登记精确例外。

## 4. 隔离 KIND 门禁

正式驱动脚本：`scripts/run_r4_knowledge_gate.sh`。最终 release ID 为
`r4-knowledge-002`，临时 namespace、Casdoor application、凭据 Secret 和 Calico 集群均使用
Knowledge R4 独立名称。

通过项：

- Knowledge Alembic `20260710_0001 -> 20260712_0002 -> 20260715_0003 -> 20260808_0004`；
- API、Worker、Scheduler 共用同一 Backend digest、使用不同命令；
- Migration/API/Worker/Scheduler 四个数据库 principal；
- 4 个 HPA、4 个 PDB、7 个 NetworkPolicy；
- Admin/Web OIDC client、redirect、cookie、policy namespace 隔离；
- 严格 TLS 下 Admin 与 Web 均完成 `401 -> 200 -> 204 -> 401`；
- 兼容旧 revision 原生 `rollout undo` 后严格 TLS 200，再按锁定 manifest 前滚；
- 前滚后再次完成双端真实 Casdoor 登录；
- Calico v3.28.2：internal caller 允许、frontend 允许、无标签 caller 拒绝。

## 5. 清理反证与旧拓扑保护

门禁退出后已确认：

- `knowledge-architecture-v2-r4` namespace 不存在；
- `sunmoonai-architecture-v2-r4-knowledge-identity` Secret 不存在；
- `knowledge-r4-policy` KIND 集群不存在；
- `preexisting-topology-before.json` 与 `preexisting-topology-after.json` 的 SHA-256 完全一致；
- 未读取或输出浏览器、Casdoor、数据库或 Harbor 凭据。

## 6. 证据与下一步

源码/同步证据：

- `R4-knowledge-sync-classification.json`
- `evidence/R4-knowledge-plan/`
- `evidence/R4-knowledge-cleanroom/`

集群证据：`evidence/R4-knowledge-gate/`，其中 `result.json`、`kind.json`、`browser.json`、
`browser-after-forward.json`、`rollback.txt`、`network-policy.txt`、`release.json` 和旧拓扑前后快照共同
构成退出证据。

Knowledge R4 关闭后，下一步只允许按同一 R3.2 release 开始 Research R4。R4 全部完成前仍不得
开始 R5、切换现有生产流量、晋级 `2.0.0` 或删除旧数据库/Secret/PVC。
