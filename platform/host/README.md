# 本机 TLS 直通入口

`entry.yaml` 使用原生 Ansible、固定摘要的官方 HAProxy 3.4.6、Compose 和 systemd。只读取 TLS ClientHello 的域名进行 TCP 分流，不终止 TLS、不持有证书私钥。

## 日常命令

在 `platform/`：

```sh
make prepare-host-materials # 核验 HAProxy/skopeo 归档；缺失的本机镜像从归档导入
make check-host-materials   # 只核验归档，不调用 Docker、不联网
make entry-plan             # 查看监听地址与两条路由
make entry-deploy           # 配置并启动本次入口，不停止其他监听者
make entry-status          # 查看 systemd 状态
make entry-stop            # 停止本次入口，保留配置和容器
make entry-start           # 检查配置并启动，验证 Harbor TLS 健康
```

站点保留 `entry_enabled` 和监听地址、端口、应用后端、配置/运行目录。运行中配置变化会拒绝部署，需先停止本次入口。新 unit 尚未启用开机自启；不能据此宣称 WSL 重启验收完成。

当前正式监听 `0.0.0.0:30443`，候选32443已退出监听，旧代理停止保留。Harbor 域名转 `127.0.0.1:11443`，其他域名保持旧入口实际目标 `172.18.0.5:30443`（保留的 kind-worker）。此 IP 是**本次过渡站点值**，并非未来新集群配置；新集群应用入口验收后改成其宿主端口。旧 main 的 19443 当前没有 Traefik，不能凭名字提前切过去。

正式 30443 切换范围和回退见 [维护操作卡](../../docs/platform-kind-v1/entry-cutover.md)。日常代码不读取旧工作树或旧代理配置；操作卡仅在本次交接时明确旧代理身份。

## 运行边界

- `/etc/sunmoon/entry/haproxy.cfg`：不含秘密的代理配置。
- `/opt/sunmoon/entry`：Compose 文件和经过校验的独立 Compose 二进制；运行不依赖 Git 工作树。
- 代理容器 UID/GID 10001，根文件系统只读、capabilities 全撤销、禁止提权，0.5 CPU/128 MiB、64 PID 上限。host 网络用于直达宿主 loopback 后端，属于本地入口的明确例外。
- systemd 是唯一重启管理者，Docker restart=no。Compose 5.5.1 在受控停止时实测返回 130，unit 将其列为正常退出；意外退出仍由 Restart=always 重启。实际停止结果必须为 inactive。
- Docker local 日志按本次入口的有限运维日志配置为 3×20 MiB。Compose 输出不复制到 journal，systemd journal 保留 unit 生命周期信息。可用 `sudo docker logs --tail 100 sunmoon-entry-proxy-1` 查代理错误。
- 候选 Harbor 路由验收使用新 CA 和真实域名，显式绕过环境代理。应用后端比对使用对端证书一致性，不把它当成应用证书信任或登录功能验收。

HAProxy SNI 语义来自 [官方配置手册](https://docs.haproxy.org/3.4/configuration.html)。入口不可用时，先查看配置和容器日志，不用关闭 TLS 校验修复连接。
