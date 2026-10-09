# 公网边缘（东京 VM）

设计见 `sunmoonai/docs/dev-investment-agent/tree-build/SDD/modules/0013-edge.md`。只在边缘机上运行；集群侧的 frpc 不在这里。

| 命令（在 `infrastructure/` 下） | 作用 |
| --- | --- |
| `make edge-plan` | 只显示将要的配置，不改任何东西 |
| `make edge-smoke` | 本机冒烟：临时令牌 + 临时 frpc + 替身后端，13 项检查，结束后全部清理；不对外、不用真令牌 |
| `make edge-deploy` | 渲染 `/etc/sunmoon/edge/` 并启动 `sunmoon-edge.service`（Traefik + frps，开机自启）。需要 root 0600 的 `/etc/sunmoon/edge/frp-token.yaml` |
| `make edge-deploy EDGE_EXTRA='--extra-vars edge_tls_mode=acme'` | 从 Let's Encrypt 测试环境切到正式证书（先在 staging 跑通，DNS 已指向本机、安全组已放行 80） |
| `make edge-status` / `edge-stop` | 看状态 / 停 |
| `make edge-firewall` | 只加 ufw 放行（1022、80、30443、7000），不启用；`EDGE_EXTRA='--extra-vars edge_firewall_enable=true'` 才启用默认拒绝。**先确认 1022 在放行列表里** |

文件：`config.yaml`（公开参数与镜像摘要）、`service.yaml`（Ansible）、`templates/`、`smoke/`。令牌、`frp.env`、`acme.json` 只在 `/etc/sunmoon/edge/`（root 0700/0600），不进 Git。访问日志关闭（安装凭证在 URL 路径里）。
