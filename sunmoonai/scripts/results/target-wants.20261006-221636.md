# 待办 28 回传：统一目标改 Wants，单独停入口不再连带

时间：2026-10-06 22:16。没有退回。

## 一、计划

`host-lifecycle-plan` 退出 0。已安装副本和候选对比：只有 `sunmoon-platform.target` 不同。原来的 `Requires=` 换成两行注释和这一行：

```text
Wants=sunmoon-registry.service sunmoon-entry.service sunmoon-cluster.service
```

`sunmoon-platform-boot.service`、`sunmoon-cluster.service`、`boot.sh`、`check-nodes.sh`、`storage.py`、`storage.json` 都与已安装副本相同。没有别的单元或脚本差异，所以继续重装。

## 二、重装

`platform-install-lifecycle` 退出 0，21 秒。单元里的指令只有 `Wants=` 那一行，没有 `Requires=`。`platform-status` 退出 0，15 秒。target、boot、cluster、registry、entry 都是 active。

## 三、单独停入口

`entry-stop` 退出 0，33 秒。当时：

| 单元 | 状态 |
| --- | --- |
| sunmoon-registry.service | active |
| sunmoon-cluster.service | active |
| sunmoon-platform.target | active |
| sunmoon-entry.service | inactive |

Harbor 三个容器都是 Up 5 hours (healthy)：`sunmoon-registry-proxy-1`、`sunmoon-registry-jobservice-1`、`sunmoon-registry-core-1`。

`entry-start` 退出 0，2 秒。之后 `platform-status` 退出 0，16 秒。五个单元都是 active。

## 结论

通过。单独停入口没有连带停 Harbor 和集群。
