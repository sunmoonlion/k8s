# Harbor冷备份与隔离恢复

本手册对应现有`recovery.yaml`和`prepare-recovery.py`，属于[仓库维护](README.md)。入口接受明确的既有同版本冷备，恢复到全新的隔离演练目录。新的备份创建、轮换、机器外保存和原地灾难恢复尚未形成统一自动入口。

## 必须备齐的内容

冷备形成于全部Harbor服务停止且写入暂停时，同时覆盖配置根`registry_config_dir`、官方运行根`registry_runtime_dir`、实例`data/`。当前分别是`/etc/sunmoon/registry`、`/opt/sunmoon/registry`、`/data/harbor/platform-kind-v1/data`。包含数据库、registry层、加密密钥、账号、证书、生成配置和运行工具；只复制镜像层不可恢复账户和加密数据。

记录备份文件完整SHA256、版本/官方包锁、文件集合/长度/权限/属主及备份时间。配置里改根路径须与备份结构一致。同盘副本不是硬件灾备，机器外落点待定。跨版本schema升级必须单独做备份和官方兼容性确认。

## 参数与预检

`BACKUP`为实际完整绝对`.tar`路径，`BACKUP_SHA256`为可信备份清单的64位摘要；不能现场为未知文件算摘要后就把它当可信来源。示例中的占位需替换：

```sh
make -C infrastructure registry-recovery-plan \
  BACKUP=/absolute/path/verified-cold-backup.tar \
  BACKUP_SHA256=REPLACE_WITH_TRUSTED_64_CHARACTER_SHA256
```

plan核对service-visible挂载和完整备份字节，显示隔离目标；不解包/启动。backup摘要、格式/来源、挂载或端口条件不符时停止。演练check按备份大小两倍加512MiB估计峰值，并核实际文件系统余量。

## 实际恢复演练

确认Harbor健康、物料工具/镜像已在本机，loopback12443空闲且空间可容纳副本；在同一参数下执行：

```sh
make -C infrastructure registry-recovery-check \
  BACKUP=/absolute/path/verified-cold-backup.tar \
  BACKUP_SHA256=REPLACE_WITH_TRUSTED_64_CHARACTER_SHA256
```

此操作解包、建立隔离网络/Compose项目、启动恢复服务并完整拉镜像，有写入和空间占用；不切30443、不原地覆盖正式数据。

1. 拒绝重复/绝对越界/父路径穿越/链接/特殊文件；完整解出普通文件并核对长度、SHA、属主、权限，保存`restored-files.json`。
2. 保存完整registry文件集/摘要`registry-before.json`；官方Compose原生渲染副本，所有bind改到副本，镜像须在官方包锁内，restart=no。
3. 独立项目只公开`127.0.0.1:12443`；后端网络internal，proxy单独access网络。core external endpoint及实际`WWW-Authenticate` realm须指向演练端口，防止借正式仓库认证。
4. 检查全部恢复组件健康、原admin身份与固定私有HAProxy摘要；使用恢复puller完整拉回，独立校验所有manifest/config/blob。
5. 再比对完整registry文件集/摘要。演练成功与失败均停止本次项目；成功另核正式Harbor仍健康，保存`verified.json`。

## 结果、失败和退出

运行目录是`registry_instance_dir/recovery/rehearsal-<本次标记>`。停止的容器、证据与演练副本保留，不能自动删除冷备或正式数据。已有日期结果见[验收边界](../../docs/platform-kind-v1/verification.md#仓库与扫描)；历史硬编码备份路径不作为下一次输入。

如果Ansible被强杀，always不保证执行。先根据本次`prepared.json`中的精确project、compose和工具路径核对隔离身份，再用该Compose项目`stop --timeout 60`，确认没有本次运行容器；禁止`down -v`或按全局容器名清理。此例外是隔离演练退出，不扩展成清理正式资源授权。

停止成功不等于回收空间。需要清理演练时，先列清本次项目/副本与备份关系，逐项核验获批后执行。失败时保留证据，不能把部分拉回/目录存在/摘要对上写成完整恢复。

## 仍需单独验收

实际WSL/KIND重启、KIND删除重建后Harbor完整文件和镜像摘要、所有新节点真实拉取；全仓业务镜像覆盖；业务数据库/对象存储恢复；机器外备份；云端。当前隔离演练不能代替这些项目。
