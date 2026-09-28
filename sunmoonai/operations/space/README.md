# 日常空间控制

从 k8s 仓根使用 `./sunmoon space`。本地已安装只读监控，**删除规则尚未批准**。
保留 `.json` 集中配置，默认 `policy.json`；自定义时把 `--policy /绝对路径` 放在动作前。
云端未经实机验证，当前配置的 Windows/WSL 路径不能直接用于云主机。

## 查看与预览

```bash
sudo ./sunmoon space status
sudo ./sunmoon space status --deep --output /tmp/space-inventory-新批次.json
sudo ./sunmoon space monitor status
./sunmoon space policy show
sudo ./sunmoon space preview --scope cache --output /tmp/cache-preview-新批次.json
./sunmoon space preview --scope harbor --output /tmp/harbor-preview-新批次.json
```

status检查真实独立盘UUID/三个挂载、C/WSL/数据文件系统和inode、两个VHDX文件长度、保护容器/卷身份摘要。
`--deep` 增加目录du，多个bind不重复累加；目录查询失败显示unknown。
从WSL读取的NTFS分配量是估计，维护窗口仍需Windows核对实际分配；当前工作峰值为0，执行大导入前须填真实额外峰值。
低空间不会阻止停止/恢复，`large_operations_allowed` 是可供入口采用的判定，**尚未接到所有构建/下载入口，不能声称已有全局拦截**。

preview不会删除。cache列default builder超过7天、未InUse/Shared的ID，另用Buildx Parents检查依赖，排除有保留子缓存的父记录；Size之和仅为API显示规模，保守保证为0，不能视为物理释放量上界；内容/快照GC可能额外释放以前延迟回收的空间，也可能因引用而少释放。不把镜像共享层相加。
Harbor/GC目前返回明确阻塞原因，不发任务、不执行删除：正式源切换、完整使用/回退/离线制品及referrer保护清单仍未闭合。
logs/backups/temporary只接受policy里逐文件登记且有保留副本的字节相同文件；空配置表示没有候选，**不代表日志或备份轮换已启用**。
不会按通配符递归删目录；旧节点/卷与旧数据路径一直排除。

## 自动监控

2026-09-28已安装：`sunmoon-space-monitor.timer`，开机3分钟后、每小时检查。
发布代码 `/opt/sunmoon/admin/space/7efb5adc11176491/` 为root所有的固定副本；不从可编辑worktree执行后台任务。
最新报告 `/var/lib/sunmoon/space/latest.json`；130分钟无新样本显示过期unknown，不能沿用绿色。
实际初次报告C盘90.58%，已显示critical；timer active/enabled。只写当前报告，不产生无限增长的样本文件。
两次样本才算增长速度，短期估计不能当容量承诺。WSL停机期间不监控；没有机器外通知。

```bash
./sunmoon space monitor install         # 只展示unit/安装目录
sudo ./sunmoon space monitor install --apply
./sunmoon space monitor disable         # 预览
sudo ./sunmoon space monitor disable --apply
sudo systemctl status sunmoon-space-monitor.timer sunmoon-space-monitor.service
sudo journalctl -u sunmoon-space-monitor.service --since today
```

配置/代码改动后需要重新发布。安装器只允许更新已识别的受管版本路径：复核原root发布文件摘要、权限及unit其余字节一致后，保存原unit并切到新版本；其他差异拒绝覆盖。不能以删旧目录代替升级。
后台不执行清理、不启动Windows窗口；系统journal自身轮转策略尚需纳入日志方案确认。

## 执行与审批

先由所有者确认新删除策略，再将 `deletion_policy_approved` 设为true并重新preview；**编辑配置/填写JSON本身不等于所有者批准**。
批准记录由实际批准消息对应生成，owner-only，字段：

```json
{"approved_by":"owner","decision":"execute-exact-plan","plan_sha256":"预览里的摘要","recoverable_cache_ids":["逐个确认输入可重新取得的缓存ID"]}
```

```bash
sudo ./sunmoon space apply --plan /绝对路径/preview.json --approval /绝对路径/approval.json
```

仅接受1小时内、配置摘要一致、候选现场完全一致的计划。cache还核Buildx精确ID过滤器；文件再次核源/保留副本摘要及inode。
仅cache和明确重复文件有执行后端，Harbor/GC未准入。执行intent/结果放计划旁，不覆盖旧回执；执行失败须查intent和现场，禁止盲目重复。
Docker容器/卷指纹前后检查；释放量分别报告文件系统可用量差值，不能把VHDX内部释放当C盘释放。并发写入会影响差值。
禁止system/volume/container prune，不清节点内部镜像，不自动收缩VHDX。

## 待确认的长期规则

| 范围 | 建议 | 自动执行 |
| --- | --- | --- |
| Harbor | 开发制品超过30天且不在最近10版/在用/回退保护集；至少2次成功回退版本 | 先预览、每次人工批准；GC另批，默认不删untagged |
| 构建缓存 | 指定builder未使用7天以上、输入可恢复 | 构建后先预览，未授权自动删 |
| Docker日志 | 新受管容器20MiB×5；旧保护节点不重建 | 策略批准后随新实例配置生效 |
| 文件日志 | 每日轮转、14天；故障/审计证据排除 | 待批准后实现并启用 |
| 备份 | 至少2份已演练恢复的完整备份+当前变更前备份；唯一来源不删 | 先预览、人工批准 |

机器外备份落点仍待所有者选定，仅数据库/对象存储/~/private。两块VHDX同在C物理盘，同盘副本不防硬件故障。
这份说明明确剩余项，不是持久化三个场景或全部空间治理已经通过。

## 本次迁移的一次性缓存清理

所有者在2026-09-28明确：迁移时缓存可以重新build，取消此次年龄/5GiB限制。它不等于批准长期自动删。
`./sunmoon space migration-cache` 默认只展示；`--apply --output /绝对路径/新批次.json` 才清默认builder当前未使用缓存（含internal/frontend），按当时精确ID约束。
前后核镜像/容器/卷清单，记录实际消失缓存个数和文件系统/C盘差值；原始回执保留。
此入口不执行system/volume/container prune，不删KIND节点内部镜像，不做VHDX压缩。正在使用的缓存交由BuildKit保留。
此前只选7天父缓存的一次小批实际释放0B；现已将父子依赖闭合检查纳入长期preview，避免重复提交无效的孤立父缓存清单。

本次已于2026-09-28完成：1845条候选全部删除，219个镜像、89个容器与46个卷前后身份一致。
WSL文件系统减少192362614784B（179.15GiB）；C可用空间同期减少约2.18GiB，WSL VHDX文件长度不变，未执行压缩。
详见[实际回收结果](../../scripts/results/luna-migration-cache-reclaim.20260928.json)。这是一次迁移授权，不能据此启用长期自动清理。
