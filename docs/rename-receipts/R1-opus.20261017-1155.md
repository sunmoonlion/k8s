# rename（0028）R1 回执 — Opus（远程机 qwen 工位）

- 手册 `docs/rename.md` R1；工具 `docs/rename-tools/`（`rename_rules.py`、`r1_apply.py`、`manual_patch.py`、`residual.py`），工具提交 `8204fd7a`。
- 时间：2026-10-17。

## 先在草稿上验（`~/rename-lab`，从 origin 复刻的八组仓含子仓）

| 项 | 结果 |
| --- | --- |
| 改名计划 | 父仓里 `git mv` 3 个子仓目录（`investment-*` → `knowbench-*`）；k8s 路径改名 64 个（gitops 组件目录、knowlab 的 `knowbench-testrun-identity/`、`repos/knowbench-app.md`；历史记录不按自己的名字改） |
| 内容替换 | 418 个文件；`runtime 仓` 规则逐行人工过（只改指仓的写法，清单 `runtime` 字段、gitops `runtime/` 目录不碰） |
| 手工补丁 | 三个同步脚本里裸词 runtime 11 处；拓扑说明删「将改名 agent」；knowbase 检索契约清单重算 1 个摘要（示例请求里 `policy_version`）；knowfeed 管理端预览样例跨应用来源 4 处 |
| k8s 收尾 | knowbench 组件目录旧 `*.sops.yaml` 15 个 `git rm` |
| 残留 | `residual.py`：0 行 |
| 后端（连临时库全量，一个一个跑） | knowbench 1151、knowlab 459、knowmart 403、knowbase 988、knowfeed 1170、tpl 352，全过；pyright 改名前后报错数相同（knowbench 原有 4，其余 0）；ruff 报的行宽问题改名前就有，没有新增 |
| 前端（装依赖、tsc、vitest） | knowbench 网页 268、管理端 61；knowlab 92 / 51；knowmart 89；knowbase 92 / 85；knowfeed 92 / 71；tpl 83，全过；tsc 全 0；prettier 的格式提示与改名前同数 |
| k8s 测试 | applications、cluster、relay、provisioner、agent-releases 五组：失败项改名前后逐条相同（缺 websockets、一条过时测试等原有环境问题），没有新增 |
| runtime | agent 单测 317 过、6 失败，改名前后同样 6 条（cli 测试，原有）；distribution 51 项 0 失败 |

## 真工位执行

`r1_apply.py ~/worktrees/qwen`：输出与草稿相同；`residual.py` 0 行；26 个仓（8 父仓 + 18 子仓中有改动的）逐仓对比 `git diff HEAD` 与草稿参照**内容逐字相同**（只有终端里中文文件名的转义显示不同）。旧 gitops 目录里只剩 Python 缓存，已删。

另：knowlab 后端一条测试说明的行宽（P5 时留下的），单独提交。

## 推送（先子仓后父仓，只推 qwen；仓名仍是旧的）

| 仓 | 提交 |
| --- | --- |
| investment-app / knowbench-backend、knowbench-web-frontend、knowbench-admin-frontend | `cc95605`、`ceb3087`、`45fcf79` |
| investment-app（GitHub 与 gitee 两个推送地址） | `3fa5a54` |
| tpl-app / tpl-backend、tpl-web-frontend；父仓 | `ab71393`、`479c7e6`；`65b8b11` |
| knowfeed-app / backend、web、admin；父仓 | `5a287ac`、`4cc0125`、`0ca833a`；`cf687a0` |
| knowbase-app / backend、web、admin；父仓 | `6d71e10`、`31389c7`、`9c9121d`；`25942e2` |
| knowlab-app / backend（含行宽）、web、admin；父仓 | `8731c9d`、`46b1b5c`、`371abce`；`2011125` |
| knowmart-app / backend、web；父仓 | `bfeb2ae`、`170d35b`；`fcf8613` |
| runtime | `130c966` |
| k8s | `806e66ec` |

推后核对：八组仓与全部子仓 `origin/qwen..HEAD` 为 0。

## gitee 现状（只读核对，给 R2 用）

- `investment-app`：与 GitHub 一致（`master 70af7cff`、`qwen 3fa5a549`）。
- 三个子仓：gitee 上是旧内容（`investment-backend` master `01d09740` / qwen `4d987c19`，GitHub 是 `9195b1bb` / `cc95605c`；另两个同样落后），日常只推 GitHub。
- `runtime`：gitee 上的仓是空的（0 个分支），两台机器的 runtime 都没配 gitee remote。

exit=0
