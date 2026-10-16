# 两台机器五工位对齐 — 远程机（Opus）

- k8s master 先快进到 qwen：cb37451d → 800bc686（GitHub、gitee 核过）。
- push-branches --apply：72 个 origin/<工位> 快进到 master（18 个仓 × cursor、fable、kimi、luna），0 HOLD、0 FAIL。
- align 预演：30 个父仓要快进、qwen 6 个已对齐、0 HOLD；--apply：30 个 DONE，30 个旧名子仓目录挪进 ~/rename-backup/20261016-114021-old-subrepos/，0 HOLD、0 FAIL。
- 之后 list：108 个检出全部 ok（子仓都接回工位分支、无游离；新建子仓推送地址 GitHub + gitee）。

## align --apply
```
== align VM-0-13-ubuntu 2026-10-16 11:40:21  HOME=/home/zym  --apply
  DONE master/k8s 快进 1029 个
  DONE master/runtime 快进 98 个
  moved master/knowfeed-app/info-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowfeed-app/info-admin-frontend
  moved master/knowfeed-app/info-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowfeed-app/info-web-frontend
  moved master/knowfeed-app/info-backend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowfeed-app/info-backend
  DONE master/knowfeed-app 快进 30 个
  moved master/knowbase-app/knowledge-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowbase-app/knowledge-admin-frontend
  moved master/knowbase-app/knowledge-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowbase-app/knowledge-web-frontend
  moved master/knowbase-app/knowledge-backend -> ~/rename-backup/20261016-114021-old-subrepos/master/knowbase-app/knowledge-backend
  DONE master/knowbase-app 快进 27 个
  DONE master/investment-app 快进 98 个
  DONE master/tpl-app 快进 15 个
  DONE cursor/k8s 快进 125 个
  DONE cursor/runtime 快进 5 个
  moved cursor/knowfeed-app/info-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowfeed-app/info-admin-frontend
  moved cursor/knowfeed-app/info-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowfeed-app/info-web-frontend
  moved cursor/knowfeed-app/info-backend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowfeed-app/info-backend
  DONE cursor/knowfeed-app 快进 2 个
  moved cursor/knowbase-app/knowledge-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowbase-app/knowledge-admin-frontend
  moved cursor/knowbase-app/knowledge-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowbase-app/knowledge-web-frontend
  moved cursor/knowbase-app/knowledge-backend -> ~/rename-backup/20261016-114021-old-subrepos/cursor/knowbase-app/knowledge-backend
  DONE cursor/knowbase-app 快进 2 个
  DONE cursor/investment-app 快进 4 个
  DONE cursor/tpl-app 快进 2 个
  DONE fable/k8s 快进 125 个
  DONE fable/runtime 快进 5 个
  moved fable/knowfeed-app/info-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowfeed-app/info-admin-frontend
  moved fable/knowfeed-app/info-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowfeed-app/info-web-frontend
  moved fable/knowfeed-app/info-backend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowfeed-app/info-backend
  DONE fable/knowfeed-app 快进 2 个
  moved fable/knowbase-app/knowledge-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowbase-app/knowledge-admin-frontend
  moved fable/knowbase-app/knowledge-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowbase-app/knowledge-web-frontend
  moved fable/knowbase-app/knowledge-backend -> ~/rename-backup/20261016-114021-old-subrepos/fable/knowbase-app/knowledge-backend
  DONE fable/knowbase-app 快进 2 个
  DONE fable/investment-app 快进 4 个
  DONE fable/tpl-app 快进 2 个
  DONE kimi/k8s 快进 125 个
  DONE kimi/runtime 快进 5 个
  moved kimi/knowfeed-app/info-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowfeed-app/info-admin-frontend
  moved kimi/knowfeed-app/info-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowfeed-app/info-web-frontend
  moved kimi/knowfeed-app/info-backend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowfeed-app/info-backend
  DONE kimi/knowfeed-app 快进 2 个
  moved kimi/knowbase-app/knowledge-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowbase-app/knowledge-admin-frontend
  moved kimi/knowbase-app/knowledge-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowbase-app/knowledge-web-frontend
  moved kimi/knowbase-app/knowledge-backend -> ~/rename-backup/20261016-114021-old-subrepos/kimi/knowbase-app/knowledge-backend
  DONE kimi/knowbase-app 快进 2 个
  DONE kimi/investment-app 快进 4 个
  DONE kimi/tpl-app 快进 2 个
  DONE luna/k8s 快进 125 个
  DONE luna/runtime 快进 5 个
  moved luna/knowfeed-app/info-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowfeed-app/info-admin-frontend
  moved luna/knowfeed-app/info-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowfeed-app/info-web-frontend
  moved luna/knowfeed-app/info-backend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowfeed-app/info-backend
  DONE luna/knowfeed-app 快进 2 个
  moved luna/knowbase-app/knowledge-admin-frontend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowbase-app/knowledge-admin-frontend
  moved luna/knowbase-app/knowledge-web-frontend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowbase-app/knowledge-web-frontend
  moved luna/knowbase-app/knowledge-backend -> ~/rename-backup/20261016-114021-old-subrepos/luna/knowbase-app/knowledge-backend
  DONE luna/knowbase-app 快进 2 个
  DONE luna/investment-app 快进 4 个
  DONE luna/tpl-app 快进 2 个
  ok   qwen/k8s
  ok   qwen/runtime
  ok   qwen/knowfeed-app
  ok   qwen/knowbase-app
  ok   qwen/investment-app
  ok   qwen/tpl-app
done_or_would=30 held=0 failed=0
exit=0
```

