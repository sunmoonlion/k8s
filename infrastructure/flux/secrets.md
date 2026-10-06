# SOPS与私有身份维护

用户普通字段在模块/组件config；秘密值在私有输入，经SOPS加密后进入GitOps。用户不编辑密文替换账号，也不将密码表当部署输入。唯一加密规则是[.sops.yaml](../../gitops/.sops.yaml)。

## 主身份和独立副本

配置真源为[config.yaml](config.yaml)：`sops_config_dir`主身份与`sops_backup_dir`数据盘副本。当前私钥文件为`age.agekey`，root0600，目录0700；公共recipient在[环境sops-recipient.txt](../environments/kind/sops-recipient.txt)。公共recipient可以入Git，私钥不能入Git/日志/命令参数。

```sh
make -C infrastructure install-secrets-tools
make -C infrastructure secrets-prepare
make -C infrastructure secrets-apply
make -C infrastructure secrets-status
```

prepare只在完全新且没有加密声明的环境生成身份；已有主文件保留；主丢失则恢复独立备份。两份同时丢失且已有密文时拒绝重新生成。apply向拥有的Flux命名空间安装解密身份，有API写入；status检查实际身份匹配。

## 组件秘密如何产生

[services credentials](../services/README.md#输入与准备)与组件prepare使用主输入/备份成对校验；应用则各自private_dir/backup_dir。已有声明或远端身份存在时，不允许用新随机值“补文件”。候选加密通过独立备份身份解密校验；比较秘密语义，避免随机密文差异误报。

TLS私钥/CA、数据库/Redis/Rabbit口令、关系服务token、AIStor许可与provider绑定各有责任目录。平台全局输入不是各组件全部备份；只保age私钥也不能恢复数据库或Harbor加密密钥。

## 恢复与轮换

恢复先核目录不是链接、root属主/权限、备份字节与recipient对应关系，再走既有prepare/apply。原主与备份不一致时停止，不能自动覆盖其中任意一份。

CA、age或业务口令轮换需保留旧解密能力/数据恢复、重新加密、服务端与客户端同步、验证、更新主备；当前没有一键轮换入口。编辑一个输入文件或提高Job代次不等于完成轮换。

数据盘和系统盘同物理C盘；独立目录副本防误删而非硬件故障。机器外身份备份待定。整机/集群重建后SOPS恢复与业务持久化仍须[实际验收](../../docs/platform-kind-v1/verification.md#未完成项)。
