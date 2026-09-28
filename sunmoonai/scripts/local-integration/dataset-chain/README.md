# 本机联调：数据集这条链

证券代码 → info 采集建库 → 对象存储 → 向知识服务登记 → 知识服务自己取文件 → 经 MCP 查询。

不连任何集群。两个后端跑的是各自仓库里的代码；对象存储、缓存是一次性的容器；数据库是已有 PostgreSQL 容器里的两个新库。

## 用法

```bash
cd sunmoonai/scripts/local-integration/dataset-chain
./run.sh up                      # 起存储与缓存，从空库跑两边的迁移，起身份服务替身与知识服务
./run.sh ingest 600009           # 采集（访问巨潮与东方财富，约三到五分钟）
./run.sh build 600009            # 建数据集并登记
./run.sh driver verify 600009    # 站在专家的位置上经 MCP 核对
./run.sh negative 600009         # 出错的情况
./run.sh queued 600276           # 生产上的走法：排队，三个任务接力
./run.sh down                    # 全部清掉
```

| 环境变量 | 默认 | 含义 |
| --- | --- | --- |
| `WORKSPACE` | `~/worktrees/fable` | 两个应用仓库所在的工位 |
| `DATASET_CHAIN_STATE` | `~/.cache/sunmoon-dataset-chain` | 状态目录：随机口令、日志、取回的文件。权限 0700 |
| `PG_CONTAINER`、`PG_URL_BASE` | `pgtest`、本机 55432 | 已有的 PostgreSQL 容器 |
| `S3_IMAGE` | `bitnamilegacy/minio:2025.7.23` | 对象存储镜像 |

口令每次 `up` 时随机生成，只在状态目录里，不进仓库，也不写进结果。

## 文件

| 文件 | 作用 |
| --- | --- |
| `run.sh` | 总入口 |
| `driver.py` | 经 MCP 查询，并与直接读对象存储里的文件逐条比对 |
| `register_once.py` | 只做登记这一步，打印稳定的错误码 |
| `enqueue_once.py` | 登记批次并排队，与管理接口调用的是同一个函数 |
| `oidc_standin.py` | 身份服务的替身：发现文档、公钥、服务间令牌 |

## 与正式环境的差别

| 项 | 这里 | 正式环境 |
| --- | --- | --- |
| 身份服务 | 替身，每次启动换签名密钥 | Casdoor |
| 对象存储 | MinIO 社区版 | AIStor（要许可证） |
| 任务队列 | 缓存容器 | RabbitMQ |
| 数据库扩展 `uuid-ossp` | 脚本替供给步骤装 | 由数据库供给步骤装 |
| 存储账号的权限 | info 可读、写、列，不能删；知识服务只能按键读 | 以部署清单为准 |

存储账号的权限是按设计意图配的最小权限，整条链在这组权限下能跑通。正式环境的实际权限没有核对。
