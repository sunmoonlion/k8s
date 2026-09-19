# 文档清理与指南更新的验证

基线 k8s `6757974b4084c92c8df62af637b020d998d4a160`，现有 Luna。
用户批准先收拢有效内容、删除旧散文档并更新 project-guide，再合 master、同步五仓，最后部署。

## 实施范围

- 删除根 docs 下 24 份 `v5-backlog-*-luna.md` 及四份明确的旧 v4/v5 计划/实施/handoff，
  删除前逐目标与上述固定提交比对无差异；精确文件名在活动验证索引中可重建。
- 新的活动入口为 `legacy-backlog/README.md`、`deployment-checklist.md`、
  `verification-index.md`；旧任务、运行欠账、历史证据分开，未删除业务资料或代码。
- 指南明确 Next/FastAPI 现状、可靠投递与 Provider Port 源码已接线、隔离验证不等于部署；
  三部分职责仍保留 B-S，桌面/runtime 未被写成现有实现。
- 现场发布锁只读核验：三 App 当前 bundle 均 `formal_release=false`、`deployment_target=KIND`，
  修正原指南“全部 formal=true”的错误；Knowledge 指南改为当前 Provider 名称过滤及 ArtifactError。
- 修正活动链接及旧设计输入指针，不改产品合同、正式模块划分、既有已冻结 turn 或当前应用源码。
  老 `mooc-manus-v5` 文字门禁只在历史 checkout 重放，不作为当前发布入口；没有篡改该历史脚本。
- 其他仓的历史修复/对齐记录仍保持原文；需要其引用的旧 k8s 文件时按固定 Git 索引读取。

## 检查结果

1. `doc-gate.py --staged`：16 份活动文档、17 个 turn 编号/字段/冻结检查通过。
2. `doc-gate.py --all`：151 份活动文档通过；49 份 thread 冻结副本按既有规则豁免；
   不宣称冻结副本的旧相对链接在当前工作树全部可用。
3. 四后端 `tests/test_dormant_capabilities.py` 串行：tpl 6、Info 12、Knowledge 7、
   Investment 19，合计 44 passed；源码未改，不冒称重新执行完整后端/真实 Provider/部署验收。
4. 活动 Markdown（排除冻结 thread 与专门历史文件名索引）已无被删除文件名引用；
   `git diff --cached --check` 通过。旧文件的完整原文仍可从基线取回。

## 同步及发布边界

`status -all` 已只读检查两端六工位五仓：除本轮 Luna 正在形成的文档修改外未见脏工作区。
核对时 tpl Luna 多一个已验证测试提交 `09ff4a9`；k8s master 独有 `42a71bfe` 的
question-data-demo，Luna 有本轮文档提交；其它工位没有应丢弃的独有改动。
后续集成保留双方内容，只做普通 merge/快进；同步前重新核 SHA、远端与子模块。
这里是预检，不提前宣称 master/远端已同步，也不授权未经固定版本的业务数据操作。

约束：D1/D2/D8 无业务库/迁移改动；T4/T5 逐仓固定对象、子模块可达；R1/R2/R5
源码同步不冒充镜像或部署，无构建、Harbor 或集群写入。回滚为反向文档提交/按 Git
基线恢复指定文件，不使用 reset 丢分支；同步之后不能把恢复文档冒充回滚业务数据。
