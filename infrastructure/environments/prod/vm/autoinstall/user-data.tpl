#cloud-config
# Ubuntu 24.04 live-server 自动安装应答（SDD 0039 生产站点虚拟机）。由 make-seed-iso.sh 填空后打进 cidata ISO。
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard: {layout: us}
  refresh-installer: {update: false}
  # 装机时不装安全更新：第一台实测这一步又从 noble-updates 拉一遍内核与固件（470 KB/s 下近一小时）。
  # 补丁交给 C4 的宿主剧本（apt full-upgrade，阿里云镜像、可重跑、有记录），安装器只管装出最小系统。
  updates: none
  identity:
    hostname: __HOSTNAME__
    username: __USER__
    password: "__PASSWORD_HASH__"
  ssh:
    install-server: true
    allow-pw: false
    authorized-keys:
      - "__SSH_PUBKEY__"
  network:
    version: 2
    ethernets:
      eth0:
        # 这台虚拟机只有一张网卡，兼容 VMware 的 ens*/enp* 命名。
        match: {name: "e*"}
        set-name: eth0
        dhcp4: false
        addresses: [__VM_IP__/__PREFIX__]
        routes: [{to: default, via: __GATEWAY__}]
        nameservers: {addresses: [223.5.5.5, 119.29.29.29]}
  apt:
    primary:
      - arches: [amd64]
        uri: https://mirrors.aliyun.com/ubuntu
  storage:
    layout: {name: direct, match: {size: smallest}}
  packages: [openssh-server, curl, git, ca-certificates, python3, make]
  late-commands:
    # 第二块盘整盘做数据盘，按标签挂 /data（宿主层 host 模块按站点参数认它）
    - |
      set -e
      data=$(lsblk -dnpo NAME,SIZE,TYPE | awk '$3=="disk"' | sort -k2 -h | tail -1 | awk '{print $1}')
      root=$(findmnt -no SOURCE /target | sed -E 's/p?[0-9]+$//')
      if [ "$data" != "$root" ]; then
        mkfs.ext4 -F -L sunmoon-data "$data"
        mkdir -p /target/data
        echo 'LABEL=sunmoon-data /data ext4 defaults,nofail 0 2' >> /target/etc/fstab
      fi
    - echo '__USER__ ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/90-__USER__ && chmod 0440 /target/etc/sudoers.d/90-__USER__
    - curtin in-target --target=/target -- systemctl enable ssh
    # 网卡名固定为内核的 eth0（net.ifnames=0）：第一台实测 netplan 的 set-name 只在 udev 首次事件时改名，
    # 而 VMware 网卡驱动在 initramfs 里就已探测、按 99-default.link 命名成 ens33；根文件系统起来后 .link 不再生效，
    # wait-online 等 eth0 两分钟超时才有东西触发改名（回执 fable-c0.boot-network）。关掉可预测命名，初始事件里就是 eth0。
    - curtin in-target --target=/target -- sh -c 'sed -i -E "s/^GRUB_CMDLINE_LINUX=\"/&net.ifnames=0 biosdevname=0 /" /etc/default/grub && update-grub'
  shutdown: poweroff
