# frpc：集群到公网边缘的客户端

设计见 SDD `0013-edge.md` 第五节。只出站连接边缘 frps，再由 `http2https` 转到本集群 Traefik 的 websecure Service。不改应用 origin、回调和 IngressRoute。

配置照 `infrastructure/edge/smoke/frpc.toml.tmpl` 的字段。正式代理名和分组名是 `investment`、`casdoor`、`relay`。每个副本用自己的 Pod 名做 `user`，否则同名代理第二个副本会被 frps 拒绝。`loginFailExit` 保持 false；边缘 frps 未启动时客户端会一直重连。

镜像 `fatedier/frpc:v0.71.0` 的运行摘要是 linux/amd64 平台清单 `sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`。边缘冒烟钉的 `sha256:99ece6a2…` 是同一镜像的多架构索引。集群从 Harbor `platform/frpc` 拉取平台清单。

私有输入是 `services_config_dir/edge-frp.yaml`（主备各一份，root 0600）。键只有 `token` 和 `group_key`，各 48 位。边缘只读 `token`。令牌不进 Git 明文。

| 字段 | 作用 |
| --- | --- |
| `services_frpc_enabled` | 是否进入阶段图 |
| `frpc_server_addr` / `frpc_server_port` | 边缘 frps |
| `frpc_traefik_port` / `frpc_local_addr` | 集群 Traefik websecure Service，给 frpc 的 `localAddr` |
| `frpc_traefik_pod_port` | 同一入口的容器监听端口，给出站 NetworkPolicy |
| `frpc_replicas` | 两副本，同一分组互备；每个副本的 `user` 是自己的 Pod 名 |
| `frpc_domains` | 与边缘 `edge_domains` 同一份名单；代理名和组名取域名第一段 |
