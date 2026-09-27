# 宿主 Harbor 候选镜像推拉验收

目标仍为一套部署代码、两种建群方式。此步骤验证宿主仓库写入能力，候选仍只发布本机18443，不切换旧30443、不创建正式KIND、不作为生产写入晋升。

## 范围与方法

1. 要求独立盘UUID/服务可见性正确、至少20GiB余量、已完成扫描器验收、所有候选服务停止，且存在同实例完整冷备份。
2. 再核完整原目录、后台任务策略；保存本轮PG17.6逻辑备份。只在实例私有 `write-acceptance-<attempt>/` 中生成可写配置，不改变原Compose与配置。三个额外registry/registryctl/core容器使用原固定镜像和同一候选数据目录，原容器先停止保留。开启持久中断标记，普通启动拒绝绕过。
3. 仅候选开启短暂写窗口，新建私有 `migration-canary-20260927` 项目，两个一天有效的机器人：写入账号仅该项目pull/push，读取账号仅该项目pull。上传一个含纯文本文件的微小OCI镜像，按摘要读取manifest/config/layer，逐字节比较；验证匿名拉取和只读机器人推送被拒。完整原项目目录保持不变。
4. TLS严格检查原CA、域名和已验五年叶；所有请求固定到18443。验证正式token realm仍为30443后，仅在本客户端中重定向token和同仓upload Location，不改全局DNS/配置，不跟随其他主机重定向。
5. 最后禁用两个机器人、恢复API只读、停止三临时容器与整个候选实例，保留新镜像/项目、凭据私有回执与所有容器。异常保留启动阻断标记；不自动删除试验记录。

协议依据：[Distribution Registry HTTP API V2](https://distribution.github.io/distribution/spec/api/)、[Harbor2.13.2固定API定义](https://github.com/goharbor/harbor/blob/v2.13.2/api/v2.0/swagger.yaml)。凭据仅在私有文件/内存；不进入Git、命令参数或输出。

```bash
# 仓根；默认只打印；已授权的本机候选验收才加 --apply。
python3 -B sunmoonai/registry-platform/host_write_verify.py \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --backup /data/harbor/backups/host-scanner-20260927-v1 \
  --docker-credentials /home/zymun/.docker/config.json --attempt v2
```

## 边界与后续

这是仓库HTTP协议与项目机器人权限验收，不等于实际CI作业、Docker Engine推拉、正式持续可写部署或新集群上线。云端未经实机验证。独立恢复新扫描器备份仍未执行；已通过的旧布局独立恢复结果不扩展解释。

可写验收增加的镜像/元数据保留，下一份备份必须重新判断registry全目录，不能继续假定与早期归档相同或盲目复用其硬链接。清理统一放到迁移最后，不能删除容器/卷、旧节点或唯一备份。正式切换前须冻结旧写端、收最终差异并对账，不能让新旧两端同时承接业务写入。

规则核对：C-R1/R2固定原镜像和冷备份；C-I3用独立短期机器身份；C-I8失败阻断启动；C-D1业务权威仍旧入口；C-T5只本地luna提交。

## 首轮修正

v1确已上传并逐字节拉回镜像，但“向推拉账号请求pull scope就得到只拉取令牌”的假设错误，权限负例因此未通过。Harbor2.13.2 `repositoryFilter` 根据账号实际项目权限重设 Actions，不把 scope 当作账号权限缩减机制；依据[固定版本实现](https://github.com/goharbor/harbor/blob/v2.13.2/src/core/service/token/creator.go)。以后需要真正只读的凭据时必须签发只授予pull的独立机器人，不能复用CI写入账号再依赖请求scope。

首轮恢复成功：机器人ID6禁用、API只读恢复、原配置未改、三临时及全部候选服务已停止，中断标记清除；原项目数据未删除。v1验收项目与失败结果保留。修正版v2使用独立项目和两个权限不同的机器人，不覆盖v1。

## 实测结果（2026-09-27）

v2通过：镜像manifest摘要 `sha256:a32ee319d77cd79e4d3973d5514315daf5b5f563d4aa320c4b87018fe931cd2b`，config/layer/manifest合计782字节，逐字节拉回一致；匿名拉取及真正只读机器人推送被拒。完整目录对比保留全部原项目和首轮验收项目，只新增v2专用项目。机器人7/8均已禁用，API恢复只读，六个v1/v2可写验收容器及原候选全部停止，原Compose和配置摘要不变。

随后启动原只读容器，通过严格TLS按摘要重新读取这三个对象并核验SHA，证明新数据在宿主独立目录中，退出再次全停。这不是KIND重建验证。卷仍46个，旧/136共六节点继续运行；数据盘可用24359378944字节，无清理。

最终只读配置检查对Docker将CHOWN等规范化为CAP_CHOWN的行为作名称归一后比较，能力集合没有扩大。Python AST与默认计划、git diff --check通过；未执行应用测试套件。脱敏结果见[验收回执](../../scripts/results/luna-harbor-write-acceptance.20260927.json)。

注意：回执中的30443镜像引用是最终规范名称，实际验收流量全经18443；该镜像目前不在旧30443仓库。现仅协议链路通过，正式持续可写部署、Docker Engine/真实CI作业、正式入口切换及KIND重建仍待实施。
