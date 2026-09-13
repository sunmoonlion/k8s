# B7c：Info 逻辑交付去重

2026-09-13；旧 M1-104 的兼容独立旧账，非新版产品功能，单人 Luna 实施。

## 冻结工作单元与约束

基线 info-app@2b4f18b、info-backend@96e3762、k8s@3fd256ee；云端 master/Luna
已只读确认一致且干净。保留本地两份未跟踪协议草稿，不新建分支。

范围：Info 创建用例、领域 ORM、线性 0009 迁移、只读 preflight、对应测试和说明。
D1/D2 唯一真源仍为 distribution_record，无新台账；D6/D7 更新精确迁移清单；
D8 数据库唯一索引与新写协议字段拒绝旧 INSERT，身份字段不可改写。
C1/C2 继续公共 Outbox/Inbox、原代次幂等及独立显式 retry；C3/C4 跨 App DTO 不变，
回归 Info 消费 Knowledge 契约；I1 复用既有 Admin 用例，无新增业务接口。
T4/T5 子仓先推、父仓锁定，固定 SHA 后快进与脚本同步；R1/R6 Info 领域扩展不改模板。

同版本、目标 App 和 dataset 的创建应返回同一记录；None/空串/default 同义。
复用保留原文件快照、回执、状态和历史；dispatch=True 仅为 pending 确保原代次命令，
不会把 failed/running/succeeded 当新任务启动。数据库锁与唯一索引共同防并发重复。
迁移先锁表核查，存量冲突一律阻断，不自动合并/删除/重键；只读报告样本有界且不含 payload。

## 验收与边界

验收项：真实 PostgreSQL 并发创建、default 别名、不同版本/dataset、手动转投递、
状态/回执/快照不变、显式 retry 代次、过期 ORM 缓存、Outbox 故障原子回滚、
数据库非服务写入唯一性、旧写入与身份改写拒绝、存量冲突阻断、有数据迁移往返、
只读预检、全量 Info PG/S3 与共享契约回归。

业务数据未核查/迁移；实际备份恢复、权限、锁窗口、旧任务分类和运行角色切换仍待验收。
新协议列不是旧 payload 验证证书。没有镜像构建、推送或部署，B7 其它项与 B8 未完成。

## 固定源码验证

Info 后端 `d607d8e90d36ad2f51a006dbb4cec4fda200f1e8`，tree
`d2ce72e2119d906198cdc73feb27fa925473e020`；精确 9 文件，Ruff/Pyright 通过。
完整回归 **351 passed / 0 skipped**（提交前 37.90 秒，固定提交复验 38.79 秒），
比 B7b 增加 31 项。12 个独立 session 并发、提交成功却丢响应、失效 ORM、失败回滚，
NULL/空/default 迁移和直接 SQL 越界写入均验证；原丢回执重投链和 S3 回归保持通过。
Knowledge 未改动固定源码 `40edfc28292964ad18ab5a29d852aa8feeb7043c` 的摄入、授权与
可靠投递配对回归 **78 passed / 0 skipped**（7.80 秒），不是 Knowledge 全量重跑。

测试用真实一次性 PostgreSQL 17.6 和 S3，跨 App schema/锁文件及公共消费向量仍验证。
Provider、身份和外部 HTTP 的受控注入不冒充真实 RAGFlow 或业务授权验收。
首轮旧抓取并发取消用例 consume 返回 False：单独复跑和随后两次全量均未复现；
没有改用例或跳过。根因尚未确定，保留为 B7 运行活性复核线索，不能声称已修复。
新测试初版误用 keyword-only 参数，已修正；备份工具首次缺少容器 TCP 连接参数，
失败后改用显式 localhost/一次性测试凭据复跑通过，没有改业务配置。

实际 `pg_dump -Fc` / `pg_restore --exit-on-error` 从独立测试 schema 的 0008 状态
恢复到新建 `luna_b7c_restore_tests`，归档 49,462 字节；1 条逻辑交付、2 条 Outbox
（索引与分发）完整 JSON 一致，恢复后 0009 升级、重复创建、降级、再升级均通过。
该探针调用迁移函数，不包含 alembic_version；实际 Alembic 版本表/单 head 的往返
由完整回归中的 schema_readiness 用例另验，不能混为同一演练。
恢复测试库和随机 schema 已回收，合成数据可重建；业务备份、旧凭据拒绝和切换仍未验收。

复跑入口：Info 后端 `app` 内运行 Ruff/Pyright 及 pytest，配置
`DELIVERY_TEST_DATABASE_URL` 指向一次性 `*_tests` 库，`ARTIFACT_TEST_S3_ENDPOINT`
指向一次性 S3，`WEB_INTERACTION_CONSUMER_VECTORS` 指向模板的版本化消费向量。
核心新测试为 `tests/test_distribution_identity_db.py`；未修改依赖或现有抓取并发测试。

## 集成游标

Info 父仓 `253869fc67d1fae5bc7336863f6781aaf7513647`；初次文档内容
`k8s@eeb645beb8dc1b311bf3cc4d8e1f7f5300278e42`，4 份文档门禁通过。本节为后续回填。
后端先推既有 master/Luna 引用，再锁父仓 gitlink；本机 master 逐仓核预期旧 HEAD 与
干净状态后快进，Info/k8s 父仓 master/Luna 推送 GitHub/Gitee。
五仓脚本 `remote-pull master` 和 `remote-pull luna` 均退出 0；SSH 再核五父仓干净，
Info 父仓/实际后端、k8s SHA 与本地一致，其余三 App 未改变。

两个一次性 PG/S3 容器按完整 ID 核对后停止，自动移除并复查无残留，仅清理可重建
合成数据。未操作业务库/桶/Secret/应用镜像/部署；两份协议草稿保持未跟踪且未修改。
无新分支、强推或 realign。下一包核 B7 指标/角色活性/归档与运行门禁，不跳过旧账
直接进新功能；B8/N1～N6 的正式接收仍未完成。
