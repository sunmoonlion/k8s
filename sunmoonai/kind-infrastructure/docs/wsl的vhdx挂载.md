# WSL VHDX 挂载说明（Kind + Docker + PV）

> **默认已不再需要本文档**：`deploy-kind.conf` 中 `KIND_PV_STORAGE_MODE=native` 时，PV 落在 WSL 发行版根分区上的普通目录，无须 E 盘独立 VHD。仅当你仍使用独立数据盘时，继续按下文配置 `KIND_PV_STORAGE_MODE=vhd` 与 `attach-vhds.ps1` / `/etc/fstab`。

本文档用于在 Windows + WSL2 环境下，稳定挂载两块 VHD：

- Docker 数据盘：`E:\wsl-disks\docker-data.vhd` -> `/mnt/docker-ext4`
- Kind PV 数据盘：`E:\kind-local-storage\pv-kind-local-storage.vhdx` -> `/mnt/pv-kind-ext4`
- Kind 持久化目录（bind）：`/data/kind-local-storage`

---

## 1. 目标与判定标准

成功标准（必须同时满足）：

1. `check-storage-mounts.sh` 返回 `0`
2. `/mnt/pv-kind-ext4` 与 `/data/kind-local-storage` 是同一设备
3. `/`（WSL 系统盘）不是 docker/pv/bind 的来源设备

快速检查命令：

```bash
/mnt/c/Users/zymun/Desktop/k8s/sunmoonai/kind-infrastructure/deploy-kind/check-storage-mounts.sh; echo $?
findmnt /
findmnt /mnt/docker-ext4
findmnt /mnt/pv-kind-ext4
findmnt /data/kind-local-storage
```

---

## 2. 前置要求

- Windows 11（或支持 `wsl --mount --vhd` 的版本）
- 以管理员权限运行 PowerShell
- WSL2 可正常使用

---

## 3. 首次准备（仅第一次）

### 3.1 创建 VHD（可跳过）

如果你已存在以下文件，可跳过：

- `E:\wsl-disks\docker-data.vhd`
- `E:\kind-local-storage\pv-kind-local-storage.vhdx`

### 3.2 在 WSL 内格式化（仅首次）

在管理员 PowerShell 先 attach：

```powershell
wsl --mount --vhd "E:\wsl-disks\docker-data.vhd" --bare
wsl --mount --vhd "E:\kind-local-storage\pv-kind-local-storage.vhdx" --bare
```

进 WSL 查设备并格式化（只对无文件系统分区执行）：

```bash
lsblk -f
sudo mkfs.ext4 -L docker-ext4 /dev/sdX1
sudo mkfs.ext4 -L kind-pv /dev/sdY1
sudo blkid /dev/sdX1
sudo blkid /dev/sdY1
```

把拿到的 UUID 记下来。

---

## 4. 配置 `/etc/fstab`

确保存在这三行（UUID 替换为实际值）：

```fstab
UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa  /mnt/docker-ext4   ext4  defaults,nofail  0  0
UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb  /mnt/pv-kind-ext4  ext4  defaults,nofail  0  0
/mnt/pv-kind-ext4  /data/kind-local-storage  none  bind,nofail  0  0
```

注意：

- bind 行不要写 `noauto`
- 否则 `mount -a` 会跳过 bind，导致 PV 目录可能落回系统盘目录层

应用并检查：

```bash
sudo mkdir -p /mnt/docker-ext4 /mnt/pv-kind-ext4 /data/kind-local-storage
sudo mount -a
findmnt /mnt/docker-ext4
findmnt /mnt/pv-kind-ext4
findmnt /data/kind-local-storage
```

---

## 5. 自动挂载（计划任务）

统一使用仓库脚本：

- `C:\Users\zymun\Desktop\k8s\sunmoonai\kind-infrastructure\deploy-kind\attach-vhds.ps1`

计划任务名：`docker-pv`

### 5.1 推荐触发器

- `AtStartup`
- `AtLogOn`（用户：`ZYMUN\\zymun`）

### 5.2 推荐设置

- `AllowStartIfOnBatteries` = True
- `DontStopIfGoingOnBatteries` = True
- `StartWhenAvailable` = True
- 最高权限运行

