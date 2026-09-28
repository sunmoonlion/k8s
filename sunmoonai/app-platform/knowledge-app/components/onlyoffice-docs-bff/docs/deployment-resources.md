# ONLYOFFICE 资源生成与部署

本轮修正共享部署路径的上层调用；本地和云端使用同一份代码，云端未经实机验证。
主服务、PostgreSQL、Redis、RabbitMQ 的版本没有改变，也没有执行现场部署。

## 日常配置

- 主服务配置仍在 `deploy-onlyoffice-docs/deploy-onlyoffice-docs.conf`。
- 资源列表和启用开关仍在 [`generate.conf`](../resources/custom-values/generate.conf)。
- 四个业务 Secret 仍使用各自相邻 `.conf` 的名称、目标键、namespace 和已有值，本轮未改任何凭据值。
- Harbor 拉取身份由[仓库模块](../../../../../registry-platform/docs/pull-secrets.md)负责，旧 Harbor 模板和生成列表项已删除。
- Secret 入口保留 `action [project namespace environment dry_run]`；实际集群动作需要明确 CLUSTER、kubeconfig、kubectl、UID 绑定。

## 生成范围

[`generate.sh`](../resources/custom-values/generate.sh) 无参数只生成配置中启用的非 Secret 资源，不生成 Harbor 认证或业务 Secret。
需要一个资源时，用配置中的输出文件名明确选择，`--resource` 可以重复：

```bash
bash resources/custom-values/generate.sh \
  --resource onlyoffice-docs-stripprefix-generated.yaml \
  --resource onlyoffice-docs-ingress-generated.yaml --dry-run
```

计划在加载配置前退出。去掉 `--dry-run` 才生成文件；生成器不执行 kubectl、不连接 API。
`--resource onlyoffice-jwt-secret-generated.yaml` 等 Secret 选择必须已有相应配置值。
JWT 缺失会失败，不自动生成新值；需要初始 JWT 时由凭据配置流程单独准备并保管。
显式选中的资源不存在或被禁用时失败；默认批量模式会跳过禁用项。

本地渲染依赖已准备的 Python/PyYAML，不自动联网下载安装。模板先解析为数据，再替换变量，
含引号、换行、美元号的凭据不会再次作为 YAML 或 Shell 代码解释。输出为 Kubernetes 接受的 JSON，
沿用 `.yaml` 文件名，临时文件权限 0600，完整写入后原子替换；失败不留下部分输出。
Secret 的目标键和名称按相邻配置覆盖，内容用 `data` 编码；不在日志打印凭据或包含输入片段的解析错误。

## 四个业务 Secret

JWT / PostgreSQL / RabbitMQ / Redis 共用 [`secret-entry.sh`](../secrets/secret-entry.sh)：

| 动作 | 行为 |
| --- | --- |
| deploy | 要求明确已有值，只重新生成并应用该 Secret；server-side apply 不强制覆盖字段所有权 |
| status | 按 namespace/name 查询；不生成文件，不随机生成或写入凭据；不存在或 API 失败返回失败 |
| uninstall | 按 namespace/name 删除，忽略 NotFound；不依赖工作树中是否存在生成文件；异步删除不代表删除完成 |
| generate | 仅本地生成此 Secret，不连接集群；仍要求明确已有值 |

修正原脚本上溯目录多一层的问题，并使用公共集群参数解析器。实际动作复用平台的目标准入，
不猜测当前 context；写入前再核 kubeconfig/UID。命令使用 10 秒 API 请求期限与 25 秒进程期限。
四个入口原来没有执行配置中的重启标志，本轮也未增加业务重启行为。
已有 JWT 而配置没有值时，部署会失败，不会偷偷保留旧值并宣称更新成功；查询仍可使用 status。

业务 Secret 生成文件暂仍在原工作树输出位置，但采用 0600；本轮没有把业务凭据全面迁到私有目录。
统一 Harbor Secret 部署则已不使用工作树凭据文件，两者不要混淆。生成文件不得提交 Git。

## Ingress

[Ingress 入口](../ingress/deploy-ingress/deploy-ingress.sh)只选择 Middleware 和 IngressRoute 两个资源。
先检查指定 namespace 和服务，再生成并按 Middleware、IngressRoute 顺序应用。
查询与卸载按明确资源名执行，不生成任何资源；卸载先路由后 Middleware。
两次写入不是事务：后一步失败时前一步可能已成功，脚本返回失败，不自动回滚。

服务名称、端口、namespace 和域名来自显式参数/既有配置，渲染不再遗漏服务字段。
Middleware namespace 随本次部署参数，不再固定为 app-platform-dev。
删除了模板内的历史云节点 IP 路由；统一域名继续由 ONLYOFFICE_UNIFIED_HOST 控制，TLS Secret 名称保持原配置模板。

## 本次证据与剩余工作

只进行了 Shell 语法/ShellCheck 错误级、Python AST、模板 YAML 静态解析、相对路径/变量/清单核对。
没有执行生成器、行为测试、Secret 写入、Ingress 部署或浏览器访问；不能据此认为 ONLYOFFICE 已在新集群通过。
正式验收还需指定 namespace、既有 JWT 保持、字符转义、字段冲突、失败传播、路由访问和真实文档操作。

Document Converter 旧 Harbor 生成器现已由仓库模块的 export-secret 私有导出替代，退役路径见仓库模块说明。
旧节点/卷/Harbor/备份保护不变，本机重构临时文件与东京下载中转物料仍需最终清理。
