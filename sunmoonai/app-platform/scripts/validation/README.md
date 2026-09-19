# 可复用验证与模板同步工具

本目录从旧重构工作目录提取工具，不是新的发布入口。App 发布仍使用相邻目录及
各 App 的规范 `deployment/`；[切换与回滚前置](../../../docs/legacy-backlog/deployment-checklist.md)
不变。保留原文件名、CLI 和环境变量，不因移目录改变行为。

| 工具 | 用途与副作用 |
| --- | --- |
| `verify_r3_network_policy_calico.sh` | 根据 `--bundle` 创建独立临时 KIND/Calico 集群验证 allow/deny；需要显式授权与可用镜像/缓存；不是对业务 KIND 的只读检查 |
| `calico_dns_ready.py`、`calico_probe_result.py` | 上述脚本的同目录依赖，保留 DNS 前置与排除 OOM/解析失败等伪拒绝的判断 |
| `test_calico_gate.py` | 假 CLI 回归：不启动 Docker/KIND，不访问业务集群 |
| `sync_r4_instance.py` | 明确模板基线、目标、实例 HEAD 和分类配置的三方同步；`plan` 只生成计划，`apply` 会写实例，必须另获授权；不是 five-repos-sync |
| `test_sync_r4_instance.py` | 保留替换范围、稳态保留实例扩展等回归 |
| `verify_runtime_role_topology.py` | 只读源码及构建身份检查；默认按本文件相对路径定位五仓，或显式指定 `--workspace-root`；不证明真实角色账号或运行状态 |

原有两组测试已接入相邻 `tests/test_validation_tools.py`，随常规脚本单元测试执行；
无需记住另跑旧文档目录。可单独运行无集群回归：

```sh
python3 -m unittest discover -s sunmoonai/app-platform/scripts/validation -p 'test_*.py'
python3 sunmoonai/app-platform/scripts/validation/verify_runtime_role_topology.py --workspace-root /path/to/five-repos
```

旧 R3/R5/R7 批处理、切流/供给/退役脚本不迁入；其硬编码候选、身份、旧数据版本和历史
证据不适用于本批开发发布。旧 R7 检查要求 `formal_release=true` 且写死旧 migration head，
不能把它宣传为当前 KIND 开发包门禁。原文及冻结发布证据按
[历史索引](../../../docs/legacy-backlog/verification-index.md#architecture-v2-目录清退) 查询。

移动与假 CLI 测试不等于重跑 Calico 包级验收、真实浏览器、跨 App 业务链路或回滚。
这些仍是发布所需证据，不能因旧脚本清退而省略，须与本次 release 绑定。