### 5.3 任务动作

- 程序：`powershell.exe`
- 参数：

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Users\zymun\Desktop\k8s\sunmoonai\kind-infrastructure\deploy-kind\attach-vhds.ps1"
```

---

## 6. 验证流程（推荐每次改动后执行）

```powershell
wsl --shutdown
Start-ScheduledTask -TaskName docker-pv
Start-Sleep -Seconds 35
Get-ScheduledTaskInfo -TaskName docker-pv | Select LastRunTime,LastTaskResult
```

```powershell
wsl -u zymun -e sh -lc '/mnt/c/Users/zymun/Desktop/k8s/sunmoonai/kind-infrastructure/deploy-kind/check-storage-mounts.sh; echo $?; findmnt /; findmnt /mnt/docker-ext4; findmnt /mnt/pv-kind-ext4; findmnt /data/kind-local-storage'
```

通过标准：

- `LastTaskResult = 0`
- `check-storage-mounts.sh` 返回 `0`
- `/` 与 docker/pv/bind 的设备来源不同

---

## 7. 常见问题

### 7.1 `WSL_E_USER_VHD_ALREADY_ATTACHED`

表示该 VHD 已附加，通常不是故障。
最终以 `check-storage-mounts.sh` 的返回码判断是否成功。

### 7.2 叠挂载（同一路径多个 SOURCE）

清理后重挂：

```bash
for p in /data/kind-local-storage /mnt/pv-kind-ext4 /mnt/docker-ext4; do
  while findmnt -rn "$p" >/dev/null 2>&1; do
    sudo umount "$p" 2>/dev/null || sudo umount -l "$p" 2>/dev/null || break
  done
done

sudo mount /mnt/docker-ext4
sudo mount /mnt/pv-kind-ext4
sudo mount /data/kind-local-storage
```

### 7.3 `check-storage-mounts.sh` 返回 1

优先检查：

1. `/etc/fstab` UUID 是否与 `blkid` 一致
2. bind 行是否误写 `noauto`
3. `findmnt /` 是否与 docker/pv/bind 冲突

### 7.4 终端出现 `[3] + done (...)`

如果只是想做一个“等几秒再验一下”的动作，统一改为前台有限重试，不再使用后台 job：

```bash
for i in 1 2 3; do
  "$check_script" >/dev/null 2>&1 && break
  sleep 1
done
```

最终仍以这两个结果判断：

- `check-storage-mounts.sh` 返回 `0`
- `findmnt /mnt/docker-ext4`、`findmnt /mnt/pv-kind-ext4`、`findmnt /data/kind-local-storage` 结果正确

### 7.5 `wsl: 检测到 localhost 代理配置，但未镜像到 WSL`

这是 WSL 对 Windows 代理设置的提示，常见于 `networkingMode=NAT`。它和 VHD 挂载流程本身不是一类问题。

这条提示的含义是：

- Windows 侧存在 `localhost:<port>` 代理配置
- 当前 WSL 仍是 NAT 模式
- NAT 模式下，WSL 不能直接把 Windows 的 `localhost` 代理当作自己的 `localhost` 使用

如果你的挂载检查通过，而且 WSL 内网络访问也正常，可以先忽略这条提示。

如果你想让环境更“干净”，有两种处理方向：

- 保持 NAT，不依赖 `localhost` 代理；改为在 WSL 内使用 Windows 网关地址，例如仓库里现有的 `HTTP_PROXY_WSL` / `HTTPS_PROXY_WSL` 方案
- 改成 mirrored 网络模式后再按需调整代理策略

只有当 WSL 内网络访问异常时，再单独排查代理或 `.wslconfig` 网络模式配置。

---

## 8. 与 Kind 的关系

`deploy-kind/kind-cluster.yaml` 使用：

- `hostPath: /data/kind-local-storage`

因此 bind 挂载错误会直接影响 Kind 的持久化写入位置。

---

## 9. 2026-04-17 实机结论

本仓库当前已验证流程：

- 计划任务 `docker-pv` 自动执行稳定
- `attach-vhds.ps1` 已做幂等处理与最终校验
- `check-storage-mounts.sh` 返回 `0` 可作为最终成功标准

