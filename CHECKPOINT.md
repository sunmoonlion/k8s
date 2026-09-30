# 新部署体系交接

## 目标、工作区和授权

从零建立可长期维护的部署代码，第一期 KIND；使用原生 Make、Ansible、官方 Harbor Compose、KIND、Flux 和 SOPS，不调用旧 `sunmoonai/`、`utils/` 或 luna 部署程序。五仓在 `/home/zymun/worktrees/platform-kind-v1`，分支均为 `platform-kind-v1`，从各自本地 master 建立；基线见 [输入盘点](docs/platform-kind-v1/inventory.md)。原 luna 仅作参考。

所有者授权新体系采用已选定版本，不迁移旧业务数据或旧 Harbor 镜像；应用可修改后重新构建，业务 Python **3.13.15**。受保护旧节点、卷、备份和他人 local-integration 工作仍不可擅删。四个应用仓未改，本轮仅改 k8s，未 push。写入新工作树继续走工具权限流程。

所有者在本轮明确批准 **每容器 3 份 × 20 MiB 的自动日志轮转**；镜像、数据、备份删除不在此次批准范围内。未启用自动镜像清理。

入口：[架构](docs/platform-kind-v1/architecture.md)、[版本](docs/platform-kind-v1/images.md)、[操作](platform/README.md)、[Harbor](platform/registry/README.md)。

## 已完成的物料与节点单元

上一个提交：`eef098e272932a0ac3e279bfc002e1ea0ef1b9a0`；节点构建提交 `e280a3850953584853a4717945a8183baf18e5ec`。

- Ansible 2.21.4 已按哈希锁安装到 `.venv`，使用宿主 Python 3.12.3，不改变业务 Python 选型。
- 55 个上游及建群配套镜像 amd64 manifest 已解析并复算摘要；`complete=true` 仅表示该清单齐全，`offline_ready=false`。
- 10 项文件共 **1,358,981,849 字节**，位于 `/home/zymun/packages-to-be-installed/releases/platform-kind-v1/{bin,packages,manifests}`。
- KIND 0.33.0、kubectl/kubeadm 1.36.5 已安装到 `.tools/bin`；本轮新增 Compose 5.5.1。未替换系统工具。
- 官方 KIND 文件模式已构建 `sunmoon-kind-node:v1.36.5-kind0.33.0`，本机 manifest ID **sha256:676c571e38792c196595853476dc020e628b9b56f3b0c3ca1d2056e5ce612a0b**；实际 Kubernetes 1.36.5、containerd 2.3.4、runc 1.4.3。
- 核对 base/rootfs、10 个内置镜像配置、144 个内部内容文件 SHA256。kubeadm pause=3.10.2；KIND base 实际配置为 3.10，分别锁定。
- 节点和三个 Calico 3.32.2 归档共 **641,355,776 字节**，在 `images/`。`fetch-bootstrap-images` 最终重复 ok=44 changed=0 failed=0；离线 `check-bootstrap-images` ok=48 changed=0 failed=0。
- Harbor 2.15.2 官方包六个成员、177 个 blob、12 个镜像已核验并导入 Docker；`prepare-harbor-materials` 最终重复 ok=34 changed=0 failed=0。
- 官方归档为未压缩 OCI 层，其 manifest 与上游分发摘要不同。使用 `harbor-offline-images.lock.json` 的 `archive_reference`；本轮实际按该 repo@digest 启动成功。
- KIND 本地产物尚未发布远端，锁内 `origin=local-build` 不是 Docker Hub 可拉取承诺。完整宿主、chart、辅助镜像及应用物料仍未齐备。

## 当前单元：新 Harbor 服务（2026-10-01）

### 实现

`platform/registry/service.yaml` 提供 plan/deploy/start/stop/status；Make 直接调用 Ansible。站点保留 `registry_enabled`，发布文件固定组件/资源。不存在额外统一 CLI 或旧代码转接。

直接调用官方 prepare 镜像，禁用网络、只挂本实例目录及指定证书；绕开会移动全局历史文件的 prepare 包装脚本，不执行含 `down -v` 的 install.sh。官方 Compose 加小型 override，固定归档 digest、资源、健康依赖和日志。

