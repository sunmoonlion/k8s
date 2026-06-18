# casdoor db-access-bootstrap

Casdoor 数据库开通工具。仅需 PostgreSQL，无 Redis / MongoDB。

## 当前状态

数据库已手动初始化（2026-04-05）：
- DB: `casdoor`，用户: `casdoor`，密码见 `config/postgresql.external.env`

再次执行脚本是幂等的（已存在的 DB / 用户不会重建）。

---

## 外部访问模式（本地调试 / 首次建库）

```bash
bash setup-external-db-access.sh
```

**前提**：需要 `psql` 命令可用。`DBCTL_BIN` 默认使用 k8s 仓库内的
`utils/db-provisioner/bin/dbctl`，特殊环境可通过环境变量覆盖。

---

## K8s Secret 模式（集群内部访问）

```bash
bash setup-k8s-db-access.sh
```

在 `app-platform-dev` 命名空间创建 Secret `casdoor-postgresql-conn`，
内含集群内连接串，供 Helm chart `envFrom` 引用。

`DBCTL_BIN` 默认使用 k8s 仓库内的 `utils/db-provisioner/bin/dbctl`，
部署机无需额外 checkout `investment-app`。

---

## 清理

```bash
bash teardown-external-db-access.sh   # 删除 DB 和用户（外部）
bash teardown-k8s-db-access.sh        # 删除 K8s Secret
```

> ⚠️ teardown 会删除数据库及全部数据，生产环境慎用。
