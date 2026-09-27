# 独立宿主机 Harbor 实例：准备、恢复与只读启停

目标仍是一套平台部署代码、两种建群方式。此实例完全在 KIND 外，使用已挂好的独立数据盘；当前验证了本地准备、恢复和只读启动/停止。**尚未成为正式写入仓库，30443 未切换，云端 SSH 编排尚未接通、未经实机验证。**

## 本次实例及结果

- 配置：`config/harbor-main-local.json`；实例 `sunmoon-harbor-main-20260927`；目录 `/data/harbor/instances/sunmoon-harbor-main-20260927`。
- Harbor2.13.2、PG17.6、Redis8.2.1，均未升级；新签五年 HTTPS 证书已在这个实例实际握手通过。旧30443仍用旧服务。
- registry冷备份逐文件复制并独立重读：4,400文件、17,850,816,895字节全部SHA256相同。镜像blob还与其digest路径核对。
- 新空PostgreSQL目标逻辑恢复：49表、10,364行以及全部角色、表结构、序列/状态、扩展、数据库元数据和大对象摘要与固定逻辑导出一致。
- 3项目、64仓库、429可达制品、164标签一致；429份manifest原始字节SHA及响应digest全核对；实际读取121,690,112字节镜像层，SHA256匹配；匿名读取私有manifest被拒绝。
- 8服务容器及1初始化容器均停止保留；Jobservice未启动。旧11个恢复容器仍停止、六个旧/验证节点运行、Docker卷数仍43，旧Harbor健康接口为healthy。
- 证据：[luna-harbor-host-instance.20260927.json](../../scripts/results/luna-harbor-host-instance.20260927.json)。没有push/Jobservice/备份新接口/重建KIND独立性验收，没有清理。

此次恢复源仍是 `backup-20260926T145600Z` 和已核过的 `pg17-20260927T040000Z` 逻辑导出。它验证了这份冻结备份；**不能代表旧仓库后续写入已同步**。正式切换前还须停写冻结并复核最新源数据。

## 可复用入口

从 `k8s` 根运行。默认只打印，不读私有输入或访问Docker；`--apply`才执行。示例配置的绝对路径是本机批次，其他主机要准备自己的明确配置；不要把旧备份路径当作所有机器通用默认值。

```bash
python3 -B sunmoonai/registry-platform/host_prepare.py --config sunmoonai/registry-platform/config/harbor-main-local.json
python3 -B sunmoonai/registry-platform/host_runtime.py create --config sunmoonai/registry-platform/config/harbor-main-local.json
python3 -B sunmoonai/registry-platform/host_restore.py --config sunmoonai/registry-platform/config/harbor-main-local.json
python3 -B sunmoonai/registry-platform/host_verify.py --config sunmoonai/registry-platform/config/harbor-main-local.json
```

本次已完成的 prepare/restore **不能再次对原实例执行**。它们要求新目录/空数据库，以保留失败产物和回退数据。后续只检查或停止：

```bash
sudo -n python3 -B sunmoonai/registry-platform/host_runtime.py check \
  --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json --apply
sudo -n python3 -B sunmoonai/registry-platform/host_runtime.py stop \
  --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json --apply
```

`check --apply` 的 apply 仅表示执行只读检查，避免默认调用就访问现场。需要复验时，下面命令会启动新实例、限时15分钟验收，再停止保留；要求18443空闲，原30443不动：

```bash
sudo -n python3 -B sunmoonai/registry-platform/host_verify.py \
  --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json \
  --docker-credentials /home/zymun/.docker/config.json --apply
```

`host_runtime.py start ... --apply`只启动已核对恢复完成的只读实例，并等待PG/Redis就绪；返回的`health_verified=false`明确表示尚未完成HTTP验收。优先用上面的有界验收入口。Docker凭据只在内存读取，Redis探针的认证走stdin，不把密码放命令行或日志。

## 执行边界与恢复

