# SDD 0039：C 段——站点与集群建法参数化（一套声明，换参数长出云上的生产站点）

> 地图位置：横切「环境参数」；第 2 站点层、第 4 集群层；交付链的两段跑法。来源：架构总纲第四节「一个站点」那行、第六节第 6、8 条（集群建法可换；开发内网、生产云上、两个 Harbor、开发构建生产只部署）、0033 第十节 10.5b。状态：**设计，待所有者定第九节**（2026-10-21 凌晨，Fable；所有者「开工」后先出设计）。B 段已闭合。

## 一、要解决什么

今天整套东西只会长成**一个样子**：本地机、kind、`sunmoon-kind`、`sunmoonai.com:30443`、`/mnt/sunmoon-data`、东京边缘。这些事实不是集中在一处，而是散在代码里：

| 事实 | 写死在哪（`environments/` 之外） |
| --- | --- |
| 集群名 `sunmoon-kind` | 96 个文件；6 处**硬断言** `cluster_name == 'sunmoon-kind'`（`components/render.yaml`、`flux/bootstrap.yaml`、`flux/source.yaml`、`flux/foundations-check.yaml`、`host/deployment.yaml`、……）；`services/`、`flux/` 的配置目录和备份目录名里带它 |
| kind 这种建法 | kubectl 一律 `--context=kind-{{ cluster_name }}`（5 处）；`entry_cluster_backend: 172.18.0.5:30443` 是 kind 节点 IP；`cluster/` 整个模块 |
| 域名 `sunmoonai.com`、端口 `30443` | 187 / 132 个文件；gitops 里 24 份 `config.yaml` 的 `origin: https://<app>.sunmoonai.com:30443` 是字面量，33 份模板也是；4 处硬断言 `registry_address == 'harbor.sunmoonai.com:30443'`，1 处 `entry_port == 30443` |
| 宿主与人 | `cluster_operator: zymun`、`cluster_kubeconfig: /home/zymun/.kube/…`、`artifact_cache_root: /home/zymun/k8s-packages`、`/mnt/sunmoon-data`（22 个文件）、`/data/*`、数据盘 UUID（`host/config.yaml`）、密码表在仓根 |
| 边缘 | `edge_public_ip: 43.153.135.74` 与三个公网域名 |
| 集群内的根 | `gitops/clusters/kind/` 一套 Flux 根，名字就叫 kind |

`environments/kind/site.yaml` 今天只有 10 行（集群名、Harbor 地址、物料缓存、7 个命名空间）。C 段要做到：**换一份 `site.yaml`，不改别的文件，`platform-plan` 就能算出另一个站点该长什么样**；生产站点的建法（kubeadm）作为 `cluster/` 旁边的另一个模块。真把云上的站点建起来是 D 段的事，C 段只保证「参数够、代码不认死理」。

## 二、站点是什么：`environments/<站点>/`

一个站点一个目录，目录里只放**非秘密的参数**和**公开的指针**：

```
environments/
  kind/            开发站点（今天的一切）
    site.yaml      站点参数（第三节）
    sops-recipient.txt
    flux-source.yaml（已晋级的指针；D 段换 Argo 后变成提交号）
  prod/            生产站点（C 段只放样例，D 段真建）
    site.yaml
    sops-recipient.txt
    flux-source.yaml
```

秘密、口令预设、私钥一律在站点宿主的私有目录（`/etc/sunmoon/…` 和备份盘），**不在仓里**。今天仓根的 `密码修改表.md` 是开发站点的，生产站点的表放生产宿主的私有目录，由 `host/accounts.yaml` 按站点参数去读。

## 三、参数面：`site.yaml` 第二版

按总纲的层分组，每个字段一个来源；今天散在各模块 `config.yaml` 里的站点事实搬进来，模块 `config.yaml` 只留模块自己的常量（端口、镜像、目录名的**相对**部分）。

