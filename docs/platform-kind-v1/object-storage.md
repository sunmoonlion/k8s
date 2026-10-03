# 对象存储接入结果与操作

2026-10-03 已接入原 Make → Ansible → Flux 服务和应用链。AIStor RELEASE.2026-09-19T17-05-25Z 与官方同日 mc 客户端均固定摘要；原许可实际被接受，不是只检查 JWT 格式。

配置/实现归 [对象存储组件](../../gitops/components/data-platform/object-storage/README.md)，应用机制归 [后端存储机制](../../gitops/components/app-platform/common/backend/storage/README.md)。秘密在 /etc/sunmoon 和独立备份，Git 只含 SOPS；无需手工 kubectl 创建 Secret。

## 原生入口

从 infrastructure 使用 services-plan/materials/publish、services-stage。审核暂存差异后本地提交，用 flux-release 发布，核对 .build/flux/source-candidate.yaml 并晋级 environments/kind/flux-source.yaml，再运行 services-bootstrap/services-check。

应用对象存储通过后端 config.yaml 启用，使用 application-stage APP=info → 提交/同一源发布晋级 → application-bootstrap APP=info。日常重复 bootstrap 校验已晋级配置，不会默默把未提交配置送入集群。application-check-public APP=info 复验现有正式域名。

## 实际验收与修复

- AIStor 在 data-platform-dev，单副本、worker2 独立 Retain 静态卷；HTTPS CA 与服务主机名验证，license/root/TLS仅只读 Secret 文件；不公开 Console。
- services-bootstrap 完成真实 S3 PUT/GET、VersionId 和文件 SHA256；只删除本轮 UUID 探针桶。
- info_storage 只访问 info-originals。桶开启版本控制，API/Worker/Scheduler读取独立凭据及公共CA，不持有root。
- 直接在实际 API 角色调用业务 ObjectStorage，写同名对象两版本，分别按 VersionId读回并核对字节/metadata；跨桶及暂停版本策略请求 AccessDenied。
- 原有登录、数据库授权、Redis、消息、Scheduler、前后端TLS与PKCE/SSR回归通过。tpl可选机制渲染逐字节不变。
- 首次 v1 判据只看进程退出码：官方 mc admin info 可返回 exit0 + JSON status=error，导致误判。v2 又暴露官方最小客户端镜像不含 grep。最终 v3 使用已锁客户端的 POSIX shell JSON错误状态检查；账号创建通过受支持的 stdin 形式，口令不放 argv。未授予额外权限。
- v1/v2仅初始化 Job失败，Flux依赖门禁阻止运行配置推进；修正版成功后，已核对并删除这两个无PVC的失败Job及其临时卷，失败记录保留在本轮忽略的证据目录。完成的v3保留作为幂等声明。

证据：infrastructure/.build/applications/runtime-unit-20261003/object-storage-*、info-storage-v3-*、info-storage-bootstrap-repeat.log；不提交操作日志或明文Secret。

## 验收边界

当前为KIND单节点单卷，不能宣称高可用、机器外灾备或重启/重建持久化已通过。整个爬取、搜索索引、RAGFlow和跨应用分发尚未完成；空间监控、保留/垃圾回收和备份轮换仍按收尾要求交付，不自动删除业务对象历史版本。
