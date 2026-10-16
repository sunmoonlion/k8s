# 组件操作与人工账号：维护单元

本单元候选按已确认方案实现。实际维护尚未开始；批准窗口统一2小时，容量10GiB，保留15分钟恢复时间。执行者负责连续编排，不要求所有者依次手工安装组件；日常仍是一条原生`platform-deploy`入口。

## 改动及保护范围

- 服务从14个阶段拆成26个，新增14个独立阶段，替代`platform-services`和`elk-runtime`两个聚合阶段。188个服务对象与原提交逐对象一致；13组静态PV/PVC身份、节点路径、已有Job规格不变。
- 统一`platform-* OBJECT=平台/应用/组件`选取；整套、PostgreSQL及Tpl-Web的候选生成已实际核对未选文件不变。实际组件部署/检查与整套重复部署在本窗口验证。
- Harbor admin使用已批准的第12项目标，Casdoor built-in/admin使用第18项目标；先实际协议改密，再同步私有主备与官方配置/SOPS运行Secret，最后同步开发密码查阅表。Kibana及其它数据库当前密码保持。
- 十类维护账号目录已接入；并非十类都可轮换。数据库管理员、人工只读账号及应用受限运行身份分别说明，见[账号维护](../../infrastructure/host/accounts.md)。
- 不关闭WSL，不删群、节点、Docker容器/卷或数据，不改证书、域名/入口分流和镜像摘要，不升级软件，不push。

## 已完成的准备与当前快照

13项对象选择正反例、原生play语法、188对象对比、149个运行UID保持通过；公开PostgreSQL/Tpl-Web stage零未选变化。三个现有人工账号真实身份检查通过，12/18表导入与重复导入通过。事务库的成功、丢响应、拒绝写入、部分文件写入及输入不一致检查在模拟账号中通过；这不能代替真实轮换验收。

当前为51个Flux阶段；旧源摘要`sha256:9f7bce56f15708fa015a8c967b32f7f802724e50bab4aebb60ee02676140b33f`。完整旧源、两个待退休阶段UID/spec及149个Pod/Job/PV/PVC的UID/spec摘要已独立保存：

`/mnt/sunmoon-data/backups/host/component-account-20261005T124637Z`

这是当前只读快照。开始维护时必须重核UID、源摘要、两个聚合阶段spec/Ready及主备；发生漂移就停止并重新准备，不覆盖旧快照冒充原批准基线。

## 固定候选与容量预检

代码提交`e59bdc006a2eaca8c7b3af367ad7e801a6136547`，已用原生flux-release发布候选`sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef`，requires_sops=true；未晋级，运行源未改变。

2026-10-05T13:03:50Z只读容量检查扣除230GiB未来增长和3GiB预算后剩49267171328字节，满足10GiB底线。开始维护前重核，不以本次读数长期替代容量检查。42份准备证据已逐字节核对并私有归档到快照的preparation-evidence/；/tmp原件本单元结束后清理。

## 执行顺序

1. 记录本次批准的绝对截止epoch，检查数据盘UUID、Docker实际挂载、C盘实测空闲减230GiB未来增长与3GiB预算；开始前平台健康。恢复时间15分钟算在两小时内。
2. 候选本地提交，`flux-release`发布固定Git对象到Harbor并取得摘要。发布不移动运行源。明示晋级拓扑候选；每次GitOps源指针修改本地提交。
3. 仅暂停两个旧聚合Kustomization：每次操作前核对快照UID、`prune=false`、`deletionPolicy=Orphan`与Ready。JSON Patch以UID测试防错对象。保留其它控制器，声明内容不变。
4. 经原生`platform-deploy OBJECT=all`应用拓扑源，等待所有新阶段当前代次Ready，核对逐对象的归属与149个受保护运行UID/spec。只读验收完成后，用UID删除前置条件仅删除这两个已被替代的Flux阶段对象；其工作负载和卷不得级联删除。
5. 实演公开PostgreSQL与Tpl-Web组件deploy/check，并重复整套deploy/check；未选声明与运行身份不得变化。实际探针只使用其独立标记并按原生程序清理。
6. 使用本次独立操作标识，经原生`platform-account-rotate OBJECT=registry`轮换Harbor。核验admin身份、新密码成功、旧密码拒绝、主备一致；原生registry-stop/deploy同步官方输入并恢复，机器人/镜像推拉及目录保留检查通过。
7. Casdoor另外生成仅身份Secret变化的加密候选：`platform-account-stage`→审阅本地提交→`flux-release`→明示晋级。不能混入拓扑或清理提交；不要提前应用该源。随后同操作标识执行`platform-account-rotate`，验证API新旧密码、当前主备、Flux Secret及机器字段保持。既有完成Job不得重跑。
8. 三个人工账号及四应用公共协议、Harbor原有镜像摘要与认证拉取再验。成功后密码表当前值与实际登录一致；Kibana密码不变。事务回执私有保留。
9. 删除已经无引用的聚合源码/路径映射与失效公共说明，整理日常入口；发布纯清理候选并再验。一份组件配置、一套原生入口，无历史转接层。私有证据归档并核对后清理本轮临时文件，收敛CHECKPOINT并本地提交。

每次停服或API写入前重核期限，剩余不足15分钟停止新增动作并恢复；不得按旧窗口或昨天的批准继续执行。

## 失败恢复

### 阶段交接

若新阶段失败，先暂停本次新增阶段，防止与原聚合争夺归属；原有工作负载、Job/PV/PVC不删除。使用快照`source-before.yaml`：

```bash
make -C infrastructure flux-source-apply FLUX_SOURCE_FILE=/mnt/sunmoon-data/backups/host/component-account-20261005T124637Z/source-before.yaml
```

核对/恢复原两个聚合阶段的spec（Orphan、prune=false），再取消其暂停，让原源重新收敛。已删除的原阶段按快照重建；控制器UID可以变化，工作负载/卷UID不允许变。核对原51阶段当前代次Ready、受保护149对象、平台和应用协议。随后精确恢复Git中源指针与对应候选声明并本地提交；不以工作区dirty状态继续部署。

### 密码轮换

账号事务先检查新旧密码分类，不盲重发API。失败恢复原密码与私有主备，然后Harbor恢复官方输入，Casdoor恢复捕获的原不可变源并核对Secret。任务以失败退出，原始失败回执不得覆盖成成功。崩溃续接使用同对象/操作标识的`platform-account-recover`和新批准截止时间；两种已知密码均失效时停止并保留回执。

恢复流程见[账号维护](../../infrastructure/host/accounts.md)，回执含恢复口令，禁止进入Git或日志。Kibana/数据库密码本轮未变，不通过“重新初始化”恢复任何账号。

## 验收边界

本单元完成统一对象操作、部署阶段归属、已选人工账号及日常文档；真实Windows/WSL冷启动、KIND删除重建持久化、机器外灾备、长期空间删除策略和云端实机仍是独立未完成项。不能用本轮同对象或目录正确替代这些验收。
