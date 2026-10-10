# Cursor 回执：卡 E 第一段（接线 + 候选）

时间：2026-10-10 17:55（UTC+8）。只做到停点 1。没有 flux-release，没有晋级，没有 `application-check`，没有重建或发布镜像，没有改镜像锁和 `sources.yaml`。

卡 D 三处小改已单独在源码仓提交，没有单独停：网页 `18e4268`，后端 `b11f9bd`。本候选没有把这两次提交写进镜像锁。运行中的镜像仍是已发布的 backend `a01db6f`、网页 `2095c04`。

## 已做

| 项 | 结果 |
| --- | --- |
| 本地校验 | `verified-local`，97 个文件，ZIP SHA256 `d00c1392e73079d24063877656599b0600da3806e18d3943e194fde617479e6e`，manifest SHA256 `e133f26f006c5e1ae3635ed0e031213a2bedb4ab6e6c574a06d74c754eb3f543`，`size_bytes` 175305493 |
| 上传回执 | `uploaded-and-verified`。桶 `agent-releases`，对象 `windows-x64/0.2.4/sunmoon-agent-0.2.4-a878d14-windows-x64.zip`。`uploaded=true`，`existing_preserved=false`，`readback_verified=true`，`reader_write_denied=true`，`writer_read_denied=true`。因此 `download_available` 保持 `true` |
| 模板原件 | runtime `a878d145` 的 `agent/distribution/install.ps1.tmpl` 复制到 `agent-releases/install.ps1.tmpl`。两边 SHA256 都是 `491035b68ea3f4bbe63ef848f51f7d292d07c9224334a5d261b527c00d066cfe`，4937 字节，开头 `efbbbf` |
| 候选解密 | `WORKBENCH_AGENT_INSTALL_SCRIPT_TEMPLATE` 与该文件逐字节相同，同一 SHA256。六个占位符各一次：`PACKAGE_URL`、`VERSION`、`SIZE_BYTES`、`ZIP_SHA256`、`MANIFEST_SHA256`、`CODEX_VERSION` |
| 配对密钥 | `domain.sops.yaml` 新增 `WORKBENCH_AGENT_PAIRING_HMAC_KEY`，40 位字母数字。原有四项（含 Fernet 的 `WORKBENCH_CREDENTIAL_KEY`）明文未变 |
| 可信代理网段 | 明文环境 `WORKBENCH_TRUSTED_PROXY_CIDRS=127.0.0.1/32,10.247.0.0/16` |
| stage | `application-stage APP=investment` 退出码 0。未选中的 stage 声明保持不变。没有应用 |

`make agent-release-verify`、`agent-release-upload` 和 `application-stage` 都是先进入 PID 1 的挂载命名空间再跑。数据盘只在那个命名空间里；直接在用户 shell 里跑时，Makefile 的 `sudo env PATH=...` 会丢掉 `AGENT_ZIP`。Makefile 没有改。

第一次候选解密时，模板少了末尾一个换行（4936 对 4937）。BOM 和六个占位符都在，Ansible 没有展开 `{{PACKAGE_URL}}`。原因是 `lookup('file')` 默认 `rstrip`。同一查找加上 `rstrip=False` 后重新 stage，第二次解密与原件逐字节相同。没有改用别的编码。

## 明文 diff

`agent-releases/config.yaml`：版本 0.2.1 → 0.2.4，源码 `a878d145553625e9283701822d455d0eb3d043c0`，对象键、两个 SHA256、`size_bytes` 175305493 如上。`codex_version` 仍是 0.155.1。

`agent-releases/prepare.yaml` 增加一行：

```yaml
WORKBENCH_AGENT_INSTALL_SCRIPT_TEMPLATE: "{{ lookup('file', component_root + '/agent-releases/install.ps1.tmpl', rstrip=False) }}"
```

`investment-backend/config.yaml` 增加：

```yaml
WORKBENCH_TRUSTED_PROXY_CIDRS: '127.0.0.1/32,10.247.0.0/16'
WORKBENCH_AGENT_PAIRING_HMAC_KEY: {source: random}
```

`runtime/workload.yaml` 把同一网段写进明文 ConfigMap。四个运行负载的 `sunmoonai.com/config-sha256` 从 `77da779461b1829c7b22fe774886a55a422022c61d9ee44b26925992700b1b76` 变为 `19a72229cb6deefc873a07cca21fd3b4f20a1a521ce84b94e9df7c19bf22393e`。

解密后的下载描述符是 `mode=object-storage`、`version=0.2.4`，对象键和两个哈希、大小与上传回执一致，地址落在 `/api/workbench/agent/package`。存储密钥没有打印。

## 候选里多出来的身份任务

`identity/workload.yaml` 从 v2 重渲成 v3：ConfigMap `investment-identity-provision-v3`，Job `investment-identity-4cf3a9391d0a-v3`，`CASDOOR_USER_ORGANIZATION=sunmoonai`，网页 ConfigMap `WEB_CASDOOR_ORGANIZATIONS=sunmoonai`。这来自本次开工前已经提交的 `identity_user_organization: sunmoonai` 和 `identity_revision: v3`。stage 照配置重渲，没有手改，也没有发布。U 仍等卡 E 验收之后。

## 未做

没有发布，没有晋级，没有 `application-check`，没有看 Traefik 日志，没有在 Windows 上卸载、安装、配对或点「允许」。第二段等「可以发」。