## list（之后）
```
== list VM-0-13-ubuntu 2026-10-16 11:47:26  HOME=/home/zym
master/k8s                                           master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/runtime                                       master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowfeed-app                                  master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowfeed-app/knowfeed-admin-frontend          master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowfeed-app/knowfeed-web-frontend            master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowfeed-app/knowfeed-backend                 master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowbase-app                                  master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowbase-app/knowbase-admin-frontend          master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowbase-app/knowbase-web-frontend            master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/knowbase-app/knowbase-backend                 master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/investment-app                                master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/investment-app/investment-backend             master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/investment-app/investment-admin-frontend      master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/investment-app/investment-web-frontend        master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/tpl-app                                       master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/tpl-app/tpl-web-frontend                      master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/tpl-app/tpl-backend                           master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
master/tpl-app/tpl-admin-frontend                    master     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/k8s                                           cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/runtime                                       cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowfeed-app                                  cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowfeed-app/knowfeed-admin-frontend          cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowfeed-app/knowfeed-web-frontend            cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowfeed-app/knowfeed-backend                 cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowbase-app                                  cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowbase-app/knowbase-admin-frontend          cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowbase-app/knowbase-web-frontend            cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/knowbase-app/knowbase-backend                 cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/investment-app                                cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/investment-app/investment-backend             cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/investment-app/investment-admin-frontend      cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/investment-app/investment-web-frontend        cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/tpl-app                                       cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/tpl-app/tpl-web-frontend                      cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/tpl-app/tpl-backend                           cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
cursor/tpl-app/tpl-admin-frontend                    cursor     ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/k8s                                            fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/runtime                                        fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowfeed-app                                   fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowfeed-app/knowfeed-admin-frontend           fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowfeed-app/knowfeed-web-frontend             fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowfeed-app/knowfeed-backend                  fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowbase-app                                   fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowbase-app/knowbase-admin-frontend           fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowbase-app/knowbase-web-frontend             fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/knowbase-app/knowbase-backend                  fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/investment-app                                 fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/investment-app/investment-backend              fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/investment-app/investment-admin-frontend       fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/investment-app/investment-web-frontend         fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/tpl-app                                        fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/tpl-app/tpl-web-frontend                       fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/tpl-app/tpl-backend                            fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
fable/tpl-app/tpl-admin-frontend                     fable      ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/k8s                                             kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/runtime                                         kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowfeed-app                                    kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowfeed-app/knowfeed-admin-frontend            kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowfeed-app/knowfeed-web-frontend              kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowfeed-app/knowfeed-backend                   kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowbase-app                                    kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowbase-app/knowbase-admin-frontend            kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowbase-app/knowbase-web-frontend              kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/knowbase-app/knowbase-backend                   kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/investment-app                                  kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/investment-app/investment-backend               kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/investment-app/investment-admin-frontend        kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/investment-app/investment-web-frontend          kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/tpl-app                                         kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/tpl-app/tpl-web-frontend                        kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/tpl-app/tpl-backend                             kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
kimi/tpl-app/tpl-admin-frontend                      kimi       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/k8s                                             luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/runtime                                         luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowfeed-app                                    luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowfeed-app/knowfeed-admin-frontend            luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowfeed-app/knowfeed-web-frontend              luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowfeed-app/knowfeed-backend                   luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowbase-app                                    luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowbase-app/knowbase-admin-frontend            luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowbase-app/knowbase-web-frontend              luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/knowbase-app/knowbase-backend                   luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/investment-app                                  luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/investment-app/investment-backend               luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/investment-app/investment-admin-frontend        luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/investment-app/investment-web-frontend          luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/tpl-app                                         luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/tpl-app/tpl-web-frontend                        luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/tpl-app/tpl-backend                             luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
luna/tpl-app/tpl-admin-frontend                      luna       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/k8s                                             qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/runtime                                         qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowfeed-app                                    qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowfeed-app/knowfeed-admin-frontend            qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowfeed-app/knowfeed-web-frontend              qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowfeed-app/knowfeed-backend                   qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowbase-app                                    qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowbase-app/knowbase-admin-frontend            qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowbase-app/knowbase-web-frontend              qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/knowbase-app/knowbase-backend                   qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/investment-app                                  qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/investment-app/investment-backend               qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/investment-app/investment-admin-frontend        qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/investment-app/investment-web-frontend          qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/tpl-app                                         qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/tpl-app/tpl-web-frontend                        qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/tpl-app/tpl-backend                             qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
qwen/tpl-app/tpl-admin-frontend                      qwen       ahead=0    behind=0     dirty=0   unpushed=0   ok           
exit=0
```
