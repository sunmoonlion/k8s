# 公共TLS入口维护

HAProxy仅读取ClientHello的SNI做TCP分流，不终止TLS、不持应用或Harbor私钥。公共30443由仓库与应用共用；服务端证书分别由Harbor/Traefik持有。

## 配置与当前路由
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `entry_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `entry_listen_address` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `entry_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `entry_cluster_backend` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `entry_config_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `entry_runtime_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `entry_cluster_routes` | 列表 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |

Harbor域名优先转registry配置的loopback后端。`entry_cluster_routes`按精确域名分组，域名取各应用config，backend取cluster端口；当前Casdoor、四应用Web/Admin及Kibana均声明到新集群29443。未知域名仍按`entry_cluster_backend`走原kind-worker过渡地址；不能据此宣布旧环境已完全退役。实际已验切换日期见[验收边界](../../docs/platform-kind-v1/verification.md#应用与业务链路)。

路由拒绝重复域名、覆盖Harbor、回指监听端口。更换域名联动证书SAN、应用origin、OAuth回调、Ingress和public检查；更改公开30443影响镜像引用及全部客户端，不能单处修改。

## 计划、候选、启停

```sh
make -C infrastructure check-host-materials
make -C infrastructure entry-plan
make -C infrastructure entry-preview
make -C infrastructure entry-status
```

check-host-materials只校验归档；缺本机HAProxy/skopeo时用`prepare-host-materials`导入已核验镜像。preview写`infrastructure/.build/entry/haproxy.cfg`并用固定HAProxy无网络/只读容器语法检查，不改运行配置、不启动监听。

已部署入口控制：

```sh
make -C infrastructure entry-stop
make -C infrastructure entry-start
```

`entry-deploy`生成/启动入口，不替用户停止别的监听者；运行中发现配置差异会拒绝，必须维护stop→deploy。start用已部署配置；status/stop只作用当前sunmoon-entry。

## 配置或域名切换

前提：目标后端已Ready且真实内部协议通过，候选语法通过，当前监听者/Harbor健康已核对。维护前保存三份实际运行文件及SHA/权限：`entry_config_dir/haproxy.cfg`、`entry_runtime_dir/compose.yaml`、`/etc/systemd/system/sunmoon-entry.service`。当前代码不自动生成整套切换回退操作卡，备份路径按本次维护记录选取。

审核配置差异并本地提交后，在获批维护内执行：

```sh
make -C infrastructure entry-stop
make -C infrastructure entry-deploy
make -C infrastructure entry-status
```

验收Harborhealth/token/真实拉取、目标域名真实应用public检查、未变路由。Kibana的公共协议检查为`make -C infrastructure services-check-public`，当前实际范围和宿主DNS限制见[验收边界](../../docs/platform-kind-v1/verification.md#kibana入口的实际范围2026-10-05)。应用公共协议验收入口统一见[applications](../applications/README.md#部署与真实入口验收)。证书一致不代表浏览器登录和业务授权通过。

失败先stop当前入口，恢复本次备份三文件及原权限（备份可0600，运行配置一般0644），systemd daemon-reload后entry-start，核验原路由及Harbor。恢复前核备份SHA/路径归属，不用历史某个旧代理或已删除main候选作为通用回退目标；配置未恢复时不能声称回退成功。

## 运行与日志

运行配置在`/etc/sunmoon/entry`，Compose/工具在`/opt/sunmoon/entry`，服务运行独立于Git工作树。代理UID/GID10001、只读根、drop全部cap、禁止提权、host网络例外、0.5CPU/128MiB/64PID；具体策略取[Compose模板](templates/entry-compose.yaml.j2)。

systemd唯一重启者，Docker restart=no；受控Compose停止130视为正常，stop必须实际inactive。日志local3×20MiB，容器输出不再复制journal。诊断：

```sh
systemctl status sunmoon-entry.service --no-pager
sudo docker logs --tail 100 sunmoon-entry-proxy-1
```

unit未启用boot；自动开机恢复、旧控制面抢端口及DNS变化仍需[独立交付](../../docs/platform-kind-v1/verification.md#未完成项)。
