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

**实施记录（2026-10-21，Fable）**，与上面设计的出入：

- 字段名保留 `cluster_operator`、`cluster_kubeconfig`（搬进 site.yaml，不改名；第三节表里的 `operator_user` 即 `cluster_operator`），另加 `operator_home`（MinIO 许可证等宿主私有文件的位置）。
- 硬断言不是改成「等于站点文件里的值」（那是同义反复），改成**跨字段核对**：`cluster_name == 'sunmoon-' + site_name`（8 处，含 gitops 里 upload.yaml、neo4j recover-rollout）、七个命名空间 `== '<层>-platform-' + site_role`、`registry_address == registry_hostname + ':' + entry_port`（4 处）、`entry_port == registry_address` 的端口（registry/publish）。路径断言全部改为从 `data_root` / `cluster_name` 派生（12 处）。
- `--context`：模板里 20 处 `kind-{{ cluster_name }}` → `{{ cluster_context }}`；8 个 Python 脚本（verify-live、object-storage、text-embeddings、elk、neo4j、ragflow、knowbase provider、sandbox provisioner、agent-releases upload）原来写死 `kind-sunmoon-kind` 或不带上下文，现在都收 `--context` 参数，调用方传 `cluster_context`；elk 采集验收的 `cluster` 标签也改为参数。`check-dns.py` 只读站点文件。`ci/release.groovy` 的站点目录与 kubeconfig 从 `site` 参数（默认 `kind`）和站点文件取。
- **教训（Cursor 卡 fable-c1 第一次改后渲染失败）**：六个应用后端的 `config.yaml` 除了作 extra-vars 加载，还被 `bind.yaml`、`applications/verify.yaml`、`deploy.yaml` 用 `lookup("file") | from_yaml` 重读，重读不过 Jinja，写进去的 `{{ cluster_name }}` 原样留着。改法：`private_dir`、`backup_dir` **不再写在应用配置里**，由这三处加载时从 `cluster_name`、`data_root`、应用名推出来（原断言本来就要求恰好这个形状），断言随之删除。规矩：**会被 `lookup("file")` 重读的文件里不能放 Jinja**，站点值只能在加载处派生。第二次渲染又发现：六个后端 `workload.yaml` 的 `config-sha256` 变了——运行配置摘要按 `cfg` 的**键序**算，派生键追加在末尾和原来在文件中间不是一个哈希，会让六个后端滚动更新；改为插回原位（`deploy_budget_bytes` 之前）。同时主工作树 `.build/components` 里有旧名应用的残留候选和旧的 sops 候选，冷目录基线没有，比对要从干净的 `.build` 起步。第三次比对只剩 knowbench `domain.sops.yaml`：解密后 before/after 明文相同、密文不同，是 sops 加密不确定性（两边都因输入早已变过而重新加密）。**字节对比的规矩补一条：`*.sops.yaml` 比解密后明文的哈希，不比密文**（远程经隧道用备份 age 身份解、只打印 sha256）。
- 账号私有路径守卫（`host/account_files.py`）的数据盘根从环境变量 `SUNMOON_DATA_ROOT` 来，由剧本传 `data_root`。
- **没动**：`host/storage.py` 与 `host/config.yaml` 的 WSL 挂载布局、Windows 脚本目录、`cluster/` 的 kind 守卫、`registry_instance_dir: /data/harbor/platform-kind-v1`（两站都能用这个路径）——宿主层按建法分型（WSL / 虚拟机）在 C4 做。`entry_cluster_backend` 这轮只搬进站点文件，身份回执派生留到 C4（现在改要重跑建群才会写回执）。`applications/check-browser.py` 的 30443 随 C2 的端口参数一起改。
- 远程机上 `platform-plan OBJECT=all` 已通过（它不依赖集群）；`components-render` 需要活集群，字节对比由本地卡 fable-c1 做。

### C2 域名与端口变参数（动 gitops/ 的 config 与模板）

**摸底（2026-10-21 夜）**：代码里 `sunmoonai.com` 的 187 处，121 处是 `harbor.sunmoonai.com:30443`（即 `registry_address`，两站同名，**不动**）；其余大多在**已提交的渲染产物** `workload.yaml` 里（渲染会重写，不是手改对象）。真正的**来源**只有这些：

| 来源 | 处数 | 今天的样子 |
| --- | --- | --- |
| 12 份应用前端 `config.yaml` 的 `origin` | 12 | `https://tpl.sunmoonai.com:30443`（字面量，**被 bind/verify/deploy/domain 用 `lookup("file")` 重读**） |
| 10 份运维/数据组件 `config.yaml` 的 `*_origin` | 10 | `https://kibana.sunmoonai.com:{{ entry_port }}`（已半参数化，只走 extra-vars） |
| `casdoor_hostname`、`jenkins_hostname` | 2 | 字面量 |
| knowbench 的 `WORKBENCH_RELAY_PUBLIC_URL`、admin 的 `KNOWFEED_ADMIN_URL` | 2 | 字面量 |
| `edge_domains`（东京）、`frpc_domains`（集群侧） | 2 | 三个公开名字的列表 |
| 模板里 `{{ casdoor_hostname }}:30443` | 8 处 `.j2` | 端口写死 |
| 断言 `is match('^https://[a-z0-9.-]+:30443$')`、`casdoor_hostname + ":30443"` | 9 | 端口写死 |
| Python：`check-browser.py` 的 `30443`、`verify-live.py` 的 casdoor 地址、`edge/smoke/run.sh` | 3 个文件 | 字面量 |

