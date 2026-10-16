# 并进 master — Opus（远程机）

- 时间 2026-10-16 11:03:32。所有者 2026-10-16 定由 Opus 直接做（不经 fable）。
- 前提核过：18 个仓 origin/master 都没有 qwen 之外的提交（全是快进）；其他工位在 origin 上的分支都已包含在 qwen 里；四个父仓 qwen 上的子仓指针都等于各子仓 qwen 的头；gitee 上的 master 推前与 GitHub 相同。
- 做法：先 12 个子仓、再 4 个父仓、最后 k8s、runtime，逐个 `git push origin <qwen 提交>:refs/heads/master`（不强推；origin 的推送地址含 GitHub 与 gitee 的两个都推）。推后 `git ls-remote` 逐个核对：GitHub 18 个、gitee 11 个 master 都等于 qwen 的提交。
- 回退（不需要时不做）：把下表「旧」推回 master，要强推，须所有者批准。

```
  knowfeed-app/knowfeed-backend e5156a0bfc -> ecce5c797d
  knowfeed-app/knowfeed-web-frontend a07af307c6 -> a284e1dc19
  knowfeed-app/knowfeed-admin-frontend 90e4ab00fc -> 3f01f34bb3
  knowbase-app/knowbase-backend 4d9804c3d5 -> 1d8fa105cf
  knowbase-app/knowbase-web-frontend 8e8d016b4c -> a657acf4f3
  knowbase-app/knowbase-admin-frontend 6634a4c64e -> b9e6b22f42
  investment-app/investment-backend abddf477fa -> 543d655f02
  investment-app/investment-web-frontend 32265f705d -> 7b84ad653a
  investment-app/investment-admin-frontend 2e1f5c67d5 -> 9bdb1b2590
  tpl-app/tpl-backend 6674125cd1 -> afd78831c8
  tpl-app/tpl-web-frontend 45ceed1a14 -> 670a6552e2
  tpl-app/tpl-admin-frontend ee1f542220 -> 3c0581f59d
  knowfeed-app 244f724dce -> 7c6be847d3
  knowbase-app b4e6f66624 -> c61ed1c155
  investment-app b66223cf89 -> d45b035265
  tpl-app 3317c84d98 -> cd343d60e4
  k8s 4156a8b0a7 -> cb37451da0
  runtime f60e9d395b -> 8cac5ab042
```

- k8s 的 master 停在推送时的 qwen 提交 `cb37451d`；本回执及之后的 k8s 提交在第 2 条对齐时随工位一起进 master。
- 两台机器的 `~/master/<仓>` 检出还在旧 master（父仓里子仓目录还是旧名），在第 2 条一起对齐。