| 组 | 字段 | 开发站点（kind） | 生产站点（prod，样例） | 今天在哪 |
| --- | --- | --- | --- | --- |
| 站点身份 | `site_name` | `kind` | `prod` | 没有（目录名隐含） |
| | `site_role` | `dev` | `prod` | 没有 |
| 集群 | `cluster_name` | `sunmoon-kind` | `sunmoon-prod` | site.yaml |
| | `cluster_builder` | `kind` | `kubeadm` | 没有（代码认死 kind） |
| | `cluster_context` | `kind-sunmoon-kind` | `sunmoon-prod` | 5 处硬写 `kind-` 前缀 |
| | `cluster_kubeconfig` | `/home/zymun/.kube/sunmoon-kind.config` | `/etc/sunmoon/cluster/prod.config` | cluster/config.yaml |
| | `cluster_pod_subnet`、`cluster_service_subnet`、`cluster_api_port`、`cluster_ingress_port` | 今天的值 | 按云网络定 | cluster/config.yaml |
| 网络 | `site_domain` | `sunmoonai.com` | `sunmoonai.com` | 字面量 187 处 |
| | `public_port` | `30443` | `443` | 字面量 132 处 |
| | `hostnames.<对象>` | `knowbench`、`casdoor`、`harbor`、`jenkins`…（短名） | 同 | 各模块 config.yaml |
| | `edge_mode` | `separate`（东京 VM） | `local`（生产宿主自己有公网 IP，入口直接对外） | 没有 |
| | `edge_public_ip`、`edge_domains` | 今天的值 | 生产宿主 IP；全部用户可见域名 | edge/config.yaml |
| 宿主 | `operator_user` | `zymun` | `sunmoon` | cluster/config.yaml 等 |
| | `data_root` | `/mnt/sunmoon-data` | `/data`（云盘挂载点） | 22 个文件 |
| | `artifact_cache_root` | `/home/zymun/k8s-packages` | `/data/packages` | site.yaml |
| | `storage_mounts` | 数据盘 UUID 三处 | 云盘 | host/config.yaml |
| 物料与仓库 | `registry_address` | `harbor.sunmoonai.com:30443` | `harbor.sunmoonai.com:443`（或 `harbor-prod.…`，第九节定） | site.yaml（另有 4 处硬断言） |
| | `registry_upstream` | （无） | 开发 Harbor 地址 + 复制项目 | 没有 |
| 交付链 | `root_repo` | `sunmoonun` | `sunmoonun` | jenkins/config.yaml |
| | `pipeline_mode` | `build-and-deploy` | `deploy-only`（第 1–7 阶段在开发站点跑，这里从第 8 阶段起） | 没有 |
| | `jenkins_hostname` 等 | 今天的值 | 同形 | jenkins/config.yaml |
| 命名空间 | 7 个 `*_namespace` | `…-dev` | `…-prod` | site.yaml |
| 秘密 | `sops_config_dir`、`sops_backup_dir`、`account_table` | 今天的值（按 `cluster_name` 派生） | 生产私有目录 | flux/config.yaml、host/accounts.yaml |

规矩：**站点文件里不许出现别的站点的值**，代码里不许出现任何站点的值。为此加一道门禁（第七节）。

## 四、代码要改什么（按停点）

### C1 集群身份与路径不认死理（只动 infrastructure/，开发站点字节不变）

- 6 处 `cluster_name == 'sunmoon-kind'` 硬断言改成「等于站点文件里的值」——它们的本意是防拿错站点，改成核对 `cluster_name == site.cluster_name` 加「kubeconfig 里的集群 UID 等于身份回执」（后者已有）。
- `--context=kind-{{ cluster_name }}` 5 处改读 `cluster_context`。
- `services_config_dir`、`sops_config_dir`、备份目录等按 `cluster_name`/`data_root` 派生，不再在模块 `config.yaml` 里写全路径；`cluster_kubeconfig`、`cluster_operator` 搬进 site.yaml。
- `entry_cluster_backend`（kind 节点 IP）改成建群模块产出的事实（身份回执里加 `ingress_backend`），入口模块读回执。
- 4 处 `registry_address == 'harbor.sunmoonai.com:30443'`、1 处 `entry_port == 30443` 改成核对站点值。
- **验收**：改前改后在开发站点上 `components-render OBJECT=all`、`platform-plan OBJECT=all` 的输出逐字节相同（`.build/` 对比），render-check SUCCESS。

