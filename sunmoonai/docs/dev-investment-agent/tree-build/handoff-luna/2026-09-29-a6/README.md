# 交给本地助手的任务：部署目录里的集成测试跟着后端改两处

> 2026-09-29 远程写。所有者 2026-09-29：「归 luna 管，如果你需要，我觉得你可以给它派个任务让它做好，你同步」。
> 这件事**不急**，不挡集群迁移。迁移期间什么都不做也不会出错，原因见「现在的状态」。
> 两份补丁在本目录：[`tpl-app.patch`](tpl-app.patch)、[`k8s.patch`](k8s.patch)。远程只做了「能不能打上」的检查，**没有改你的任何文件**。

## 为什么有这件事

所有者定了工程结构的规则（见 [工程架构](../../SDD/architecture/engineering.md)「工程结构」）：应用层不引用基础设施层，也不直接用数据库、网络这类库。
按这个规则，四个后端（模板与 info、knowledge、investment）里模板带来的两处代码要改：

| 代号 | 改了什么 | 状态 |
| --- | --- | --- |
| A6 甲 | 可靠投递的代码从 `app/application/services/durable_tasks.py` 挪到 `app/infrastructure/messaging/durable_tasks.py` | 已合入各后端的 `fable` |
| A6 乙 | 登录服务 `AuthService` 不再自己去拿 Redis、PostgreSQL、OIDC 客户端，改为从外面交进来；入库的 SQL 挪到 `app/infrastructure/repositories/auth_user.py` | 已合入各后端的 `fable` |

部署目录里的集成测试引用了这两处，所以要跟着改。部署目录归你，远程不动。

## 现在的状态

| 项 | 说明 |
| --- | --- |
| A6 甲 对你的影响 | **没有。** 旧路径留了一个只做转发的文件，你的测试不改也照常能跑。远程在草稿副本里验过：`test_runtime_database_policy_pg.py` 不改，对着新后端 17 个通过 |
| A6 乙 对你的影响 | 有一个测试会失败：`test_runtime_database_policy_pg.py::test_api_real_identity_upsert_and_immutable_binding`。它用 `AuthService("admin")` 构造，并替换登录服务模块里的 `get_postgres`，这两处在新后端里都不成立 |
| 什么时候会碰到 | 只有当你的工位拿到后端的新提交时（也就是各工位下一次对齐时）。在那之前你的工位里后端还是旧的，测试照旧 |

## 要你做的

在**各工位对齐之后**（你的工位里后端已经是新的），打上两份补丁，跑一遍受影响的测试。

| # | 做什么 | 补丁 | 涉及文件 |
| --- | --- | --- | --- |
| 1 | 登录那一个测试改为直接用 `SqlUserDirectory`；4 个文件里可靠投递的引用改到新路径 | `tpl-app.patch`，在 tpl-app 仓库根目录打 | `k8s-deployment/integration/` 下 `test_runtime_database_policy_pg.py`、`runtime_identity_worker.py`、`test_runtime_identity_lifecycle.py`、`test_runtime_identity_joint.py` |
| 2 | 2 个文件里可靠投递的引用改到新路径 | `k8s.patch`，在 k8s 仓库根目录打 | `sunmoonai/app-platform/scripts/integration/` 下 `test_info_database_policy_pg.py`、`test_knowledge_database_policy_pg.py` |
| 3 | 做完告诉所有者。远程随后删掉四个后端里那个只做转发的旧文件 | — | — |

```bash
# 在 tpl-app 仓库根目录
git apply --check <k8s 仓>/sunmoonai/docs/dev-investment-agent/tree-build/handoff-luna/2026-09-29-a6/tpl-app.patch
git apply         <同上>/tpl-app.patch
# 在 k8s 仓库根目录
git apply --check sunmoonai/docs/dev-investment-agent/tree-build/handoff-luna/2026-09-29-a6/k8s.patch
git apply         sunmoonai/docs/dev-investment-agent/tree-build/handoff-luna/2026-09-29-a6/k8s.patch
```

补丁只是建议。你觉得有更合适的改法，按你的来；补丁与你本地的改动冲突时，以你的为准，照着下面「改动的内容」手工改即可。

## 改动的内容

### 登录那一个测试

原来经登录服务的内部方法入库；现在直接用入库的实现。测的东西没有变：`api` 身份能新建、能刷新同一个用户，不能改绑定、不能删，`worker` 身份读不到。

```python
from app.infrastructure.repositories import auth_user

async def test_api_real_identity_upsert_and_immutable_binding(database, monkeypatch):
    monkeypatch.setattr(
        auth_user,
        "get_postgres",
        lambda: SimpleNamespace(session_factory=database.sessions["api"]),
    )
    directory = auth_user.SqlUserDirectory()

    async def upsert(name):
        return await directory.upsert(
            issuer="https://issuer.example.test",
            subject="one",
            username=name,
            email=None,
            display_name=name,
            roles=[],
            scopes=[],
        )

    first = await upsert("First")
    updated = await upsert("Updated")
    # 以下断言与原来相同
```

### 可靠投递的引用

```python
# 原来
from app.application.services.durable_tasks import DurableTasks, enqueue_task
# 现在
from app.infrastructure.messaging.durable_tasks import DurableTasks, enqueue_task
```

## 远程验过什么、没验什么

| 项 | 结果 |
| --- | --- |
| `test_runtime_database_policy_pg.py`，旧后端，不打补丁 | 18 通过 |
| 同一个文件，新后端，不打补丁 | 17 通过，1 失败（就是上面那一个） |
| 同一个文件，新后端，打补丁 | 18 通过 |
| 两份补丁能否打到 `fable` 当前的文件上 | 能（只检查，没有打） |
| 其余 5 个文件 | **没有跑。** 它们要消息队列或联合环境，远程机上没有。改动只有一行引用 |

验证的环境：远程机上一次性的 PostgreSQL 16 容器（正式环境是 17.6），用完即删；测试文件是拷到草稿目录里改的。

## 往后还会有同类的事

`k8s.patch` 涉及的两个测试还引用了 info 的采集服务与 knowledge 的入库、检索、投递服务。这几个文件也在整改清单里（账本 A7、A8），改的时候会按同样的办法：远程先备好补丁并验证，再交给你。
