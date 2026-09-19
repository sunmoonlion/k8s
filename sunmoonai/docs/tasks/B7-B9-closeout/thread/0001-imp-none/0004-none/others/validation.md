# 第二批旧材料清理

## 基线与边界

k8s 基线 `6facaaaad8eded7f96ee54c4c62d20ff37cd234d`；五父仓与十二子仓开工时干净。
本轮只在本地 Luna 清理历史文件及引用。用户随后明确：“先提交在 luna，暂不同步”。
不合 master、不推 GitHub/Gitee、不改远端工位，不构建、不部署、不操作业务数据。
子仓沿用既有本地分支，不新增分支；父仓本地提交记录这些子仓对象，尚不能宣称远端可达。
后续获得同步授权后必须先推九个子仓，再推父仓 gitlink，不能直接运行五仓推送脚本。

## 交付与检查

- 精确删除 113 个受跟踪文件：旧 v5 目录 111 个，旧 v2 重构计划与 Provider 实施报告各 1 个。
  均可从上述固定 k8s 提交恢复，没有另建备份目录。
- `architecture-v2/`、`evidence/`、此前三个冻结 turn 与基线相比无改动。
- 按路径及全部旧脚本文件名搜索五仓（含隐藏配置，排除依赖/生成目录），未见现行代码
  调用旧 v5 脚本。历史证据里的命令保留原文，按原提交解释。
- 必要结论及完整原文查询入口进入 `legacy-backlog/verification-index.md`；不把旧 R5 状态
  当当前断点，不将内部 Provider Port 说成已接 WeKnora 或已部署。
- 修复 k8s 活动入口、模板 README、八个前端 README 和 Knowledge Backend 文档引用。
  Luna 根目录保留的“专业Agent与业务编排架构决策分析.md”只修一处旧 ADR 链接，
  该文件在五仓之外，不能通过父仓提交或 five-repos-sync 同步；其余正文未改。
- k8s `doc-gate.py --staged`：5 份活动文档、18 个 turn 检查通过；
  `--all`：136 份活动文档通过，52 份冻结 thread 副本豁免。
- 四父仓及九子仓 `git diff --check` 通过；子仓逐一检查提交只含指定 Markdown。
  本轮未改应用/部署实现，不重跑业务测试、不将历史测试数字写成本轮运行结果。

## 规则与恢复

T4/T5：逐仓固定本地提交；用户明确暂不同步，所有新对象只保证本机可达，未来子仓先推。
R1/R2/R5：源码与运行态分开，本轮不涉及发布 tag、镜像、迁移、凭据或集群。
既有架构规则及发布工具不变；architecture-v2 工具与历史材料分离留到单独一轮。
恢复按固定 Git 快照取指定文件或反向提交，不 reset 其它工作、不恢复旧部署到当前环境。

## 本地固定提交

| 父仓（luna） | 交付提交 |
| --- | --- |
| k8s | `74053a1141d495a48363cb0158f2b6fcd7d1e671`（清理与引用正文；本回执随后单独提交） |
| tpl-app | `1d2995765b9742ad4da31d30e9e746008fff1387` |
| info-app | `43e0b1e113cbc900c5e18fa4eddb6316e776eb0c` |
| knowledge-app | `ad96ad07dbebc3e795be2c05f32c4f5111a31a4f` |
| investment-app | `c33654397b4a47a8a7e7b23c81076a73447ca9b8` |

九个文档子仓的新提交由上述父仓 gitlink 精确锁定；均仅变更 README 或 Provider Markdown。
五仓提交后工作区干净，实际子模块 HEAD 与 gitlink 一致。无远端推送或 master 合并。
加入验证附件后再次 `doc-gate.py --all` 通过：136 份活动文档、53 份 thread 豁免。

## 只读远端预检的已知缺口

在用户选择暂不同步之前启动的只读基线检查，于第二个远端因不一致退出，未执行写入。
复查确认 GitHub `tpl-admin-frontend/master` 为 `3c8727fc827dddab875bfe65e7d46210cd588c66`，
Gitee 同分支为 `a6b25db7c152cf5e3c1ae9aa0fcddad5fd47ec58`。
`git rev-list --left-right --count <Gitee>...<GitHub>` 为 `0 3`：Gitee 是祖先，落后三个提交，
不是分叉或网络失败。本轮仅记录，不补推；其余八个子仓远端尚未逐一核验。
此前“全量同步已验证”的范围是五父仓分支与两端实际子模块，不应推导成每个子仓的
GitHub/Gitee master 分支也相等。未来同步先全面核子仓实时引用及权限，再做普通快进推送。