### C2 域名与端口变参数（动 gitops/ 的 config 与模板）

- 24 份 `config.yaml` 的 `origin: https://tpl.sunmoonai.com:30443` 改成 `origin: 'https://{{ hostnames.tpl_web }}.{{ site_domain }}:{{ public_port }}'`（`--extra-vars @file` 进来的值 Ansible 会在用到时模板化，已有先例 `entry_cluster_routes` 就这么写）；33 份模板里的字面量同样改。
- 边缘、入口、Jenkins、Harbor 的域名都从 `hostnames` + `site_domain` 拼。
- **验收**：同 C1，开发站点渲染结果逐字节相同（因为值没变）。

### C3 站点角色：两段流水线与 Harbor 复制

- `ci/release.groovy` 按 `pipeline_mode`：`deploy-only` 时第 1 阶段核对后直接进第 8 阶段（候选从**本站 Harbor** 读——开发站点发完第 7 阶段后多一步「把声明包和镜像按摘要复制到生产 Harbor」）。
- `registry/` 模块加 `registry-replication-plan/apply`：用 Harbor 接口在开发 Harbor 上建一条按摘要推送到 `registry_upstream`（生产 Harbor）的复制规则（只推 `platform/` 项目里被晋级候选引用的制品，不全量）。开发站点的 release 第 7.5 阶段触发一次复制并等完成。
- 生产 Jenkins 的 `release`：参数多一个 `CANDIDATE`（候选摘要），第 8 阶段摆出来等人批，后面照旧。
- **验收**：开发站点上能对一个**假目标**（第二个本地 Harbor 项目）建复制规则并复制一次候选；生产那头等 D 段。

### C4 生产建法：`infrastructure/kubeadm/`（新模块，`cluster/` 不动）

- 和 `cluster/` 同形的五个动作 `kubeadm-plan/deploy/status/…`，`cluster_builder: kubeadm` 时 `platform-*` 调它而不是 `cluster-*`。
- 第一版：**单节点** kubeadm（和 kind 一样是一个节点，上层最少改动），containerd，Calico 用同一组锁住的镜像，本地路径存储用云盘挂载点，`cluster_kubeconfig` 写到站点参数指定的位置、context 名按 `cluster_context`，生成同样格式的集群身份回执。节点上的物料（kubeadm/kubelet/containerd 二进制与镜像）走物料链锁住，不 `apt install` 最新版。
- 多节点、高可用控制面以后按需要加，不在 C 段。
- **验收**：C 段只能做到「剧本写完、`--syntax-check` 过、在一台**一次性**云 VM 上排练一遍建起来、`kubectl get nodes` Ready、身份回执生成、删掉 VM」。没有一次性 VM 就只做前两项，排练并进 D 段。

### C5 样例站点与门禁

- `environments/prod/site.yaml` 按第三节填样例值；`platform-plan OBJECT=all SITE=environments/prod/site.yaml` 和 `platform-config` 能在**没有集群、没有宿主**的情况下算出计划（plan 本来就不碰集群）。
- 门禁 `site-gate.py`：`infrastructure/`、`gitops/`、`ci/` 里不许出现 `environments/` 下任何站点文件里的值（集群名、域名、端口、IP、数据根、用户名），白名单只有 `environments/` 自己和历史文档。进 `.githooks`。

## 五、顺序与停点

| 停点 | 内容 | 验 | 谁 |
| --- | --- | --- | --- |
| C1 | 集群身份与路径 | 开发站点渲染字节相同；render-check SUCCESS | Fable 改，luna 跑 |
| C2 | 域名与端口 | 同上 | 同上 |
| C3 | 两段流水线 + Harbor 复制 | 假目标复制一次成功；开发站点 release 照常 | 同上 |
| C4 | kubeadm 模块 | 语法；有一次性 VM 就排练 | Fable 写；排练要所有者给 VM |
| C5 | 样例站点 + 门禁 | prod 样例 plan 通过；门禁零命中 | Fable |

C1、C2 是「改很多处、结果不变」的活，靠字节对比兜底；C3、C4 是新能力。每个停点所有者看一眼。

## 六、和 D 段的边界

