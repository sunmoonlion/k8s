# 本地 KIND 部署准备与同步取证

2026-09-19，继续 0008 的五仓同步与本地 KIND 部署；此前用户明确允许本地 KIND 维护窗口。
本次知识库授权只绑定 `codex-smoke → fee8dcdc7cc611f1a85655b688ac3ca7 / codex-smoke`，
不新增知识库、不自动重放历史任务。此处是对话授权的 reported 记录，不冒称 attested。

## 已执行的同步与清理

`five-repos-sync/sync-five-repos.sh to-remote -all` 已退出 0。随后分别重新读取本地/云端
master、cursor、kimi、luna、opus、qwen 的五父仓：分支名、HEAD、干净状态、实际递归
子模块 gitlink 与子仓干净状态均匹配。GitHub/Gitee 的五仓六分支也以 `ls-remote` 重核。

| 仓 | 本次同步提交 |
| --- | --- |
| tpl-app | a53d565bdbe4683daeddaeca9f7cc482455132a1 |
| info-app | 372a698126991dbe27376193e12f9c4f1cb72a1c |
| knowledge-app | 4799485468b331ec4c2808417ff9f7ca2ab714e5 |
| investment-app | f0b63481aec4d3d0ae1114b3122b29175bc03cc9 |
| k8s | 8e3146b829beb0c4704cfa66ac729197100297f9 |

本文件及后续部署准备是该基线之后的新工作，不能据上表声称它们已同步。
十二子仓先已普通推送至两端 master；不新建分支、不 force/reset/realign。
修正了 Gitee 八个前端 master 原先落后问题。

同步中首次 `submodule update --no-fetch` 失败：master 的独立子模块对象库没有 Luna 新
对象。核实只有父仓 gitlink 与子仓 HEAD 的差异且子仓无修改后，允许正常 fetch 修复，
再完成快进与同步。云端只读核验首次因未安装 rg 导致子模块筛查未生效，该次输出不采信；
改用 grep 后完整重跑通过。没有把工具失败记成业务通过。

用户另行确认后，实际删除 master 中被 Git 忽略的历史残留：architecture-v2 的 4 SQL、
6 pyc；evidence 的 17 log；mooc-manus-v5 的 3 pyc，三个目录及空父目录已消失。
此前只核 Git 跟踪文件而漏核 ignored 文件，不能声称普通同步能删除这类残留。
这些未跟踪文件未备份，不能保证从 Git 恢复；未删除业务数据库、对象或镜像。

## 当前运行态：只读核验

显式 kubeconfig `/home/zymun/.kube/kind-config`、context `kind-kind`，节点 providerID
均为 kind://。namespace 是 `app-platform-dev`；三 App API 2、Worker 1、Scheduler 1
均 ready；没有缩容、迁移或改写 Secret。question-data、Casdoor、RAGFlow 不在切换范围。

| App | 实际数据库 | 当前登录 | 实际 Alembic revision |
| --- | --- | --- | --- |
| Info | info_admin | info_backend_user | 20260911_0007 |
| Knowledge | knowledge_admin | knowledge_backend_user | 20260911_0006 |
| Investment | investment_admin | investment_backend_user | 20260911_0007 |

上述查询为 REPEATABLE READ / READ ONLY 事务，输出只有目录和聚合；表 owner 均为对应
`*_backend_user_migration`。新 `*-backend-runtime` Secret 尚不存在，旧三个运行角色仍引用
共享键；不得复制同一 URL 冒充独立身份。

Info 以本次锁定源码的 0008/0009 预检实现通过 stdin 在旧 API 中执行（未写容器文件）：
canonical identity 28 行、invalid=0、duplicate_groups=0、normalization_changes=0；
distribution 38 行、conflicting_groups=0，两项 ready=true；事务 read_only=on。
这不是已执行迁移，切换前仍须静止窗口重新审计。

Knowledge API 生效环境没有 INGESTION_DATASET_BINDINGS，检索 allowlist 为 codex-smoke。
通过现有 Provider 身份 GET /api/v1/datasets，total=6，本页=6，唯一 codex-smoke 的 ID
与上方授权相符。仅列名称/ID，没有上传、解析、删除文档。

## 准备中的制品与门禁

本次脚本普通测试 `python3 -B -m unittest discover -s
sunmoonai/app-platform/scripts/tests -p 'test_*.py' -v`：45 passed，含 13 项保留验证工具
内层回归；不是业务运行验收。

构建候选 tag：`kind-b7-closeout-20260919-135549`。调用既有 build-push-app-images.sh，
SOURCE_ROOT=Luna、CLUSTER=KIND、12 组件、使用缓存、保留内置 lint/format/typecheck。
目标只为本机 Harbor，不覆盖 1.0.0/2.0.0；构建完成和实际 digest 必须另核，不能提前认定。

后续实测：构建脚本已退出 0，12 镜像均成功。逐一用 `docker buildx imagetools inspect`
从 Harbor 重取 manifest digest，与源码提交一起保存在 [候选清单](image-candidate.json)。
该清单不是部署 release，业务 Pod 仍为旧镜像，未推送 C1 Harbor。

Knowledge renderer 现已新增 `--ingestion-dataset-bindings-file`，复用 Backend 严格解析器，
无输入默认为空，不从检索白名单推导。获准映射存入 deployment 下 KIND JSON；渲染将其
写入 ConfigMap、更新运行配置摘要并记录输入/解析器摘要。新增 3 项测试通过，普通套件
合计 48 passed。尚未生成或应用新的规范 bundle。

数据库管理员只读目录检查：三个库 owner 均为对应 migration 角色；现有业务角色无
超级用户/建库/建角色/bypassrls，未发现角色继承；数据库 PUBLIC 仍有 CONNECT/TEMP，
需在切换设计中收敛，不能仅追加新 GRANT。broker 当前分别为 info-development /
knowledge-development / investment-development，队列 info.admin.default /
knowledge.admin.default / investment.default，结果后端均未配置。
当前共享用户分别为 info-admin-backend-worker / knowledge-admin-backend-worker /
investment-backend-worker；其它 tools/research/admin 用户仍存在，不属于自动清理范围。

## 尚待完成，不允许绕过

1. 固定新 source locks、镜像 digest、开发 bundle 与精确回滚对象；当前锁与旧 bundle 仍旧。
2. 获准的摄入绑定已接入 renderer，下一步在新规范 bundle 中显式选用并验证生效。
3. 独立数据库/broker 身份供给、封闭 PUBLIC/default ACL、共享启动 definitions 保留非目标
   条目与一致性、旧连接撤销及回滚。现有 policy 是纯编译器，不是业务 provisioner。
4. Investment deploy.py 仍自动运行历史 prepare-investment-broker-kind.sh 并改变 LOGIN；
   不得直接执行该旧入口作为新角色切换。必须先修正/审查明确的开发发布路径。
5. 实际业务备份与隔离恢复、迁移及回退演练、必要对象备份；不能拿合成测试代替。
6. 固定制品和受控切换方案后再维护、Info→Knowledge→Investment 串行验证；一项失败停止。
7. 本次切换、真实 Provider 回执、浏览器全旅程和 Calico 包级门禁均尚未执行。

约束自检：D1–D9 保留各域主档、独立库/角色和独立迁移 Job，不清账或隐式迁移；
I3/I8 不复用浏览器、服务、数据库身份，配置不满足即拒绝；T3–T5 四运行角色、子仓先推、
提交逐仓列明；R1–R7 源码/镜像/数据共同固定、只用 digest、保持正式版本与模板优先。
