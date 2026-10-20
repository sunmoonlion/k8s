# fable-b4 回执：release 全程（luna，WS=fable）

执行时间：2026-10-20 23:28 至 2026-10-21 凌晨，Asia/Shanghai。任务卡 `2026-10-20-fable-b4-release-full.md`。起始基线 `5acac32895`，最后成功的流水线从 `52b8c527fdfcd433eb6363e5e42edd76bcdd2a03` 开始。

**结果：失败路径 pass，超时路径 pass，真发布与集群核对 pass。** 真发布 `release #7` 为 SUCCESS，493760 毫秒，Make exit=0；所有者以 admin 在页面批准，十二个阶段及两个收尾均完成。8 个 tpl Kustomization Ready=True，lastAppliedRevision 全等于新指针摘要；web/admin 两个 `/api/internal/x` 都 404。

**尚未闭合：** 卡第六节要求 Build Artifacts 中有自动回执，实际归档只有 20 个阶段产物、没有自动回执，故这一项 fail；自动回执已在 Git。所有者最终浏览器首页走查尚未提供结论。已另写 `inbox/fable/2026-10-21-fable-b4-review.md`，不自行修改通过标准或冒充整卡无缺口通过。

## 一、核对与控制器更新

`git status --short` 起始干净，分支 fable；`git pull --ff-only origin fable` 从 fd113de6 快进到 5acac328，exit=0。阶段计数 14（十二阶段加两次收尾），引导含 body.main 和 APPROVAL_TIMEOUT_MINUTES。

`make -C infrastructure jenkins-status`、`jenkins-agent-status` 均 exit=0，active/enabled。先等 render-check #32 和队列清空，再顺序执行 `jenkins-agent-stop`、`jenkins-stop`、`jenkins-deploy`、`jenkins-agent-start`、两项 status：六个 Make 全 exit=0；控制器停止后 ActiveState=inactive、Result=success；恢复后两个单元 active、Result=success。`/opt/sunmoon/jenkins/init.groovy.d/` 恰好 4 个 .groovy.override 文件；release/config.xml 中 APPROVAL_TIMEOUT_MINUTES_count=1、body.main_count=1。

原始输出 `.01-preflight.txt`、`.02-wait-idle.txt`、`.03-controller-update.txt`、`.04-controller-update-verification.txt`（以下简称均带本文件的 `fable-b4.20261020-232845` 前缀）。

执行命令修正：卡用 `journalctl --since '5 min ago'` 查 Exception，这会把刚才主动停止旧代理时的 INFO ClosedChannelException 也扫进去。我加的断言因此令 `.03` exit=1，部署本身都已成功。改为按 systemd 当前 InvocationID 查本次控制器启动日志，仍检查 SEVERE/Exception，结果 0；`.04` exit=0，没有重装或重启第二次。原始失败记录保留。

## 二、三条路径，含两次修复前的失败

| 路径 / 构建 | 实际结果 | Make exit | 毫秒 | 原始执行输出 / 核对 |
| --- | --- | --- | --- | --- |
| 迁移头故意写旧，#3 | FAILURE，Expected schema differs；止于第 2 阶段 | 2（预期） | 35120 | `.07-failure-path.txt` / `.08-failure-verification.txt` |
| 超时第一次，#4 | FAILURE，第 7 阶段缺 Flux CLI，未进入审批 | 2 | 169098 | `.10-timeout-path.txt` / `.12-timeout-attempt1-evidence.txt` |
| 修工具后重跑超时，#5 | ABORTED，2 分钟自动超时 | 2（预期） | 459159 | `.14-timeout-path-retry.txt` / `.15-timeout-verification.txt` |
| 真发布第一次，#6 | FAILURE；所有者已批，第 9 阶段取标签 HTTPS 握手失败 | 2 | 842537 | `.16-real-release.txt` / `.19-real-release-attempt1-evidence.txt` |
| 修取标签后重跑真发布，#7 | SUCCESS，部署、检查、推送完成 | 0 | 493760 | `.21-real-release-retry.txt` / `.23-final-verification.txt` |

命令分别为：

```bash
make -C infrastructure jenkins-release-run RELEASE_BRANCH=fable-b4-test APPS="tpl" PIN=keep NOTE="B4 失败路径"
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B4 超时路径" APPROVAL_TIMEOUT_MINUTES=2
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="tpl ingress 补 /api/internal 收敛规则"
```

每次外层 Bash 使用 pipefail + tee 保留真实退出码；RETRYING 是等待同一次构建，不是再次触发。

### 失败路径