**两个 30443 不是一回事**：公网/入口端口（开发 30443、生产 443）和 Traefik 的 NodePort（30443，两站都是，kind 的 `containerPort`、`entry_cluster_backend` 的端口都是它）。前者进站点文件叫 `public_port`，后者是入口组件的常量，不参数化。

**参数面（site.yaml 加三个，短名不进站点文件）**：`site_domain`（开发 `sunmoonai.com` → C2b 改 `dev.sunmoonai.com`；生产 `sunmoonai.com`）、`public_port`（开发 30443、生产 443）、`edge_public_ip`（从 `edge/config.yaml` 搬来，它是站点事实；`edge_mode` 一并加）。短名（`tpl`、`tpl-admin`、`casdoor`、`kibana`…）两站相同，留在各模块 config 里：`casdoor_hostname: 'casdoor.{{ site_domain }}'`、`origin: 'https://tpl.{{ site_domain }}:{{ public_port }}'`、`entry_port: '{{ public_port }}'`、`edge_domains: ['knowbench.{{ site_domain }}', …]`。与第三节表的出入：表里的 `hostnames.<对象>` 不做，短名不是站点事实。`registry_hostname` 仍是字面量（所有者定）。

**重读的解法（C1 教训的正解）**：所有 `lookup("file", <config.yaml>) | from_yaml` 改成 `lookup("template", …) | from_yaml`——`template` 查找会先过一遍 Jinja、变量和当前 play 相同、键序不变。bind/verify/deploy 的 web/admin 配置（6 处）、`domain/prepare.yaml` 的四个 `web_origins`、test-computer 读 `edge/config.yaml` 的那处（改成直接用变量）一起改。改完这条规矩变成：**配置文件里可以写 Jinja，重读一律用 `template`**。

**代码清单**：① 24 份 config.yaml 的 origin/hostname/domains 改派生；② 8 处 `.j2` 与 9 处断言的 30443 改 `public_port`；③ `check-browser.py` 端口从目标 origin 取、`verify-live.py` 收 `--casdoor-origin`、`edge/smoke/run.sh` 从 edge 配置取域名与端口；④ edge 的 make 目标加载站点文件；⑤ `test-computer` 的出站放行端口改 `public_port`。`casdoor_client_id: sunmoon-kind-tpl-web` 这类嵌着集群名的身份 **C2 不动**（它们是 Casdoor 里登记过的身份，改了要重新登记），留到 C5 和样例站点一起定。

**分两停**：

- **C2a 参数化、值不变**：开发站点渲染逐字节相同（方法同 C1：冷目录 before/after、sops 比明文哈希）、五项只读入口、render-check SUCCESS。远程自己跑。
- **C2b 开发站点改 `dev.sunmoonai.com`**：改一行 `site_domain`，然后走一次**真实发布**（Jenkins release，人批）。渲染会变的：所有前端 origin 与跨应用链接、Casdoor 各应用的回调地址（`provision.py` 按 origin 重新登记）、平台 CA 重签 casdoor/组件/Jenkins 证书（SAN 换名）、relay 公网地址、frpc 与东京的域名、HAProxy 路由。**所有者要做的三件**：(1) 域名商处加公网 DNS：`knowbench.dev`、`casdoor.dev`、`relay.dev` → 43.153.135.74（或 `*.dev.sunmoonai.com` 泛解析；Let's Encrypt 要靠它签新证书，集群内 Pod 解析 casdoor 也靠它）；(2) 本机 hosts 加 17 个 `*.dev.sunmoonai.com` → 127.0.0.1（`windows_hosts_add.ps1`，过 UAC），旧行先留着；(3) Jenkins 第 8 阶段点批。**验收**：render-check SUCCESS；release SUCCESS；所有者浏览器用新名字登录工作台一次；东京 `edge-smoke` 过；`application-check` 过；Windows 本地代理（sunmoon-link）能重新连上新的 relay 地址——它装在所有者电脑上、连接地址来自工作台下发，若缓存了旧名要重配一次，这是 C2b 最可能出问题的地方。正式名 `knowbench.sunmoonai.com` 等的 DNS 这时**不动**，继续指东京（等生产站点建好再指过去）。

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
| C0 | 生产宿主：本地机 Hyper-V 虚拟机建起来 | SSH 免密、sudo、/data 挂着、能出站 | Fable 写脚本与卡，所有者跑 PowerShell，luna 做 WSL 侧与核对 |
| C1 | 集群身份与路径 | 开发站点渲染字节相同；render-check SUCCESS | Fable 改，luna 跑 |
| C2 | 域名与端口 | 同上 | 同上 |
| C3 | 两段流水线 + Harbor 复制 | 假目标复制一次成功；开发站点 release 照常 | **往后挪**（所有者 2026-10-21：先只建一台虚拟机，在生产站点上开发；有第二个站点时再做） |
| C4 | kubeadm 模块 | 语法；有一次性 VM 就排练 | Fable 写；排练要所有者给 VM |
| C5 | 样例站点 + 门禁 | prod 样例 plan 通过；门禁零命中 | Fable |

