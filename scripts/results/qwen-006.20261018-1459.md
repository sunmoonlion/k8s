# qwen-006 小发布回执（本地机 Qwen）——第三节 stage knowmart exit=2 停点

- 派活卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-006-small-release.md`
- 执行者：Qwen（本地机）；停点时间 2026-10-18 14:59
- 停点规则：卡「任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回」——**本节停止，不重试、不退回；第四、五节未执行**

## 1. 各步 exit

| 节 | 命令 | exit |
| --- | --- | --- |
| 一 | `git pull --ff-only origin qwen`（k8s 到 `16643f3a`，与卡要求一致）；三父仓 fetch/checkout/pull/submodule update | 全 0 |
| 一 | 三父仓 HEAD 与九子仓指针核卡表 | 逐字一致（见 §2） |
| 一 | `make -C infrastructure platform-status` | 0（PLAY RECAP failed=0；注：zsh 无 `PIPESTATUS`，改用不带管道写法取 exit） |
| 二 | 卡内 python 改钉脚本 | 0（`pin exit=0`；只动 sources.yaml；加行计数 `19`；knowlab `backend_*` 钉出现在加行 0 次） |
| 三 | `platform-build` ×3（knowbench/knowlab/knowmart） | 全 0 |
| 三 | `platform-stage` knowbench | 0 |
| 三 | `platform-stage` knowlab | 0 |
| 三 | `platform-stage` knowmart | **2 → 停**（原文见 §4） |
| 三 | `application-deployment-plan` knowbench / knowlab | 0 / 0 |
| 三 | `application-deployment-plan` knowmart | **2**（同一断言；脚本在 stage 失败后仍按卡序跑到此处） |
| 四、五 | 未执行 | — |

## 2. 第一节核对结果（与卡表逐字一致）

- knowbench 父 `e15475827519130dd3eaa9343b6ee38011aa9f83`：管 `26964553…`、后 `f9129c84…`、网 `59e1956d…`
- knowlab 父 `72c6247530c40d9caf148d677e27af21d5490db3`：管 `ef4fe7f3…`、后 `4e39358a…`、网 `699ddb71…`
- knowmart 父 `b1cbe7d3a8f9fa1d3189a328fe4cb4a4cbc426e0`：管 `107fda29…`、后 `360effd1…`、网 `85e7877e…`

## 3. 第三节已产出证据

镜像锁八行（`source_revision`，与钉一致，日志原文）：

```text
knowbench-admin-frontend: 26964553ed9d581ac855c38edeaee8e65add792f
knowbench-backend:        f9129c84aba21fd5666379bed2342f33d9553021
knowbench-web-frontend:   59e1956db154b8ac29c8b95ac3d23bf2832a870e
knowlab-admin-frontend:   ef4fe7f3f7e93df122bc10881e3c2a50ca4846e5
knowlab-web-frontend:     699ddb71cfde571308e5ebde2e8e4fea886695f9
knowmart-admin-frontend:  107fda29642e9bf7259af274fa6d6c991302bfeb
knowmart-backend:         360effd1110241a1f020d968f1096b3815307f76
knowmart-web-frontend:    85e7877e4e5a1d92fb632faffa0ca9a4e6e24cfb
```

`key-check-done` 前无密钥文件名。暂存后 `git status --short gitops` 归并计数：

```text
      2 components/app-platform/knowbench-app/knowbench-admin-frontend
     10 components/app-platform/knowbench-app/knowbench-backend
      2 components/app-platform/knowbench-app/knowbench-web-frontend
      2 components/app-platform/knowlab-app/knowlab-admin-frontend
      3 components/app-platform/knowlab-app/knowlab-backend
      2 components/app-platform/knowlab-app/knowlab-web-frontend
      1 components/app-platform/knowmart-app/knowmart-admin-frontend
      1 components/app-platform/knowmart-app/knowmart-backend
      1 components/app-platform/knowmart-app/knowmart-web-frontend
