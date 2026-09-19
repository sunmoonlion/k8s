# B7v 固定候选验证与交付边界

2026-09-19，Luna 单人实现与自测，不是独立 UAT；没有切换业务环境。
本附件与 [范围](scope.md)、[B8 映射](backlog-routing.md)、
[KIND 只读核对](kind-cutover-preflight.md) 一起阅读。

## 固定对象

测试候选 `tpl-app@09ff4a9268db5006f5d32a2953f58c95b1369819`，
基线 `33f5b636db7e98a9ae7ad0adc211cad22cfdd397`。
仅增加生命周期测试、给既有夹具暴露自身容器/重启后端口刷新、补 README；
没有修改生产 Backend、数据库迁移、权限编译器或父仓 gitlink。

| 后端 | 固定提交 |
| --- | --- |
| tpl-backend | `44e74fe02d29616dfe636b06cc717bd9698536d9` |
| info-backend | `5fb909b6a012bfa62d1002abb6deb3fd9e3dc016` |
| knowledge-backend | `26aa0715f15e2c8df4713559063a9a2e3215a1c8` |
| investment-backend | `68f776edf6f8155f4e5ebfc4e321a17da229dc95` |

固定 PostgreSQL 镜像 `sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b`；
RabbitMQ 镜像 `sha256:ee10eb35bee296808f458c828ef7f581c15e4f18bcaf621742938b0897fcf718`。
每次用真实迁移和各自已审查的数据库编译器；不把模板六表策略套给领域仓。

## 实际执行命令

从 `/home/zymun/worktrees/luna` 运行；所有 Docker 运行均经过本地平台批准，
测试确认开关只允许新建一次性资源，不接受业务连接 URL。

```sh
JOINT_RUNTIME_TEST_CONFIRM=disposable-b7u-only \
BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only \
tpl-app/tpl-backend/app/.venv/bin/python -m pytest \
  -c tpl-app/tpl-backend/app/pyproject.toml \
  tpl-app/k8s-deployment/integration/test_runtime_identity_lifecycle.py \
  tpl-app/k8s-deployment/integration/test_runtime_identity_joint.py \
  tpl-app/k8s-deployment/integration/test_runtime_broker_policy.py \
  -k 'not full_template and not auxiliary' -q -s --tb=short \
  --junitxml=/tmp/luna-b7v-20260919-vc9Rmi/template.xml

for appname in info knowledge investment; do
  JOINT_RUNTIME_TEST_CONFIRM=disposable-b7u-only \
  BROKER_PERMISSION_TEST_CONFIRM=disposable-b7s-only \
  BROKER_PERMISSION_TEST_BACKEND=/home/zymun/worktrees/luna/${appname}-app/${appname}-backend/app \
  ${appname}-app/${appname}-backend/app/.venv/bin/python -m pytest \
    -c ${appname}-app/${appname}-backend/app/pyproject.toml \
    tpl-app/k8s-deployment/integration/test_runtime_identity_lifecycle.py \
    -q -s -x --tb=short \
    --junitxml=/tmp/luna-b7v-20260919-vc9Rmi/${appname}.xml || exit $?
done

python3 -m unittest discover -s tpl-app/k8s-deployment/tests -q
```

如实保留模板执行时的筛选表达式：实际测试名是 `full_backend`，因此并未排除完整后端
包装测试；本次确实执行了它。只 deselect 两个未受此次代码影响的 s3/redis 辅助服务测试，
不是跳过失败用例。三领域只重跑新增六项，不声称本轮重新执行它们的完整后端套件。

## 固定版本结果

| 验证 | 结果 | 留存的原始 JUnit |
| --- | --- | --- |
| 模板外层：6 生命周期＋3 联合＋30 broker＋1 完整后端包装 | 40 passed、0 skipped；2 个辅助服务测试未选中；244.25 秒 | [template.xml](template.xml) |
| 上述包装实际运行的模板完整后端 | 258 passed、0 skipped；52.38 秒 | [template-backend.xml](template-backend.xml) |
| Info 生命周期；实际恢复 15 表 | 6 passed、0 skipped；34.55 秒 | [info.xml](info.xml) |
| Knowledge 生命周期；实际恢复 10 表 | 6 passed、0 skipped；34.42 秒 | [knowledge.xml](knowledge.xml) |
| Investment 生命周期；实际恢复 18 表 | 6 passed、0 skipped；34.80 秒 | [investment.xml](investment.xml) |
| 模板父仓部署策略单元 | 18 tests，OK | 命令如上，0.246 秒 |
| 三份涉及的 Python 测试文件 | Ruff check 与 format --check 通过 | 无格式或静态检查错误 |

