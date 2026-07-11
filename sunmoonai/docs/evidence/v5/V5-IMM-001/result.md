# V5-IMM-001 配置真相紧急保护执行证据

日期：2026-07-11
状态：ACCEPTED

## 实施结果

- Git desired state 将 `AGENT_V4_TRAFFIC_ENABLED` 固定为 `false`。
- 新增 `AGENT_V5_TRAFFIC_MODE=off`。
- 生成阶段执行独立门禁校验。
- 部署 ConfigMap 前再次执行相同校验。
- 生成使用临时文件，全部校验通过后原子替换目标文件；失败不会留下不安全生成产物。
- 无 Kubernetes API 时仍执行模板变量和流量门禁离线检查；有 API 时继续执行 kubectl OpenAPI dry-run。

## 验证

正向验证：

```text
bash generate-research-admin-backend-config.sh
[SUCCESS] Agent traffic gates are closed
[SUCCESS] configmap 生成完成
```

反向验证：

```text
AGENT_V4_TRAFFIC_ENABLED=true bash generate-research-admin-backend-config.sh
=> rejected

AGENT_V5_TRAFFIC_MODE=canary bash generate-research-admin-backend-config.sh
=> rejected
```

两次失败后，安全生成文件 SHA-256 保持不变：

```text
03e21f6df4b8c7a5faeeec32fc0e795d2e690f6c83b2fa6a63d4de2ace870fb6
```

Shell 语法检查：通过。

KIND 应用结果：

```text
configmap/research-admin-backend-config configured
```

集群复核：

```text
AGENT_V4_TRAFFIC_ENABLED=false
AGENT_V5_TRAFFIC_MODE=off
```

## 回滚与限制

- 回滚代码会移除 v5 门禁并可能重新引入配置漂移，不建议回滚。
- 本任务只保证配置生成和部署默认拒绝开流量；未来正式 canary 必须引入经 Gate M1b 授权的显式发布机制，不能绕过校验脚本直接修改 ConfigMap。
- ConfigMap 更新不会自动重启现有 Pod；当前 v4 值此前已为 `false`，因此不存在关闭状态延迟生效风险。v5 mode 目前仅作为发布保护字段，应用代码尚未消费。
