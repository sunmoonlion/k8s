# rename（0028）本地机对齐回执 — Qwen

- 手册 `docs/process/rename-2026-10-15/README.md`「R4 之后」第 4 步，HEAD `c4406283`（远程机对齐已完成、Qwen 可做本地机）。执行者：Qwen（本地机），2026-10-17 13:07–13:21。
- 工具：`docs/process/switch-test/align_workstations.sh`；结果先落仓外 `/tmp/align-*` 再拷入 `docs/process/rename-2026-10-15/receipts/`（避免自照 HOLD）。

## align 预演

```
done_or_would=40 held=0 failed=0
exit=0
```

闸门通过，执行 --apply。

## align --apply

```
done_or_would=40 held=0 failed=0
exit=0
```

40 个检出快进（含 master 八仓、五工位各仓及子仓）。无 HOLD，无 FAIL。

## list 后核

158 行（含 2 行头/尾），155 行 `ok`，1 行 `ahead-pushed`（`qwen/k8s`，预期态：qwen 分支 ahead=1 master）。非 ok/ahead-pushed 行零命中。

```
qwen/k8s   qwen   ahead=1   behind=0   dirty=0   unpushed=0   ahead-pushed
```

与远程机 `align-opus` 结果一致（远程机 156 项全 ok；本地机 156 项 = 155 ok + 1 ahead-pushed）。

## 结果文件

- `align-plan-qwen.20261017-1307.txt`（预演）
- `align-apply-qwen.20261017-1307.txt`（执行）
- `align-list-qwen.20261017-1307.txt`（后核 list）

exit=0
