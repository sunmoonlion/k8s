# 模板 Redis 独立身份维护

状态：代码与候选已准备，运行维护待所有者批准。2026-10-03，平台分支platform-kind-v1。

## 范围与依据

模板账号、私有输入、任务声明均归 `gitops/components/app-platform/tpl-app/tpl-backend/redis/`，用户字段在其上一级config.yaml；应用仍用app-platform-dev。Redis服务在data-platform-dev。本单元不切入口、不改版本、不部署常驻业务组件。

现Redis仅default账号，aclfile为空；只读检查keyspace为空，AOF启用且last_write_status=ok。身份若只写内存会在重启后丢失，因此服务先具备持久ACL文件，再初始化模板身份。

采用[Redis官方ACL文件机制](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/)：initContainer只在文件不存在时写入原default口令的SHA256规则，保留现有账号和数据；Redis配置读取/data/users.acl。应用Job设置独立用户名和tpl:*键范围后ACL SAVE。应用用户不持平台管理员口令，不允许跨前缀、管理命令或FLUSHALL。

## 维护窗口与执行顺序

预计Redis两次短暂不可用，每次约10–60秒；全窗口上限10分钟，失败恢复另留10分钟。第一次为声明更新的正常滚动替换；第二次为验证ACL不依赖进程内存而受控重建redis-0。其余平台服务不主动重启。窗口开始前重新核对唯一集群UID、容量、原Redis Pod UID、PVC/PV、当前keyspace和原default认证；本批继续50GiB底线，最多新增1GiB预算，不沿用历史40GiB例外。

1. 确認当前GitOps源仍为e2708f2ef172a55c85f291a436b209b30812d779e8d3e428c01e016c3828cdd3。保存原Pod/PVC身份、默认账号摘要和持久化状态，只存私有证据。原平台凭据独立备份必须完整；如keyspace已出现新业务键，暂停并补充一致性备份安排。
2. 发布已提交声明：`make -C infrastructure flux-release`；核对candidate后显式晋级environments/kind/flux-source.yaml并本地提交。
3. 先原生services-render和services-validate-release确认平台候选对应晋级源，再 `make -C infrastructure application-bootstrap APP=tpl`。由Flux先完成Redis启动配置，后运行tpl-redis-v1，不用手工SETUSER绕过声明。
4. 验收Job必须完成真实写读、跨前缀拒绝、管理命令拒绝和ACL SAVE。FLUSHALL仅用ACL DRYRUN判断权限，禁止实际执行。默认账号仍可认证，/data/users.acl在既有Redis PVC上且权限0600。
5. 在同一窗口内记录当前redis-0 UID，仅删除该Pod以由同一StatefulSet重建（保留PVC/PV）；等待Ready后执行application-check验证真实账号认证，确认default也正常及Pod UID已变、PVC UID不变。再次执行application-bootstrap应无额外部署变更。
6. 记录实际结果；未完成重启后的认证校验不得宣称持久化通过。窗口结束不延伸成其他停机授权。

## 失败恢复

1. 停止后续操作，若新tpl-redis Kustomization已存在先suspend，避免它继续初始化；保留失败证据。
2. 从本地提交cd94bc87读取原environments/kind/flux-source.yaml，恢复同一固定摘要e2708f2e…并提交，再使用`make -C infrastructure flux-source-apply`恢复原声明；不覆盖数据库或Secret明文。
3. 等待Redis按原声明Ready，验证原default账号与AOF状态。原requirepass配置重新生效，新增users.acl保留；不删除PVC、数据或备份。
4. 旧源不包含tpl-redis目录；回退时新Kustomization保持暂停，后续按精确归属退役，不能把存在暂停对象称为全部验收成功。窗口内不能恢复就明确报错，保留现场。

## 操作入口与边界

准备：application-stage；正式应用：application-bootstrap；核对：application-check，均APP=tpl。Redis平台模板/密文由services-render生成并经同一Flux源发布。普通日常操作无新CLI或手工按组件拼接命令。

redis.yaml和其独立备份是私有输入，root0600。Git只保存SOPS密文；输入丢失必须恢复，不得重新随机生成。模板自己的Redis口令与数据库身份不同。已有同名账号但口令摘要不符会停止，不能默默接管或轮换。应用Redis Job的成功结果记录不替代当前进程认证，也不替代本次受控重启验收。

后续Celery结果存储还需核对键前缀；不会为了方便对模板账号放开全部Redis键。RabbitMQ、Casdoor应用注册及常驻运行仍是后续工作。
