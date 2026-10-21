#cloud-config
# Ubuntu 24.04 live-server 自动安装应答（SDD 0039 生产站点虚拟机）。由 make-seed-iso.sh 填空后打进 cidata ISO。
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard: {layout: us}
  refresh-installer: {update: false}
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
  shutdown: poweroff
