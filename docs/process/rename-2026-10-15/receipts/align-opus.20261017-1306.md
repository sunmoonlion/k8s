# rename（0028）并 master 与远程机对齐 — Opus

## 1. master 快进到 qwen（26 个仓，先子仓后父仓）

推后逐个核对 GitHub 与 gitee 的 master 等于 qwen（tpl 三个子仓只有 GitHub）：26 个全对。k8s `18938511..1d9c39ca`。

## 2. push-branches

预演 104 个 WOULD、0 HOLD；--apply 104 个 PUSHED、exit=0（26 个仓的 origin/cursor、fable、kimi、luna 快进到 master）。

## 3. 远程机 align

```
  WOULD master/k8s 快进 90 个
  WOULD master/sunmoon-link 快进 3 个
  WOULD master/knowfeed-app 快进 4 个
  WOULD master/knowbase-app 快进 4 个
  WOULD master/knowbench-app 快进 8 个；挪走旧子仓目录: investment-backend investment-admin-frontend investment-web-frontend
  WOULD master/tpl-app 快进 5 个
  WOULD master/knowlab-app 快进 8 个
  WOULD master/knowmart-app 快进 7 个
  WOULD cursor/k8s 快进 90 个
  WOULD cursor/sunmoon-link 快进 3 个
  WOULD cursor/knowfeed-app 快进 4 个
  WOULD cursor/knowbase-app 快进 4 个
  WOULD cursor/knowbench-app 快进 8 个；挪走旧子仓目录: investment-backend investment-admin-frontend investment-web-frontend
  WOULD cursor/tpl-app 快进 5 个
  WOULD cursor/knowlab-app 快进 8 个
  WOULD cursor/knowmart-app 快进 7 个
  WOULD fable/k8s 快进 90 个
  WOULD fable/sunmoon-link 快进 3 个
  WOULD fable/knowfeed-app 快进 4 个
  WOULD fable/knowbase-app 快进 4 个
  WOULD fable/knowbench-app 快进 8 个；挪走旧子仓目录: investment-backend investment-admin-frontend investment-web-frontend
  WOULD fable/tpl-app 快进 5 个
  WOULD fable/knowlab-app 快进 8 个
  WOULD fable/knowmart-app 快进 7 个
  WOULD kimi/k8s 快进 90 个
  WOULD kimi/sunmoon-link 快进 3 个
  WOULD kimi/knowfeed-app 快进 4 个
  WOULD kimi/knowbase-app 快进 4 个
  WOULD kimi/knowbench-app 快进 8 个；挪走旧子仓目录: investment-backend investment-admin-frontend investment-web-frontend
  WOULD kimi/tpl-app 快进 5 个
  WOULD kimi/knowlab-app 快进 8 个
  WOULD kimi/knowmart-app 快进 7 个
  WOULD luna/k8s 快进 90 个
  WOULD luna/sunmoon-link 快进 3 个
  WOULD luna/knowfeed-app 快进 4 个
  WOULD luna/knowbase-app 快进 4 个
  WOULD luna/knowbench-app 快进 8 个；挪走旧子仓目录: investment-backend investment-admin-frontend investment-web-frontend
  WOULD luna/tpl-app 快进 5 个
  WOULD luna/knowlab-app 快进 8 个
  WOULD luna/knowmart-app 快进 7 个
done_or_would=40 held=0 failed=0
exit=0
```

