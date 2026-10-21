# luna 卡 fable-c0：生产宿主——本地机 Hyper-V 上建 `sunmoon-prod` 虚拟机（0039 停点 C0）

> 状态：**可执行**（远程 Fable 2026-10-21 写，第二版：本地机实测是 Windows 家庭版，所有者不想动原系统，建机改用 VMware Workstation Pro）。所有者定：手里没有云，生产站点先建在本地机的虚拟机上（128 GB 内存，给它 32 GB）。这张卡三方配合：你在 WSL 里准备两个 ISO 并在最后核对，**所有者在 VMware 界面里建机**（你不能替），装完你再核。不碰现有的一切：开发集群、Jenkins、Harbor、WSL 的数据盘都不动。
>
> 临时就地修授权同前：`infrastructure/environments/prod/vm/` 下的脚本与模板、本卡命令里让步骤过不去的错可以就地改、验、续跑并推 `origin/fable`；不改规格（8 核、32 GB、60+200 GB、192.168.80.10，网关 192.168.80.2）、不改设计。

```text
工位 WS=fable：~/worktrees/fable/sunmoonun，分支 fable；收件箱 docs/process/switch-test/inbox/luna/
会联网的：下载 Ubuntu 24.04 live-server ISO（releases.ubuntu.com，约 3 GB）与校验和；WSL 里可能要 apt 装 xorriso
磁盘：本地机只有 C 盘（约 119 GiB 空闲）。ISO 放 `C:\iso\`，虚拟机放 `C:\VMs\sunmoon-prod\`；两块虚拟盘都选「不立即分配全部空间」（用多少长多少），标称 60 + 200 GB 不会一次占掉。所有者安排 WSL 离线压缩在建机**之前**（同一次停机），压完把回收量写进回执
```

## 一、WSL 侧：两个 ISO（luna）

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
command -v xorriso >/dev/null || sudo -n apt-get install -y xorriso
mkdir -p /mnt/c/iso && cd /mnt/c/iso
curl -fsSL -o SHA256SUMS https://releases.ubuntu.com/noble/SHA256SUMS
iso=$(grep -o 'ubuntu-24.04[.0-9]*-live-server-amd64.iso' SHA256SUMS | head -1); echo "iso=$iso"
[ -f "$iso" ] || curl -fL -o "$iso" "https://releases.ubuntu.com/noble/$iso"
grep " \*$iso$" SHA256SUMS | sha256sum -c -; echo "iso verify exit=$?"
ls -l ~/.ssh/id_rsa.pub
bash ~/worktrees/fable/sunmoonun/infrastructure/environments/prod/vm/make-seed-iso.sh --out /mnt/c/iso/sunmoon-prod-seed.iso --pubkey ~/.ssh/id_rsa.pub --gateway 192.168.80.2
ls -l /mnt/c/iso/
```

要看到：`iso verify exit=0`（`…: OK`）；生成应答 ISO 时会要一个**控制台口令**（只在 Hyper-V 控制台登录用，SSH 走钥匙；你随机生成一个，告诉所有者，不进回执）；最后 `ls` 里有系统 ISO 和 `sunmoon-prod-seed.iso`。把系统 ISO 的文件名写进回执（第二节所有者要用）。

## 二、Windows 侧：建虚拟机（**所有者**，VMware Workstation Pro）

本地机是 Windows **家庭版**、所有者不想动原系统，所以不用 Hyper-V，改 VMware Workstation Pro（免费）。luna 把 [`vm/README-vmware.md`](../../../../../infrastructure/environments/prod/vm/README-vmware.md) 这页和系统 ISO 文件名交给所有者，所有者照它做三段：一次性准备（开 Windows Hypervisor Platform、装 VMware、把 VMnet8 改成 192.168.80.0/24 网关 .2）→ 界面里新建虚拟机（8 核、32 GB、60 + 200 GB 两块盘、两张 ISO、UEFI、NAT）→ 控制台输一次 `yes`，装完自己关机，移除光盘再开机 → 管理员 PowerShell 两行开转发 → 告诉 luna「起来了」。

## 三、WSL 侧：核对（luna）

```bash
ssh-keygen -R 192.168.80.10 >/dev/null 2>&1; ssh-keyscan -T 10 192.168.80.10 >> ~/.ssh/known_hosts 2>/dev/null
ssh -o BatchMode=yes -o ConnectTimeout=10 sunmoon@192.168.80.10 'hostname; id -un; sudo -n true && echo sudo-ok; lsblk -o NAME,SIZE,MOUNTPOINT | grep -E "sd|data|/$"; findmnt /data; free -g | head -2; nproc; curl -sI https://mirrors.aliyun.com | head -1; ip -4 addr show eth0 | grep inet'; echo "ssh exit=$?"
ping -c 2 192.168.80.10 | tail -1
```

要看到：`ssh exit=0`；主机名 `sunmoon-prod`、用户 `sunmoon`、`sudo-ok`；`/data` 挂着约 200 GB 的盘；内存约 31 GB、8 核；`HTTP/2 200`（能出站）；`inet 192.168.80.10/24`。

连不上：先在 Windows 管理员 PowerShell 看 `Get-VM sunmoon-prod`（Running？）、`Get-NetNat`、`Get-NetIPInterface | ? Forwarding -eq Enabled | select InterfaceAlias`；WSL 到 192.168.80.0/24 不通多半是转发没开（脚本开了，重启 Windows 后可能要再开），这一步属于卡改到的脚本范围，可以就地修。

## 四、回执与推回

`scripts/results/fable-c0.<时间>.md`：第一节输出（ISO 名、校验结果、应答 ISO 大小；**不含口令**）、第二节所有者做了什么（一句话）、第三节 ssh 输出原文、「就地修了什么」。

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git add scripts/results/fable-c0.*.md && git mv docs/process/switch-test/inbox/luna/2026-10-21-fable-c0-prod-vm.md docs/process/switch-test/done/ && git commit -m "fable-c0 回执：生产宿主虚拟机建起（luna）" && git push origin fable; echo "push exit=$?"
```
