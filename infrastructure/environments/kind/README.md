# KIND共享环境与晋级身份

[site.yaml](site.yaml) 保存**站点事实**（SDD 0039 第二版，C1 字段集）：跨模块共用、换一个站点就会变的值。模块参数在自身 config（只留模块常量与按站点值派生的路径），版本在锁，秘密在私有输入/SOPS；保持一个来源。规矩：站点文件里不许出现别的站点的值，代码里不许出现任何站点的值。模块 config 里可以写 `{{ site_domain }}` 这类 Jinja，但**重读配置文件一律用 `lookup("template", …, convert_data=False)`**，`lookup("file")` 不过 Jinja（C1 教训）。

| 字段 | 维护条件 |
|---|---|
| `site_name` / `site_role` | 目录名与命名空间后缀的来源：守卫核对 `cluster_name == 'sunmoon-' + site_name`、七个命名空间 `== '<层>-platform-' + site_role`。改它等于换站点 |
| `cluster_name` | 集群/目录/receipt/私有输入相关身份；派生 `services_config_dir`、`sops_config_dir`、`host_runtime_dir`、应用 `private_dir`、各备份目录。不是任意重命名入口 |
| `cluster_builder` / `cluster_context` | 建法（`kind` / `kubeadm`）与 kubectl 上下文名；kind 的上下文固定是 `kind-<cluster_name>`，kubeadm 的等于 `cluster_name`。所有 kubectl/flux 调用只认 `cluster_context` |
| `cluster_kubeconfig` | 本集群独立访问文件（从 cluster/config.yaml 搬来） |
| `cluster_operator` / `operator_home` | 宿主操作用户及其家目录：候选与构建产物属主、Jenkins 代理用户、MinIO 许可证位置 |
| `data_root` | 数据盘挂载根：`backups/`、`jenkins/` 都在它下面派生；WSL 开发站点是 `/mnt/sunmoon-data`，虚拟机/云上是数据盘挂载点 |
| `site_domain` / `public_port` | 站点域名与公网入口端口（开发 `sunmoonai.com`:30443，C2b 起开发改 `dev.sunmoonai.com`；生产 `sunmoonai.com`:443）。短名（`tpl`、`casdoor`、`kibana`…）两站相同，留在各模块 config 里拼成 `<短名>.{{ site_domain }}`；`entry_port`、`edge_https_port` 从 `public_port` 派生。Traefik 的 NodePort 30443 是入口组件常量，不是这个端口 |
| `edge_mode` / `edge_public_ip` | 公网边缘在哪（`separate`=东京 VM，`local`=宿主自带公网 IP）及其地址；`edge_domains` 由短名与 `site_domain` 拼出 |
| `entry_cluster_backend` | 入口上非 Harbor 域名的默认后端（kind：节点 IP + 节点入口端口）。C4 起改由建群模块的身份回执给出 |
| `registry_address` | 公共仓库契约；守卫核对它等于 `registry_hostname:entry_port`。域名/端口改变联动证书、镜像引用和节点/客户端信任 |
| `artifact_cache_root` | 正式物料路径；先核锁内文件完整与生成依赖，再迁移路径 |
| 七个 `*_namespace` | 共享运行位置；应用都用 `app_namespace`；已有 PVC/身份跨 namespace 不是热改配置 |

C4 加 kubeadm 的网段与节点表，见 [SDD 0039](../../../docs/design/SDD/modules/0039-c-site-parameterization.md)。

Makefile显式加载模块/组件config再加载`SITE`，当前默认本文件。不要引入同名重复字段依赖覆盖顺序维持“两个默认值”。

[flux-source.yaml](flux-source.yaml)保存已晋级repository/digest/revision/path/requires_sops，它们必须对应同一个真实已发布Git产物；当前path为`./clusters/kind`。公共加密recipient在[sops-recipient.txt](sops-recipient.txt)，私钥工作树外。

日常流程见[Flux发布与晋级](../../flux/README.md#发布与显式晋级)、[组件配置分类](../../../gitops/components/README.md)。修改共享身份需独立迁移、备份、恢复与验收安排，不能通过覆盖参数绕开原生守卫。
