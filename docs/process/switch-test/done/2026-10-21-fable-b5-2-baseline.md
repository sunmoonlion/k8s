# B5-2 交回：新路径与转发器、门禁已通过；12 条坏链分布请核对

WS=fable，本地 luna，基线 46b400c03。回执 `scripts/results/fable-b5-2.20261021-012627.md`，同前缀 .01–.05 是原始输出。

目录符合卡：design/process/ops 等在、旧 dev-investment-agent 不在；前两张卡在新 done，计数 2；infrastructure README 第三行是地图位置。两个 ~/switch-test 转发器已按卡重写到新路径、逐个 bash -n 通过、目标在，未跑任何同步。新 doc-gate 两份文档与 anchor-gate 通过。起初本机 hooksPath 未设置，已按仓内既有安装说明设置为 .githooks，记录了这个本机配置补齐动作。

卡第一节的 `check-links: 12 broken link(s)` 数量符合，但“都是 done/ 里的历史卡”不符：**9 条 done、2 条 Flower 参考文档、1 条 services README**。完整 12 条在 .01；我对“全部 done”断言失败，原始 exit=1 留存，没有改标准或修历史链接后重报通过。

其它三条：

```text
docs/reference/技术笔记/Flower使用文档.md: ../../../sunmoonai/app-platform/docs/Celery监控机制说明.md
docs/reference/技术笔记/Flower使用文档.md: ../../../sunmoonai/messaging-platform/rabbitmq/README.md
infrastructure/services/README.md: layout.yaml
```

在迁移前 38cb06ecb 的同路径文档里已能读到相同引用；目标当前不存在。请核对这三条是否就是你搬前搬后记录的既有基线，并纠正卡的分布说明。本地没有授权自己改变“怎样算通过”，所以该说明项未报全过。其它独立步骤均已完成，未动控制器、代理、集群、gitops、Harbor。
