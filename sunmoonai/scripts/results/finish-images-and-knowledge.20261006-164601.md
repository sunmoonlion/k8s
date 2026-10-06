# 待办 26 回传续二：finish-images-and-knowledge

时间：2026-10-06 16:46。同步后的 inbox 仍是同一份待办 26。HEAD 在 `7f756882`（只引用签名密钥对的应用不再要求 `private_dir/domain.yaml`）之上。工作区当时干净，stash 为空。沙箱锁和供给器的 `SANDBOX_IMAGE` 已在 `a2e74eb0` 里，钉提交没变，这次没有重跑第二、三节。

## 二、沙箱（上次已完成，本次未重跑）

上次 `platform-build OBJECT=sandbox-platform/sandbox` 退出 0，76 秒（16:28:58–16:30:14）。日志 `infrastructure/.build/applications/sandbox-build-domestic.log`。已提交的锁没有 `harbor_project`，digest `sha256:e758ccb23d40e07f53c4e26b9473bb26d5425ef80848e15d5a7ca4eb88a75c3b`，`source_revision` `e3ce871f96d160aa2017960e98d176c102b991e4`。

## 三、会合点、供给器（上次已完成，本次未重跑）

会合点暂存退出 0，25 秒，diff 为空。供给器暂存退出 0，16 秒。`SANDBOX_IMAGE`：

- 旧：`harbor.sunmoonai.com:30443/app-images/sandbox@sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f`
- 新：`harbor.sunmoonai.com:30443/platform/sandbox@sha256:e758ccb23d40e07f53c4e26b9473bb26d5425ef80848e15d5a7ca4eb88a75c3b`

工作区里这一行已与新摘要一致。

## 四、knowledge 暂存

`platform-stage OBJECT=app-platform/knowledge-app` 退出 0，用时 69 秒（16:43:31–16:44:40）。

`runtime/domain.sops.yaml`：`stringData` 只有 `KNOWLEDGE_MCP_JWT_PUBLIC_KEY`，值是密文；文件头是 `BEGIN AGE ENCRYPTED FILE`；`sops:` 头 1 个。`grep -c 'ENC['` 是 2，另一处是 sops 的 `mac`。没有 `BEGIN PRIVATE KEY` / `BEGIN PUBLIC KEY`。已跟踪的其它 sops 文件没有改动。

供给器策略 diff：`knowledge-source-policy-v1` → `v2`，`knowledge-source-v1` → `v2`，Resource 从 `info-originals/info/original/*` 变成 `info-originals/info/*`，记录行的 source 变成 `info-originals/info/`，挂策略失败时认 `already in effect`。

runtime 新增行里有：`ARTIFACT_S3_ALLOWED_PREFIXES: "info/"`、`CROSS_APP_TARGETS_JSON`、`CROSS_APP_SOURCES_JSON`、`KNOWLEDGE_DATASET_REGISTRY_ENABLED: "true"`、`sizeLimit: 2Gi`、`kind: NetworkPolicy` / `name: knowledge-sandboxes-in`（来自 `sandbox-platform-dev`、标签 `sunmoonai.com/sandbox=true`）。

## 五、部署计划

| 计划 | 退出码 | 用时 | 结论 |
| --- | --- | --- | --- |
| tpl | 0 | 4s | schema `20260911_0003` |
| info | 0 | 4s | schema `20260929_0013` |
| knowledge | 0 | 4s | schema `20260927_0007` |
| investment | 0 | 4s | schema `20260929_0012` |
| platform-plan OBJECT=all | 0 | 1s | 退出 0 |

## 六、提交

`b6a5560f test(local): 待办 26 沙箱锁、会合点与供给器再暂存、knowledge 候选`。10 个文件，含新建的 `domain.sops.yaml`。

## 结论

通过。knowledge 暂存退出 0，密文、前缀 `info/`、代次 v2、沙箱入站策略和五个计划都对上。沙箱镜像与供给器镜像行沿用 `a2e74eb0`，本次没有重构建。
