# Document Converter 配置资源与拉取身份

本地/云端共用这份部署代码，云端未经实机验证。此次只整理代码，没有部署或改变镜像、数据库版本。

## 配置保持

`deploy-document-converter-backend` 下的父级开关和各子组件 `.conf` 继续控制部署。
Secret / ConfigMap 分别保留 `document_converter_secret_*` / `document_converter_config_*`，
namespace 使用 `document_converter_bff_namespace_*`；扫描器已与这些实际键名对齐，
不会再把 `dc-secret` / `dc-config` 简单转换成不存在的变量而忽略开关。
子配置在隔离的 Shell 中读取，不覆盖父级 PROJECT_ID/NAMESPACE。
启用的组件缺脚本或配置、开关格式不合法、子脚本失败均返回失败。

Harbor 身份由仓库模块提供；旧生成器、配置、模板已经删除，人工导出改为
[统一私有导出](../../../../../registry-platform/docs/export-pull-secret.md)。不再从旧集群补读管理员口令。

## Secret / ConfigMap

两个入口仍接受 `action [project namespace environment dry_run]` 和 `--cluster`：

- deploy：核对指定目标，只渲染并应用本资源。名称固定为 document-converter-secret / document-converter-config。
- status：按 namespace/name 查询，不生成文件；API 失败或不存在返回失败。
- uninstall：按 namespace/name 删除，不依赖生成文件；只忽略 NotFound，删除是异步请求。
- generate：只生成本资源，不连接集群。

共同实现是 [config-resource.sh](../resources/config-resource.sh) 和 [render_config_resource.py](../resources/render_config_resource.py)。
各自的 generate-dc-secret.conf / generate-dc-config.conf 继续控制值、模板、输出文件和 ENABLED。
显式传入的 namespace/environment 和调用者提供的数据值优先；两个生成器改正了原来应用根目录多上一层的问题。
SENTRY_DSN 等可选遥测值保持允许为空，不自动生成或修改业务凭据。
ENABLED=false 会拒绝此次被请求的生成，避免调用者随后应用以前遗留的文件。

生成器支持 --dry-run，在读配置之前返回；实际渲染使用已准备的 Python/PyYAML，
不调用 kubectl 验证，不自动下载依赖。先解析模板再填字符串，避免引号、换行破坏 YAML；
输出为 JSON（文件仍可使用 .yaml 后缀），Secret 转为 data，0600 临时文件完整写好后原子替换。
业务配置输出目前仍位于原工作树目录，不代表所有业务凭据已迁到私有目录；不要提交生成的 Secret 文件。

实际 API 动作必须有明确 CLUSTER、KUBECONFIG、SUNMOON_KUBECTL、SUNMOON_EXPECTED_CLUSTER_UID，
沿用公共 deploy-target 绑定和写入前复核。API 请求期限10秒，两个资源入口的进程期限25秒。
server-side apply 不强制抢占字段，错误不输出可能含凭据的 API 诊断；成功提交不等于工作负载或回读已验收。

## 父级总控修复

- 当前主配置缺失/读取失败即停止，不再加载旧配置覆盖；namespace 与父级布尔开关必须合法。
- 主入口也先准入目标；去除其猜测当前连接并自动重连的主分支，禁止旧 EXIT 自动清理。
- Ingress/Middleware 按实际的直接入口调用，避免目录扫描把它们跳过。
- 部署按优先级降序，卸载同类子组件按升序；卸载类别按 ingress、middleware、ConfigMap、Secret 顺序。
- 主服务卸载使用当前模板实际的 document-converter Deployment/Service 名称；不先生成清单，不用过期生成文件确定删除对象。
- 子组件卸载失败向上传递，PVC、namespace 保留。不会清理旧 kind 节点、Docker 卷或 Harbor 数据。

此修复未覆盖所有其余资源生成器。应用、PVC、namespace、Ingress 的旧渲染内部逻辑仍待继续审阅；
不要把本页两个配置生成器的“纯本地”保证扩大到所有子脚本。父级其他直接 API 查询仍用原请求方式，
整体部署还需实机验证。

## 当前证据

本次只做 Shell 语法/ShellCheck 错误级、Python AST、模板解析、路径/覆盖清单和差异静态检查。
没有运行行为测试、资源生成、Secret 导出、API、Docker、SSH、Windows 或清理。
后续验收需覆盖开关/优先级、非默认namespace、字段冲突、子组件失败、卸载保留PVC/namespace、真实转换服务调用。
整体 main/30443 迁移仍未完成，最终本机重构临时文件和东京下载中转物料清理仍是必做收尾。
