# fable-c1 停在第三节：仅 knowbench domain.sops.yaml 非 IDENTICAL（第四版）

WS=fable，本地 Cursor，2026-10-21。卡第四版（`c86f57399`：干净 `.build/components` + 摘要键序原位）。**改后 render/plan failed=0；PLAN-IDENTICAL、CONFIG-IDENTICAL 出现；RENDER-IDENTICAL 未出现——只差一个文件。卡仍 inbox/cursor/。未改代码。**

## 现象

`diff -r before/components after/components` 仅：

```text
Files /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml and /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml differ
```

完整输出 `~/sunmoon-probe-runs/c1-20261021-2008/diff.txt`（33 行，含 sops 密文，不进 git）。上一轮的旧名目录 / `cluster-stages.yaml` / 六应用 `config-sha256` 差异在第四版已消失。

## 证据

```text
P=/home/zymun/sunmoon-probe-runs/c1-20261021-2008
HEAD=c86f57399
§1 复用 before：components 有、plan failed=0、config 62 行
§2 rm -rf .build/components → services-chart failed=0 → components-render ok=2640 failed=0 → plan failed=0 → config 62
```

`domain.sops.yaml` 差异形态：各 `ENC[...]` blob、recipient 块、`lastmodified`（before `2026-10-21T12:18:12Z` / after `2026-10-21T13:21:25Z`）、`mac`。像两次独立加密各写一份候选；是否算验收噪声由所有者裁，本地不裁定。

第四节未跑。

## 边界

- 卡未移 done/。
- 本页 + `scripts/results/fable-c1.20261021-2126.md` 推 origin/fable。
