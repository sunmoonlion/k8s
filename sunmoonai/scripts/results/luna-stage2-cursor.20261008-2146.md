# Cursor 回执：Windows 第 2 段补验与两个镜像发布

时间：2026-10-08 21:46（UTC+8）。只在 luna 工位完成本条。没有 push，没有改 `luna-feedback.md`，没有把第 2 段整体记为通过。

本条完成的是：普通用户 Windows 全测、投资后端与 relay 两个镜像的原生构建发布、Flux 晋级和对应服务检查。MCP 真实调用、本机 CLI 审批到工作台审计回执、两次旧投影拒绝定位，仍由 Luna 下一步做，这里不记 pass。代理没有改成无沙箱，也没有自动启动真实 Windows 测试代理。

## 一、Windows 普通用户全测

测试副本 `C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-20261008\agent` 的 `src`、`native`、`test`、`contracts`、`package.json`、`pnpm-lock.yaml` 与 runtime `6461f3f29c63d74dbdf0364a65de5c9ada7cdf7c` 逐文件相同（35 个文件，无缺失、无差异、无多余文件）。夹具脚本 SHA-256 为 `c5b9de85a0a2fd30e5f715acb2fe366b112ed0ad26108b9cab56854b0dc96595`。没有使用普通用户留下的部分夹具 `windows-agent-2-20261008/symlink-fixture`。没有复制 `auth.json` 或 `.sandbox-secrets`。

管理员 PowerShell 只执行了指定夹具脚本，退出码 0。夹具目录：

`C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-native-links-20261008`

普通用户复核：`allowed\directory-link` 与 `allowed\file-link.txt` 的 `LinkType` 都是 `SymbolicLink`，目标分别是夹具 `outside` 和 `outside\secret.txt`，正文是 `outside-control`。

随后用普通用户 PowerShell 跑指定的 `build`、`typecheck`、`test`。账号 `ZYMUN\zymun`，`IsAdmin=False`。Node `v24.19.0`。`VerifiedAndReputablePolicyState=1`，本轮没有改应用控制、执行策略或开发者模式。既有 elevated 测试家 `C:\Users\zymun\.codex-probe-exec` 没有 `auth.json`。

| 步骤 | 退出码 |
| --- | --- |
| build | 0 |
| typecheck | 0 |
| test | 0 |

Vitest 3.2.7：13 个文件、**150 passed**、0 failed，用时 49.43 秒。日志在 `C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-20261008\cursor-ordinary-user-20261008.log`。原先失败的 `rejects precreated native symbolic links as an ordinary user` 已通过。

两种沙箱模式都在这 150 项里通过：unelevated 探测到可用内层沙箱，目录替换后的普通 Node 写入被拒绝；elevated 使用既有测试家，目录替换写入被拒绝，受保护文件助手写入成功。这只证明测试套件，不表示真实代理已改为无沙箱。

## 二、构建与发布

集群是 `kind-sunmoon-kind`，kubeconfig 为 `~/.kube/sunmoon-kind.config`，kubectl 为 `infrastructure/.tools/bin/kubectl`。C 盘剩余约 123 GiB。维护前现场在 `infrastructure/.build/luna-stage2-release-20261008-213221`（不入库）。源码锁已核对：investment `backend_revision=db96b401944b43fc2541704b165951eaac808e84`，relay `revision=4d0ff0433628b8e821ca6239eebd8cf46f0a4fe3`；其它应用、前端、sandbox、provisioner 锁未改。

维护前 Flux 源：`revision=dfe30caaf016765e788017dcfd5284d7c4a91f82`，`digest=sha256:e761175adf35e18eb525de2d977b637e8a80c2257069971fd3ee7918b1537b0e`。核对时 `knowledge-redis` 曾短暂 `DependencyNotReady`，复查后 71 个 Kustomization 全部 Ready。`platform-status` 退出码 0。

用户会话和 PID 1 的挂载命名空间不同。直接 `make platform-build` 时 sudo 清掉了 `OBJECT`，选择器把动作当成构建全部对象，投资后端第一次退出码 **2**，没有发布。同一条 `make` 改在 PID 1 挂载命名空间里执行，对象选择保留，签名和 TLS 检查没有关闭。

