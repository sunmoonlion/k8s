# 应用构建、发布、部署与验收

四应用共享原生编排及[common模板](../../gitops/components/app-platform/common/README.md)，源码为并列五仓及其子模块。各应用仍分后端、Web、Admin组件；配置在[组件导航](../../gitops/components/README.md)就近维护。

## 与物料和组件目录的关系

本目录保留应用源码选择、在线构建、部署与验收；共用下载/归档/skopeo发布在[artifacts](../artifacts/README.md)。应用配置与成品镜像锁在gitops/components/app-platform/<应用>/<前后端组件>，Python/Node基础镜像只保存于物料批次shared/build-base-images，不按四应用复制。

`make -C infrastructure material-inventory MATERIAL_OWNER=components/app-platform`查看应用成品锁及Harbor目标；`MATERIAL_OWNER=shared/build-base-images`查看基础物料。普通部署从Harbor拉成品，不要求`~/k8s-packages`内有各应用离线包，npm/Python依赖仍在线下载。

## 配置与固定源

[config.yaml](config.yaml)保存构建预算、基础镜像选择和下载模式；[sources.yaml](sources.yaml)固定四应用各parent revision、backend/web/admin gitlink，拒绝dirty或未经审核来源；构建配方从固定Git对象导出到一次性context。应用config/image.lock与环境namespace、当前Flux指针职责分开。

| 选择 | 支持值/含义 |
|---|---|
| APP | tpl、info、knowledge、investment；每条应用命令显式指定 |
| COMPONENT | backend、web、admin，用于application-source-plan |
| application_download_mode | domestic或official-proxy；源与代理配套 |
| 构建预算字段 | backend/frontends各自峰值；host检查再扣VHD增长 |
| application_base_image_ids | 上游固定基础镜像；集群从Harbor取得成品 |

## 在线构建与发布

以info为例，替换APP即可覆盖4应用×3角色：

```sh
make -C infrastructure application-source-plan APP=info COMPONENT=backend
make -C infrastructure application-verify-materials
make -C infrastructure application-publish
make -C infrastructure application-build-backend APP=info
make -C infrastructure application-publish-backend APP=info
make -C infrastructure application-build-web APP=info
make -C infrastructure application-publish-web APP=info
make -C infrastructure application-build-admin APP=info
make -C infrastructure application-publish-admin APP=info
```

缺基础物料先`application-plan`、`application-materials`；verify/publish处理基础镜像，build在线取npm/pnpm、pip/uv依赖。成品发布固定manifest，构建结果与传输归档在`.build/applications/`；生成的组件image.lock记录实际来源、recipe、基底及成品身份。发布只用独立publisher，puller核目标摘要，成功后删除本次transport，不要求以后部署保留业务离线包。

构建输出必须为linux/amd64、预期非root用户和实际解释器版本；私有Harborauth以root0600临时配置提供。转换工具受限，不共享Docker socket。源码/配方/基底/网络输入计入本地构建身份，不混用其他应用结果。新增版本先审核源码与依赖锁，禁止构建任意dirty树。

## 下载失败与代理

[download-modes.json](download-modes.json)是配套端点唯一来源；domestic默认国内npm/Python直连，不继承构建HTTP代理；official-proxy配套官方npm/PyPI与HTTPS_PROXY。Python只在一次性导出context中映射受批准URL，保持uv.lock版本/hash/依赖身份，不改业务仓源码锁。

依赖下载网络失败 → 提示并自动切官方代理模式一次 → 探测现有HTTPS_PROXY到对应官方源 → 可用则唯一重试；未设置、不可达或重试仍失败时给提示并非零退出，不等待终端交互。启动代理后可重新执行同一build；若想直接官方源，在config显式选official-proxy。编译/证书/401/403/404/完整性错误不能以自动切源掩盖；第二次失败不无限重试。

