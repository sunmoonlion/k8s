# 旧 Harbor 最新逻辑快照与原服务恢复

`source_snapshot.py` 是正式同步前的有界快照工具。默认只打印；`check --apply` 只读预检；`capture --apply` 暂停旧 Harbor 写入并保留最新 PG17.6 导出，结束后恢复原服务；`recover --apply` 从同一批次日志恢复服务。

当前：Python 语法和默认计划通过；现场只读预检通过，原7控制器Ready、密钥与已保存输入一致、4400文件的既有归档全摘要检查通过。新的固定 kubectl 数据库只读连接及共用库存方法实际读取49表/10374行/47序列。此行数是在线观察，不是冻结快照。**尚未执行 capture 或 recover，没有停旧写端，也没有生成最新冻结导出。** 本轮转去处理附盘和自动任务后，后续执行须重新预检。

## 使用边界

- 固定旧1.27.3客户端、旧kube-system UID、私有静态kubeconfig、节点ID/挂载/网络、控制器UID与spec摘要；不依赖PATH默认kubectl。
- 新 Harbor 必须停止且只读；数据盘UUID与服务挂载检查通过、余量至少20GiB；恢复动作不受20GiB余量阻止，但仍要求正确挂盘和日志。
- 先写持久恢复日志，再开启Harbor只读、等待任务排空，停止Jobservice/Trivy/Core/Portal/Registry；PG和Redis保留。检查无剩余PG客户端、无未完成任务。
- 新导出PG17.6逻辑库与全局角色，前后两次比较全部表/行摘要、序列、角色密码摘要、schema及数据库元数据。原始数据/密钥只落root私有目录，不输出到公开结果。
- 逐个源registry文件与已验证可恢复的完整旧归档核对；只有完全相同才保存归档引用，避免再次复制约17GB。任一不同就失败并恢复旧服务，不删除差异文件、不忽略新增层、不降空间门槛。
- 工作预算25分钟，自动恢复另10分钟；普通异常和SIGINT/SIGTERM转入恢复。强杀、断电仍需显式recover，不能保证自动finally。恢复先恢复原副本、健康和目录，再恢复原readonly开关。自动恢复超时会停止并保留日志，不宣称服务已恢复。
- 完成后旧源重新允许原有写入，因此结果明确 `final_cutover_admission=false`。这份快照还需独立恢复，最终切换仍需要持续停写下的最新同步和正式入口执行器，不能拿本次阶段性备份直接放行。

## 命令

从k8s仓根执行。挂载和维护范围确认后再运行有副作用的capture；每次使用新的attempt，不覆盖失败记录。

```sh
python3 -B sunmoonai/registry-platform/source_snapshot.py capture
sudo -n python3 -B sunmoonai/registry-platform/source_snapshot.py check \
  --docker-credentials /home/zymun/.docker/config.json --apply
# 有界停写快照，之后恢复原服务；本次尚未执行。
sudo -n python3 -B sunmoonai/registry-platform/source_snapshot.py capture \
  --attempt <新的批次> --docker-credentials /home/zymun/.docker/config.json --apply
# 中断后只恢复同一批次；不要换attempt绕过未恢复日志。
sudo -n python3 -B sunmoonai/registry-platform/source_snapshot.py recover \
  --attempt <原批次> --docker-credentials /home/zymun/.docker/config.json --apply
```

私有日志在 `/data/harbor/source-snapshots/<attempt>/state.json`，目录0700、文件0600。当前尚未建立批次目录。原备份、源数据、节点、容器和卷全部保留；新候选未写入任何同步数据。

适用规则：C-D1仍由旧源提供权威写入；C-I8身份或挂载变化就拒绝；C-R1/R2快照绑定旧客户端、数据与归档摘要。只读预检不能替代真实停写恢复演练。
