# 新部署体系：第一实现单元

本目录直接使用原生 Make、Ansible 和声明文件，不调用旧 `sunmoonai/`、`utils/` 或 luna 工作区的部署程序。当前完成上游镜像身份盘点、工具依赖锁和宿主挂载预检；Harbor 新装、KIND 创建、平台部署与统一启停尚未实现。

## 目前可用的入口

从本目录执行：

```sh
make tools         # 安装带哈希锁的 Ansible 到本目录 .venv；需要物料或网络
make images        # 列出上游目标和已核实的 amd64 摘要
make check-images  # 有未核实镜像即列出原因并以非零退出
make preflight     # 只读检查宿主挂载，不启动或更改任何服务
```

`make tools` 使用宿主现有 Python 3.12，满足 Ansible 2.21.4 要求；不修改系统 Python。业务镜像独立固定 Python 3.13.15。工具依赖源为 `tools/requirements.in`，完整依赖及 SHA256 为 `tools/requirements.lock`；后续更新使用 `uv pip compile --python-version 3.12 --generate-hashes --no-header --index-url https://pypi.org/simple tools/requirements.in --output-file tools/requirements.lock`，审查 diff 后才同步环境。

## 输入的职责

- `environments/kind/site.yaml`：本机集群名、仓库地址、盘 UUID、三个挂载身份；没有凭据或镜像覆盖字段。
- `host/inventory.yaml`：仅本地主机，Ansible 原生 local 连接。
- `host/preflight.yaml`：核对 ext4、UUID、精确挂载点与 bind 子目录，报告容量。check 模式下执行的 command 都是只读。
- `artifacts/upstream-images.lock.json`：43 个上游目标，保留 source tag、linux/amd64 manifest digest、config digest 和压缩层大小；`reference` 是最终使用的 `repo@sha256` 格式，不是 index 或归档摘要。

镜像记录通过东京服务器原生 `docker manifest inspect --verbose` 取得，仅读取公开 manifest。选择 linux/amd64 Descriptor，并对响应中的 Base64 Raw 解码后复算 SHA256，与 Descriptor.digest 对比。没有下载镜像层或在东京留下此次脚本/归档。查询使用的临时程序不作为部署依赖。

当前 39 项成功；Casdoor、BusyBox helper、Calico CNI、Calico kube-controllers 的复查遇到 Docker Hub 匿名限流，标记 unresolved。Casdoor 先前的带 v 标签不存在，已修正为不带 v 的目标，但尚未确认该目标存在。不要用浮动标签替代，不要把失败删出清单。

## 当前边界

`check-images` 只检查这批上游身份记录；即使以后通过，也不表示离线材料已完整。KIND 1.36.5 构建产物、kubeadm 配套镜像、最终 chart/辅助镜像及自有应用镜像仍需加入正式发布。`offline_ready=false` 直到归档、校验和与完整依赖全部齐备。

`preflight` 通过只证明执行进程看到的宿主挂载身份正确。Docker 服务命名空间可见性、Windows C 盘增长预算、TLS/认证和服务重建恢复尚需后续准入及验收。数据盘空间数字不等同 C 盘物理剩余空间。

## 本轮规则对应

| 规则 | 本单元处理 |
| --- | --- |
| C-R1 / C-R2 | 固定上游镜像身份；保留来源，部署引用为纯摘要；完整发布尚未形成 |
| C-R4 | 站点配置不提供镜像覆盖；发布身份与主机参数分开 |
| C-R6 | 只读盘点模板和实例依赖；应用改动仍从模板开始 |
| C-D3 / C-D8 | 本轮不改数据库身份或迁移链，后续保持独立逻辑库和迁移 Job |

首轮执行发现容量命令的 YAML argv 将逗号拆为多个参数，已修正为一个字符串；修正后实际执行通过（ok=5、changed=0、failed=0）。没有执行业务测试或服务重启。
