# qwen-003-D（Qwen，本地机）— D1 全过；D2 STOP（C 段登记缺 database 目录），停在此等 Opus

- 分支：`qwen`，起点 `90b01d01`，D1 前 pull 到 `37fec280`（「D1 本地机地址改用 https」）。执行者：Qwen（本地机）。时间 2026-10-16 16:08–16:33。
- 结论：**D0 闭环、D1 全过（10 行 mounted）；D2 第一条 `topology-stage` 即 exit=2，按规矩停**——不修、不重跑，D3–D8 未做。失败后 `git status` 0 改动（stage 在收集阶段即失败，未写入任何 gitops 文件）。

## D0 前提（含一处事故与处置）

- `~/five-repos-sync/config.sh` REPOS 已含 `"knowlab-app"`、`"knowmart-app"`（24/25 行，所有者先已加好）。
- `toolboxes` 的 `repos.conf`：本机原缺两行，经所有者授权由 Qwen 在工作区代加（不碰 toolboxes 的 git）；随后所有者在 toolboxes 手动 `git pull` 拉远程机 `43ae1d3`（同一改动）被本地未提交改动挡住。经逐字比对（本地 diff 与远端 diff 相同，blob `c83c111..4118c83` 一致），Qwen `git checkout --` 还原本地那份后 pull fast-forward 到 `43ae1d3`，零丢失；`tail -3` 复核两行仍在（已提交版本）。toolboxes 工作区剩一处他人改动 `sunmoon-hosts-schemes.txt`，未碰。

## D1 本地机挂上两个新仓 — 全过

- 首跑（卡 `90b01d01` 版，SSH 地址）：`ssh: connect to host github.com port 22: Connection timed out` → `STOP clone knowlab`，零残留。只读诊断：本机 GitHub 仅 HTTPS 代理通（`http.proxy → 192.168.32.1:7890`）、22 直连超时、`ssh.github.com:443` 通；上报后 Opus 改卡为 https（`37fec280`）。
- 重跑（https 版脚本与卡 58–72 行 diff=0）：**10 行 mounted**——knowlab 五工位全 `a7d9e71`、knowmart 五工位全 `3377874`（与建仓核对时的 master HEAD 一致）；随后 k8s pull `Already up to date`（`37fec280`）；`align_workstations.sh list` 过滤 knowlab/knowmart 后**除 `list-done` 零输出**。符合「要看到」。

## D2 现有应用一个都不变 — STOP（原样）

脚本与卡 80–85 行 diff=0。输出关键行：

```
make: *** [Makefile:392: topology-stage] Error 2
topology exit=2
===== stage app-platform/tpl-app
fatal: [localhost]: FAILED! => {... "cmd": [.../components/stages.py graph ...], "rc": 1,
 "stderr": "stage graph: app-platform/knowlab-app/knowlab-backend/stage.yaml stage knowlab-database path app-platform/knowlab-app/knowlab-backend/database does not exist" ...}
PLAY RECAP: localhost ok=1 changed=0 unreachable=0 failed=1
make: *** [Makefile:406: platform-selection] Error 2
exit=2
```

- `topology-stage OBJECT=all` 与 `platform-stage OBJECT=app-platform/tpl-app` 两处 fatal 是**同一错误**（stages.py graph 收集全树时失败）；tpl 失败即 break，knowfeed/knowbase/investment 三个未跑；「git status 汇总」行未执行到。
- **根因（只读核实，未动任何文件）**：C 段提交 `90b01d01` 登记的 `knowlab-backend/stage.yaml` 第 7–8 行声明 stage `knowlab-database → path: database`，但 `gitops/components/app-platform/knowlab-app/knowlab-backend/` 下只有 `README.md、config.yaml、identity、rabbitmq、runtime、stage.yaml`，**无 `database/` 目录**；`knowmart-backend` 同病（stage.yaml 同样声明 `knowmart-database → path: database`，目录同缺）。对照四个现有应用 backend **都有 `database/`** 目录。
- 待 Opus 处置（二选一，Qwen 不自修）：补交两个 `database/` 目录（对齐现有应用形态），或改两份 stage.yaml 去掉 database 声明。修好后 Qwen pull 重跑 D2 起。

## 其他

- 未跑 `platform-stage OBJECT=all`（卡明令）；未做 D3–D8。
- 口令、令牌未出现在任何命令输出与本回执。
- D1 脚本与日志为仓外临时文件，收尾时按「用完即删」清理。

exit=2（D2 停点：topology exit=2、tpl-app stage exit=2，原样记录）
