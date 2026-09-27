# 正式 KIND 准备入口

目标仍是：一套平台和应用部署代码，KIND / kubeadm 两种建群方式。

`prepare.py` 当前实现 **plan / render / check**，没有 create、delete 或 apply 动作。它为 `sunmoon-kind-main` 准备建群参数、复核本地物料和现场条件；**不能把本单元当作正式建群完成**。旧 `deploy-kind/deploy-kind.conf` / `kind-cluster.yaml` 是 1.27.3 历史路径，不用于新正式集群。

## 固定输入

| 项目 | 值 |
| --- | --- |
| 集群 / 节点数 | `sunmoon-kind-main`，1 控制面 + 2 worker |
| Kubernetes / KIND / Calico | 1.36.4 / 0.33.0 / 3.32.2 |
| 节点镜像 | 原官方 kindest/node 1.36.4，复用 `../isolated/artifacts.lock.json` 的精确镜像身份与归档摘要 |
| API | `127.0.0.1:17443` |
| Pod / Service 网段 | `10.246.0.0/16` / `10.98.0.0/16`；实际创建前重新查冲突 |
| kubeconfig | `/home/zymun/.kube/sunmoon-kind-main.config`，独立新文件 |
| 数据盘 | UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`，100 GiB |
| 每节点挂载 | 独立 `local-path` → `/var/local-path-provisioner`；独立 `static` → `/data/kind-local-storage` |
| TLS 下一跳 | 宿主 `127.0.0.1:19443` → 控制面节点 `30443` |
| 其余原有端口 | 保留 80、30444、30445、30446 的原监听范围，需维护窗口释放 |
| Harbor | 宿主服务；统一 `harbor.sunmoonai.com:30443`；不挂入任何 KIND 节点 |

六条宿主路径来自已批准的[存储方案](../docs/storage-and-harbor-placement-decision.md#22-正式-kind-六条挂载)。节点镜像别名仅用于 KIND 读取本地已导入镜像；未来创建器必须核对真实 image ID，不能按可变别名直接信任。数据平台静态 PV 仍需逐项渲染 nodeAffinity；本工具不创建 PV 或改权限。

## 当前可执行命令

在 `k8s` 仓库根目录：

```sh
# 只打印，不访问 Docker/API，不建目录、不下载。
python3 -B sunmoonai/kind-infrastructure/formal/prepare.py

# 只向 stdout 输出 KIND 配置；不是完整部署包，不直接拿它手工建群。
python3 -B sunmoonai/kind-infrastructure/formal/prepare.py render

# 只读本机检查；root 用于已发布挂载检查与 Docker socket。
sudo -n python3 -B sunmoonai/kind-infrastructure/formal/prepare.py check
```

`check` 完整重读 10 个已验收离线文件的 SHA256，并与仓内验收锁一致比较；不写旧物料目录。检查存储 UUID 与 PID 1/Docker 可见性、目标路径不存在、端口、主机路由、旧/验证集群网段和容量。通过显式本地 Docker socket 查询；两个已知控制面的 `kubectl` 仅执行 ConfigMap GET，不使用当前 kubeconfig，也不输出凭据。

容量同时读 Windows C 实际 free 和数据 VHDX Length。初始建群暂计系统盘 10 GiB、元数据 2 GiB、新数据盘 2 GiB；扣除数据 VHDX 长满 100 GiB 的潜在增长后 C 必须余 50 GiB，数据盘必须余 20 GiB。**这是初始建群预算，不包含独立 Harbor 恢复副本或业务数据库增长，也不是磁盘配额**。后续执行器需在动作前复核并追踪实际增量。

退出码：0 为计划/渲染成功；1 为输入、物料或现场读取失败；2 为检查已完成但尚不准建群。目前创建器和 P3 尚未完成，`ready_for_creation` 明确为 false，不可用参数跳过。现场检查要求旧/验证控制面仍运行；P3 停旧控制面后须使用维护前快照与容器身份核对的后续创建器，不能为通过检查重启占端口的旧控制面。

## 本轮实际结果与未完成项

实际输出见[预检记录](../../scripts/results/luna-formal-kind-preflight.20260927.json)：物料摘要、挂载与网段检查完成；17443/19443 空闲，80/30444–30446 占用。尚未创建宿主六个子目录、kubeconfig 或新节点，未更改旧节点与入口。未执行应用测试套件。

进入创建前仍须完成：

1. 新 managed Harbor 完整备份的独立恢复演练（旧布局验收不能代替）；当前容量不足，保留门槛。
2. P3 具体维护卡、所有者 WSL 压缩与旧控制面停机窗口；入口故障须能恢复旧控制面。
3. 正式 30443 SNI / Harbor 的 TLS、认证推拉与回退验收。
4. 带存储门禁的正式创建/启动入口、CNI 导入与现有共享平台模块接线。不得直接运行历史自动重建入口，也不得直接运行裸 `kind create` 跳过门禁。

建群后记录真实 UID，验六条实际 Docker mount、静态 PV、仓库信任与真实拉取，再部署平台。重建集群不影响 Harbor 数据必须实测。业务 inbox 仍用旧 `kind` 和原 kubeconfig / 1.27.3 kubectl。**最终清理仍是必须完成的收尾项，目前不执行。**

| 规则 | 本单元处理 |
| --- | --- |
| C-R1 / C-R2 | 复用已提交物料锁，全 SHA 验证；正式创建前仍须核 node ID |
| C-D8 | 不更改数据服务版本、表结构或现有数据 |
| C-I8 | 现场/物料异常停止；缺失阶段不判通过 |
| C-T5 | 本地 luna 提交，未 push；代码审阅不等于完成迁移验收 |
