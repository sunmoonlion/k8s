# 本次物料与 Harbor 保留入口

本目录属于 2026-09-26 的明确批次，不是可直接套用任意生产环境的总控部署脚本。先读 [物料手册](../../kind-infrastructure/docs/物料提交备齐方案和方法.md) 和 [Harbor 方案](../../kind-infrastructure/docs/harbor-preservation-plan.md)，复核路径、集群、版本和授权。

## 模板构建物料（进行中）

`profile.json` 固定当前模板父仓/三个子仓提交、Linux amd64 基镜像摘要及 Node/pnpm/uv 版本。`materials.py` 依次支持 `plan`、`snapshot`、`bases`、`tools`、`packages`。

```sh
python3 materials.py plan
python3 materials.py snapshot
python3 materials.py bases
python3 materials.py tools
sunmoon-network run -- python3 materials.py packages
```

独立根为 `~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`。源码 bundle、基镜像归档与六份工具文件已准备；工具在 `--network=none --pull=never` 容器中运行成功。包预取遇到公网 TLS/连接重置，有限重试后失败；完整依赖闭包、离线构建、负例和 CI/CD 尚未通过。不要把 `tools` 成功视为整个批次验收成功。

工具下载可以使用已授权公开中转主机，回传后核验官方 pnpm SRI、PyPI wheel SHA256 与 Node 官方校验清单；不得上传私有源码/凭据。来源元数据自身经 TLS 获取；并未声称做了发布签名验证。原始日志与命令保留于批次 `evidence/`，成功文件散列在 `preparation.json`。

## Harbor（独立范围）

| 入口 | 动作 |
| --- | --- |
| `harbor_inventory.py --output <新文件>` | 使用已有 Docker 登录凭据，GET 分页盘点；展开索引子清单/附件，输出不含凭据 |
| `harbor_prepare.py --output <新目录>` | 只读导出相关资源、必要 Secret、chart、节点启动镜像；输出必须留在私有目录 |
| `harbor_cold_backup.py --output <获准批次新目录>` | **会停止旧 Harbor**；必须事先确认停服窗口；固定本机目标，不支持任意传入集群 |
| `harbor_cold_backup.py --resume-services <已有备份目录>` | 根据持久化状态恢复精确控制器副本与原只读值；不覆盖源数据 |
| `harbor_verify_backup.py <备份目录>` | 核对归档散列和内部 registry blob/manifest 依赖；不等于隔离恢复通过 |
| `harbor_restore_plan.py --output <新目录>` | 从备份生成独立 namespace/存储/镜像摘要/TLS/网络策略清单，全部控制器为 0 副本；不连接集群或实施恢复 |

冷备份的失败/中断恢复命令也写入备份目录 `RECOVER-SERVICES.txt`。整个批次使用文件锁防止并发冷备份或重复恢复。不会强制删除 Pod，不清理数据，不改变 Harbor 版本。

`harbor_prepare.py` 导出的是命名空间内恢复输入；实际 TLS 入口可能在别处。本次已另外保存 Traefik 默认 TLSStore、`ingress-platform-dev/traefik-tls-secret` 与客户端 CA，索引在私有批次 `preparation/tls-addendum.json`。将来重新执行时必须重新定位并纳入这类跨命名空间依赖，不能认为仅执行准备脚本就覆盖完整入口。

脚本依赖 Python 3.12、kubectl、helm、Docker/节点 ctr、节点 tar；具体运行证据和未完成项写入检查点和方案。私有备份不能提交 Git、推送公开物料中转服务器，或把 Secret 内容复制到终端日志。

本次隔离恢复见 [具体方案](../../kind-infrastructure/docs/harbor-isolated-restore-plan.md)。动态 Trivy PVC/PV 元数据已补读至 `preparation/private/storage-addendum.json`（数据本来已归档）；准备脚本现沿 Pod PVC 引用补全存储，避免依赖不一致的 instance 标签。恢复生成器使用补充清单及散列；这个一次性兼容输入不能当成任意备份批次的通用自动发现逻辑。
