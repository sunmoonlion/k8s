# 生产站点 `prod`

> 所在层：2 站点层。第二个站点，和 `kind/` 共用同一套声明，只换参数（SDD 0039）。

**现在的形态（2026-10-21 所有者定）**：手里还没有云，先在本地机（Windows 专业版，128 GB 内存）上用 Hyper-V 建一台 Ubuntu 24.04 虚拟机当生产宿主：8 核、32 GB、系统盘 60 GB、数据盘 200 GB，内部交换机 `sunmoon-prod`（192.168.80.0/24），固定 IP `192.168.80.10`。C、D、E 三段都先在它上面走通；将来租到云 VM，同一份 `site.yaml` 只换 IP 和盘。公网仍经东京边缘的 frp（`edge_mode: separate`），搬到云上再改 `local`。

| 文件 | 用途 |
| --- | --- |
| [`vm/New-SunmoonProdVm.ps1`](vm/New-SunmoonProdVm.ps1) | 所有者在**管理员 PowerShell** 里跑：建交换机与 NAT、建虚拟机、挂系统 ISO 与应答 ISO、开机 |
| [`vm/make-seed-iso.sh`](vm/make-seed-iso.sh) | 本地助手在 WSL 里跑：按模板生成 Ubuntu 自动安装的应答 ISO（主机名、用户、SSH 公钥、固定 IP、数据盘） |
| [`vm/autoinstall/`](vm/autoinstall/) | 应答模板 |
| `site.yaml`、`sops-recipient.txt`、`flux-source.yaml` | C5 起填（样例），D 段真建时定值 |

建好后的核对：WSL 里 `ssh sunmoon@192.168.80.10` 免密进得去、`sudo -n true` 通、`lsblk` 看到 `/data` 挂着数据盘、能出站（`curl -sI https://mirrors.aliyun.com` 回 200）。之后宿主层各模块（Harbor、入口、Jenkins）和 `kubeadm/` 模块都在这台机**里面**跑，和开发站点在本地机里跑一样。
