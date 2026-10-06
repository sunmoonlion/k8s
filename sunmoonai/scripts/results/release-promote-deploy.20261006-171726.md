# 待办 27 回传续二：入口先停再部署

时间：2026-10-06 17:17。工作区在开始时干净。第五节、第六节没有做。没有退回晋级指针。

## 一、配置差

`entry-preview` 退出 0。`diff` 退出 1（有差异）。只新增了两行 `use_backend` 和两段 backend，都指向 `127.0.0.1:29443`：

- `cluster_operator-consoles`：`rabbitmq`、`neo4j`、`aistor`、`pgadmin`、`redisinsight`、`flower`、`mongo-express`
- `cluster_relay`：`relay.sunmoonai.com`

`default_backend cluster` 和 `backend registry` 没有出现在差异里。

## 二、停入口并部署

| 命令 | 退出码 | 用时 |
| --- | --- | --- |
| `entry-stop` | 0 | 67 秒（17:15:23–17:16:30），停完 ActiveState=inactive |
| `entry-deploy` | 2 | 25 秒 |
| `entry-start`（deploy 失败后按待办拉起） | 2 | 约 21 秒 |

`entry-deploy` 已把新配置写入并启动了入口，然后健康检查失败。失败任务：`Verify Harbor SNI routing with the trusted certificate`（`entry/service.yaml:222`）。`curl` 退出 35：`SSL_ERROR_SYSCALL`，地址 `harbor.sunmoonai.com:30443`。`entry-start` 是同一个检查失败。

现在 `sunmoon-entry.service` 是 `ActiveState=active`、`SubState=running`。`haproxy.cfg` 时间是 2026-10-06 17:16:33。`0.0.0.0:30443` 在听。`11443` 没有监听。

Harbor 容器在 17:16:26 退出（`sunmoon-registry-core-1` 退出码 0，`sunmoon-registry-registry-1` 退出码 2），比入口单元停完早几秒。入口单元的 `ExecStop` 只停 compose 项目 `sunmoon-entry`。用 root 再探一次 `https://harbor.sunmoonai.com:30443/api/v2.0/health` 仍是 curl 35。

## 三、后面没做

`platform-deploy` 和第六节检查没有跑。

## 结论

不通过。入口配置差符合预期，入口进程已用新配置起来，但 Harbor 后端不在听，30443 上的仓库健康检查失败。
