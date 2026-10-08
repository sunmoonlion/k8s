# Cursor 发布卡：投资电脑代理安装包托管

所有者已授权由 Cursor 执行本卡发布。按 A → B → C 顺序执行，**每段失败立即停并回传，不开始后续段**。
只在 luna 工作树；本待办只本地提交结果，不 push、不合并 fable。不要更改应用 schema、代理包、其他应用或线上登录凭据。

```text
被测仓：k8s，~/worktrees/luna/k8s；关联 investment-app 与其 backend/web 子仓
跑：依次执行本卡 A、B、C；每段完成并核实后再开始下一段
仓与提交：k8s 基线 723d637d47ec3b5690c26f59795c38e657e01cb8；investment 源锁提交 87f56ec2；investment-app 231f305de2e0b72edb3d7cdd7c880151f8e3aaaf；investment-backend a01db6f10f22d11116ba4421309ca676e2790f18；investment-web-frontend 2095c04927a1510efc54bef5ffd28e0c52d25558；固定代理包源码 6de600279ffc1996e19409b1bd6c4ee1eb1eccbe
预计：由 Cursor 按当前站点发布/晋级窗口执行；需联网、Docker/KIND、Harbor、AIStor、Flux 与既有秘密恢复输入；不需要 Windows 管理员或真人浏览器操作
看什么：A 两镜像和 enabled=true/download_available=false 的托管配置通过原链部署；B 私有桶、最小权限、条件写/重复写与独立读回摘要通过；C 下载开关开启后未登录拒绝且 HEAD/下载元数据正确
前提：确认工作树干净且各仓提交与本卡一致；按 k8s inbox README 的约定，满足当前集群状态、10 GiB容量底线、SOPS/私有输入可恢复；保存本次原 Flux source 与两个 investment image.lock 回退点。不得使用 source-before.yaml
回传：k8s/sunmoonai/scripts/results/agent-release-hosting-cursor.<时间>.md；记录每段命令退出码、镜像摘要/source_revision、Pod imageID、Flux 摘要/Ready、读写拒绝结果及回退点；结果本地提交，不 push
```

## 固定发布输入

本卡执行前先核 `infrastructure/applications/sources.yaml` 的 investment 锁为：

- parent `231f305de2e0b72edb3d7cdd7c880151f8e3aaaf`
- backend 与 backend_parent `a01db6f10f22d11116ba4421309ca676e2790f18`
- web 与 web_parent `2095c04927a1510efc54bef5ffd28e0c52d25558`
- admin 锁保持原值。

固定安装包不重组、不替换：

```text
C:\Users\zymun\sunmoon-probe-runs\windows-agent-3-20261009\sunmoon-agent-0.2.1-6de6002-windows-x64.zip
大小 174243923 字节
ZIP SHA256 2d5421627198b9cf2eccf15d88b726c80d46f4180e2db30606120f5bd52aea5a
manifest SHA256 d72f5443be1fa13895a92cb97f37b9cef6ce5fe27e7707705f3ee0e56a11f1b2
```

平台级 Make/Ansible/Flux 入口及回退方法见：
`gitops/components/app-platform/investment-app/investment-backend/agent-releases/README.md`。

## A：构建后端与网页，先部署但关闭下载

1. 核 `git status --short`、当前 `sunmoon-kind` 集群与 kubeconfig、Harbor/Flux 状态及容量；
   用新的本轮结果目录保存原 `infrastructure/environments/kind/flux-source.yaml`、
   `investment-backend/image.lock` 与 `investment-web-frontend/image.lock`。
   目录不得覆盖旧回退材料。若状态不健康、锁不匹配、恢复材料缺失或容量低于 10 GiB，停止。
2. 先用原生 source plan 确认导出的固定提交，再通过现有应用构建入口，仅构建并发布 investment backend 和 web；
   不构建 admin、relay 或其它应用：

```bash
make -C infrastructure application-source-plan APP=investment COMPONENT=backend
make -C infrastructure application-source-plan APP=investment COMPONENT=web
make -C infrastructure application-build-backend APP=investment
make -C infrastructure application-publish-backend APP=investment
make -C infrastructure application-build-web APP=investment
make -C infrastructure application-publish-web APP=investment
```

3. 将 `gitops/components/app-platform/investment-app/investment-backend/agent-releases/config.yaml`
   设为 `enabled: true`、`download_available: false`。不要生成空的 SOPS/私有身份；由现有组件部署链准备桶、身份与 reader 输入。