Harbor始终NO_PROXY直连，源与代理是配套选择；系统/Vlinux网络工具负责提供实际代理，不让构建脚本改全局npm/pip/git/Docker设置。宿主工具依赖安装不自动使用这个应用fallback；详情见[tools](../tools/README.md)。

诊断按`.build/applications`本次两种模式日志查看最后失败步骤和DNS；日志私有，分享前脱敏。`application-rehearse-downloads`是真实依赖构建演练，会联网并消耗缓存，仅人工维护调用，不作为每次构建前置。

## 声明准备与晋级

```sh
make -C infrastructure application-deployment-plan APP=info
make -C infrastructure application-stage APP=info
```

plan校验拥有的API与固定源码schema；`application-stage`走通用组件渲染器（`OBJECT=app-platform/<应用>-app`），生成/备份账号、TLS和候选并写本应用声明，不覆盖其他APP。`platform-stage OBJECT=all`只跑一次组件 stage，不再按应用重复准备。审阅公开与加密语义、提交组件image.lock/声明，再按[Flux发布晋级](../flux/README.md#发布与显式晋级)处理固定源。真实协议检查在[verify.yaml](verify.yaml)。

**准备有副作用**：private/backup文件、身份和TLS；Knowledge provider还可通过远端RAGFlow API建立私有dataset，见[provider维护](../../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md)。未知同名/绑定冲突停止，不称stage纯只读。

## 部署与真实入口验收

```sh
make -C infrastructure application-bootstrap APP=info
make -C infrastructure application-check APP=info
make -C infrastructure application-check-public APP=info
```

bootstrap对已晋级版本串联render/validate→Flux apply→check，Jobs先建独立DB/角色→schema迁移→Redis/Rabbit/浏览器/关系身份→API/Worker/Scheduler/Web/Admin。后端database/migrator权限分离，用户名和密码见组件README，不手动提前初始化。

check除Ready/镜像/Job/真实账号权限外，还验API→Celery Worker、Scheduler限定tick、浏览器PKCE/SSR/session/跨surface拒绝/CSRF/logout。普通check连接内部候选后端，public检查走正式30443；真实浏览器UI点击、所有业务功能不由该协议模拟覆盖。入口切换按[entry维护](../entry/README.md#配置或域名切换)。

Info S3检查通过实际适配器写两个随机版本读回摘要并核权限；Knowledge启用关系时走真实Info HTTP身份→Outbox/Worker/RAG→Investment HTTPS领域检索。探针会写入随机数据并精确清理，provider失败记录和原文保留直到可安全处理，禁止整桶/整库删除。

## 恢复、代次与边界

私有目录每应用root0700，credentials/redis/rabbitmq/identity/service-identity等文件0600，独立副本按config的backup_dir保留；两份均丢失而声明已有时拒绝生成。备份口令不等于备份数据库。

不可变Job输入改动须新代次并审核schema/账号实际状态；成功Job不为清输出反复删掉重跑。数据库schema以固定源迁移head比对，源变更需要迁移/恢复评估。退回按[Flux](../flux/README.md#故障与退回)，新阶段和数据不自动清除。当前业务验收范围与未覆盖目标见[验收边界](../../docs/platform-kind-v1/verification.md#应用与业务链路)。

## 构建字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `application_base_image_ids` | 列表 | 引用上游锁的基础镜像ID；修改后准备、发布并审核重新构建。 |
| `application_build_budget_bytes` | 整数 | 单次后端构建峰值预算；须覆盖上下文、依赖、镜像层和传输。 |
| `application_frontend_build_budget_bytes` | 整数 | 单个Web/Admin构建峰值预算；host检查同时扣除数据盘未来增长。 |
| `application_download_mode` | 文本 | domestic或official-proxy，下载源和代理配套；网络失败时按上文唯一重试。 |

部署发布门禁允许组件README独立维护；仅这些说明文件不参与晋级Git对象的字节差异检查。配置、模板、锁、秘密密文及运行声明仍严格匹配；GitOps工作区须已提交，不能据此部署未批准配置。