```

knowbench 运行时 workload diff（除镜像/摘要外的行，与卡预期一致）：

```diff
-  DEPLOYMENT_ID: "knowbench-backend-b98dc78340d87e4a"
+  DEPLOYMENT_ID: "knowbench-backend-502de707c13ef7cc"
+            - {secretRef: {name: knowbench-knowlab-read-service}}
-      - {key: app.kubernetes.io/name, operator: In, values: [knowbench-api, knowbench-worker]}
+      - {key: app.kubernetes.io/name, operator: In, values: [knowbench-api, knowbench-worker, knowbench-runner]}
```

测试电脑 workload diff（与卡预期一致：多一行清 `runs` 的 find + 脚本摘要变）：

```diff
-    # 测试产出保留 7 天：每小时删一次 7 天前的底稿目录（只动 底稿/对话-*）
+    # 测试产出保留 7 天：每小时删一次 7 天前的底稿目录（只动 底稿/对话-*）。每次测试自己的目录 runs/*
+    # 由工作台测完就删（账 129），这里只兜底删 7 天没动的
+        find "/workspace/runs" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
-        sunmoonai.com/scripts: '1eac2401f78e7fac73c6ccc9c2555b87602df4a76b0a615c2f7653a828cd7ae4'
+        sunmoonai.com/scripts: 'd7750b72234e908b172817da396bffe74605001a0ea7f0379fad76144a22d4f9'
```

knowmart 运行时 `CROSS_APP_TARGETS` diff：**未到达**（stage knowmart 在渲染前失败）。

计划迁移头：knowbench `20261017_0020`（不变）、knowlab `20261016_0006`（不变）、knowmart **未核到**（plan exit=2）。

观察（非闸门，交 Opus 判断）：knowlab-backend 有 3 个文件随暂存变化（`knowbench-testrun-identity/workload.yaml`、`knowmart-deliver-identity/workload.yaml`、`runtime/workload.yaml`），推测为服务身份注册脚本（连 Casdoor 自动重试）渲染进共用模板所致；卡未列此预期。

## 4. 停点原文（stage knowmart，exit=2）

```text
TASK [Require the configured schema to match the immutable source chain] *******
[ERROR]: Task failed: Action failed: Expected schema differs from pinned backend source. Correct the configuration before rendering or deployment.
Origin: /home/zymun/worktrees/qwen/k8s/gitops/components/app-platform/common/backend/prepare.yaml:111:3
fatal: [localhost]: FAILED! => {"assertion": "cfg.expected_schema_revision == (pinned_schema.stdout | from_json).head", "changed": false, "evaluated_to": false, "msg": "Expected schema differs from pinned backend source. Correct the configuration before rendering or deployment."}
PLAY RECAP *********************************************************************
localhost                  : ok=46   changed=0    unreachable=0    failed=1    skipped=17   rescued=0    ignored=0
make[2]: *** [Makefile:390: services-stage] Error 2
make[1]: *** [Makefile:484: platform-stage-selected] Error 2
make: *** [Makefile:481: platform-stage] Error 2
exit=2
```

plan knowmart 同断言失败：`fatal: … "assertion": "cfg.expected_schema_revision == (pinned_schema.stdout | from_json).head" …`，PLAY RECAP `ok=14 failed=1`，`plan knowmart exit=2`。

## 5. 根因（只读定位，未改）

- 配置侧：`gitops/components/app-platform/knowmart-app/knowmart-backend/config.yaml:9` 为 `expected_schema_revision: '20261016_0004'`
- 钉侧：knowmart-backend `360effd1` 的 alembic 版本头为 `20261018_0005_expert_catalog.py`（即 `20261018_0005`，卡第 9 行也写明新增这条迁移）
- 两侧不等 → 断言失败。**卡的第一~三节命令里没有改 `config.yaml` 这一步**（改钉脚本只动 sources.yaml 19 行），属卡片缺步，与 qwen-005 第二节同类；交 Opus 补卡或补配置提交，我不擅自改配置。

## 6. 现场状态（不退回）

- `infrastructure/applications/sources.yaml` 已按卡改钉（19 行，未提交）
- `gitops/` 为 knowbench、knowlab 两应用暂存产物 + 三应用 image.lock（未提交）；knowmart 仅 image.lock 三件
- 未 commit、未 release、未 apply、未 push；第四节推送命令未执行
- 一次性脚本 `/tmp/q006-s3.sh`、日志 `/tmp/q006-s3.log`、`/tmp/q006-status.log` 留在 /tmp（工位目录顶层无残留）

exit=2（stage knowmart；第一、二节与三个构建全 0，knowbench/knowlab 暂存与计划全 0）