按卡在独立工作树 `/home/zymun/sunmoon-probe-runs/b4test` 创建临时分支，仅把 tpl-backend/config.yaml 的 expected_schema_revision 改为 20260101_0000，提交 fda48bce；tpl-app 同名分支指向原 origin/fable。两个仓均推至 GitHub/Gitee。#3 进入 1 核对、2 改钉、前半段收尾，报 Expected schema differs，未进入 3 构建；代理仓干净、abandoned/* 为空。

临时工作树和本地分支已删，两个仓两站的远端测试分支都经新鲜 ls-remote 核对不存在，见 `.09-test-cleanup.txt`，exit=0。没有使用卡中的 --force 清理，工作树本来就干净。

执行器自加的 `git diff --exit-code --quiet` 检查在有预期差异时退出 1，导致首次准备脚本 `.05-test-branches.txt` 退出 1，尚未提交推送。改用 Python 精确核对唯一改动路径与迁移头，然后续做卡中提交推送，`.06-test-branches-push.txt` exit=0。这个检查命令错误与原始输出保留，不算产品失败。

### 超时路径

#4 已生成 deploy 提交 b0875e82，但发布器在 Flux CLI 身份门禁发现代理克隆没有 `.tools/bin/flux`，所以第 7 阶段失败，没有候选或集群部署。提交保留在 abandoned/release-4。

修复后 #5 依次进入 1–7、前半段收尾、8 人批；日志含 `Timeout set to expire in 2 min 0 sec`、`Cancelling nested steps due to timeout`、`Finished: ABORTED`。没有第 9 阶段。abandoned/release-5 指向 `7cb54625874867355a162e36a4b8b42a488485e3 deploy(tpl): B4 超时路径（release #5）`；与 origin/fable 比较 flux-source.yaml 差异为空。候选摘要 6fa234f992570e3fe906f926953facdd3099275fccc479fb36f7b15db8be025f 留在 Harbor，没有手动清除。

### 真发布第一次

#6 的所有者审批已成功，日志 `Approved by admin`，时间 2026-10-21T00:04:31+08:00。第 9 阶段原命令 `git fetch -q --tags origin` 通过 HTTPS 报 gnutls_handshake 失败，未进入第 10 阶段，集群未动。

实际已产生本地指针提交 `33b1ba85`，位于 abandoned/release-6，父提交为 deploy `38a5dc48`。构建说明只显示 deploy 的短号，因为 state.pointerCommit 在整个 shell 块完成后才赋值；保留实际分支，不以说明替代 Git 事实。

## 三、就地修了什么

两处均在任务卡的临时授权范围，代码单独提交并已推 origin/fable，未改安全门禁或设计。

1. **`3ecd39396e21f7a931a17b9bcb56854fa2a73da7`**：代理工作区准备只安装普通二进制与 sops/age，漏了候选发布必需的 Flux CLI。在 `infrastructure/jenkins/tasks/workspace.yaml` 的原生 Make 循环增加 install-flux，README 写明前提。执行 `make -C infrastructure jenkins-agent-deploy` exit=0；原生安装校验归档、成员哈希、容量与版本，独立复核可执行文件 SHA-256=`392a85dd1126875c1ab677e18b6edb73f292c9e9ebcbb2e5402eb98bcfd81974`、版本 v2.9.5。`.11-agent-tools-fix.txt`、`.13-flux-cli-verification.txt` 均 exit=0；#5 实跑越过原第 7 阶段停点并到达超时审批关。没有手改代理仓文件。
2. **`52b8c527fdfcd433eb6363e5e42edd76bcdd2a03`**：`ci/release.groovy` 第 9 阶段取标签补命令级 GitHub HTTPS→SSH insteadOf，与已有推送机制一致。`git -c url.git@github.com:.insteadOf=https://github.com/ fetch --dry-run --tags origin` exit=0，见 `.20-tag-fetch-verification.txt`；#7 实跑越过取标签并完成 9–12。没有改全局 Git 配置或关闭 TLS 校验。

另有只读诊断命令的路径拼写与 Python 括号错误，当场更正后重查；没有据此修改运行配置或通过标准。

## 四、#7 最终发布与验收

所有者再次在新构建页面审批；日志 `Approved by admin`，`8-approval.txt` 为 `批准人 admin  2026-10-21T00:10:57+08:00`。没有沿用 #6 的批准替代新构建审批。

