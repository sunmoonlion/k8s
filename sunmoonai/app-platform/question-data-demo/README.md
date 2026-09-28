# 问数展示服务（研究 Demo）

保留课程 integrated_agent_service 的人工展示用途：单副本 FastAPI、内存任务、课程 SQLite 演示库；重启仍可能丢进行中的任务。它不是正式应用 bundle，也未部署企业微信/其他智能体集成。本地/云端消费同一镜像与脚本，云端未经实机验证。

## 当前部署方式

`deploy.sh` 只消费已发布的镜像；旧的 docker build、kind load、本机源码目录和默认旧kind连接已移除。源码/OCI物料按[统一发布流程](../../registry-platform/README.md)准备，使用 `./sunmoon harbor prepare-image` / `harbor publish` 的计划与准入；实际发布依赖物料准备，不能用假摘要或本机同名镜像替代。

公开控制在 [deploy.conf](deploy.conf)，继续支持同名环境变量覆盖：

| 字段 | 用途 |
| --- | --- |
| QUESTION_DATA_IMAGE | 必填，`harbor.sunmoonai.com:30443/<项目>/<镜像>@sha256:<真实摘要>` |
| QUESTION_DATA_NAMESPACE | 默认app-platform-dev；必须已存在，不自动建或删namespace |
| QUESTION_DATA_HOST | 默认question.sunmoonai.com；访问域名，不默认挂本机IP的根路径 |
| QUESTION_DATA_PULL_SECRET | 默认harbor-registry-secret；使用独立仓库的消费凭据，卸载时保留 |
| DEEPSEEK_ENV_FILE | 必填私有文件绝对路径，无课程目录默认值，不在配置里放API key |
| QUESTION_DATA_WAIT_SECONDS | 默认180，允许10–3600；等待Deployment更新并可用 |

入口用法：

```bash
bash sunmoonai/app-platform/question-data-demo/deploy.sh --dry-run
bash sunmoonai/app-platform/question-data-demo/deploy.sh --help
# 实际操作前设置批准目标的 CLUSTER/KUBECONFIG/SUNMOON_KUBECTL/SUNMOON_EXPECTED_CLUSTER_UID，
# 并在上面的配置/环境中提供已发布镜像和私有文件。不要用默认context或猜测UID。
bash sunmoonai/app-platform/question-data-demo/deploy.sh --cluster KIND deploy
bash sunmoonai/app-platform/question-data-demo/deploy.sh --cluster KIND status
bash sunmoonai/app-platform/question-data-demo/deploy.sh --cluster KIND uninstall
```

以上不是批准现在对旧集群执行；当前现场迁移仍按总方案暂停。`--dry-run`先于配置/凭据读取返回。实际目标沿[统一绑定](../../operations/configuration.md#平台部署的固定目标传递)，仓库配置由REGISTRY_CONFIG_FILE及其私有凭据路径提供；云端必须提供云仓库配置。

## 私有输入与更新

DEEPSEEK_ENV_FILE须调用用户所有、绝对路径、0600/0400、非末级软链、至多64KiB。文件只作为数据解析，不source/eval，不展开变量或命令。读取DEEPSEEK_API_KEY（必填）、DEEPSEEK_BASE_URL、DEEPSEEK_DEFAULT_MODEL；允许每行KEY=value或匹配的单/双引号，不支持多行、转义插值或行尾注释。不要照用包含这些语法的旧.env，应准备符合格式的私有副本。

API key和仓库认证在Python内存构造，走kubectl标准输入，错误不回显Secret；不写生成Secret到Git工作树，不把口令塞入命令参数。部署分别用sunmoon-registry和sunmoon-question-data字段管理者，不force冲突；两份Secret回读对比。ConfigMap/业务Secret内容摘要写入Pod模板注解以触发配置更新，不记录其明文。

部署先确认固定摘要镜像存在及namespace/路由CRD，再依次提交拉取身份、业务Secret、配置、应用和路由。Deployment等待检查observedGeneration、期望/更新/Ready/Available副本及实际镜像；超时返回失败。单次API最长25秒，因此总截止点附近最多还需等待正在进行的请求结束。提交并非事务，失败可能留下部分资源，不能自动当作回退成功。

status不读取私有文件，只报告Deployment期望/就绪数量。uninstall只删除本Demo的路由、transport、Deployment/Service、业务配置和业务Secret；不会删共享拉取Secret、namespace、PVC或节点，异步删除提交后未等待全部消失。

## 访问与证据

默认访问 `https://question.sunmoonai.com:30443/`，沿用入口TLSStore的默认证书和已配置的CA信任。删除原来借用info-tls Secret及localhost/IP根路由的耦合，避免与其它应用抢根路径。不要忽略证书校验或使用curl -k代替验收。

本次只有Shell/配置语法与ShellCheck、Python AST、两份模板解析、路径/引用检查；没有运行生成/部署、行为测试、API调用、模型请求、镜像构建/发布、KIND导入或数据清理。实际镜像来源与发布、私有输入、字段冲突、配置更新/就绪、节点拉取及HTTPS业务请求仍须在准入环境验收，不能称Demo已上线。
