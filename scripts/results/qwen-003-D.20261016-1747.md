# qwen-003-D（Qwen，本地机）总回执 — D0–D8 全过，停此等 Opus 审

- 分支 `qwen`；起点 `90b01d01`，期间 pull `37fec280`（D1 改 https）→ `26eb5aed`（补三目录）→ `a11bcf14`（nsenter OBJECT 透传修复）；本段产出提交 `242f9034`（deploy）与 `2d4325ac`（晋级到 242f9034），均已双推 GitHub+gitee。执行者：Qwen（本地机），2026-10-16 16:08–17:47。
- 结论：**D0–D8 全部通过**（含两次历史停点，均为卡/平台侧问题、修复后原样重跑通过）；工作区干净；口令、令牌未出现在任何命令输出与本回执。

## D0 前提

- `~/five-repos-sync/config.sh` REPOS 含 `"knowlab-app"`、`"knowmart-app"`（24/25 行）。
- toolboxes `repos.conf` 两行经授权代加后，所有者 pull 被挡；逐字比对（blob `c83c111..4118c83` 一致）后 checkout 还原 + pull fast-forward 到 `43ae1d3`，零丢失。

## D1 挂两新仓 — 全过

- 首跑（SSH 地址版）STOP：github.com:22 超时；只读诊断（HTTPS 代理通、ssh.github.com:443 通）上报后 Opus 改卡 https（`37fec280`）。
- 重跑：**10 行 mounted**（knowlab 五工位 `a7d9e71`、knowmart 五工位 `3377874`）；align list 过滤后除 `list-done` 零输出。

## D2 现有应用零变动 — 两停点后全过

- 停点一：stage graph 报两新 backend 缺 `database` 目录（C 段漏交）→ `26eb5aed` 补 database/migration/redis。
- 停点二：tpl stage 读 knowlab `image.lock.yaml` File not found；根因非缺锁——nsenter 模式下 sudo 清环境、OBJECT 未透传，按 all 跑 → `a11bcf14` 修。
- **D2-0 只读证据**（`a11bcf14` 后）：`ns differ（nsenter 模式）`；选择文件清单含 `10-16_16:45 all.json/all.mk`（旧 all 选择残留，坐实根因）；`make -n` 输出 `OBJECT="$OBJECT"`（透传已生效）；`d2-0-done`。
- **D2 重跑全过**：topology + tpl/knowfeed/knowbase/investment 五处 exit=0、零 fatal；git status 汇总仅 `1 clusters/kind`（stages.yaml），四现有应用零行。

## D2b 待办 97 修法实跑 — 全过

`ragflow exit=0`（不再报 `'valkey_credentials' is undefined`）；`status-done` 前 git status 零行（ragflow、valkey 文件不变）。

## D3 构建并 stage 两新应用 — 全过

- 两 build、两 stage、两 plan 六个 exit=0。
- git status 汇总：`clusters/kind` + 两新应用六目录共 58 个新文件（`image.lock.yaml` ×6、`workload.yaml` ×16、`*.sops.yaml` ×20）；现有四应用零行。
- `key-check-done` 前无任何文件名（无明文 PRIVATE/PUBLIC KEY）。
- `sudo ls /etc/sunmoon/applications/sunmoon-kind/`：investment knowbase knowfeed **knowlab knowmart** tpl。

## D4 提交、发布、晋级 — 全过

- `242f9034` deploy（59 files +3104）；flux-release exit=0；flux-source.yaml tee+chown（1 file 2+/2−）；`2d4325ac` 晋级到 242f9034；flux-source-apply exit=0。
- `wait exit=0`：knowlab/knowmart 各 8 个 kustomization（admin/database/identity/migration/rabbitmq/redis/runtime/web）全部 condition met。
- `get kustomizations | grep -v True` 只剩表头 `NAME AGE READY STATUS`。
- push 双远程成功（`a11bcf14..2d4325ac` ×2）。

## D5 入口分流 — 全过

- entry-plan 见 `item=knowlab`、`item=knowmart` 及四域名（knowlab/knowlab-admin/knowmart/knowmart-admin.sunmoonai.com）。
- preview/stop/deploy/status 四个 exit=0；四段 PLAY RECAP 均 failed=0；entry-status 见 HAProxy `ActiveState=active, SubState=running`。

## D6 Windows hosts 四域名 — 全过

- 演练：exit=0；diff 真 hosts 与演练副本仅多一行 `127.0.0.1 knowlab.sunmoonai.com knowlab-admin.sunmoonai.com knowmart.sunmoonai.com knowmart-admin.sunmoonai.com`。
- 真改（UAC 所有者点「是」）：备份 `hosts.bak-add-20261016-173856`；真 hosts 末行即上述四域名行；结果文件 iconv 后 added 四域名、active 行清单照实。
- 演练残件（rehearsal/bak-add-*/rehearsal.txt）已 rm，复核无残留。

## D7 检查 — 全过

六应用 application-check（tpl/knowfeed/knowbase/investment/knowlab/knowmart）+ platform-status 共**七个 exit=0**，零 fatal。

## D8 浏览器（所有者登录，Qwen 核截图）— 全过

四张截图，地址栏均无 `code=` 等回跳参数：

1. `https://knowlab.sunmoonai.com:30443/zh-CN/dashboard`：「控制台 / 欢迎使用 knowlab 应用 / 当前用户：sig-am」——进 dashboard。
2. `https://knowmart.sunmoonai.com:30443/zh-CN/dashboard`：「控制台 / 欢迎使用 knowmart 应用 / 当前用户：sig-am」——进 dashboard。
3. `https://knowlab-admin.sunmoonai.com:30443/zh-CN/dashboard`：SunmoonAI Admin 侧栏「治理控制台/设置」，「治理控制台 / 欢迎使用 SunmoonAI 管理后台 / 当前管理员：admin」，含「管理能力迁移中枢 P0-007E」占位卡片——进治理控制台。
4. `https://knowmart-admin.sunmoonai.com:30443/zh-CN/dashboard`：同 3（knowmart）——进治理控制台。

照实记录一处：网页端当前用户为 **sig-am**（sunmoonai 组织普通用户，R5.3 起网页端在用的账号），非字面用户名「sunmoonai」；管理端 admin 与卡一致。留 Opus 审定夺是否需换账号复截。

## 收尾

- 一次性脚本已删（用完即删）：`d1-mount.sh`、`d2-stage-existing.sh`、`d2-0-evidence.sh`、`d2b-ragflow.sh`、`d3-build-new-apps.sh`、`d4-release-promote.sh`、`d5-entry.sh`、`d6-rehearsal.sh`、`d6-apply.sh`、`d7-check.sh`（共 10 个，均在 ~/worktrees/qwen/ 顶层）；`~/worktrees/qwen/` 只剩六仓检出加两新仓检出。
- 未做：业务功能、公网边缘、对外上架（卡「不做的」节）。

exit=0（D0–D8 全过；D8 截图核验通过，网页端用户名 sig-am 照实记录）