4. 走原生应用暂存与计划。确认 backend/web image lock 的 `source_revision` 分别等于上面的已审源码；
   检查 schema revision、其他应用、非本模块 SOPS 与无关对象没有变化。通过后仅提交本次 investment 声明、镜像锁与必要密文：

```bash
make -C infrastructure application-stage APP=investment
make -C infrastructure application-deployment-plan APP=investment
```

`application-stage` 已覆盖 investment 下新增的 `investment-agent-releases` 阶段；不要再对 backend 单组件重复 stage。
审 diff 通过后本地提交，再执行 `make -C infrastructure flux-release`。

检查候选 OCI 的 repository/digest/revision/path/requires_sops 与已审源提交。按
`infrastructure/flux/README.md` 显式晋级：将已发布候选的完整固定字段复制到
`infrastructure/environments/kind/flux-source.yaml`，本地提交晋级，再执行：

```bash
make -C infrastructure flux-source-apply
make -C infrastructure flux-source-status
make -C infrastructure platform-check OBJECT=app-platform/investment-app/investment-backend
make -C infrastructure application-check APP=investment
make -C infrastructure application-check-public APP=investment
```

确认新 Pod imageID 与刚发布摘要一致、Flux 相关阶段 Ready；网页下载仍显示不可用。
提交/构建/暂存/晋级/检查任一步失败即停止，按 README 用本段保存的原 Flux source 和 image.lock 恢复，
报告是否已成功恢复；不删除桶、对象、PV/PVC 或回退材料。

## B：校验并上传固定包

只有 A 全部通过才执行。先只读校验，再上传：

```bash
AGENT_ZIP=/mnt/c/Users/zymun/sunmoon-probe-runs/windows-agent-3-20261009/sunmoon-agent-0.2.1-6de6002-windows-x64.zip make -C infrastructure agent-release-verify
AGENT_ZIP=/mnt/c/Users/zymun/sunmoon-probe-runs/windows-agent-3-20261009/sunmoon-agent-0.2.1-6de6002-windows-x64.zip make -C infrastructure agent-release-upload
```

核回执与固定 ZIP/manifest 摘要、长度、90 个文件一致。记录并实际验证：

- `agent-releases` 是私有桶，匿名读取被拒；
- reader 可以读取固定对象，不能写；writer 可以新增固定对象，不能读；两者不能列桶、删除或管理对象；
- 上传使用条件写；第二次同名上传不覆盖且读回仍匹配，不产生第二个版本；
- 读回由独立 reader 完整流式重算 SHA256；实际 AIStor 支持预期的条件请求及策略语义。

任何凭据/策略/读回/摘要不符立即停止。不要关闭 TLS、扩大权限、覆盖对象或删除桶数据。
上传失败可能留下对象：保留并查因，不自行清理；没有匹配的成功读回回执不得进入 C。

## C：启用下载并检查接口

只有 B 的实机权限与读回检查全部通过，且回执与配置版本/对象 key/长度/两个摘要完全匹配才执行。
将 `download_available: true`，按原生 `application-stage APP=investment` → 审 diff → 本地提交 →
`flux-release` → 显式晋级 →
`flux-source-apply/status` 部署；再检查 investment 应用与公开入口。

用非真人自动化/接口检查确认：未登录请求被拒；已登录 HEAD 返回固定长度、附件/校验头与 `no-store`；
完整下载、206 Range、416 与 If-Range 行为正确；下载文件 SHA256、manifest 摘要匹配固定包；
未配置/关闭时 descriptor 不暴露可用下载 URL。不能通过修改真实登录会话来代替未登录检查。

完成 C 后停下，交回证据；**浏览器真人“下载 → 安装 → 领令牌 → 在线”由所有者验收**，
GUI 真人批准、重启登录自启、UAC 和干净 Windows 也仍按原任务保持待验，不得记为本卡通过。

## 失败回退与交回

任一段失败就停在原段；保留错误输出与候选，不自动清对象或卷。需要恢复时按该段保存的固定 Flux source、
镜像锁和组件 README 回退，并确认 source Ready/Pod imageID 后再交回。不得从尚未合入的 fable 发布投资后端或 relay。

报告写入 `k8s/sunmoonai/scripts/results/agent-release-hosting-cursor.<时间>.md`，最后一行 `exit=<码>`；
列出实际完成到 A/B/C 哪一段和各退出码、失败原文、回退是否完成、真实镜像/Flux 证据。
本地提交报告，不 push、不移动本待办。所有者负责同步回 luna。