- 数据：`/data/harbor/platform-kind-v1/data`，在 230 GiB 数据盘；UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。
- 私密配置：`/etc/sunmoon/registry`，独立随机凭据和新 CA/证书；不进 Git、不在输出显示。服务器证书 1825 天，到期 **2031-09-29 UTC**，CA 3650 天。
- 运行文件：`/opt/sunmoon/registry`，独立于工作树，含已校验 Compose、官方配置、挂载守卫和 storage.json。
- 后端：**127.0.0.1:11443**；正式地址配置为 `harbor.sunmoonai.com:30443`，但 **30443 仍走旧服务**，此次未切换。
- 生命周期：`sunmoon-registry.service`，systemd 唯一重启管理者，容器 restart=no；挂载守卫逐次验证 host/Docker 所见数据盘一致。unit **disabled**，待完整开机验收才启用。
- 10 个容器均 Docker local 日志 3×20m；Compose 不再把容器日志复制到 journal。未设镜像保留/GC/备份删除；upload purging 关闭。
- Trivy 暂设 skip_update/skip_java_db_update/offline_scan；**漏洞数据库未备齐，扫描功能未验收**。

### 本轮实际执行及发现

- `make install-binaries BINARIES=compose`：ok=19 changed=1 failed=0。
- 首次 `make registry-deploy`：ok=57 changed=18 failed=0，最终健康；期间 jobservice 早于 core 就绪，导致两次自动重启。已在正式 override 加 service_healthy 依赖，不把这次重试隐去。
- 修正后停止并重新部署：ok=58 changed=5 failed=0；10 个容器 healthy，systemd `NRestarts=0`。
- 最终代码重复 `make registry-deploy`：**ok=58 changed=0 failed=0**。运行配置相同时不重建凭据、不重启。配置改变要求先停止。
- 已实际核验 TLS 信任链/域名/私钥匹配、健康接口 healthy、管理员 `/users/current` 身份、匿名 `/v2/` 返回 401。
- 逐个检查实际容器：10/10 healthy、repo@digest、restart=no、日志 local/20m/3。
- 最终 `registry-stop`：ok=7 changed=1 failed=0，实际 10/10 容器停止并保留；`registry-start`：ok=16 changed=1 failed=0，恢复健康及认证，NRestarts=0。没有停止旧 Harbor、SNI 或 KIND。
- `registry-plan`：ok=8 changed=0 failed=0；`registry-status`：ok=6 changed=0 failed=0。
- 最终 10/10 容器 healthy，均具有非零内存/CPU 上限；服务 active/running，开机自启仍 disabled。

原始 Ansible 输出在本次会话工具记录；可从同一 Make 入口重跑，不另提交大批 results 文件。没有新增或运行测试套件。实际部署、认证和生命周期检查属于此前授权验收。

### 现场边界

旧 Harbor 项目 `sunmoon-harbor-cutover-20260930-v1` 后端 18443；旧 SNI `sunmoon-sni-transition-main-20260928` 占用 30443，旧 KIND main/136/旧节点维持原状。不得把这些已有环境当作新体系验收结果。

最近部署容量检查：C 空闲约 **131.53 GB**，数据盘实际分配约 **176.00 GB**，预留长至 230 GiB 的约 **70.96 GB**，再计本次 2 GiB 预算后约 **58.42 GB**，高于 50 GiB（53.69 GB）。下次写入必须重测；这里不是全套部署空间已足够的证明。数据盘当时文件系统剩余约 76.09 GB。

Windows 容量助手位于 `C:\wsl-disks\scripts\platform-kind-v1\windows-capacity.ps1`。本轮未改执行策略、计划任务或 Docker 配置，未关闭 WSL。东京未连接、无新增远程临时物料。

## 下一步顺序

1. 新 Harbor 服务单元完成后，补新入口、客户端认证与真实镜像推拉；正式 30443 切换前准备可回退的具体维护方案。
2. 补扫描器数据库、Harbor 配置/数据备份与实际恢复；再推进新 KIND 创建及 Flux，不引用原 luna 部署链。
3. 工具/物料继续形成完整发布；平台服务与应用逐项部署。公共业务修改从 tpl-app 开始，再同步实例。
4. 验证单组件与整套一键部署、统一启停、自动挂盘启动、WSL/KIND 重启及 KIND 删除重建后的 Harbor 数据/镜像摘要与新节点拉取。
5. 完成长期开销监控与受控清理入口。日志策略已获批，镜像/缓存/备份删除另按具体清单授权。达到退出条件后才清理受保护旧资源及本次临时物料。

尚未实现完整部署/集群创建/全套启停；不能宣布新体系整体完成。当前没有 token/时间预算；已授权工作继续执行，不重复要求所有者审阅已确定方案。
