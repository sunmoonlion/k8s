# Investment 旧改名文档删除回执

- 删除前 k8s 与 Investment 的 luna 工作区干净；目标文档与固定历史提交
  `6facaaaad8eded7f96ee54c4c62d20ff37cd234d` 的原文一致，可按验证索引恢复。
- 删除一份已完成的历史实施方案，修正 R4 历史 runbook 与 Investment 构建文档两处引用。
  `architecture-v2/` 仅修改这一处文档指针，不删目录、不修改脚本或证据。
- k8s 正文提交 `c9fedb51774353ab479243ceac06ad78809b3b9e`；
  Investment 引用提交 `eb4ada1f694b5c2dc12411d9994f0ae7b5f4775c`。
- `doc-gate.py --staged` 两份活动文档、19 个 turn 检查通过；
  `--all` 135 份活动文档通过。两仓 diff whitespace 检查通过，无代码修改，不跑业务测试。
- 初次提交命令在 k8s 目录错误使用相对 Investment 路径，未改动该仓；已改绝对路径完成提交。
- 沿用用户决定：只在本地 luna 提交，不合 master、不推送、不部署；不修改业务数据或历史备份。
  T5 逐仓记录提交，R1 源码/文档与实际运行分开，不据文档删除宣布重构已部署。
