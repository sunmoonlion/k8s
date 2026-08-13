# 正式发布配置合同

Info、Knowledge、Investment 的 Kubernetes 部署均采用同一套配置合同：保留熟悉的
`deploy-<app>-app-all.conf`、App 总入口和六个组件入口，但所有入口只委托给同一份正式
bundle 和同一套部署实现，不复制 YAML。

## 目录职责

```text
<app>-app/
├── deploy-<app>-app-all/
│   ├── deploy-<app>-app-all.sh
│   ├── deploy-<app>-app-all.conf
│   └── profiles/
│       ├── KIND.conf
│       ├── C1.conf
│       └── production.conf
├── deploy-<app>-backend-api/        # 薄组件入口
├── deploy-<app>-backend-worker/
├── deploy-<app>-backend-scheduler/
├── deploy-<app>-migration/
├── deploy-<app>-admin-frontend/
├── deploy-<app>-web-frontend/
└── deployment/
    ├── bundle/                       # 门禁后不可变的发布真相
    ├── render.py
    └── deploy.py
```

App `.conf` 声明当前发布的 namespace、release id、三个不可变镜像 digest、三个公开 origin
和五个 Deployment 的副本数。profile 只声明集群侧操作参数，例如 kubeconfig 和超时。
Secret 值不得写入任何 `.conf`。

## 为什么配置不能直接覆盖 bundle

镜像、域名、副本数和 namespace 会改变实际发布物。入口会逐项比较 `.conf` 与
`deployment/bundle/release.json`；不一致时直接失败，并要求重新 render、执行门禁、生成新
release 后再部署。这样既保留可读、可编辑的配置入口，也避免把已经验收的 `2.0.0` 在运行时
偷偷改成另一个未留证版本。

配置文件采用严格 `KEY=VALUE`，不是 shell 脚本：禁止 `export`、未知键、重复键、命令替换
和空值。需要空格的说明文字必须加引号。

## 操作

```bash
# 仅检查配置、profile 和正式 bundle 是否一致，不访问集群
./deploy-info-app-all/deploy-info-app-all.sh config --cluster KIND

# 总体部署
./deploy-info-app-all/deploy-info-app-all.sh plan --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh server-dry-run --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh drift --cluster KIND

# 独立组件部署，仍复用同一配置与 bundle
./deploy-info-backend-worker/deploy-info-backend-worker.sh deploy --cluster KIND
```

当前只有 `KIND` profile 经过 `2.0.0` 门禁并启用。`C1`、`production` 文件是显式占位合同，
默认 `PROFILE_ENABLED=false`；完成对应集群的镜像可达性、Secret、TLS、NetworkPolicy、浏览器
和回滚门禁后，才可随新正式 release 一起启用，不能只改开关。