模板恢复为 6 表；新增生命周期测试合计 24 项，不重复把包装测试计为后端业务用例。
XML 从 pytest 输出复制，只规范化文件末尾换行；不包含凭据或业务载荷。
所有临时容器与夹具创建的匿名卷均由其 finally 精确删除并断言不存在；
最终 Docker 标签查询 `luna.disposable=b7u` 与 `b7s` 均为空，原有三台 KIND 容器及
既有停止容器保持原样。不执行任何 prune 或清理非本轮资源。

## 已查清的调试失败

1. 首次收集时模块搜索路径设置晚于公共夹具导入，导致 `runtime_database_policy` 找不到。
   调整为先明确 deployment/目标 Backend 路径，再导入；不安装额外副本绕过。
2. RabbitMQ 将默认 classic 队列物化为 `arguments={"x-queue-type":"classic"}`。
   精确核 `type=classic`、原期望参数为空及上述唯一物化参数；不改成忽略 arguments。
3. HTTP DELETE 关闭连接后，闲置客户端不处理 Connection.Close，关闭握手会悬挂。
   测试显式收到 320 ConnectionForced、发送 Close-Ok，再有界核管理面连接消失。
   与 [RabbitMQ HTTP API](https://www.rabbitmq.com/docs/4.1/http-api-reference) 的连接关闭端点及
   [AMQP 0-9-1 规范](https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf) 的关闭握手一致；
   结论以本次固定镜像实测为准。
4. 重启后连接拒绝不是 broker 数据损坏：实际观测回环动态端口从 `32774/32775`
   变为 `32776/32777`；夹具重新读取 Docker 映射并更新 HTTP/当前与后续 AMQP URL。
5. `basic_get` 返回底层 AMQP Message，不提供 Kombu 的 `message.ack()`。
   按既有测试使用 channel `basic_ack(message.delivery_info["delivery_tag"])`。

调试失败未作为通过证据，所有最终结果以固定提交复跑为准。没有放宽业务权限，
没有删除失败测试或吞掉异常。最终 JUnit 作为同目录附件保存，不依赖临时目录续接。

## 覆盖界限与尚待决定的工作

- PG 恢复覆盖所有实际表的结构与行快照，但非空业务样本仅合成 Outbox/Inbox；
  未验证完整领域业务数据、对象存储、外部副作用、跨实例灾备或业务 RPO/RTO。
  本次 `pg_dump -Fc` 未用 `--create`；角色/密码与目标数据库 CONNECT 是独立供给，
  不能把单份数据库归档当作完整环境恢复包。
- RabbitMQ 验证临时容器重启及自身数据库保存的权限、拓扑和持久消息。
  未给业务 `rabbitmq-app-definitions` 导入任何内容；不能证明共享启动 Secret 已更新。
- B7 的业务供给/排空/凭据撤销与切换、实际备份恢复、归档保留策略仍未完成。
  不擅自设保留天数或删除旧账；Prometheus/Alertmanager 继续留 N4-OPS-01。
- B8 已核对 N1～N6 与新合同的冲突和接收落点，尚未把未决设计伪装为正式新任务树。
  已向用户询问合同 D1；没有收到决定就不擅自移动 PRD/SDD 模块。
- B9 本轮只交本地固定提交；未合 master、未推 GitHub/Gitee、未运行同步或部署。
  核对时 k8s master 为 `42a71bfebeb840da8d0acccfe3feebcca70acb54`，比本轮基线
  多一个独立 `question-data-demo` 提交，四文件与本次无交集；保留该提交，禁止用 Luna
  覆盖 master。后续按新鲜引用与精确批准集成，不复用旧的暂停同步授权。
