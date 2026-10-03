# 模板 Redis 独立身份维护

状态：2026-10-03已完成。持久账号经过实际滚动重启、ACL摘要和权限、真实认证及隔离验收；统一部署入口重复通过。以下保留实施顺序与失败修正记录，以末节结果为准。

## 范围与依据

模板账号、私有输入、任务声明均归 `gitops/components/app-platform/tpl-app/tpl-backend/redis/`，用户字段在其上一级config.yaml；应用仍用app-platform-dev。Redis服务在data-platform-dev。本单元不切入口、不改版本、不部署常驻业务组件。

维护前Redis仅default账号，aclfile为空；当时只读检查keyspace为空，AOF启用且last_write_status=ok。身份若只写内存会在重启后丢失，因此服务先具备持久ACL文件，再初始化模板身份。

采用[Redis官方ACL文件机制](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/)：initContainer只在文件不存在时写入原default口令的SHA256规则，保留现有账号和数据；Redis配置读取/data/users.acl。应用Job设置独立用户名和tpl:*键范围后ACL SAVE。应用用户不持平台管理员口令，不允许跨前缀、管理命令或FLUSHALL。

## 维护窗口与执行顺序

预计Redis两次短暂不可用，每次约10–60秒；全窗口上限10分钟，失败恢复另留10分钟。第一次为声明更新的正常滚动替换；第二次为验证ACL不依赖进程内存而受控重建redis-0。其余平台服务不主动重启。窗口开始前重新核对唯一集群UID、容量、原Redis Pod UID、PVC/PV、当前keyspace和原default认证；本批继续50GiB底线，最多新增1GiB预算，不沿用历史40GiB例外。

1. 确認当前GitOps源仍为e2708f2ef172a55c85f291a436b209b30812d779e8d3e428c01e016c3828cdd3。保存原Pod/PVC身份、默认账号摘要和持久化状态，只存私有证据。原平台凭据独立备份必须完整；如keyspace已出现新业务键，暂停并补充一致性备份安排。
2. 发布已提交声明：`make -C infrastructure flux-release`；核对candidate后显式晋级environments/kind/flux-source.yaml并本地提交。
3. 先原生services-render和services-validate-release确认平台候选对应晋级源，再 `make -C infrastructure application-bootstrap APP=tpl`。由Flux先完成Redis启动配置，后运行tpl-redis任务（初版v1失败，修正后v2成功），不用手工SETUSER绕过声明。
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

## 首次窗口实际结果与剩余项（2026-10-03）

首次窗口11:23:07Z–11:33:07Z已结束。声明滚动替换成功，tpl-redis-v2完成真实权限检查；8个Flux阶段Ready且同一摘要84bcfc316cb46bcfabcf9c29254959643a57263e57b98209f48b993faf23c566。完整application-bootstrap重复执行四阶段changed=0，当前账号认证通过，Redis PVC未变，其余26个原Pod未变化。

期间修正了两处验收代码：ACL DRYRUN返回普通拒绝字符串的处理，以及Ansible命令中用户名的引号。第一处修正通过v2 Job发布，第二处只改当前认证检查。失败证据保留；失败v1 Job/旧ConfigMap及其Pod已按UID核对清除。成功Job仍由Flux管理，不清理。

第二次重启在删除Pod前被剩余时间检查拦住，没有执行。因此本单元不能标记“重启后持久化验收通过”。证据位于infrastructure/.build/applications/redis-unit-20261003/，原window.json不得覆盖。

### 补充窗口：仅验证账号创建后的持久化（待批准）

拟维护上限5分钟，失败恢复另5分钟；只重建当前data-platform-dev/redis-0一次，预计不可用10–60秒。源摘要、Secret、PVC/PV、入口和其他服务均保持当前状态。沿用50GiB底线和本单元1GiB预算，执行前重新检查。

