# Jenkins Kaniko 构建制品

本目录的 `kaniko-build-pipeline.groovy` 是**未完成实机验收的构建示例**，云端未经实机验证。
它只检出真实源码、构建并归档 Docker tar，不负责发布。原来直接推 tag/latest、占位 Dockerfile、
硬编码 Harbor IP 和跳过 TLS 的路径已移除。

## 必须提供的配置

- Jenkins 作业明确选择已核实目标集群的 `KUBERNETES_CLOUD`。
- `JNLP_IMAGE`、`KANIKO_IMAGE` 使用已准入内部仓库 `repo@sha256`；默认空值会被拒绝。
  Agent 必须有 git/sh；Kaniko 必须是支持 `/busybox/sh` 及所用参数的 debug 制品。
  这里没有把旧 debug/latest 标签冒充为已锁定版本，也没有下载或升级构建器。
- `IMAGE_REPOSITORY` 是 app-images 内的仓库名，不带 tag；源码仓根必须有真实 Dockerfile。
- 节点已配置独立 Harbor DNS、CA 与拉取身份；Pod DNS 必须能解析同一域名，不使用旧云 IP。
- 命名空间中准备只读拉取用途的 `kaniko-registry-secret`、`harbor-registry-secret`，
  以及 `registry-ca`（`ca.crt`）；`CA_SHA256` 必须对应已准入 CA。
  不得把旧管理员或推送账号当作构建容器的只读账号。

示例禁用 ServiceAccount token 自动挂载，固定 amd64，设置构建资源/临时存储限制。
CA 在执行前核摘要；Kaniko 使用 `--registry-certificate` 和 TLS 默认校验。
`--no-push` 与 `--no-push-cache` 同时启用，避免仅禁最终镜像却仍向仓库写缓存。
源码在 `source/`，输出在其同级 `sunmoon-build-artifacts/`，避免把导出包放进构建上下文。
构建前后核 Git 状态和提交；被忽略文件、下载依赖仍不属于可复现构建保证。

## 输出如何发布

Jenkins 归档 Docker tar、tar SHA256、源码提交和构建器 manifest digest。
按批准的制品传输流程取回并核对 tar 字节后，执行：

1. `./sunmoon harbor prepare-image`：指定 tar、SHA、无 tag 的目标仓库和新输出目录；先计划后 apply。
2. 复核生成的 OCI 摘要和 `publication.json`。转换后可能改变 digest，以新批次为准。
3. `./sunmoon harbor publish`：同一发布器、独立发布账号、严格 TLS；先计划后 apply。
4. 将实际 OCI 摘要接入发布门禁/bundle，经过验收再部署；不重新构建正式别名。

参数与失败恢复见[统一发布说明](../../registry-platform/docs/publication.md)。
本轮未启用 Jenkins 作业、运行 Pipeline 或推送镜像；没有声称 CI 自动传输和发布调度已经接通。
旧 README 提到的 `Kaniko实施指南.md`、`Kaniko迁移方案.md` 在当前仓未找到，不作为入口。
现存 CASC 模板与 Secret 部署入口仍须逐项适配、核验只读身份，不能直接沿用旧 tag 或认证配置。

[上游参数说明](https://github.com/GoogleContainerTools/kaniko/blob/v1.23.2/README.md)
解释 no-push/no-push-cache、tar-path 和 registry-certificate；实际选定构建器仍须核版本/参数及拉取能力。