```text
deploy: ef103e4db89ec082e7819ff57fb106f3a8f889cc
pointer: a7985bffdcb20ba75c00b93102c5bcb836bb328c
receipt: 48838294b585770eb7419c674d09a0e934b79d87
tag: release-20261021-1（指向 pointer 提交）
digest: sha256:44f56adc0b3b9db50e1adae244da164605d12669b2e4da959e92e33384db1788
revision: ef103e4db89ec082e7819ff57fb106f3a8f889cc
```

`git pull --ff-only origin fable` 拉到三个自动提交，exit=0；自动回执 `scripts/results/release-7.20261021-001448.md` 已在 Git。第 10 阶段 flux-source-apply、8 项 tpl wait 全过；第 11 阶段 application-check APP=tpl 过。第 12 阶段推送成功，三个秘密样子检查 total=0。完整控制台仅保留本机忽略目录 `infrastructure/.build/jenkins/release-{3,4,5,6,7}.log`。

按卡提取的 #7 日志原文：

```text
13:[Pipeline] { (ci/release.groovy)
31:[Pipeline] { (1 核对)
13713:[Pipeline] { (2 改钉)
13844:[Pipeline] { (3 构建)
14927:[Pipeline] { (4 暂存)
16088:[Pipeline] { (5 计划)
16215:[Pipeline] { (6 提交)
16228:[Pipeline] { (7 发布)
16709:[Pipeline] { (前半段收尾)
16712:total=0
16724:[Pipeline] { (8 人批)
16753:[Pipeline] { (9 写指针)
16755:批准人 admin  2026-10-21T00:10:57+08:00
16762:tag release-20261021-1
16773:[Pipeline] { (10 部署)
17012:[Pipeline] { (11 检查)
17423:[Pipeline] { (12 推送与回执)
17426:total=0
17436:[Pipeline] { (后半段收尾)
17439:total=0
17449:Finished: SUCCESS
```

独立只读核对使用 Ready 条件的 type 精确取值（没有拿 conditions[0] 的 Reconciling 代替 Ready），8 个 tpl-admin/database/identity/migration/rabbitmq/redis/runtime/web 全 Ready=True，lastAppliedRevision 全等于上述 digest。两个 curl 使用平台 CA、无 -k：

```text
tpl web /api/internal 404
tpl admin /api/internal 404
```

原文在 `.23-final-verification.txt`，exit=0。两次审批前的 12 行差异与候选分别在 `.17-approval-candidate.txt`、`.22-retry-approval-candidate.txt`，均 exit=0；变化只有两个 ingress 各 4 行，改钉为空，镜像锁明确记录同钉同摘要、没有变化。

## 五、归档、镜像站推送与保留项

#7 Build Artifacts 有 20 个阶段文件，包括 12-push.txt、批准记录、指针和检查日志，但缺自动生成的 release-7.*.md，见 `.24-archive-and-publication.txt`。归档表达式只收 `${out}/**`，回执写在 scripts/results/，所以本机文件与 Git 中有回执、Jenkins 产物中没有。此项交远程补齐并验，不重跑一次已无差异的发布来凑检查。

代理克隆的 origin 只有 GitHub 地址，流水线 #7 的 12-push.txt 也只记 GitHub；本机 origin 有 GitHub/Gitee 两个 push URL。本地按卡推回时补齐 Gitee：先取已发布 tag、精确核对它指向 a7985bffdcb20ba75c00b93102c5bcb836bb328c，再 `git push origin fable refs/tags/release-20261021-1`，exit=0，见 `.25-tag-mirror.txt`。没有另造 tag 或变更发布对象。代理克隆的双站推送是否应自动配置也交远程审。

所有 abandoned/release-{4,5,6,7} 分支及 Harbor 候选照卡保留，未做 GC 或补偿回退。发布后没有手改集群、gitops、现有 Harbor 镜像。非所有者不能批准这条只按 submitter 配置保证，没有第二个账号的真人拒绝测试；最终浏览器首页和产物点击走查待所有者，终端 404 不替代 GUI 结论。

## 六、原始输出与推回

本批 `.01` 至 `.25` 原始输出保留原文。除已解释的 `.03`、`.05` 为 exit=1，以及预期/修复前的构建 `.07`、`.10`、`.14`、`.16` 为 exit=2，其余均 exit=0。不修改失败日志、不提交完整控制台或秘密。`.18` 是审批前状态快照，不代替最终结果。

回执、原始输出、远程复审请求与卡移动已在 f05b3f18b 提交并推到 GitHub/Gitee 的 origin/fable，exit=0。原始推送输出另存 `.26-receipt-push.txt`，随本次补充提交交回。最终两站分支与发布标签另以服务器新鲜 ls-remote 核对。不触碰其它工位分支。

exit=0