- `host_prepare.py`核数据盘UUID、PID1/Docker挂载可见性和空间余量；本地沿用已发布storage-v2检查器。生成新的私有文件、raw env经Compose解析后逐字比对、导入缺少的官方镜像、复制registry；不建/启容器、不恢复数据库。
- 所有实例持久路径在其独立根目录下。文件按PG/Redis1001、Harbor10000设所有权；父目录0700，容器绑定目录显式设置750。CA私钥不复制，原core加密/令牌签名身份保持。
- 创建前检查同名容器、网络归属；显式实例标签和容器ID写入journal。创建后复核image、mount、端口、网络、环境值、restart=no和无匿名卷。失败不接管陌生资源。
- `host_restore.py`只在新空目标恢复固定SHA的globals/registry.dump，复用既有逐表库存核对函数。结束或失败时停止新PG及初始化器；失败数据库不覆盖重做。
- `host_runtime.py`支持create/check/start/stop。每次检查配置SHA，启动前再查挂载；stop按实例身份停止保留，不执行down/rm/prune，不改集群。它还不是无人值守自动重启服务；systemd与管理员附盘顺序仍待接通。
- `/data/harbor/.instance-preparation.lock`串行化准备、恢复、验收和启停，避免两个进程同时改实例。运行状态、输入收据和失败结果都在私有实例根中。
- 云端共享渲染和主机准备逻辑已保留显式独立数据盘UUID检查分支；仅静态审阅，未在云运行。完整SSH传输/主机身份校验/step11前置调用及首次上云演练仍待完成。

## 两个实际问题及修复

### Docker image ID 与官方 config digest

第一次镜像导入已完成，随后用归档config摘要执行`docker image inspect`被拒绝：本机containerd镜像存储的Docker ID是OCI manifest摘要。不是镜像版本发生了变化。

修复保留两项身份：`source_config_sha256`是官方归档config摘要，`id`是可运行Docker image ID。通过显式`/run/containerd/containerd.sock`的moby命名空间，只读获取manifest及config，分别复核内容SHA，确认manifest指向原config、其diff_ids与Docker报告一致，再固定运行ID。官方安装包整体SHA仍是输入门槛，不使用可变tag作为运行依据。

首次产生的6个官方别名、`runtime-import.tar`及诊断保留。没有删除重建目录。`--resume-before-copy`只允许同配置、私有文件逐字相同、尚无服务容器、registry为空且未生成preparation收据的前阶段；保存旧Compose后仅修正镜像引用。本次已完成复制后，该参数不能再次使用。此前纯渲染记录中官方镜像的id是config摘要，不能直接当作本机运行ID。

### API引用数组顺序

第一次目录验收停止，第二次保存快照后定位为97个制品的`references`排列不同；制品无增删，全部引用字段、内容与重复次数相同。官方[Harbor2.13.2 API模型](https://raw.githubusercontent.com/goharbor/harbor/v2.13.2/api/v2.0/swagger.yaml)将其表达为带父子ID、子digest及platform等字段的引用关系。

比较器仅对最外层references关系按完整JSON排序；保留全部字段和重复次数，不归一化引用内的数组、不修改原始快照，也不改写manifest。随后仍逐份读取原始manifest及其digest核验，镜像层目录的全文件SHA核对不变。失败的`catalog-observed-*`与`catalog-difference-*`留在实例目录；未把顺序差异当成数据丢失，也未跳过内容比对。

## 接下来的准入

1. 将Compose5.1.3、相关管理工具及PG/Redis恢复来源纳入完整离线物料清单；本次直接使用本机已有工具，未宣称新空主机已具备离线安装闭包。
2. 正式备份/恢复接口、只读到可写切换、Jobservice与认证推拉/CI-CD、挂载检查后的自动启动。当前原始官方配置生成阶段仍使用前次候选输出，尚未成为全新空主机的通用安装入口。
3. SNI30443入口、KIND main创建、静态/动态卷接线，以及重建集群不影响Harbor数据的实际验收。
4. 最终切换前冻结旧仓库写入并核对最新数据；与所有者的WSL压缩维护窗口衔接。观察期保护旧容器/卷和冷备份。
5. 最后按批准清单清理并记录实际释放量，不能遗漏；本次未清理。

规则：C-D1独立持久目录；C-I8配置/身份/挂载冲突拒绝；C-R1/R2同版本及摘要固定；C-T5只提交本地luna、不push。
