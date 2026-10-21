# luna 卡 fable-c0c：生产虚拟机首次开机网卡改名时序——固定 eth0，重启两次验收（0039 停点 C0 收尾）

> 状态：**可执行**（远程 Fable 2026-10-21 写，答你 c0 回执里的「一个未修的启动告警」）。判断：不是 netplan 配置错，是**改名发生在错误的时刻**——VMware 网卡驱动在 initramfs 里就被探测、按 udev 默认 `99-default.link` 命名成 `ens33`；根文件系统起来后 netplan 生成的 `.link`（`OriginalName=e*` → `eth0`）不会对已命名的接口重放，`.network` 只匹配 `eth0`，于是 wait-online 等两分钟超时；之后不知什么触发了一次 udev 重放才改名、网络才通。原生修法：内核参数 `net.ifnames=0 biosdevname=0`，关掉可预测命名，首次 udev 事件里它就叫 `eth0`，netplan 的 `set-name` 变成空操作，模板一个字不用改。单网卡虚拟机用这个是标准做法；多网卡时再谈。
>
> 临时就地修授权同前：`infrastructure/environments/prod/vm/` 下模板脚本与本卡命令里让步骤过不去的错可以就地改、验、续跑并推 `origin/fable`，回执里写「就地修了什么」；不改机制（不是禁用 wait-online、不是改 netplan 匹配、不是 reset-failed 糊过去）、不碰 WSL/开发集群/Jenkins/Harbor。虚拟机此时还是空系统，没有数据风险。

```text
工位 WS=fable：~/worktrees/fable/sunmoonun，分支 fable；收件箱 docs/process/switch-test/inbox/luna/
目标机：sunmoon@192.168.80.10（只它）。开始前 `vmrun -T ws list` 确认它在跑；没开让所有者开
本卡两处改动已随卡提交：模板 user-data.tpl 加 late-command（grub 参数）与 `updates: none`；账 155
```

## 一、拉取

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
git show --stat HEAD | tail -5
```

## 二、给现有虚拟机加内核参数，重启两次，每次验

```bash
ssh -o BatchMode=yes sunmoon@192.168.80.10 bash -s <<'REMOTE'
set -e
sudo cp -n /etc/default/grub /etc/default/grub.before-c0c
grep -q 'net.ifnames=0' /etc/default/grub || sudo sed -i -E 's/^GRUB_CMDLINE_LINUX="/&net.ifnames=0 biosdevname=0 /' /etc/default/grub
grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub
sudo update-grub 2>&1 | tail -3
REMOTE
echo "grub exit=$?"
```

要看到 `GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 "` 和 `done`。然后重启、验，**重复两轮**（第二轮证明无人值守开机可重复）：

```bash
for round in 1 2; do
  ssh sunmoon@192.168.80.10 'sudo systemctl reboot' 2>/dev/null; sleep 45
  for i in $(seq 1 12); do ssh -o BatchMode=yes -o ConnectTimeout=5 sunmoon@192.168.80.10 true 2>/dev/null && break; sleep 5; done
  echo "=== round $round"
  ssh -o BatchMode=yes sunmoon@192.168.80.10 bash -s <<'REMOTE'
echo "cmdline: $(cat /proc/cmdline)"
echo "wait-online: $(systemctl is-active systemd-networkd-wait-online)"
echo "failed units: $(systemctl --failed --no-legend | wc -l)"
journalctl -b -u systemd-networkd-wait-online --no-pager -o short-iso | grep -i -E 'timeout|failed' || echo "wait-online: no timeout"
journalctl -b -u systemd-networkd --no-pager | grep -i -E 'renamed|name change' || echo "rename: none"
systemd-analyze critical-chain network-online.target --no-pager | sed -n 1,4p
ip -br link | grep -v lo
ip -4 -br addr show eth0; ip route | head -1
REMOTE
done
```

通过标准（两轮都要）：`cmdline` 含 `net.ifnames=0`；`wait-online: active`；`failed units: 0`；`wait-online: no timeout`；`rename: none`；`network-online.target` 在开机后 **30 秒内**到达（critical-chain 第一行的 `@` 时间）；`eth0` 有 `192.168.80.10/24`，默认路由经 `192.168.80.2`。

## 三、把模板改动落到应答 ISO（给将来重建用）

```bash
mkdir -p ~/sunmoon-probe-runs/c0c && cd ~/sunmoon-probe-runs/c0c
bash ~/worktrees/fable/sunmoonun/infrastructure/environments/prod/vm/make-seed-iso.sh --out ~/sunmoon-probe-runs/c0c/seed.iso --pubkey ~/.ssh/id_rsa.pub --gateway 192.168.80.2
xorriso -osirrox on -indev seed.iso -extract /user-data user-data.out 2>/dev/null; python3 -c "import yaml,sys; d=yaml.safe_load(open('user-data.out')); a=d['autoinstall']; print('updates=',a.get('updates')); print('grub cmd present=', any('net.ifnames=0' in str(c) for c in a['late-commands']))"
cp seed.iso /mnt/c/iso/sunmoon-prod-seed.iso && ls -l /mnt/c/iso/sunmoon-prod-seed.iso
```

要看到 `updates= none`、`grub cmd present= True`。控制台口令沿用你私有目录里那一个（脚本问就填它），不进回执。这张新 ISO 只影响将来重建，现有虚拟机不受影响。

## 四、回执

`scripts/results/fable-c0c.<YYYYMMDD-HHMM>.md`：两轮的原始输出各一段、critical-chain 时间、就地修了什么（没有就写没有）；卡移 `done/`；`git add` 回执与卡 → commit → `git push origin fable`。不通过就停，把两轮输出放进 `inbox/fable/`。
