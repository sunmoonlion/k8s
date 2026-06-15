# Elasticsearch App 资源 Provisioner

## 定位

Provisioner 是平台 Elasticsearch 管理面的唯一入口。它根据 App 声明创建：

- 索引模板；
- 版本化物理索引；
- 稳定的读写别名；
- Backend 专用角色和原生用户；
- 目标 Namespace 中的 Secret 和 ConfigMap。

声明不保存密码。业务 Backend 不获得 `elastic` 管理员凭据，也不得自行创建
平台索引、角色或用户。

声明格式参考 `declarations/example-backend.json`，JSON Schema 位于
`schema/elasticsearch-access.schema.json`。

## 命令

```bash
./sunmoonai/data-platform/elasticsearch/provisioner/elasticsearch-provisioner.sh \
  validate DECLARATION.json

./sunmoonai/data-platform/elasticsearch/provisioner/elasticsearch-provisioner.sh \
  --cluster KIND provision DECLARATION.json

./sunmoonai/data-platform/elasticsearch/provisioner/elasticsearch-provisioner.sh \
  --cluster KIND status DECLARATION.json

./sunmoonai/data-platform/elasticsearch/provisioner/elasticsearch-provisioner.sh \
  --cluster KIND rotate DECLARATION.json

./sunmoonai/data-platform/elasticsearch/provisioner/elasticsearch-provisioner.sh \
  --cluster KIND revoke DECLARATION.json
```

`provision` 是幂等操作。`rotate` 更新用户密码和目标 Secret。`revoke` 删除用户、
角色、Secret 和 ConfigMap，但保留模板、索引和别名。

## Backend 配置

Secret：

```text
ELASTICSEARCH_USERNAME
ELASTICSEARCH_PASSWORD
ca.crt
```

ConfigMap：

```text
ELASTICSEARCH_URL
ELASTICSEARCH_CA_CERT_PATH
ELASTICSEARCH_ALIASES
```

Deployment 应将 `ELASTICSEARCH_CA_CERT` 作为文件挂载到
`ELASTICSEARCH_CA_CERT_PATH`，并通过 `envFrom` 注入其余配置。

## 当前边界

- 首版使用原生用户，后续可以增加 API Key 凭据类型。
- 破坏性 Mapping 变更必须提升 `schemaVersion`。
- Provisioner 不删除索引，也不接管 RAGFlow 私有 Elasticsearch。
- 当前通过受控的本地 port-forward 执行管理 API；运行密码不会写入声明。
