# 账号与密码维护

账号配置与其组件放在同一目录，`platform-account-* OBJECT=...` 按同一对象分类选择。人工登录、平台管理与程序运行是用途分类，不由产品名称决定；数据库也有维护者使用的管理员账号。

## 当前账号目录与能力

| 对象 | 账号 | 用途 | 本轮能力 |
|---|---|---|---|
| registry | admin | Harbor管理员 | 计划、私有查看、初次预设、表导入、真实检查；轮换候选待维护验证 |
| app-platform/auth-app/casdoor | built-in/admin | 认证管理员 | 同上；轮换由SOPS候选和Flux同步 |
| data-platform/elk/kibana/ui | sunmoon_kibana_reader | 人工只读 | 计划、查看、真实检查；本轮密码保持 |
| data-platform/postgresql | postgres | 数据库管理员 | 计划、查看、首次私有预设；实际轮换未实现 |
| data-platform/redis | default | 平台全权限管理及初始化 | 同上；应用各用独立受限ACL |
| messaging-platform/rabbitmq | platform | 消息平台管理及初始化 | 同上；应用各用独立用户/vhost |
| data-platform/elk/elasticsearch | elastic | 搜索平台管理员 | 计划、查看；初次预设与轮换未接入 |
| data-platform/neo4j | neo4j | 图数据库管理员 | 同上 |
| data-platform/mongodb | sunmoon_mongo_admin | 文档数据库管理员 | 同上 |
| data-platform/object-storage | sunmoon_storage_root | 对象存储根身份 | 同上 |

各条身份的私有文件、字段及主备位置由组件`config.yaml`中的账号元数据提供，`platform-account-plan`打印路径与明确能力，绝不打印密码。管理员凭据也用于初始化任务；更换时必须同步这些消费者，不能仅改一个Secret。

应用运行账号、迁移账号、服务身份、Harbor机器人、数据库内部账号、复制密钥和cookie保持随机且互相独立。它们由相应组件/应用私有输入和SOPS配置给程序，不要求维护者记忆，不复用人工登录密码。以上表格不代表完整的机器身份列表。

## 查看与首次设置

```bash
make -C infrastructure platform-account-plan OBJECT=all
make -C infrastructure platform-account-plan OBJECT=data-platform/postgresql
# 仅在所有者本人交互终端显示值；助手日志与非交互执行不可查看。
make -C infrastructure platform-account-view OBJECT=data-platform/postgresql
```

首次预设是计划中给出的root0700目录/root0600文件，内容为一个8–128字符值，不附换行；Casdoor不允许空白。不要把密码放在命令参数、环境变量或Git普通配置里。已支持的原生初始化器读取预设；未提供则随机生成。已有实际输入及其独立备份始终优先，改变预设不会改现有账号。预设自身缺主副本时从另一份恢复，两份不一致则停止。当前数据库管理员的首次预设代码仍待新建环境实演，不能用现有输入沿用证明首次创建通过。

所有者批准新集群管理员从一开始全部映射密码表：1 Redis、4 PostgreSQL、8 MongoDB、10 Neo4j、11 RabbitMQ、12 Harbor、15a Elasticsearch、15d Kibana reader、18 Casdoor、19 对象存储。应用运行账号不映射。导入只写首次预设，不改已有 sunmoon-kind 现网口令。

```bash
make -C infrastructure platform-account-import OBJECT=all
```

导入只保存预设与独立副本，不修改服务器。相同值重复导入无变化，不同预设需要明确替换授权。根目录`密码修改表.md`是所有者保留的开发查阅表；不作运行真源。实际轮换验证成功后同步对应当前值，生产前轮换开发凭据。禁止把值输出到对话、日志或diff。

## 已有账号轮换

本轮仅实现Harbor/Casdoor候选，尚未实演，不把下列流程标成已验收。一次选择一个准确账号对象，不支持用all执行批量轮换；Kibana及其它数据库现有密码保持。其它管理员真实轮换需先实现该组件协议、消费者同步与恢复。

1. 明确目标预设与主备，查看计划和真实身份。Harbor必须是db_auth的admin/user_id=1；Casdoor必须是built-in/admin且isAdmin=true。Kibana检查验证指定只读角色与平台归属。
2. Casdoor先完成其它部署的晋级，再使用同一`ACCOUNT_OPERATION`执行`platform-account-stage`。它仅修改自己的加密身份Secret，保存当时的源快照；普通服务stage会按当前实际输入恢复旧值，因此轮换候选应最后stage。
3. 审阅并本地提交加密候选，执行`flux-release`，显式晋级source-candidate到环境源指针；**此时不要执行flux-source-apply或platform-deploy**。轮换检查只允许本次身份Secret变化，不接受夹带其它GitOps改动。
4. 所有者批准两小时窗口后提供绝对秒数`ACCOUNT_DEADLINE`和唯一`ACCOUNT_OPERATION`，执行所选`platform-account-rotate`。API写入只发送一次；丢响应先检查新旧密码。新密码登录、旧密码拒绝后同步私有主备；Harbor经原生stop/deploy重新生成官方配置，Casdoor经原生Flux应用已审源并核对运行Secret，不修改已有初始化Job。
5. 最后再次检查API、主备与运行配置，保存root0600事务回执；成功后同步开发查阅表。失败恢复旧API账号/文件与官方配置或原Flux源，任务仍以失败退出，不能把恢复当轮换成功。

```bash
make -C infrastructure platform-account-check OBJECT=registry
make -C infrastructure platform-account-check OBJECT=app-platform/auth-app/casdoor
make -C infrastructure platform-account-stage OBJECT=app-platform/auth-app/casdoor ACCOUNT_OPERATION=<本次标识>
# 以下仅在针对本次范围的有效批准窗口内使用。
make -C infrastructure platform-account-rotate OBJECT=registry ACCOUNT_OPERATION=<本次标识> ACCOUNT_DEADLINE=<截止epoch>
```

## 恢复与限制

`platform-account-recover`使用同对象、同操作标识及另行批准的窗口，从私有回执恢复；不重置卷、数据库或机器账号。Harbor回执在它的凭据备份目录`rotations/<标识>/`；Casdoor在平台凭据备份目录同名子目录。回执含恢复密码，必须保留root0600，不能提交或贴到对话。

若两种已知密码均无法验证，立即停止并保留回执，禁止盲重试API。Casdoor回退恢复的是运行源；Git中的源指针和加密候选需依据回执精确恢复、审阅提交，下一次部署门禁会阻止不一致状态。普通Git回退不能逆转数据库中的账号密码。

主与备份仍在同一物理盘，不防硬件故障；机器外身份备份落点待定。当前容量底线与维护窗口以host/config.yaml及已批准范围为准。扩大账号轮换范围、恢复后删除回执或其它数据都需要明确处理依据。

## 官方协议依据

Harbor2.15.2使用[官方users/password API](https://github.com/goharbor/harbor/blob/v2.15.2/api/v2.0/swagger.yaml)，Casdoor4.12.0使用[官方set-password](https://github.com/casdoor/casdoor/blob/v4.12.0/controllers/user.go)；[IsGlobalAdmin定义](https://github.com/casdoor/casdoor/blob/v4.12.0/object/user.go)按built-in归属判断，接口并无同名JSON布尔字段。未来Kibana只读身份轮换对应[Elasticsearch用户密码API](https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-security-change-password)，当前只调用身份读取核验。
