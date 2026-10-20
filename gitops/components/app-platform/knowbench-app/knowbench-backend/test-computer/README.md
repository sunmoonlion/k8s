# 分身测试的测试电脑

knowbench 作为运行方跑分身测试（[SDD 0027](../../../../../../docs/design/SDD/modules/0027-knowbot-first-path.md) §3.4）时，委托在这台「电脑」上执行：集群里一个常驻容器，跑与用户同一份代码的本地代理（Linux 包，sunmoon-link 仓 `build-linux.mjs` 打出，版本与摘要钉在 [agent-releases 配置](../agent-releases/config.yaml) 的 `linux` 一节），只配对给测试账号 `knowbot-tester`。

- **取包**：初始化容器用发行包的只读身份（`knowbench_release_reader`，只有 GetObject）从私有桶取包，核归档摘要，解到持久卷，再用包里的 `installer/verify-linux.mjs` 按清单逐字节核对。包要先上传并读回核对（`make -C infrastructure agent-release-linux-upload AGENT_LINUX_TGZ=/绝对路径.tar.gz`，回执 `knowbench-agent-release-linux-published.json`），否则 stage 停下。
- **运行**：镜像复用沙箱镜像（钉好的 Node 24.21.0 与 Codex），非 root、只读根文件系统、不提权；代理不开外层沙箱（容器本身就是隔离）。工作区 `/workspace`，代理配置在持久卷 `/data/home`。
- **配对**：第一次启动没有凭据时，容器日志里显示连接码，所有者用测试账号在工作台确认；凭据落在持久卷上，重启不用再配。
- **网络**：只放行 DNS、对象存储（取包）和公网边缘 `relay.sunmoonai.com` / `knowbench.sunmoonai.com` 的 30443（像用户家里的电脑一样经边缘连进来，用系统信任的证书）。模型不在这里调（在测试账号的云端沙箱里），所以没有别的外网出口。
- **清理**：每小时删一次工作区里 7 天前的底稿目录（`/workspace/底稿/对话-*`）；委托与交回物由 knowbench 自己 7 天后删。

本目录的 `workload.yaml`、`download.sops.yaml`、`kustomization.yaml` 由 stage 生成，不手改；配置是 [后端 config](../config.yaml) 的 `knowbot_test_computer`。Linux 与 Windows 的差别见待办账 118。
