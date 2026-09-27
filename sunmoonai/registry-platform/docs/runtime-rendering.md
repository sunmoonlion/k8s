# 集群外 Harbor 共用运行配置

本地和云上共用 `runtime_config.py`（Compose）与 `runtime_files.py`（私有文件）两部分，输入是官方 Harbor 2.13.2 生成结果、原加密/认证材料、已验证叶证书和固定镜像标识。**这一步是配置准备，不是安装和启停完成。**云上未经实机验证。

后续进展：新实例已使用本生成器完成实际准备、逻辑恢复和只读运行验收，见[宿主实例](host-instance.md)。下文保留纯渲染单元当时的范围；官方归档config摘要与Docker运行ID的区别及修复也见该文。

## 已核对范围

2026-09-27 使用本机官方生成结果，在内存中生成本地/云端、只读/可写四组配置；当前 Compose 5.1.3 已用 `config --no-env-resolution` 解析四组输出。原配置和演练目录未改，未创建文件/容器、未启动服务、未 SSH。结果：[公开证据](../../scripts/results/luna-registry-runtime-render.20260927.json)。

- 8 个角色：core、registry、registryctl、portal、proxy、jobservice、PostgreSQL、Redis。
- Harbor 2.13.2 的 6 个官方运行镜像元数据取自整包 SHA256 已核验的安装包；Compose 使用固定 image ID，不依赖可变 tag。PG17.6/Redis8.2.1 使用现有精确摘要，并核本机 image ID。Jobservice 镜像尚未在此步骤导入，镜像层运行验收仍待安装。
- 每个实例独立目录 `/data/harbor/instances/<deployment>`；目录名须与 `sunmoon-harbor-...` 实例名对应。全部持久文件用显式 bind，`create_host_path=false`；覆盖镜像声明卷，避免产生匿名卷。KIND 节点、卷和集群目录不出现在映射中。
- 本地仅发布 `127.0.0.1:18443`，将由 SNI 代理承接 30443；云端只发布显式仓库主机私有 IPv4 的 30443。示例 `10.50.0.5` 只用于内存渲染，不是登记云主机。
- backend 是 internal 网络，frontend 只接 proxy、关闭 masquerade；不自动赋予 core/jobservice 访问公网的能力。将来启用复制、Webhook、扫描数据库更新等出站任务前，须把目的地址/出站策略接进主机配置并验收，不能因本次解析通过就宣称这些任务可用。
- 原 core 16字节加密密钥、令牌签名证书/私钥、registry htpasswd 原样映射；core/registryctl/jobservice 的共享凭据和 registry HTTP secret 保留。HTTPS 使用原 CA 新签的五年 Harbor 叶证书，原内部令牌身份不变。
- Redis 仍为8.2.1，正式准备时生成一次并保存的独立高强度认证口令，同步到 core、registry、jobservice；数据库编号0/1/2和官方 `idle_timeout_seconds=30` 原样保留。配置启用 AOF/everysec，实际运行/恢复还没验收。只读检查的随机口令只存在内存，没有持久化或替换任何口令。
- 初始只读模式的 registry 数据 bind 为只读、READ_ONLY=true，Jobservice 置于默认不启用的 profile。可写模式只是另一个渲染参数；这一步没有切换现有服务写状态。GC/保留策略尚未配置，暂时关闭删除和上传清理，后续与备份验收一并接通。
- Docker restart=no；将由挂载检查通过后的主机生命周期负责启停。当前未安装自动启动单元。

## 复核方法

从 `k8s` 根目录运行，默认只打印、不读私有文件、不访问 Docker：

```bash
python3 -B sunmoonai/registry-platform/runtime_inspect.py
```

只读核对当前已完成的本地准备批次（需要读 root 私有配置和 Docker 权限）：

```bash
sudo -n python3 -B sunmoonai/registry-platform/runtime_inspect.py --check \
  --source /data/harbor/candidates/harbor-2.13.2-20260927 \
  --tls-batch /home/zymun/private/registry-platform/tls-20260927-five-year \
  --installer /home/zymun/packages-to-be-installed/releases/registry-platform-2.13.2-linux-amd64/harbor-offline-installer-v2.13.2.tgz \
  --ca-sha256 30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec
```

输出只有公开元数据和核对结果，不输出私有环境/Compose正文/口令/密钥。`--check` 不落盘新配置；Compose 关闭 env 文件解析，因为正式实例尚不存在。需要等真正准备实例目录后，再逐字节验证 raw env 的有效值。默认 profile/真实启停/健康、推拉和数据库恢复均未由此命令验证。

## 安装器必须继续完成

1. 固定 Compose/管理工具与 PG/Redis/Jobservice 的完整离线物料。此处沿用本机 Compose 5.1.3，尚未制作其独立离线包。`env_file.format: raw` 的语义依据 [Docker Compose 官方文档](https://docs.docker.com/reference/compose-file/services/#env_file)，必须保留原凭据字节。
2. 在新的正式实例目录生成私有文件，写明目录及文件 UID/mode、根盘 UUID/服务挂载可见性检查；不能修改演练目录或沿用其 repaired 容器状态。
3. 停写时生成一致的新备份；数据库逻辑导入、镜像层复制、全目录摘要、身份和目录核对。禁止把旧冷备份验证通过当成最新数据已经迁移。
4. 镜像内容核验及导入、受管容器创建、分阶段启动、明确容器 ID 的停止/保留、备份恢复与 systemd 挂载门禁；不使用 down/rm/prune，不接管陌生容器。
5. 接上主机 local/SSH 参数化执行、云端 step11 前置步骤和首次上云清单；云端只演练，不能将本机的四组内存渲染称为 SSH 已实现或云部署已验证。
6. TLS 握手、权限推拉、Jobservice/CI-CD、备份恢复、重建 KIND 不影响 Harbor 数据；SNI 30443 切换与所有者的 WSL 压缩维护窗口衔接。清理仍最后执行。

规则核对：C-D1 数据主档在集群外独立目录；C-I8 参数/映射冲突拒绝；C-R1/R2 整包和运行镜像身份固定；C-T5 仅本地 luna 提交。
