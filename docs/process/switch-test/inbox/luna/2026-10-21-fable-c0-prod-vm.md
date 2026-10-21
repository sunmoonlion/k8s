# luna 卡 fable-c0：生产宿主——本地机 Hyper-V 上建 `sunmoon-prod` 虚拟机（0039 停点 C0）

> 状态：**可执行**（远程 Fable 2026-10-21 写）。所有者定：手里没有云，生产站点先建在本地机的 Hyper-V 虚拟机上（Windows 专业版，128 GB 内存，给它 32 GB）。这张卡三方配合：你在 WSL 里准备两个 ISO 并在最后核对，**所有者在管理员 PowerShell 里跑建机脚本**（Hyper-V 要管理员，你不能替），装完你再核。不碰现有的一切：开发集群、Jenkins、Harbor、WSL 的数据盘都不动。
>
> 临时就地修授权同前：`infrastructure/environments/prod/vm/` 下的脚本与模板、本卡命令里让步骤过不去的错可以就地改、验、续跑并推 `origin/fable`；不改规格（8 核、32 GB、60+200 GB、192.168.80.10）、不改设计。

```text
工位 WS=fable：~/worktrees/fable/sunmoonun，分支 fable；收件箱 docs/process/switch-test/inbox/luna/
会联网的：下载 Ubuntu 24.04 live-server ISO（releases.ubuntu.com，约 3 GB）与校验和；WSL 里可能要 apt 装 xorriso
磁盘：ISO 与虚拟机文件放 Windows 的 D 盘（`D:\iso\`、`D:\Hyper-V\`）；D 盘没有或空间不够就换一个盘，把实际用的盘写进回执，PowerShell 脚本加 `-VmRoot` 参数
```

## 一、WSL 侧：两个 ISO（luna）

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
command -v xorriso >/dev/null || sudo -n apt-get install -y xorriso
mkdir -p /mnt/d/iso && cd /mnt/d/iso
curl -fsSL -o SHA256SUMS https://releases.ubuntu.com/noble/SHA256SUMS
iso=$(grep -o 'ubuntu-24.04[.0-9]*-live-server-amd64.iso' SHA256SUMS | head -1); echo "iso=$iso"
[ -f "$iso" ] || curl -fL -o "$iso" "https://releases.ubuntu.com/noble/$iso"
grep " \*$iso$" SHA256SUMS | sha256sum -c -; echo "iso verify exit=$?"
ls -l ~/.ssh/id_rsa.pub
bash ~/worktrees/fable/sunmoonun/infrastructure/environments/prod/vm/make-seed-iso.sh --out /mnt/d/iso/sunmoon-prod-seed.iso --pubkey ~/.ssh/id_rsa.pub
ls -l /mnt/d/iso/
```

要看到：`iso verify exit=0`（`…: OK`）；生成应答 ISO 时会要一个**控制台口令**（只在 Hyper-V 控制台登录用，SSH 走钥匙；你随机生成一个，告诉所有者，不进回执）；最后 `ls` 里有系统 ISO 和 `sunmoon-prod-seed.iso`。把系统 ISO 的文件名写进回执（第二节所有者要用）。

## 二、Windows 侧：建虚拟机（**所有者**，管理员 PowerShell）

luna 把下面这段连同 ISO 文件名交给所有者；所有者右键「以管理员身份运行」PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd \\wsl.localhost\Ubuntu\home\zymun\worktrees\fable\sunmoonun\infrastructure\environments\prod\vm
.\New-SunmoonProdVm.ps1 -IsoPath D:\iso\<系统ISO文件名> -SeedIso D:\iso\sunmoon-prod-seed.iso
```

（WSL 发行版名字不叫 `Ubuntu` 就按 `wsl -l` 里的名字改路径；`Set-ExecutionPolicy -Scope Process` 只对这一个窗口生效，不是关闭策略。）脚本会建内部交换机 `sunmoon-prod`、NAT、虚拟机，然后开机。所有者再做三下：

1. 打开 Hyper-V 管理器 → 连接 `sunmoon-prod` 控制台 → 安装器问「Continue with autoinstall?」输 `yes` 回车。之后全自动，装完虚拟机**自己关机**（十来分钟）。
2. 关机后在同一个 PowerShell 窗口跑：`Get-VMDvdDrive -VMName sunmoon-prod | Remove-VMDvdDrive; Start-VM sunmoon-prod`
3. 告诉 luna「起来了」。

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
