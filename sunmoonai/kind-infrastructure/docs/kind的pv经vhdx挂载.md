# Kind PV（VHDX）与 Docker 数据盘（VHD）：安装与自动挂载参考

从零假设：**`docker-data.vhd`** 与 **`pv-kind-local-storage.vhdx`** 均未就绪。顺序：**目录 → `diskpart` → 挂盘与 `mkfs` → `fstab` → 自检 → 计划任务**。只重装一块盘时跳过对应建盘/格式化，**`blkid` / `fstab` 的 UUID 须一致**。

---

## 约定（路径）

| 项 | 值 |
|----|-----|
| Docker 数据盘（VHD） | `E:\wsl-disks\docker-data.vhd` → WSL **`/mnt/docker-ext4`** |
| Kind PV（VHDX） | `E:\kind-local-storage\pv-kind-local-storage.vhdx` |
| PV 上 ext4 | `/mnt/pv-kind-ext4` |
| Kind `hostPath`（与 `deploy-kind/kind-cluster.yaml` 的 `extraMounts` 一致） | `/data/kind-local-storage` |

**环境**：WSL2；Windows 侧命令需 **管理员** PowerShell / CMD；**`mkfs`** 前必须在 WSL 内 **`lsblk`** 核对设备名。

---

## 1. 准备目录

在资源管理器中确认 **`E:\wsl-disks`** 与 **`E:\kind-local-storage`** 均存在（没有则新建）。

---

## 2. 新建 Docker 用 VHD（仅当 `docker-data.vhd` 尚不存在时）

1. **`E:\wsl-disks\dp-docker.txt`**（勿多空行）。**`maximum=`** 单位 **MB**，GiB 换算：**×1024**（150 GiB → `153600`）。不能写 **`150g`** 后缀。下为 **150 GiB** 示例，按需改。

```
create vdisk file=E:\wsl-disks\docker-data.vhd maximum=153600 type=expandable
attach vdisk
create partition primary
detach vdisk
exit
```

2. **管理员 CMD**：

```bat
diskpart /s E:\wsl-disks\dp-docker.txt
```

---

## 3. 新建 PV 用 VHDX（仅当 `pv-kind-local-storage.vhdx` 尚不存在时）

1. 在 **`E:\kind-local-storage`** 新建 **`dp-pv.txt`**（**`maximum=`** 规则同第 2 节：仅 MB、无 `g` 后缀）。下面示例为 **约 256 GiB**（`262144` = 256×1024）：

```
create vdisk file=E:\kind-local-storage\pv-kind-local-storage.vhdx maximum=262144 type=expandable
attach vdisk
create partition primary
detach vdisk
exit
```

2. **管理员 CMD**：

```bat
diskpart /s E:\kind-local-storage\dp-pv.txt
```

---

## 4. 首次挂盘与格式化（分步做，避免 `lsblk` 认错盘）

**原则**：先只挂 **Docker**，格式化并 **`blkid`**；再挂 **PV**，再格式化并 **`blkid`**。

### 4.1 Docker：挂盘 → `mkfs` → `blkid`

**管理员 PowerShell**：

```powershell
wsl --mount --vhd "E:\wsl-disks\docker-data.vhd" --bare
```

在 **WSL** 中：

```bash
lsblk -f
```

**`lsblk -f`** 里选 **Docker 新分区**（无 **`FSTYPE`**），**`/dev/sdX1` 的 `X` 换成 `NAME` 列真实字母**，勿照抄。只做一次：

```bash
sudo mkfs.ext4 -L docker-ext4 /dev/sdX1
sudo blkid /dev/sdX1
```

记下 **Docker 分区的 UUID**。

### 4.2 PV：再挂第二块 → `mkfs` → `blkid`

**管理员 PowerShell**（**不要**先卸 Docker，直接再挂 PV）：

```powershell
wsl --mount --vhd "E:\kind-local-storage\pv-kind-local-storage.vhdx" --bare
```

在 **WSL**：

```bash
lsblk -f
```

**`lsblk -f`** 里选 **PV 分区**（**`FSTYPE` 仍空**、且非 Docker 分区）。**`/dev/sdY1` 的 `Y` 换成真实名**，勿照抄。只做一次：

```bash
sudo mkfs.ext4 -L kind-pv /dev/sdY1
sudo blkid /dev/sdY1
```

记下 **PV 的 UUID**。

---

## 5. 写入 `/etc/fstab`（Docker 一行 + PV 两行）

