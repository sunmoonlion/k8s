# 待办 33 回传：沙箱镜像加 Windows 沙箱级别

时间：2026-10-07 23:51。没有退回。所有者 23:49 拉起了沙箱。

## 一、核对与构建

头工作区干净。入口脚本第 35 行写 `[windows]`，下一行是 `sandbox = "unelevated"`。清单钉的提交是 `2fe6652cb99c3bb482263724ccefd42ea01532e4`。`platform-status` 退出 0，16 秒。

`platform-build OBJECT=sandbox-platform/sandbox` 退出 0，41 秒。锁：

```yaml
digest: sha256:57b2db0e498b34809482b15afcc0a21c47232bda7b530be3f90fa0f106c48f6a
source_revision: 2fe6652cb99c3bb482263724ccefd42ea01532e4
```

旧摘要是 `sha256:e758ccb2…`，源修订从 `e3ce871f…` 换成上面这一条。

## 二、暂存与提交

`platform-stage OBJECT=sandbox-platform/provisioner` 退出 0，17 秒。变的是：

- `sandbox/image.lock.yaml` 的 digest、source_revision、deployment_id
- 供给器 `SANDBOX_IMAGE` 换成 `sha256:57b2db0e…`
- 供给器 `input-sha256` 从 `e2a37b28…` 换成 `bff6473e…`（供给器自己的镜像没变）

提交 `2b8f5208`。

## 三、发布、晋级、应用

`flux-release` 退出 0，29 秒。候选：

```yaml
digest: sha256:e13a5391f0d47731a2537466b18d7b9b7da8287ad5ecc648e4e912c3a37ce76c
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 2b8f5208412409599c9d938626a8a21d77eb6f42
```

diff 只有 digest 和 revision。提交 `125d8b49`。`flux-source-apply` 退出 0，190 秒。`flux-source-status` 退出 0，3 秒。供给器新 Pod `sandbox-provisioner-6c74bcd96-4v4tc` 1/1 Running，声明里的 `SANDBOX_IMAGE` 已是 `sha256:57b2db0e…`。

## 四、重拉沙箱

23:48 时旧 Pod `sandbox-u-f1cee6277692-65bfcbd995-ggdqf` 仍是 `sha256:e758ccb2…`，进容器找 `[windows]` 退出 1。所有者随后拉起。23:50 新 Pod：

```text
sandbox-u-f1cee6277692-b87d4946d-8cjvc  sandbox@sha256:57b2db0e…  Running  2026-10-07T15:49:55Z
```

`/data/codex/config.toml` 第 12–13 行：

```text
[windows]
sandbox = "unelevated"
```

`exec` 退出 0。`platform-check OBJECT=sandbox-platform/provisioner` 再跑一次，退出 0，19 秒。

## 结论

通过。新沙箱用的是新镜像，配置里有 `[windows] sandbox = "unelevated"`。
