# 物料与发布锁

本目录的配置就是各份已存在的 `*.lock.json`：文件/镜像类型、来源、版本、摘要、归档成员和用途与files.yaml、image-archives.yaml及tasks同处。它们是发布输入，不另造一份config.yaml重复版本。

物料根唯一引用environments/kind/site.yaml的artifact_cache_root；大文件在正式物料目录，日志/备份不入源码。Make的ARTIFACTS只选择已锁物料，不改变其版本或摘要。

更新流程：选择兼容版本→准备并核验完整包/镜像→更新相应锁与声明→审查发布→原生检查及实际部署验收。不得只改tag或摘要来绕过核验，未备齐的物料不能标记offline_ready。

入口为 `make plan-artifacts`、`make fetch-artifacts`、`make check-artifacts`；节点与宿主镜像归档使用已有对应目标。删除旧物料需核对引用与既定批准范围；本目录没有自动删除策略。
