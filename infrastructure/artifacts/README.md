# 物料与发布锁

本目录的配置就是各份已存在的 `*.lock.json`：文件/镜像类型、来源、版本、摘要、归档成员和用途与files.yaml、image-archives.yaml及tasks同处。它们是发布输入，不另造一份config.yaml重复版本。

物料根唯一引用environments/kind/site.yaml的artifact_cache_root；大文件在正式物料目录，日志/备份不入源码。Make的ARTIFACTS只选择已锁物料，不改变其版本或摘要。

更新流程：选择兼容版本→准备并核验完整包/镜像→更新相应锁与声明→审查发布→原生检查及实际部署验收。不得只改tag或摘要来绕过核验，未备齐的物料不能标记offline_ready。

入口为 `make plan-artifacts`、`make fetch-artifacts`、`make check-artifacts`；节点与宿主镜像归档使用已有对应目标。删除旧物料需核对引用与既定批准范围；本目录没有自动删除策略。

`publish.yaml` 是已锁镜像的公共离线准备/发布入口，由Make明确传入模块选择、动作和容量操作标识。平台选择来自services/config.yaml，应用构建基础选择来自applications/config.yaml，共用tasks/publish-image.yaml，无第二套传输逻辑。

应用构建产物通过同一个publish.yaml读取显式publication_lockfile；客户端skopeo版本始终从上游工具锁读取，不由应用产物替换。上游默认锁不变。

应用构建镜像使用在线发布：`publication_image_directory`指向构建模块的临时transfer目录，`publication_remove_transport=true`仅允许清除此目录中已经确认发布成功的指定归档及旁边JSON。远端已有相同摘要时无需本地归档，仍以独立puller复核。上游引导物料默认不清理，不受应用传输策略影响。

## 固定 CPU 模型与平台镜像子集（2026-10-04）

模型文件使用现有 files.lock.json，`kind=model`，`models/` 只存带模型名及修订的扁平文件。`model_path` 保存官方逻辑文件路径；组件 prepare 只允许已知文件名并复制到不可变修订目录。SHA256 与字节数必须吻合；HTTPS 可续传 `.part`，未完成或摘要不符不能成为正式文件。模型文件不是镜像，也不进备份/日志目录。

`make services-{plan,materials,verify-materials,publish} SERVICE_IMAGES=comma,separated,ids` 只选择 services/config.yaml 已配置的镜像子集；默认 all。选择不启用运行组件，不跳过发布摘要和独立 puller 检查。RAGFlow 大镜像下载与小物料可分别执行；没有全部备齐时不能宣称整套离线部署完成。

`service_material_timeout_seconds` 是平台镜像单次下载限时，当前 3600 秒；其它模块默认 600 秒。公共发布器只接受 60–7200 秒，重试仍有限。超时失败与容量、TLS、摘要校验失败均保留真实失败记录，不以放宽校验换成功。