| 命令 | 退出码 |
| --- | --- |
| `platform-status` | 0 |
| `platform-build OBJECT=app-platform/investment-app/investment-backend`（用户命名空间） | 2 |
| 同上（PID 1 挂载命名空间） | 0 |
| `platform-build OBJECT=relay-platform/relay`（PID 1 挂载命名空间） | 0 |
| `platform-stage OBJECT=app-platform/investment-app` | 0 |
| `platform-stage OBJECT=relay-platform/relay` | 0 |
| `application-deployment-plan APP=investment` | 0 |
| `flux-release` | 0 |
| `flux-source-apply` | 0 |
| `flux-source-status` | 0 |
| `platform-check OBJECT=relay-platform/relay` | 0 |
| `application-check APP=investment` | 0 |
| `application-check-public APP=investment` | 0 |

| 镜像 | digest | source_revision |
| --- | --- | --- |
| investment-backend | `sha256:0c75cb542efbe02989f56e804c6a4452d601d2347fcdb0b510792dc0787b751d` | `db96b401944b43fc2541704b165951eaac808e84` |
| relay | `sha256:04421137f2a2fb2bf07b3bb20c582c6a83626e5a438c8b7708eee98add913672` | `4d0ff0433628b8e821ca6239eebd8cf46f0a4fe3` |

候选 diff 只有这两个镜像锁、所属 workload 的镜像摘要、`deployment_id`、relay 的 `input-sha256` 注解，以及随摘要更换的 Job 名。迁移 Job 从 `investment-migrate-d2e6ed5d20a3-v4` 换成 `investment-migrate-0c75cb542efb-v4`。`EXPECTED_SCHEMA_REVISION` 仍是 `20261007_0013`。没有 SOPS 或其它对象变化。没有退回。

## 三、提交、晋级与运行镜像

| 提交 | 作用 |
| --- | --- |
| `f6e9aa0b09ee222699eb6bf6b55473a202030663` | 两个镜像锁与 workload 候选 |
| `8d07a0c059670487c5c852e481dc5ca2828ac326` | 晋级 `flux-source.yaml`；revision 仍是候选 `f6e9aa0b`，没有改成晋级提交 |

`infrastructure/.build/flux/source-candidate.yaml` 与晋级后的环境源一致：

- repository `oci://harbor.sunmoonai.com:30443/platform/deployments-kind`
- path `./clusters/kind`
- requires_sops `true`
- revision `f6e9aa0b09ee222699eb6bf6b55473a202030663`
- digest `sha256:ed2e004657e99435027e32d37c0a824ef270384af99b0c97cd0b6be30e35cb3d`

晋级后 OCIRepository `platform` Ready，71 个 Kustomization Ready，`relay`、`investment-runtime`、`investment-migration` 的 `lastAppliedRevision` 都是上述 digest。relay 的 HTTPS `/healthz` 检查 `passed=true`。

实际 Pod `imageID`：

| Pod | 阶段 | imageID |
| --- | --- | --- |
| `relay-5cf7b449f9-ktpbc` | Running | `harbor.sunmoonai.com:30443/platform/relay@sha256:04421137f2a2fb2bf07b3bb20c582c6a83626e5a438c8b7708eee98add913672` |
| `investment-api-c9f7597db-ztqnz` | Running | `harbor.sunmoonai.com:30443/platform/investment-backend@sha256:0c75cb542efbe02989f56e804c6a4452d601d2347fcdb0b510792dc0787b751d` |
| `investment-runner-597b555747-h6fnl` | Running | 同上 |
| `investment-scheduler-6ccdc74c4f-mc62w` | Running | 同上 |
| `investment-worker-6d7c9cbc8-22ntx` | Running | 同上 |
| `investment-migrate-0c75cb542efb-v4-hlcbh` | Succeeded | 同上 |

identity、redis、rabbitmq、service-identity 这几个一次性 Job 也是 Succeeded，镜像摘要相同。没有删账本事件，没有重建集群。

## 四、本条没有做的检查

- MCP 真实端点调用。
- 本机 CLI 审批进入工作台审计回执。
- 1b 第 4/6 轮两次旧投影拒绝的定位。

这些不能从本条的合成测试或健康检查推断为通过。

exit=0
