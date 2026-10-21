# fable-c1 停在第三节：RENDER 非 IDENTICAL（PLAN/CONFIG 相同）

WS=fable，本地 Cursor，2026-10-21。卡第三版（复用 `c1-20261021-2008/before`，改后在主树 `fc37a4e8c` 及之后渲染）。**改后 render/plan 均为 failed=0；PLAN-IDENTICAL、CONFIG-IDENTICAL 出现；RENDER-IDENTICAL 未出现。卡仍留 inbox/cursor/。未改代码、未部署。**

## 现象（一句话）

`diff -r before/components after/components` 有差异（完整输出 `~/sunmoon-probe-runs/c1-20261021-2008/diff.txt`，119 行）：after 多出旧名应用目录与 `cluster-stages.yaml`；六个后端 `workload.yaml` 的 `config-sha256` 全变；knowbench `domain.sops.yaml` 密文/时间戳变了。

## 证据

```text
P=/home/zymun/sunmoon-probe-runs/c1-20261021-2008
HEAD=6f56b4476
改前：复用 c1-20261021-2008/before（c2d0dbb5，上一轮 failed=0）
改后：services-chart failed=0；components-render ok=2483 failed=0；platform-plan failed=0；config 62 行
```

### 第三节原文结果

```text
PLAN-IDENTICAL
CONFIG-IDENTICAL
# RENDER-IDENTICAL 未出现
DIFF_LINES=119
```

### `diff -rq`（文件级）

```text
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: info-app
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: investment-app
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbase-app/knowbase-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbase-app/knowbase-backend/runtime/workload.yaml differ
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml differ
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml differ
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowfeed-app/knowfeed-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowfeed-app/knowfeed-backend/runtime/workload.yaml differ
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowlab-app/knowlab-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowlab-app/knowlab-backend/runtime/workload.yaml differ
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: knowledge-app
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml differ
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/tpl-app/tpl-backend/runtime/workload.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/tpl-app/tpl-backend/runtime/workload.yaml differ
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components: cluster-stages.yaml
```

### 分类（观察，不裁定）

1. **仅 after 有**：`app-platform/info-app`（34 文件）、`investment-app`（35）、`knowledge-app`（31）、根下 `cluster-stages.yaml`。改前临时 worktree 冷渲染没有这些；主树 `.build/components/app-platform/` 里现在也有这三个旧名目录——像是主工作树 `.build` 残留被 `cp -a` 带进 after，还是 C1 之后渲染新写出，所有者裁。
2. **六应用 backend `runtime/workload.yaml`**：仅 `sunmoonai.com/config-sha256` 注解值变化（路径类字段改由 bind 推出后，进哈希的配置视图可能变了，即使落盘路径字符串仍是 `sunmoon-kind`）。
3. **knowbench `domain.sops.yaml`**：密文 blob / `lastmodified` / mac 不同（两次加密各写一份）；完整 diff 在 `$P/diff.txt`，**不把密文贴进本页**。

`$P/diff-safe-excerpt.txt` 有去密文后的摘要。第四节五条未跑。

## 边界

- 卡未移 done/。
- 本页 + `scripts/results/fable-c1.20261021-2056.md` 推 origin/fable。