**`/etc/fstab` 末尾**追加三行。**`UUID=`** 分别填 **4.1、4.2 的 `blkid` 输出**（勿用下面 **`aaaa` / `bbbb` 占位**）。整盘 Docker 用 **`blkid /dev/sdX`** 的 UUID。重装过旧盘先备份并删掉旧 **`UUID` 行**。

```fstab
UUID=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa  /mnt/docker-ext4  ext4  defaults,nofail  0  2
UUID=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb  /mnt/pv-kind-ext4  ext4  defaults,nofail  0  2
/mnt/pv-kind-ext4  /data/kind-local-storage  none  bind,nofail  0  0
```

执行：

```bash
sudo mkdir -p /mnt/docker-ext4 /mnt/pv-kind-ext4 /data/kind-local-storage
sudo mount -a
df -h /mnt/docker-ext4 /mnt/pv-kind-ext4 /data/kind-local-storage
```

**校验**：**`/mnt/pv-kind-ext4`** 与 **`/data/kind-local-storage`** 的 **`df`** 容量应一致；若不一致，先 **`sudo umount /data/kind-local-storage`** → **`sudo umount /mnt/pv-kind-ext4`** → 确认 **第 4 节** 两条 **`wsl --mount` 均已执行** → 再 **`sudo mount -a`**。

---

## 6. 自检（`fstab` 生效后立刻做）

```bash
df -h /mnt/docker-ext4 /mnt/pv-kind-ext4 /data/kind-local-storage
findmnt /mnt/docker-ext4
findmnt /data/kind-local-storage
```

**`df` 里 Docker 若约 1T**：`fstab` 里 Docker **UUID 错挂成根盘**；只挂 **`docker-data.vhd`**，**`blkid`** 小盘 UUID 写回 **`fstab`**，**`sudo umount -l /mnt/docker-ext4`**（busy 且 **`fuser` 有 `kernel mount /`** 时）再 **`mount -a`**。**PV 与 bind** 两行 **`df` 容量须一致**。

---

## 7. 登录自动挂两盘（最后做：一条计划任务）

**第 4～5 步与第 6 节通过后再做。**

1. **`Win + R`** → **`taskschd.msc`** → **创建任务**（不要「基本任务」）。  
2. **常规**：名称自定；勾选 **「使用最高权限运行」**。  
3. **触发器**：**登录时**。  
4. **操作** → **启动程序**  
   - **程序或脚本**：`powershell.exe`  
   - **添加参数**（整行；发行版非默认时最后一个 `wsl` 改成 **`wsl -d <名>`**，**`wsl -l -v`** 查看）：

```text
-NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 10; wsl --mount --vhd 'E:\wsl-disks\docker-data.vhd' --bare 2>$null; wsl --mount --vhd 'E:\kind-local-storage\pv-kind-local-storage.vhdx' --bare 2>$null; wsl -u root -e sh -c 'mount -a'"
```

   - **起始于**：`C:\Windows\System32`

5. **确定**；**右键 → 运行** 测一次；WSL 再跑 **第 6 节**。

**`2>$null`**：盘已挂时忽略重复报错。**`Sleep`** 可改 12～15 秒。旧任务若只挂 Docker，**停用**，只留本条。

**仅当前会话要挂 VHD**：在 WSL 里 **`bash scripts/attach-docker-pv-vhds.sh`**（会先调 **`wsl.exe --mount`**；若报权限失败，再在 **Windows 管理员 PowerShell** 里手动执行脚本末尾打印的两行 **`wsl --mount`**）。

---

## 8. 冷启动验证（可选）

**Windows**：`wsl --shutdown`，等待约 15 秒 → 重新登录 → 再开 WSL → 再跑 **第 6 节**。无需再手敲 **`wsl --mount`**（计划任务应已执行）。

---

## 9. 创建 Kind 集群（可选；挂载稳定后再执行）

```bash
cd ~/k8s/sunmoonai/kind-infrastructure && ./kind-up.sh
```

（仓库路径按本机修改。）

---

## 附：开机 `mount -a` 提示

VHD 未 attach 时 **`mount -a`** 可能报错，一般 **登录后第 7 节任务**会再挂。**`nofail`** 可减轻；仍异常则核对 **`blkid` 与 `fstab` 的 UUID**。

---

## 约束

- **`mkfs`** 前必须 **`lsblk`** 确认分区。  
- 删 **`fstab` 行**、**`rm -rf`** 前须确认路径。
