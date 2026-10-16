# qwen-003-D（Qwen，本地机）第二停点 — D2 重跑：topology 过了，tpl-app stage 又停（knowlab/knowmart 缺 image.lock.yaml）

- 分支：`qwen`，pull 到 `26eb5aed`（「D2 停点修复 + 待办 97」：补两新后端 database/migration/redis 目录、prepare 按阶段依赖排序）。执行者：Qwen（本地机）。时间 2026-10-16 16:44–16:50。
- 结论：**上一停点（stage graph 缺目录）已修好——`topology-stage OBJECT=all` 这次 `exit=0`；但第一个 `platform-stage app-platform/tpl-app` 又 `exit=2`**，挂在 services-stage 读 `knowlab-backend/image.lock.yaml`（File not found）。按规矩停，不修、不重跑；D2b–D8 未做。

## 现场（脚本与卡 80–85 行 diff=0，原样从头重跑）

```
topology exit=0
===== stage app-platform/tpl-app
exit=2        ← break，knowfeed/knowbase/investment 未跑
      1 clusters/kind   ← git status 汇总只到这一行
```

fatal 原文（log 第 5108 行，同一错误共 3 处命中）：

```
fatal: [localhost]: FAILED! => {"changed": false, "msg": "Task failed: Finalization of task
args for 'ansible.builtin.set_fact' failed: Error while resolving value for 'app_images':
The lookup plugin 'file' failed: Unable to access the file
'…/gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml': File not found."}
PLAY RECAP: ok=1126 changed=18 unreachable=0 failed=1
make[2]: *** [Makefile:386: services-stage] Error 2
```

## 根因（只读核实，未动任何文件）

- `26eb5aed` 补的三个目录已在（两 backend 下均有 database/migration/redis），stage graph 收集通过（topology exit=0 实证）。
- 但 **services-stage 的 `set_fact app_images` 会用 `lookup('file')` 读全部已登记应用的 `image.lock.yaml`**；C 段已把 knowlab/knowmart 登记进应用清单，而两者的 `image.lock.yaml` **不存在**（该文件按卡属 D3 `platform-build` 生成——「生成文件由 D3 的 stage 写进去」）。对照：`tpl-backend/image.lock.yaml` 存在。
- 即 **D2 在 D3 之前跑存在先后矛盾**：D3 未跑 → 新应用无 lock → 任何现有应用（tpl 起）的 platform-stage 都会在 services-stage 失败。knowmart 同构（目录里同样无 lock）。

## 待 Opus 定夺（Qwen 不自修）

1. 调整卡内顺序：先 D3（build 生成两新应用的 lock 并 stage）再回跑 D2 验证「现有应用零变动」；或
2. C 段补交两新应用的占位 `image.lock.yaml`（形态由 Opus 定）；或
3. 改 services-stage 对缺失 lock 的应用容忍/跳过。

## 工作区状态（如实）

- `git status` 仅 1 行：`M gitops/clusters/kind/stages.yaml`——topology-stage exit=0 的产物，正是 D2「要看到」里预期的 `clusters/kind` 改动（加了两个应用的阶段）。**原样保留、未提交、未还原**，等 Opus 定夺后随下一步处置。
- ansible `changed=18` 均落在 ignore 路径（`.build` 等），gitops 内除上述 1 行外零改动。
- 未跑 `platform-stage OBJECT=all`（卡明令）；D2b–D8 未做；口令、令牌未出现在任何输出。

exit=2（D2 重跑停点：topology exit=0、tpl-app stage exit=2，原样记录）