1. 原生application-check与容量检查通过，核对8个阶段、v2 Job成功、Redis Ready及原PVC UID；私有备份和输入一致。记录当前Pod UID、ACL文件SHA256/0600权限、默认与tpl_runtime实际认证。新窗口时间另存restart-window.json，剩余不足60秒不开始删除。
2. 使用UID前置条件仅删除当前redis-0 Pod，不删除StatefulSet、PVC/PV或修改声明；等待同一StatefulSet的新Pod Ready。
3. 核对新Pod UID不同、PVC UID相同、ACL文件摘要及0600权限不变。再次验证默认与应用认证、应用自己的随机tpl:*键写读/删除、跨前缀及管理命令拒绝。FLUSHALL只允许ACL DRYRUN，禁止实际执行。
4. 再运行make -C infrastructure application-check APP=tpl；写restart-acceptance.json和实际不可用时长。任何一项失败不得标记完成。
5. 若新Pod异常先保存脱敏事件并停止后续部署；不重新生成口令或删数据。需回退启动配置时，在5分钟恢复预算内按上面的原源回退步骤执行，保留持久ACL；无法恢复则明确报告现场。不能用再次重启延长预算。

## 补充验收的前置检查发现：ACL SAVE文件权限（2026-10-03）

所有者批准仅重建一次、不发布配置的5+5分钟窗口后，前置检查实测Redis主进程Umask为0022，/data/users.acl属主999但权限0644；默认账号及应用认证正常。检查在记录新维护窗口及删除Pod前失败，未重启、未执行ACL SAVE或修改线上权限。原有认证检查未覆盖文件权限，之前的“认证通过”不能解释成全部持久化要求通过。

原因：[选定Redis 8.10.2源码ACLSaveToFile](https://github.com/redis/redis/blob/8.10.2/src/acl.c#L2403-L2435)以0644创建临时文件再替换原文件。原实现只在initContainer设置umask和chmod，不能约束redis-server后续保存；这是部署模板遗漏。

准备的最小修正：Redis主容器启动命令先umask 077，再exec redis-server /run/auth/redis.conf，保留原PID1信号行为。initContainer仍修复既有文件为0600，秘密、卷、版本和账号规则不变。application-check追加实际文件属主/0600和主进程0077检查，不能再只凭认证与旧Job结果通过。

### 修正后的维护提案（待所有者确认）

此前批准明确“不重新发布配置”，因此不将它扩成发布授权。拟以一次声明滚动替换代替原先的手工Pod删除：候选核对及发布准备完成后，维护5分钟、失败恢复5分钟；只晋级该Redis启动命令，其他Pod模板必须逐一确认无差异。

先保存ACL私有副本及摘要、原Pod/PVC和当前源84bcfc316cb46bcfabcf9c29254959643a57263e57b98209f48b993faf23c566；晋级后先确认新Pod UID、原PVC、原ACL摘要与两个账号认证，证明账号从原持久文件恢复，再执行一次ACL SAVE验证同样内容仍0600。检查主进程Umask=0077、真实键隔离/管理拒绝及application-check；不再额外删除Pod。此前tpl-redis-v2不重新执行。

若启动异常，在恢复预算内将源回退到本次84bc…固定源，保留ACL/PVC和凭据，不重新初始化；该源仍有0644问题，回退只能称服务恢复，不能称修复通过。失败不得延长预算或宣称本单元完成。

## 最终结果（2026-10-03）

所有者确认修正范围后，源码753b7ff4、晋级10b08eac，发布摘要98a2643276fc6ec8ed319e535e7aec36ef7b3e4b89e3210219a30252011ea816；8个Flux阶段均Ready且同一摘要。通过声明自动替换Redis一次，没有额外手工删除Pod。

重启前后ACL摘要相同，默认与tpl_runtime账号真实认证通过；实际键写读/跨前缀拒绝/管理命令拒绝通过。随后ACL SAVE成功、文件仍0600且摘要不变，主进程Umask0077。原PVC/PV保留，其余27个Pod的UID和重启次数未变。窗口起点11:55:47Z，到观察Ready17.04秒（非精确业务停机时长），主要验收11:56:05Z完成。

原生application-check ok19 changed0 failed0；application-bootstrap重复render/validate/Flux apply/check四阶段全部changed0。证据见原目录restart-acceptance.json、restart-final-state.json、umask-*.log。私有ACL备份root0600，禁止贴其内容；前次失败证据保留。

所有者随后将当前开发阶段维护窗口统一2小时、容量底线改10GiB；统一入口已实际按10GiB复测通过。以上历史5/10分钟和50GiB描述只代表当时约定，后续以AGENTS.md及host/config.yaml最新配置为准。本单元完成不等于模板应用或全项目部署完成。