C1、C2 是「改很多处、结果不变」的活，靠字节对比兜底；C3、C4 是新能力。每个停点所有者看一眼。

## 六、和 D 段的边界

C 段**不**：建生产集群、买 VM、改 DNS、换 Argo、改 `gitops/clusters/kind/` 的结构（它随 D 段一起变 `clusters/<站点>/` 或 Argo 的 ApplicationSet）、合并两份 verify、搬 `infrastructure/` 目录。D 段冷建时同时验两件事：开发站点能从物料重新长出来；生产站点第一次长出来。

**所有者已定（2026-10-21 早，总纲第六节第 9 条最终版）**：C → D（kind 冷建）→ E（切到新 kind）→ 整套 kind 导出到本机外存档并试导验证 → 回收本机 kind → D'（虚拟机上用同一份声明空着冷建，kubeadm）→ 以后在虚拟机开发。C 段任务不变：参数化到位，kubeadm 建法在 c0 那台虚拟机上排练通，为 D' 铺路；c0 那台之后是生产站点；**开发虚拟机先不建**（所有者 2026-10-21：在生产站点上开发、上线，有真实用户再分开），C3 随之往后挪。

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

- 第 2 条定（所有者 2026-10-21 早：「手中没有云，用本地机虚拟，内存足够大」；Windows 专业版、128 GB、给 32 GB）：**生产站点先建在本地机的虚拟机上**（Ubuntu 24.04，8 核、32 GB、系统盘 60 GB、数据盘 300 GB（按需增长），192.168.80.0/24，固定 IP 192.168.80.10；本地机实测是 Windows 家庭版且所有者不想动原系统，所以用 VMware Workstation Pro 而不是 Hyper-V，网关 .2），C、D、E 都先在它上面走通，搬云时同一份 `site.yaml` 换 IP 和盘。建法在 `infrastructure/environments/prod/vm/`（所有者跑的 PowerShell + 本地助手生成的自动安装应答 ISO），卡 fable-c0。单节点够用的理由：和 kind 同形；有状态服务的数据在节点本地盘，多节点不带跨节点存储也换不来高可用；`kubeadm` 模块按「一个控制面加零到多个工作节点」写，以后加机器是加一行。原先说的「生产 VM」= 云厂商租的一台虚拟服务器，生产站点整个跑在它上面（宿主层 + kubeadm 集群），和东京那台小边缘 VM 不是一台（那台太小）。规格等量过开发集群的实际占用再定；C4 排练另要一台几小时的一次性小 VM。
- 第 3 条定：**生产用正式名，开发改成 `*.dev.sunmoonai.com`**（开发 `site_domain: dev.sunmoonai.com`），在 C2 做：本机 hosts、Casdoor 各应用的 origin、平台 CA 重签证书、东京边缘公开的三个名字一起换；正式名的 DNS 等生产站点建好再指过去。
- 第 5 条定：**Harbor 两站同名 `harbor.sunmoonai.com`，不改开发的**。理由：它只在各自内网解析、从不跨站访问，不冲突；而改开发 Harbor 的名字要重写全部镜像引用与镜像锁、重推所有镜像，代价大且没有收益。`registry_address` 因此是独立字段，不从 `site_domain` 派生。


1. **生产集群的建法**：kubeadm 单节点自建（推荐：和 kind 同形、最省、不绑云厂商；高可用以后加），还是云托管 Kubernetes。
2. **生产 VM**：哪家云、大致规格。当前开发集群整套（六个应用、RAGFlow、ELK、数据库们）跑在一台机上；我建议先开一张小卡在开发集群上量实际占用（CPU、内存、盘），再定规格。C4 的排练还需要一台**一次性**小 VM（几小时），要不要现在给。
3. **域名**：生产直接用 `knowbench.sunmoonai.com` 等正式名（推荐）；那开发站点经东京边缘公开的三个名字要改成 `*.dev.sunmoonai.com` 之类，或者生产上线后边缘不再公开开发站点。
4. **生产公网端口**：443（推荐），不再是 30443。
5. **生产 Harbor 的名字**：和开发同名 `harbor.sunmoonai.com`（各自内网解析，推荐，参数最少）还是 `harbor-prod.…`。
6. **生产的口令与秘密放哪**：生产宿主私有目录（推荐），仓里只有 sops 公钥。
7. 停点顺序按第五节；C4 排练没有 VM 就并进 D 段。
