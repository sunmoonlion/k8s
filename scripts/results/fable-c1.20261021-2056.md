# fable-c1 回执（停点·RENDER 非 IDENTICAL）Cursor 20261021-2056

P=/home/zymun/sunmoon-probe-runs/c1-20261021-2008
HEAD=6f56b447626340e90fffe488df1ef10b89b72646

## 改后 render 末尾
```
skipping: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=2483 changed=6    unreachable=0    failed=0    skipped=746  rescued=0    ignored=0   
```

## 第三节
```
=== RENDER ===
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: info-app
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: investment-app
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbase-app/knowbase-backend/runtime/workload.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbase-app/knowbase-backend/runtime/workload.yaml
84c84
<         sunmoonai.com/config-sha256: 45ff5508afbb70a66541a9919de5a9977f7e845acedbcd50bfb7f78ee581754d
---
>         sunmoonai.com/config-sha256: 65ecb6dae4461f8488ccf277ef4ede8f3fa0c064d983da5159bd73fd3961ee1b
148c148
<         sunmoonai.com/config-sha256: 45ff5508afbb70a66541a9919de5a9977f7e845acedbcd50bfb7f78ee581754d
---
>         sunmoonai.com/config-sha256: 65ecb6dae4461f8488ccf277ef4ede8f3fa0c064d983da5159bd73fd3961ee1b
205c205
<         sunmoonai.com/config-sha256: 45ff5508afbb70a66541a9919de5a9977f7e845acedbcd50bfb7f78ee581754d
---
>         sunmoonai.com/config-sha256: 65ecb6dae4461f8488ccf277ef4ede8f3fa0c064d983da5159bd73fd3961ee1b
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml
7,12c7,12
---
17,21c17,21
<             c3pRdEpWNXZzNjRnMlJCSVNZWU9uVGN0MTNjCkxnRTkvcFBMVWJ0YTJOM0tmeWw0
<             SUpZbEFRNk1HNjFyUG8wSTUwVjNsSm8KLS0tIE5JMGpaeTFMWVBLQWswNVlJN0xH
<             bDJyTWNlMkYvdDV0YkVlQzRQbkwrc2sKwe+CVjpz6p2DcLYFdUbmphsXuw1Efe8b
<             gRej2nYQTgeJ4Yvxz6wHgS/SVfA+B0rjB6lD3jJM2L2hNXJkjBoH6w==
---
>             Q0pGVm9KZXhOSFNVbm1CcTZvTitoWjJheUVBCjlGUTJIUmJIblI2S3hoOW9WTzBz
>             MlJLTG5jdHdSRzNjdWVyOEdtWEZzYW8KLS0tIHJETVk2Z0IxMkZKeTJRWVVPOFFy
>             MC9ZeUd0Wk5aKzlHVURvOGt6c3dhWmsKNS4uwtCSGFC8VHFlp0xsOGRx7M8BrowC
>             UnhG/rpbye+U4yFfWx7VsbKJBJcYMZ4OWQHuufzoa7lO9OKHVuueZA==
25,26c25,26
<     lastmodified: "2026-10-21T12:18:12Z"
---
>     lastmodified: "2026-10-21T12:39:15Z"
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowbench-app/knowbench-backend/runtime/workload.yaml
96c96
<         sunmoonai.com/config-sha256: ebb02ebc238aef419751937fb2b01b066422f97db131c63d6ca14a4519bc74d9
---
>         sunmoonai.com/config-sha256: 923f685e476690c3d91bcd0d119f28560ddae9c05141969aaa73d83b65daafdb
163c163
<         sunmoonai.com/config-sha256: ebb02ebc238aef419751937fb2b01b066422f97db131c63d6ca14a4519bc74d9
---
>         sunmoonai.com/config-sha256: 923f685e476690c3d91bcd0d119f28560ddae9c05141969aaa73d83b65daafdb
222c222
<         sunmoonai.com/config-sha256: ebb02ebc238aef419751937fb2b01b066422f97db131c63d6ca14a4519bc74d9
---
>         sunmoonai.com/config-sha256: 923f685e476690c3d91bcd0d119f28560ddae9c05141969aaa73d83b65daafdb
279c279
<         sunmoonai.com/config-sha256: ebb02ebc238aef419751937fb2b01b066422f97db131c63d6ca14a4519bc74d9
---
>         sunmoonai.com/config-sha256: 923f685e476690c3d91bcd0d119f28560ddae9c05141969aaa73d83b65daafdb
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowfeed-app/knowfeed-backend/runtime/workload.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowfeed-app/knowfeed-backend/runtime/workload.yaml
68c68
<         sunmoonai.com/config-sha256: 27172e3f924de74c5df18e19123ac532112c82690140cfa49ec6c089aa105261
---
>         sunmoonai.com/config-sha256: e3acbe4b6b1c1848a57920b147e0444a035303fb4da436ee0eb2b3b467b1d660
133c133
<         sunmoonai.com/config-sha256: 27172e3f924de74c5df18e19123ac532112c82690140cfa49ec6c089aa105261
---
>         sunmoonai.com/config-sha256: e3acbe4b6b1c1848a57920b147e0444a035303fb4da436ee0eb2b3b467b1d660
194c194
<         sunmoonai.com/config-sha256: 27172e3f924de74c5df18e19123ac532112c82690140cfa49ec6c089aa105261
---
>         sunmoonai.com/config-sha256: e3acbe4b6b1c1848a57920b147e0444a035303fb4da436ee0eb2b3b467b1d660
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowlab-app/knowlab-backend/runtime/workload.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowlab-app/knowlab-backend/runtime/workload.yaml
78c78
<         sunmoonai.com/config-sha256: c90c098a3d60880df7bc9d45d71695b0d8c66114a1014c2d5a002d0edcdf0c49
---
>         sunmoonai.com/config-sha256: 14e66476452436d60c1db73dc1ad8a8a7c984653478ac7ad7b620d84bed81cff
144c144
<         sunmoonai.com/config-sha256: c90c098a3d60880df7bc9d45d71695b0d8c66114a1014c2d5a002d0edcdf0c49
---
>         sunmoonai.com/config-sha256: 14e66476452436d60c1db73dc1ad8a8a7c984653478ac7ad7b620d84bed81cff
206c206
<         sunmoonai.com/config-sha256: c90c098a3d60880df7bc9d45d71695b0d8c66114a1014c2d5a002d0edcdf0c49
---
>         sunmoonai.com/config-sha256: 14e66476452436d60c1db73dc1ad8a8a7c984653478ac7ad7b620d84bed81cff
Only in /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform: knowledge-app
diff --color -r /home/zymun/sunmoon-probe-runs/c1-20261021-2008/before/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml /home/zymun/sunmoon-probe-runs/c1-20261021-2008/after/components/app-platform/knowmart-app/knowmart-backend/runtime/workload.yaml
67c67
<         sunmoonai.com/config-sha256: c2d83cb88c8ec33ef023c4e70ff15f82de6bf4084b231f8cad7d19fb89cb92b7
```

## diff -rq
```
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

DIFF_LINES=119
完整 diff：$P/diff.txt（含 sops 密文，不进 git）

卡仍 inbox/cursor/；停点 docs/process/switch-test/inbox/fable/2026-10-21-fable-c1-render-not-identical.md
