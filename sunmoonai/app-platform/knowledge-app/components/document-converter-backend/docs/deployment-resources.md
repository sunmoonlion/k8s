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

## 其余资源与主入口（2026-09-28 续接）

应用、PVC、namespace、Ingress 的四个旧生成器也已接入同一渲染器。六个生成入口均支持 `--dry-run`，在配置之前返回；实际生成不调用 kubectl/envsubst，不读取当前 context。原相邻生成配置、模板路径和输出文件名继续使用。数字字段（副本和端口）显式转换为 JSON 数字，资源名称/路由域名/PVC 参数校验；不以静态解析冒充 API schema 验证。

### 主服务

- 主入口现在只加载参数解析、配置映射、目标绑定与资源函数库，移除旧统一连接库、SSH重连及连接清理。所有实际 API 命令使用指定 kubectl/kubeconfig，并有请求/进程超时。
- App 只渲染一次，取其中唯一 Deployment 的实际镜像调用统一 Harbor manifest 检查；返回 reference 必须相同，取得原始 manifest 的 SHA256 后将输出锁定为 repo@sha256 再提交。消除“检查一个 tag、模板用另一个镜像”的分叉，也不重新构建/发布镜像。生成配置的默认仓库补齐30443，版本/tag保持原值。
- manifest 检查不是完整镜像层拉取，不证明Pod能启动。此模板仍是组件配置生成路径，不是正式应用release bundle，也不能代替源码/镜像来源审查。
- 核心 Deployment/Service 使用 `sunmoon-document-converter` 字段管理者进行server-side apply，不force。依赖之后部署核心Service，再部署Ingress；返回成功表示请求提交成功，未等待rollout。
- status 用模板真实的资源名称及 `app=document-converter` 标签，查询失败返回失败。uninstall先路由/中间件，再核心服务和业务配置；保持PVC/namespace，且不生成文件。删除异步提交，不宣称资源已全部消失。

### PVC 与 namespace

独立入口保留 deploy/status/uninstall/generate 和原参数。status/uninstall只读取配置确定名称，不渲染；PVC名称继续从其原生成配置读取，namespace来自显式参数或相邻配置。独立uninstall会删除指定资源，namespace删除具有级联影响；它不在父级自动卸载链中。实际调用仍需显式集群/工具/kubeconfig/UID，不得用于删除受保护的旧集群资源。

主配置新增 `pvc_enabled=false`：当前App模板没有volumeMount/PVC引用，旧父脚本却会发现遗留PVC YAML就直接apply。现在只能显式开启并经原PVC组件开关批准后生成/创建，默认不创建闲置卷。`PVC_MOUNT_PATH` / `PVC_SUB_PATH` 仍是原配置里的未消费字段，未借这次修复给业务新增持久化语义；需要应用使用卷时须另明确路径、权限和多副本访问方式。

### 路由与中间件

- 两个入口现在真正分派deploy/status/uninstall/generate，查询或卸载不会意外部署。
- Ingress只按 `UNIFIED_HOST` 路由，移除旧云节点IP路线及其NODE_IP配置。原 SERVICE_NAME/PORT、USE_STRIP_PREFIX/USE_RATE_LIMIT控制保留。
- StripPrefix开时，Ingress渲染Middleware+IngressRoute；否则按原优先级引用外部rate-limit，或显式不使用中间件。部署前检查目标Service与外部Middleware存在，权限/连接错误失败，不自动捏造缺失的限流参数。
- 当前默认 `USE_STRIP_PREFIX=false, USE_RATE_LIMIT=true`，而仓库没有管理 `document-converter-rate-limit` 的实现。若启用Ingress而现场该资源不存在，将明确阻断；需选择现有外部中间件、提供限流需求后实现，或由所有者明确关闭该选项。不能静默移除保护以部署成功。
- 独立Middleware入口使用同一Ingress配置/模板，只管理StripPrefix；关闭StripPrefix时拒绝deploy/generate，不伪报部署完成。单独输出使用新增 `MIDDLEWARE_OUTPUT_FILE`，不覆盖Ingress输出。status/uninstall仍可查询/删除既有StripPrefix，不触及外部rate-limit。
- Ingress卸载管理自己的IngressRoute和StripPrefix，保留外部rate-limit。变更开关时不会顺手删除已存在的旧Middleware。

## 当前证据

本单元只做 Shell 语法/ShellCheck 错误级、Python AST、模板解析、路径/覆盖清单和差异静态检查。
没有运行行为测试、资源生成、Secret 导出、API、Docker、SSH、Windows 或清理。
后续验收需覆盖开关/优先级、非默认namespace、字段冲突、子组件失败、卸载保留PVC/namespace、真实转换服务调用。
整体 main/30443 迁移仍未完成，最终本机重构临时文件和东京下载中转物料清理仍是必做收尾。

## 接续顺序

先完成原来的全部组件部署调用链整理，再执行[持久化与空间管理收尾](../../../../../operations/persistence-and-space-acceptance.md)。新增收尾要求不会替代原修复任务；代码完成、静态检查、实机验收分别报告。当前独立Harbor/正式main迁移仍暂停。
