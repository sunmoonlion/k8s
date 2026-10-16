# 收尾对齐-qwen — 预演过、执行 FAIL(master/k8s 残留 sunmoonai/) 停在此，未修未重跑，等所有者定夺

- 分支：`qwen`，执行前 `git pull --ff-only` 到 `e348398f`（「移出 sunmoonai、旧体系删除」）、工作区干净。执行者：Qwen（本地机）。时间 2026-10-16 13:37–13:44。
- 结论：**第 1 步只读核查干净；第 2 步预演 `held=0 failed=0` 过闸门，执行 `--apply` 出现 1 个 FAIL、`exit=3`，按规矩停**——`list` 后核与第 3 步（修转发脚本、列残留）**未做**；不修、不重跑。已有结果文件（plan、apply）随本回执提交。

## 1. 只读核查（旧路径引用）

命令照所有者原文（grep systemd + crontab + sudo crontab），输出**只有 `check-done`**：本机无任何 systemd 服务或 crontab 引用 `k8s/sunmoonai` / `/sunmoonai/kind-infrastructure`。

## 2. 对齐（输出先落仓外 `~/align-out-final-20261016-1337/`，仓全程干净）

- **预演 `align`**（align-final-plan-qwen.20261016-1337.txt）：`done_or_would=35 held=0 failed=0`、`exit=0`、无 HOLD → 闸门过。
- **执行 `align --apply`**（align-final-apply-qwen.20261016-1337.txt）：`done_or_would=34 held=0 failed=1`、`exit=3`。FAIL 行原文：

```
FAIL master/k8s 做完仍不干净或不在 master：?? sunmoonai/
```

- 其余 34 项全部 DONE/ok（含 master、luna、qwen 三组各仓快进；`qwen/k8s` 显示「比 master 多 1 个，都已推到 origin/qwen」属正常）。

### FAIL 核实（只读，未动任何文件）

- `~/master/k8s` 确在 `master` 分支、快进本身成功；`git status --porcelain` 唯一一行就是 `?? sunmoonai/`。
- 该目录 **1.4G**，是 git 删除旧体系后**磁盘上留下的未跟踪残留**：内含 `app-platform/…/secrets/harbor-registry-secret/harbor-registry-secret.yaml`（被 ignore 的本地密钥）、多个 `__pycache__/` 等。目录非空 → git 报未跟踪 → 工具判「做完仍不干净」→ FAIL。
- 这正是所有者第 3 步预告的那类残留（「git 删除以后还留在磁盘上的被忽略文件，可能是旧体系的本地密钥或缓存。只列，不删，删不删由所有者定」）。**Qwen 未删、未修、未重跑**；其余四工位未逐一复核（停在 FAIL 处）。

## 3. 修转发脚本、列残留 — 未做

停在第 2 步 FAIL，按「出现 FAIL 就停，把已有的结果文件提交上来，不要修」执行；`~/switch-test/*.sh` 未改动，残留清单未生成。

## 4. 提交

- 本回执 + `align-final-plan-qwen.20261016-1337.txt` + `align-final-apply-qwen.20261016-1337.txt` 一并提交推送。仓外暂存 `~/align-out-final-20261016-1337/` 留着未删。

exit=3（对齐工具 --apply 的退出码，原样记录）
