# 官方 Harbor 配置准备（2026-09-27）

本单元已完成：官方 Harbor 2.13.2 配置生成、原密钥/凭据映射与复核。尚未启动宿主 Harbor、恢复镜像层或切换入口。当前脚本固定本机批次；SSH 未实现，云上未经实机验证。

## 输入与执行

输入来自固定冷备份 `harbor-preserve-20260926/backup-20260926T145600Z`、同批次入口 TLS 补充文件与已核验的官方离线安装包。所有私有文件留在 `/data/harbor/candidates/harbor-2.13.2-20260927`，不入 Git。目录 root 私有，尚需为正式运行逐项审查最小访问权限。

`harbor_inputs.py` 默认 plan；check 只读；stage --apply 只向不存在的候选目录写入。已实际完成 stage，不可重复覆盖。原 core 的 16 字节 secretKey、令牌签名证书/私钥、core/jobservice 共享凭据、registry HTTP secret/htpasswd、数据库口令和入口 TLS 分别映射，不生成新身份。

`official_prepare.py --installer <固定官方 tgz>` 默认只打印，`--apply` 导入一个配置生成镜像并运行其官方 Python prepare 命令。此次执行不调用上游 install.sh（含 compose down -v），也不调用上游 prepare 外壳（包含宿主根目录挂载和 privileged）。生成器无网络、无端口、非 privileged，只挂新候选目录。官方声明的 `/harbor_make` 用 tmpfs 承接，没有匿名卷。

官方生成器会新建若干内部凭据，脚本保存生成原件后，将对应字段替换为备份值，并重新核对原输入和加密/签名材料。registry 设只读、关闭上传清理和删除。生成结果中没有内置 PostgreSQL 或 Trivy；数据库配置指向独立 PostgreSQL 17.6。

## 本次失败与恢复

第一次已导入镜像，但在创建容器前被 User 字段核对拒绝。原 Docker archive 的 User 是空串，Docker inspect 将其省略为 null；层 diff_ids 相同。修正只接受这两种默认用户表达等价，其他字段仍严格比较。

`--resume-import --apply` 仅允许尚无生成器容器、状态文件和 Compose、generated-config 为空的状态继续；重新核对安装包、私有输入、镜像配置摘要和层。它不支持重复运行已完成批次，不覆盖失败产物。

本次继续执行退出 0，生成器已停止并保留。原私有输入字节一致、内部凭据一致、43 个 Docker 卷数量不变，旧 Harbor HTTPS 健康检查为 healthy。脱敏结果见 [证据](../../scripts/results/luna-harbor-config-preparation.20260927.json)。私有日志/收据留在候选目录，禁止直接粘贴或提交。

## 仍需完成

生成的官方 Compose **不能直接 up**：包含上游默认的端口、重启策略与容器名称。下一单元须生成独立名称、限定 127.0.0.1:18443、关闭后台任务的恢复运行配置，明确外部 PG17.6 和数据目录权限，复制 registry 数据、逻辑恢复数据库并核对全目录摘要。完整恢复验收前不切换、不清理。

## 内部证书有效期

本次核对入口证书到期日为 **2027-06-22 08:51:00 UTC**，尚未过期；SunMoonAI Root CA 到期日为 **2036-05-07 07:48:53 UTC**。所有者提出将内部服务证书改为 5 年，技术上可沿用该 CA 重新签发；不能修改已签名证书的日期。

更新：2026-09-27 已沿原 CA 签发 Harbor/入口两套独立五年叶证书，到期 2031-09-27；原签发材料未变，尚未替换在线服务。实际批次、公有摘要、校验、续签及消费方法见 [证书手册](certificates.md)。旧演练配置继续保留，正式准备时再接新叶证书。不要运行会重建 CA 的 force/rotate 路径来完成单张叶证书续签；Harbor 内部令牌签名证书单独处理。