C 段**不**：建生产集群、买 VM、改 DNS、换 Argo、改 `gitops/clusters/kind/` 的结构（它随 D 段一起变 `clusters/<站点>/` 或 Argo 的 ApplicationSet）、合并两份 verify、搬 `infrastructure/` 目录。D 段冷建时同时验两件事：开发站点能从物料重新长出来；生产站点第一次长出来。

## 七、风险

- 改 187 处字面量会漏：靠门禁（C5）和字节对比（C1/C2）双保险，不靠眼睛。
- `--extra-vars @config.yaml` 里的 Jinja 值在某些 `assert` 里可能提前被当字符串比较：逐处跑过，开发站点字节对比会暴露。
- 生产公网端口 443 要 root 绑定或 `CAP_NET_BIND_SERVICE`：入口模块已是 root 跑的 systemd 单元，可以。
- 生产和开发同用 `sunmoonai.com`：生产 DNS 指到云上后，开发站点内网靠 hosts 文件不受影响，但**东京边缘今天公开的三个开发域名要让位**（第九节第 3 条）。

## 八、怎么验（汇总）

1. 开发站点：C1、C2 前后 `.build/components/` 与 `platform-plan` 输出逐字节相同；render-check、一次 `release` NOT_BUILT 照常。
2. 门禁：`site-gate.py` 零命中；doc-gate、anchor-gate、check-links 不退步。
3. 样例生产站点：`platform-plan/config OBJECT=all SITE=environments/prod/site.yaml` 通过。
4. Harbor 复制：对假目标复制一次候选，摘要相同。
5. kubeadm：`--syntax-check`；有 VM 则 `kubectl get nodes` Ready 加身份回执。

## 九、要所有者定的（2026-10-21 早所有者答复见各条末尾）

所有者答：1 自建（kubeadm）；2 问「生产 VM 啥意思」（答在下面第 2 条）；3、5 指出现在用的就是正式域名，问是不是该改开发的；4 用 443；6、7 按建议。

- 第 2 条：「生产 VM」= 云厂商租的一台虚拟服务器，生产站点整个跑在它上面（宿主层 + kubeadm 集群），和东京那台小边缘 VM 不是一台（那台太小）。规格等量过开发集群的实际占用再定；C4 排练另要一台几小时的一次性小 VM。
- 第 3 条定：**生产用正式名，开发改成 `*.dev.sunmoonai.com`**（开发 `site_domain: dev.sunmoonai.com`），在 C2 做：本机 hosts、Casdoor 各应用的 origin、平台 CA 重签证书、东京边缘公开的三个名字一起换；正式名的 DNS 等生产站点建好再指过去。
- 第 5 条定：**Harbor 两站同名 `harbor.sunmoonai.com`，不改开发的**。理由：它只在各自内网解析、从不跨站访问，不冲突；而改开发 Harbor 的名字要重写全部镜像引用与镜像锁、重推所有镜像，代价大且没有收益。`registry_address` 因此是独立字段，不从 `site_domain` 派生。


1. **生产集群的建法**：kubeadm 单节点自建（推荐：和 kind 同形、最省、不绑云厂商；高可用以后加），还是云托管 Kubernetes。
2. **生产 VM**：哪家云、大致规格。当前开发集群整套（六个应用、RAGFlow、ELK、数据库们）跑在一台机上；我建议先开一张小卡在开发集群上量实际占用（CPU、内存、盘），再定规格。C4 的排练还需要一台**一次性**小 VM（几小时），要不要现在给。
3. **域名**：生产直接用 `knowbench.sunmoonai.com` 等正式名（推荐）；那开发站点经东京边缘公开的三个名字要改成 `*.dev.sunmoonai.com` 之类，或者生产上线后边缘不再公开开发站点。
4. **生产公网端口**：443（推荐），不再是 30443。
5. **生产 Harbor 的名字**：和开发同名 `harbor.sunmoonai.com`（各自内网解析，推荐，参数最少）还是 `harbor-prod.…`。
6. **生产的口令与秘密放哪**：生产宿主私有目录（推荐），仓里只有 sops 公钥。
7. 停点顺序按第五节；C4 排练没有 VM 就并进 D 段。