```
  DONE master/k8s 快进 90 个
  DONE master/sunmoon-link 快进 3 个
  DONE master/knowfeed-app 快进 4 个
  DONE master/knowbase-app 快进 4 个
  moved master/knowbench-app/investment-backend -> ~/rename-backup/20261017-125143-old-subrepos/master/knowbench-app/investment-backend
  moved master/knowbench-app/investment-admin-frontend -> ~/rename-backup/20261017-125143-old-subrepos/master/knowbench-app/investment-admin-frontend
  moved master/knowbench-app/investment-web-frontend -> ~/rename-backup/20261017-125143-old-subrepos/master/knowbench-app/investment-web-frontend
  DONE master/knowbench-app 快进 8 个
  DONE master/tpl-app 快进 5 个
  DONE master/knowlab-app 快进 8 个
  DONE master/knowmart-app 快进 7 个
  DONE cursor/k8s 快进 90 个
  DONE cursor/sunmoon-link 快进 3 个
  DONE cursor/knowfeed-app 快进 4 个
  DONE cursor/knowbase-app 快进 4 个
  moved cursor/knowbench-app/investment-backend -> ~/rename-backup/20261017-125143-old-subrepos/cursor/knowbench-app/investment-backend
  moved cursor/knowbench-app/investment-admin-frontend -> ~/rename-backup/20261017-125143-old-subrepos/cursor/knowbench-app/investment-admin-frontend
  moved cursor/knowbench-app/investment-web-frontend -> ~/rename-backup/20261017-125143-old-subrepos/cursor/knowbench-app/investment-web-frontend
  DONE cursor/knowbench-app 快进 8 个
  DONE cursor/tpl-app 快进 5 个
  DONE cursor/knowlab-app 快进 8 个
  DONE cursor/knowmart-app 快进 7 个
  DONE fable/k8s 快进 90 个
  DONE fable/sunmoon-link 快进 3 个
  DONE fable/knowfeed-app 快进 4 个
  DONE fable/knowbase-app 快进 4 个
  moved fable/knowbench-app/investment-backend -> ~/rename-backup/20261017-125143-old-subrepos/fable/knowbench-app/investment-backend
  moved fable/knowbench-app/investment-admin-frontend -> ~/rename-backup/20261017-125143-old-subrepos/fable/knowbench-app/investment-admin-frontend
  moved fable/knowbench-app/investment-web-frontend -> ~/rename-backup/20261017-125143-old-subrepos/fable/knowbench-app/investment-web-frontend
  DONE fable/knowbench-app 快进 8 个
  DONE fable/tpl-app 快进 5 个
  DONE fable/knowlab-app 快进 8 个
  DONE fable/knowmart-app 快进 7 个
  DONE kimi/k8s 快进 90 个
  DONE kimi/sunmoon-link 快进 3 个
  DONE kimi/knowfeed-app 快进 4 个
  DONE kimi/knowbase-app 快进 4 个
  moved kimi/knowbench-app/investment-backend -> ~/rename-backup/20261017-125143-old-subrepos/kimi/knowbench-app/investment-backend
  moved kimi/knowbench-app/investment-admin-frontend -> ~/rename-backup/20261017-125143-old-subrepos/kimi/knowbench-app/investment-admin-frontend
  moved kimi/knowbench-app/investment-web-frontend -> ~/rename-backup/20261017-125143-old-subrepos/kimi/knowbench-app/investment-web-frontend
  DONE kimi/knowbench-app 快进 8 个
  DONE kimi/tpl-app 快进 5 个
  DONE kimi/knowlab-app 快进 8 个
  DONE kimi/knowmart-app 快进 7 个
  DONE luna/k8s 快进 90 个
  DONE luna/sunmoon-link 快进 3 个
  DONE luna/knowfeed-app 快进 4 个
  DONE luna/knowbase-app 快进 4 个
  moved luna/knowbench-app/investment-backend -> ~/rename-backup/20261017-125143-old-subrepos/luna/knowbench-app/investment-backend
  moved luna/knowbench-app/investment-admin-frontend -> ~/rename-backup/20261017-125143-old-subrepos/luna/knowbench-app/investment-admin-frontend
  moved luna/knowbench-app/investment-web-frontend -> ~/rename-backup/20261017-125143-old-subrepos/luna/knowbench-app/investment-web-frontend
  DONE luna/knowbench-app 快进 8 个
  DONE luna/tpl-app 快进 5 个
  DONE luna/knowlab-app 快进 8 个
  DONE luna/knowmart-app 快进 7 个
done_or_would=40 held=0 failed=0
exit=0
```

之后 `list`：156 项全部 ok（`align-list-opus.20261017-1306.txt`）。旧名子仓目录在 `~/rename-backup/20261017-125143-old-subrepos/`，不删。

exit=0
