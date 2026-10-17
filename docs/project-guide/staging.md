# 接下来做什么

> 计划，不是进度。最后更新 2026-10-17，按所有者定的顺序；做到哪了从 Git、派活卡与回执推出来。旧的分期与人周粗估（2026-09-23，按「顾问」定位）已作废，见 Git 历史。

| 顺序 | 做什么 | 依据 |
| --- | --- | --- |
| 1 | 建 `knowlab-app` 与 `knowmart-app`（私有模式）：建仓、由 tpl-app 实例化、跑通空应用的部署（2026-10-16 已做） | [0026](../dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)、[0018](../dev-investment-agent/tree-build/SDD/modules/0018-advisor-market.md) |
| 2 | knowlab 的第一个真功能：受理一个想法和一份数据，做成分身；knowmart 登记、按所有者列出、给工作台的「请」接口；有人值守的测试、运行时读用户数据（0027 P1–P5 代码已写，未部署） | 0026「二」「一之二」；设计 [0027](../dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md) |
| 2½ | 改名：工作台 investment → knowbench、本地代理仓 runtime → sunmoon-link（所有者 2026-10-17 定「先改名」）；仓与检出先改，并 master、两台机器对齐后解除冻结；集群切换（R5）并进下一行的 P6 | [0028](../dev-investment-agent/tree-build/SDD/modules/0028-knowbench-rename.md)、执行手册 `k8s/docs/rename.md` |
| 2¾ | 0027 P6：一次发布 P1–P5 与改名后的 knowbench（新域名、新 Windows 与 Linux 安装包、命令改名 sunmoon-link、重装代理与配对、测试账号与测试电脑），浏览器走一遍；之后下线改名前的对象（0028 R6） | 0027「八」、0028「五」 |
| 3 | 我们以普通用户身份做分身「中国A股上市公司财务分析与预测」（600009、600519 的财报作为这个用户上传的数据） | [0023](../dev-investment-agent/tree-build/SDD/modules/0023-fin-forecast.md) |
| 3½ | **核心能力：从想法或 skill 写出专家包（pack）**——现在空白、靠手写；第一条实测时 Opus 手写并记下样板，走通后定做法（拟 SDD 0029） | [待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 119 |
| 4 | 工作台对用户开放前的检查：「专家」改叫「分身」；内置专家包改为归属用户（撤掉「问数」「财报体检」）；沙箱默认不接 knowbase 数据服务；管理端角色白名单 | 0026「四」、[待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 98 |
| 5 | 对外收费前取得书面法律意见；生成式 AI 备案或登记、ICP 许可 | 0026「五」 |
| 随时 | 组件 prepare 顺序隐患；admin 旧沙箱回收（0014 U4）（本地代理命令与安装包改名 `sunmoon-link` 已排进 2¾） | [决策](../dev-investment-agent/tree-build/decisions.md)、[待办账](../dev-investment-agent/tree-build/pending-after-migration.md) 97、99 |
| 持牌后 | knowmart 对外：有资格的开发者把分身上架给别人用 | 0018 |
