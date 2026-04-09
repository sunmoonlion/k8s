# db-access-bootstrap

用于给 `auth-app-backend` 快速落地“external / k8s 两种场景”的数据库接入引导脚本。

## 文件说明

- `setup-external-db-access.sh`：external 场景，创建/更新租户并生成运行时 env
- `teardown-external-db-access.sh`：external 场景，回收租户并删除运行时 env
- `setup-k8s-db-access.sh`：k8s 场景，创建/更新租户并写入 K8s Secret
- `teardown-k8s-db-access.sh`：k8s 场景，回收租户并删除 K8s Secret
- `config/common.env`：统一开关和路径
- `config/postgresql.external.env`：PostgreSQL 外部配置
- `config/postgresql.k8s.env`：PostgreSQL k8s 配置
- `config/redis.external.env`：Redis 外部配置
- `config/redis.k8s.env`：Redis k8s 配置
- `config/mongodb.external.env`：MongoDB 外部配置
- `config/mongodb.k8s.env`：MongoDB k8s 配置

## 默认行为

- PostgreSQL：通过 `dbctl` 幂等创建/授权，写入 `DATABASE_URL`
- Redis：做外部连通校验，写入 `REDIS_HOST/REDIS_PORT/REDIS_DB/REDIS_PASSWORD`
- MongoDB（可选）：通过 `dbctl` 幂等创建/授权，写入 `MONGODB_URI`

## 典型使用

```bash
./setup-external-db-access.sh
set -a && source ./.env.c1-external && set +a
```

## 回收

```bash
./teardown-external-db-access.sh
```

## 安全提醒（非常重要）

- **不要把生产密码写进 repo**：`config/*.env` 中出现的密码仅用于演示/开发。
- **k8s 场景推荐**：通过 Secret/密管把 `PG_ADMIN_PASSWORD / APP_DB_PASSWORD / REDIS_PASSWORD` 注入到执行脚本的环境中，而不是写死在 `.env` 文件里。
- **回收风险**：`teardown-*` 默认只回收“用户/凭据”，不会删除数据库；若你显式开启删库开关，请确保不会误删数据。
