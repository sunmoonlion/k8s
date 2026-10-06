# 外置Harbor维护

Harbor由宿主WSL上的官方离线安装包、同版prepare、官方配套镜像、Compose与systemd运行，数据与KIND节点独立。版本、归档和镜像身份分别见[文件锁](../artifacts/files.lock.json)、[启动镜像锁](../artifacts/harbor-offline-images.lock.json)、[发布策略](release.yaml)；不复制第二套BOM。

## 安装、启停和前提

需要Docker/systemd/OpenSSL、非交互sudo和可见的数据盘；工具和已校验物料按[tools](../tools/README.md)、[artifacts](../artifacts/README.md)准备。首次使用：

```sh
make -C infrastructure prepare-harbor-materials
make -C infrastructure install-binaries BINARIES=compose
make -C infrastructure registry-plan
make -C infrastructure registry-deploy
make -C infrastructure registry-status
```

已有部署的日常控制：

```sh
make -C infrastructure registry-stop
make -C infrastructure registry-start
```

plan检查挂载/配置；deploy生成本实例官方配置并启动；start只启动已部署配置；stop保留容器、卷、配置和数据；status不依赖挂载预检。运行中的配置差异会拒绝deploy，修改须在维护中stop→deploy；`registry_enabled=false`阻止deploy/start，不停止已有服务。

## 配置、数据与秘密位置
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `registry_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `registry_hostname` | 文本/表达式 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `registry_project` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `registry_https_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `registry_config_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `registry_runtime_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `registry_data_root` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `registry_instance_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `registry_log_rotation_approved` | 开关 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |

| 内容 | 位置/责任 |
|---|---|
| 管理员admin、内部数据库口令 | `registry_config_dir/private/admin-password`、`database-password`，root0600 |
| publisher/puller及认证JSON | 同`private/`下`{publisher,puller}.json`、`*-auth.json`，root0600 |
| CA/私钥/服务证书 | `registry_config_dir/tls/`；客户端公共CA在`clients/ca.crt` |
| 运行配置、Compose和挂载守卫 | `registry_runtime_dir`；运行独立于Git工作树 |
| 数据库、registry层、加密密钥、扫描数据 | `registry_instance_dir/data/`；日志在`logs/` |

当前公共仓库地址统一来自[site.yaml](../environments/kind/site.yaml)，为`harbor.sunmoonai.com:30443`；后端只绑loopback11443，由[entry](../entry/README.md)按域名直通。Compose项目名与Harbor内私有`platform`项目名不同。

输入目录0700、秘密0600。已初始化的管理员/数据库密码不会因重新编辑本地文件而轮换；入口会实际登录并检查输入，漂移时停止。秘密或证书/密钥只剩半对时要求恢复，不自动覆盖已有身份。凭据、证书与数据均需完整备份。

## 项目和受限身份

```sh
make -C infrastructure registry-accounts
make -C infrastructure registry-publish-check
```

accounts核对/创建私有platform项目，分别创建publisher（pull/push）与puller（pull），无删除权限，令牌90天；同入口核对精确权限、至少7天有效期和真实token认证。服务返回的secret须保存，不能假设请求指定secret已生效；项目机器人查询限定Level/ProjectID，再精确匹配账号。

管理员只管理身份，不供应用发布使用。主身份文件/远端账号缺一时停止，恢复或显式轮换，不能静默改密。自动轮换和到期告警尚未交付。

publish-check限定锁中的HAProxy验收镜像：独立publisher按manifest发布→puller完整拉回→逐blob/manifest/config核验→要求puller推送被拒；还有宿主Docker真实认证拉取。它会写入验收镜像，精确清除本次pullback工作区，保留已发布镜像。全部应用发布复用[artifacts](../artifacts/README.md)与[applications](../applications/README.md)，不把该单镜像检查泛化为全仓数据恢复。

## 证书与信任

服务器证书1825天、CA3650天；检查链、域名、至少30天剩余有效期以及公钥匹配。期限取`release.yaml`，证书的实际到期时间由实际证书读取；手册不固定某一次到期日期。

accounts追加Docker的仓库专用CA并保留其他CA。KIND信任与DNS由[cluster](../cluster/README.md)负责，浏览器信任另验。证书续签、CA轮换须联动客户端/节点/备份，当前没有一键轮换入口。Docker认证CA兼容性见[故障定位](../host/troubleshooting.md#docker认证拉取失败)。

## 启动与故障恢复

直接运行同版官方prepare镜像，在限定实例配置/数据/证书挂载中生成配置；不用包含`down -v`的install.sh，也不运行会操作全局/data身份的包装prepare。原Compose保留，原生override负责digest、资源、端口、健康、日志和重启归属。

systemd唯一管理重启，容器restart=no、Compose前台；任一组件退出停止整组并经过守卫恢复，120秒最多3次。启动核精确ext4/UUID/bind fsroot、宿主与Docker的设备/inode及实例落盘。失败即拒绝启动。此守卫不等于运行期故障监控。

本模块deploy只daemon-reload并管理本仓库，不单独启用boot autostart。当前由[宿主统一生命周期](../host/lifecycle.md)协调开机顺序，恢复单元已安装并启用；Harbor/KIND整套停启及目录/镜像验收已通过，真实Windows/WSL重启和删群重建仍见[未完成项](../../docs/platform-kind-v1/verification.md#未完成项)。

错误先看systemd和限定日志：

```sh
systemctl status sunmoon-registry.service --no-pager
sudo docker logs --tail 100 sunmoon-registry-core-1
```

日志可能含秘密，分享前脱敏。配置回退须恢复维护前完整配置/输入，stop后deploy/start，并检查health、认证和镜像摘要；含数据库schema的升级只能恢复匹配版本备份，不靠退回Git自动降库。完整方法见[恢复](recovery.md)。

## 日志、扫描和容量

已批准Docker local日志每容器最多3×20MiB，10组件约600MiB配置上限，不含额外文件/元数据。jobservice走stdout；Compose不再复制容器输出到journal。上传残留自动清理关闭，镜像保留/GC与备份删除未启用。

[扫描器维护](scanning.md)说明离线库、真实扫描、风险边界；[备份恢复](recovery.md)说明现有隔离恢复入口。容器healthy、库字节正确和扫描Success分别是不同结论；持久化重启/删群验收和生产安全门禁见[验收边界](../../docs/platform-kind-v1/verification.md)。
