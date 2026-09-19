# Architecture v2 目录清退与工具迁移

## 对象与恢复

基线 k8s `82c709705aa92b1b44d9913b4416d4ca505a6665`，Luna，开工时干净。
旧目录 301 个受跟踪文件：迁移 7 个工具/测试，其余 294 个退出当前工作树。
完整文件清单、正文、SQL、锁文件、发布证据可从上述固定提交取回，不建第二份备份目录。
另清除原目录三份自动生成的 Python 字节码及空目录；字节码可重新生成。
删除的是源码工作树材料，不操作 Harbor、业务集群/备份、数据库、Secret 或凭据。

## 分类与实现

- 迁到 `sunmoonai/app-platform/scripts/validation/`：Calico shell、DNS/结果判定两依赖、
  Calico 测试、模板三方同步及测试、源码运行角色拓扑检查，共 7 个文件。
- 前 6 个文件与原 Git blob 逐字一致，两个原 executable 文件保留 100755 模式。
  相对层级相同，拓扑脚本默认 workspace 定位经实际运行验证，不指向 master 或旧目录。
- 保留原 CLI/环境变量；模板同步仍要求明确 base/target/instance/config，不拿历史分类 JSON
  自动写当前实例。`plan` 与 `apply` 边界不变，本轮没有调用真实实例 apply。
- 旧 capability 校验依赖已退役的双 Backend；旧 R7 固定旧迁移 head 且要求正式包。
  不把历史切流、供给、删除、发布脚本迁为当前开发门禁。指南据源码纠正这些过时入口。
- 真实浏览器、跨 App、故障/回滚和网络验收要求不删；本轮离线验证不能替代本次发布验收。
- `tpl-app/template-release-manifest.json` 字节不变；九个 test_evidence 路径逐一验证
  可在固定 k8s 快照解析，索引/模板 README 明确它们是历史路径，不伪装当前文件路径。
- 修改四后端 kernel invariant 测试的历史路径说明，未改断言；Investment Backend 另改文档入口。
  冻结 turn 不改，现行 bundle/source lock/保护 tag 不变。

## 失败根因与修正

第一次拓扑检查报告 `dev-to-prod-deploy` 禁止目录存在。读取目录与模板 README 确认该目录
已恢复为纯 Markdown 操作手册，不是旧部署工具。根因是旧检查只按目录名判错。
检查改为允许纯文档、拒绝非 Markdown、可执行文件和软链接；临时目录正负测试与当前
五仓拓扑检查均通过。不是删除现有手册，也不是放宽旧 Worker/Backend 拓扑限制。

## 验证结果

- `python3 -m unittest discover -s sunmoonai/app-platform/scripts/tests -v`：45 passed；
  其中一个常规测试入口实际运行迁移工具原有 13 个回归，防止迁移后测试失联。
- 新入口还测从 `/tmp` 执行两个 CLI 的 `--help`，以及手册正例/脚本/可执行/软链反例。
- `python3 sunmoonai/app-platform/scripts/validation/verify_runtime_role_topology.py`：passed。
- 四后端 `tests/test_kernel_invariants.py`：tpl 5、Info 6、Knowledge 6、Investment 6，合计 23 passed。
- Calico 与构建 shell 的 `bash -n`、diff whitespace 检查通过；没有运行真实 Calico/Docker/集群。
- 暂存区文档门禁：4 份活动文档与 20 个 turn 检查通过；全部 113 份活动文档通过。
  门禁范围外的 scripts README/validation README 另调用同一链接/表格校验器通过，
  不将默认门禁显示“0 份”误说成已经检查这两份文件。
- 扫描旧脚本名及旧目录路径：保留工具调用已迁移；旧路径仅作为冻结 manifest/回执/证据
  或显式 Git 历史查询存在。旧目录本身不再存在。

## 本地父仓交付

| 仓 | 本轮提交 |
| --- | --- |
| tpl-app | `a53d565bdbe4683daeddaeca9f7cc482455132a1` |
| info-app | `372a698126991dbe27376193e12f9c4f1cb72a1c` |
| knowledge-app | `4799485468b331ec4c2808417ff9f7ca2ab714e5` |
| investment-app | `f0b63481aec4d3d0ae1114b3122b29175bc03cc9` |

四后端新对象由父仓 gitlink 固定；k8s 正文提交见本 turn 的回执。
T4/T5：遵照用户暂不同步要求，新对象仅保证本地可达；下次须先推子仓再推父仓，不能直接
用 five-repos-sync 跳过子仓。R1/R2/R5：不改 release tuple，不将本轮测试当运行发布证据。
恢复可反向本轮提交或按固定快照取指定文件，不 reset 他人工位或执行历史回滚脚本。
