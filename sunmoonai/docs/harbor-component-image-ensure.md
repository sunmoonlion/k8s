# 组件部署前的独立 Harbor 镜像检查

更新：2026-09-28。本文替代原来的“部署时发现缺失即从本地或远端补推”机制。
本地 KIND 与云集群共用 `registry-platform/images.py`；云上执行未经实机验证。

## 入口和行为

在仓库根运行，默认只打印目标镜像，不联网、不读取凭据：

```bash
./sunmoon harbor images check --component postgresql
./sunmoon harbor images check --component ragflow --project app-images
```

显式加 `--apply` 才读取私有凭据并向 Harbor 发 GET 请求：

```bash
./sunmoon harbor images check --component postgresql --apply
./sunmoon harbor images check --image 'harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4' --apply
```

该动作没有 Docker load/login/push、SSH、Kubernetes 查询、目录清理或系统配置修改。
已有独立仓库必须先完成域名、CA 和使用方账号准备，见 [客户端说明](../registry-platform/docs/clients.md)。

| 结果 | 返回值与后续 |
| --- | --- |
| 全部 manifest 存在，原始响应字节 SHA256 与响应摘要一致 | 0；输出摘要、是否按 digest 查询，以及 `layers_verified=false` |
| Registry 返回可识别的 MANIFEST_UNKNOWN / NAME_UNKNOWN | 2；列出 missing，停止部署，先备齐物料 |
| 网络、TLS、认证、权限、响应结构或摘要错误 | 非零；停止部署，不把异常当成缺失，也不转远端尝试推送 |
| 清单为空、引用无明确 tag/digest、多个不同来源映射到同一目标 | 非零；先修清单 |

使用锁定 CA，校验域名，直连 `harbor.sunmoonai.com:30443`，不使用终端 HTTP(S) 代理。
只向同一个 HTTPS 仓库的 `/service/token` 发送私有账号，不跟随重定向或认证挑战中的其他域名。
每个网络请求受配置超时约束，无无限重试；失败后可修复网络再重新检查。
错误输出不含口令、令牌或服务端响应正文。

**manifest 检查不是完整拉取验收。** 它尚不递归核验多架构清单、配置与镜像层，也不验证节点或 CI 的访问路径。
tag 查询只报告当前摘要；不会自动把一个可变 tag 视为已经和发布锁匹配。
正式发布仍必须用锁定的 `repo@sha256:<64hex>`，并完成目标架构和真实拉取验收。
当前组件清单仍含 tag，不能据此宣称发布锁和实际 Helm 渲染已全部闭合。

## 日常配置

配置选择：`--config <可信配置绝对路径>`、`REGISTRY_CONFIG_FILE`，否则仅 KIND/无 CLUSTER 使用本地配置。
显式 C1/C2/C3 而未给仓库配置会拒绝，不能误选 WSL 地址。

| 字段 | 默认 / 含义 |
| --- | --- |
| `REGISTRY_IMAGE_PROJECT` | `k8s-images`；`--project` 可临时覆盖，RAGFlow 使用 `app-images` |
| `REGISTRY_COMPONENT_LIST_DIR` | 本仓 `utils/components-images`；可设为另一个绝对目录 |
| `REGISTRY_REQUEST_TIMEOUT` | 每请求 15 秒，允许 1–120 秒；也用于 client 的 `/v2/` 检查 |
| `REGISTRY_CREDENTIALS_FILE` | Git 外消费者 JSON；`--credentials-file` 可临时覆盖 |
| `REGISTRY_CA_FILE` / `REGISTRY_CA_SHA256` | 证书文件及已锁定摘要；不会自动修改系统 CA |

凭据格式和权限见 [日常配置](../operations/configuration.md)。检查用只读账号；缺文件即拒绝，
不读取旧 KIND/远端推送配置来补管理员口令。上述默认值兼容没有新增字段的既有可信仓库配置。

## 清单和映射

每个组件维护 `<component>-images.txt`，一行一个明确 tag 或 SHA256 digest；忽略空行和整行 `#` 注释。
Harbor 完整引用原样保留；上游引用通常映射为 `<仓库>/<项目>/<最后一段镜像名>:tag`，
`minio/aistor/*` 保留嵌套路径。digest 引用保留 `@sha256:`，不当 tag 解析。

新增或改清单时，核对其映射结果和真正部署的 Helm/应用镜像一致。默认计划不检查清单中所有镜像是否已在仓库。

## 部署脚本接入

共享模板提供：

```bash
ensure_component_images_in_harbor "postgresql" "" "$dry_run" || return 1
ensure_component_images_in_harbor "ragflow" "app-images" "$dry_run" || return 1
```

第三参数为 `true` 时只打印；`false` 时实际检查。旧函数名 `push_component_images_to_harbor` 为兼容转发，
**现在只检查，不补推**。调用方须明确传播非零返回，不能仅依赖 `set -e`。
16 个现有组件入口已传递此参数及失败结果。这只描述镜像检查子步骤；旧组件脚本其他步骤的 dry-run、目标核验仍须继续整理。
`SKIP_COMPONENT_IMAGE_ENSURE`、`SKIP_HARBOR_WAIT` 不再是准入开关。

Harbor 已搬出集群，检查不等待集群中的 Harbor Pod，也不缓存一次成功供后续部署冒用。
Harbor 本身和集群自举制品使用独立离线物料，不依赖尚未可用的目标 Harbor。

## 发布链尚待完成

准备和发布是部署前的显式步骤，不能靠部署时自动从未知 tar 补包。
本批删除共享模板里的自动补推、猜 tar 名、忽略登录失败和不校验 TLS 的回退。
专用 KIND 推送、`loadimage.sh` 和应用构建入口仍需统一物料锁、凭据、摘要及失败处理；不宣称它们已经具备新发布链的全部保护。
镜像不足时先停止；后续由统一显式发布入口消费已核验清单，保留原有推送能力后再退役旧工具。

当前公开入口仍是旧 KIND，正式迁移未切换。本批只做静态检查和默认计划，没有执行真实 Harbor 查询或推拉。
