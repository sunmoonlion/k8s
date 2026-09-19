# 本机业务备份演练与历史对象缺失

2026-09-19，执行者 luna，宿主 `/home/zymun/worktrees/luna`。
延续 [批准范围](scope.md)，只操作本机 kind-kind；集群 UID
`5d71ab3a-ea5a-4535-adc6-d7698d820249`。原服务未停止，未迁移业务库，
未创建/撤销业务账号，未改 Secret/definitions，未向 S3/RAGFlow 写入。

## 实际完成与证据范围

采用 `app-platform/scripts/kind_database_rehearsal.py`，PG 17.6 同镜像、
repeatable-read 导出快照和 pg_dump custom archive；隔离容器无外部网络。
每 App 两次从旧备份重新恢复，再用上一轮固定候选镜像运行独立迁移入口。
比较表/列/约束/索引/触发器/关系与 default ACL，以及每表原有列的全部行摘要。
这不是全量身份安全验收，也不是停机后最终备份。

| App | 成功目录 | dump SHA-256 | 迁移后的 head |
| --- | --- | --- | --- |
| Info | info-preflight-03 | 26e60598f66c5ef92155d43d7c049cee8686201e79eadbe4423344ee24318d2c | 20260913_0009 |
| Knowledge | knowledge-preflight-01 | 310054fd828ec0f30f698c63cd4c1d9e2a886ea5d4af1d7125a89df26a72be3a | 20260911_0006 |
| Investment | investment-preflight-01 | 6076e201235aa8a54a8143cca7f98d6b92b7cdc6fec88d3cdecfe078ae1089ca | 20260911_0007 |

以上目录均在 Git 外私有根
`/home/zymun/worktrees/luna/.local/kind-cutover-20260919/`，目录 0700、材料 0600。
包括数据库、角色定义、旧 K8s 资源/Secret 与共享 broker 启动定义；不得提交或同步这些材料。
每个成功目录的 `rehearsal.json` 记录两次恢复及迁移结果。命令退出码均为 0；
原有业务列/行全部一致，临时容器与其自有匿名卷已清理。
对象存储与真实撤权未被该数据库演练覆盖；回执明确 `cutover_backup_receipt=false`。

## 失败原因与处理（未跳过）

1. Info 第一次恢复目录校验失败。实际是 ACL 数组排序及 varchar 字面量数组转 text[]
   的 PostgreSQL 等价序列化变化；比较器仅归一化已核实的两种表示，不删 ACL 或约束。
   单测确认修改 status 枚举值仍失败，原始目录快照保留。
2. 第二次失败为 Bitnami 初始化服务器短暂可连接，随后关闭造成 readiness 竞态。
   改为 PID 1 已是 postgres 再执行 SELECT 1；第三次两轮均成功。私有错误日志保留。
3. 对象备份第一版 AttributeError：旧部署镜像没有候选代码的 `ObjectStorage.s3_client`。
   现场只读确认配置字段存在、方法不存在；改为使用旧 Settings 构造 boto3 客户端。
4. 第二版实际对象读取发现历史缺失，**不是脚本异常，也不是本次变更造成**：
   189 条引用中 183 条内容核验通过，6 条 NoSuchKey；没有把不完整结果标作备份成功。
   183 条是已读验证，不声称已经持久保存为完整对象备份。

## 需要另批的历史文件恢复

6 条引用是 `raw_artifact` 四条、`extracted_content` 两条，对应四个文件，均无 version_id。
仅涉及桶 `development-info-originals` 下这一精确目录：

`info/original/source=manual/date=2026-07-07/job=3b05ae27-480d-4d9f-af67-1502f8cbd1f9/`

| 文件 | 字节数 | 原记录 SHA-256 | 只读恢复验证 |
| --- | --- | --- | --- |
| raw.html | 775 | 2830717a990580eab262822cd784a7bfeaf01f34d2f1a6e0532cbd8f76a98e06 | 找到另一条 versioned 引用，GET 精确版本，内容完全匹配 |
| clean.md | 156 | 2546628224caf2e38918a5346b4326a24f07db2245d444d58b6637aea79be049 | 从匹配 HTML 用已有提取函数重算，完全匹配 |
| text.txt | 156 | 2546628224caf2e38918a5346b4326a24f07db2245d444d58b6637aea79be049 | 从匹配 HTML 用已有提取函数重算，完全匹配 |
| headers.json | 163 | c7c4da02e0e2ffbfabcaa95459d9be18edd4acf48cd3ea2fe11957bbc7a4764b | 从原任务 response_metadata.headers 恢复 JSON 字段顺序，第 7 个候选完全匹配 |

精确目录的 S3 `list_object_versions` 返回 Versions/删除标记均为空、未截断。
没有重新抓外网、没有猜内容、没有写回。只读恢复检查命令退出 0，四项大小和摘要全部一致。
数据库记录任务在 7 月 7 日 succeeded，存在 document/version 引用；本次对该版本的
distribution_record 精确查询没有返回记录。**这不意味着可删除，也不证明无其它引用。**
文件最初为何丢失尚无证据，不能归因于本次同步或特定历史操作者。

拟请求：仅补回这四个缺失 key；写前重查、使用不覆盖现存对象的条件写入，
每个 PUT 后 GET 返回版本再核大小/摘要；若出现同名对象或差异则停止。
不改数据库行、不补 version_id、不删记录、不重放任何历史任务、不影响其它 key。
这项 S3 写入是历史数据修复，**本轮尚未获准且没有执行**。

## 检查与下一步

`python3 -B -m unittest discover -s sunmoonai/app-platform/scripts/tests -v`
在 k8s 根执行：57 tests，退出 0（包括 6 个数据库备份安全测试和 3 个对象验证测试）。
三 App 现有 API 2、Worker 1、Scheduler 1 及两个前端各 2 均 ready。

下一步先等待上述四对象补回授权；批准后重新获取当前数据并核摘要，不能盲用旧观察。
恢复后重跑完整对象导出与隔离恢复验证，再继续独立账号供给/拒绝试验、修正 Investment
开发部署入口的旧共享身份副作用、冻结新 source lock/bundle、同步与串行维护切换。
停机窗口需新备份；在线准备回执不能替代。新账号、队列拓扑和旧连接撤权均还没实施。
