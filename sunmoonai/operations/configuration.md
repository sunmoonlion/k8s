# 日常配置入口

所有者要求：新部署继续像原来一样用配置文件做日常控制。
统一命令只负责选动作、选目标和临时覆盖；不把平台开关搬进脚本常量，
不要求每次部署都重新拼一长串参数。公开配置保留在 Git，凭据内容放在 Git 外。

## 现有控制项与新位置

| 控制内容 | 当前配置入口 | 整理后的规则 |
| --- | --- | --- |
| 平台开关、优先级、等待、Secret 准备开关 | `sunmoonai/deploy-sunmoonai-all/deploy-sunmoonai-all.conf` | 保留；本批未改现有开关值。建群仍是独立步骤，`infrastructure_enabled=false` |
| 各组件副本、资源、命名空间、参数 | 各平台和组件现有 `.conf` / values | 保留；不能让普通配置覆盖已发布 bundle 的镜像摘要等受控字段 |
| 仓库地址、客户端 IP、CA、端口、数据路径 | `sunmoonai/registry-platform/config/local-wsl.conf`；云上从 `cloud.example.conf` 复制成所有者配置 | 本地/云上共用模块；`REGISTRY_CONFIG_FILE` 或命令行 `--config` 选仓库配置 |
| 仓库使用方账号、密码 | 上述配置的 `REGISTRY_CREDENTIALS_FILE` | 只保存 JSON 私有文件的路径；账号、密码、仓库地址成套读取，不能和旧管理员密码拼接 |
| 仓库镜像检查 | 仓库 `.conf` 的 `REGISTRY_IMAGE_PROJECT`、`REGISTRY_COMPONENT_LIST_DIR`、`REGISTRY_REQUEST_TIMEOUT` | 项目默认 k8s-images，清单默认 utils/components-images；每请求默认 15 秒、允许 1–120 秒；缺失与异常阻止部署 |
| 应用构建与制品 | `app-platform/scripts/build-push-app-images.conf`、`registry-platform/config/build-publication.local.json` | 默认计划；构建生成 OCI 批次，发布单独执行；保留 App/组件/源码/缓存控制，取消按集群切换仓库别名 |
| 应用候选输入 | `./sunmoon app prepare-input` 的显式基础输入、组件制品目录和 App 源码锁 | 默认元数据计划；apply 核文件/源码/仓库后只创建新 development-input，复用原渲染与部署门禁 |
| KIND 静态卷节点 | `kind-infrastructure/formal/static-storage.json`；`SUNMOON_KIND_STORAGE_CONFIG` 可选配置 | 节点后缀统一选择 worker/worker2，集群名读取正式建群配置；PV/对象存储 Pod 共用。容量/类/卷名仍在组件模板；已绑定卷不能靠改配置迁移 |
| 显式镜像发布批次 | `registry-platform/config/publication.example.json` 的真实副本 | 同一 OCI 发布器；控制归档/摘要、工具/策略、空间、重试；模板不是已准入物料 |
| Harbor 实例及恢复输入 | `registry-platform/config/harbor-main-local.json` | 保留已有 JSON 配置和摘要核验；实例初始化后不能靠改路径冒充同一个实例 |
| TLS 分流入口 | `registry-platform/config/sni-local-*.json` | 区分候选、过渡和正式方案；正式入口仍受维护窗口门禁保护 |
| 云端节点、步骤与物料 | `infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf` 及 materials 锁文件 | 保留；实际云部署未经实机验证，闭包门禁仍关闭 |
| KIND 的版本与离线物料 | `kind-infrastructure/isolated/profile.json` / `artifacts.lock.json` | 已固定版本和 SHA；改版本要同时备齐物料并更新锁，不能只改字符串 |
| 正式 KIND 的部署参数 | `kind-infrastructure/formal/deploy-kind.json` | prepare/create/CNI/lifecycle 共读一份；端口、网段、物料路径、kubeconfig、容量门槛和等待时间可见。集群名/盘 UUID、三节点六挂载和旧节点保护仍受批准边界限制 |

普通控制项可在配置中日常调整；身份、物料摘要和存储绑定等受控项需要相应准入流程。
修改配置不自动执行部署、不自动重建、不自动清数据。

正式 KIND 默认读取 `formal/deploy-kind.json`，统一入口可用 `--config <绝对路径>` 临时选择完整 JSON；
也可设置 `SUNMOON_KIND_CONFIG`。建群保存配置快照和身份摘要；此后改变端口、网段、物料/kubeconfig 路径等
身份字段会拒绝按原节点继续操作，不能改 JSON 冒充迁移。等待时间和更严格的容量门槛可日常调整，
已有的容量安全下限不能调低。具体命令与字段见 [formal 配置说明](../kind-infrastructure/formal/README.md#日常配置)。

## 仓库凭据的选择顺序

1. 命令行临时覆盖：`harbor client login --credentials-file <绝对路径>`，
   或 `platform deploy --registry-credentials-file <绝对路径>`。
2. 调用者显式设置 `REGISTRY_CREDENTIALS_FILE`。
3. 选定仓库 `.conf` 中的默认路径。当前本地为 `~/private/registry-platform/consumer.json`，云配置示例为 `~/private/registry-platform/cloud/consumer.json`。

两个官方配置使用 `${变量:-默认值}`，保留显式覆盖。自定义配置也应按此方式书写。
`platform` 可用 `--registry-config` 选仓库配置；`harbor client` 用 `--config`。
保留原有 `login --username ... --password-file ...` 单独登录方式；显式用户名/口令文件不和 JSON 文件混用。

私有文件格式（只展示占位值，不要把真实内容提交仓库）：

```json
{
  "registry": "harbor.sunmoonai.com:30443",
  "username": "<该用途的机器人账号>",
  "password": "<该账号的令牌>"
}
```

要求绝对路径、调用者所有、0600/0400、非软链、大小不超过 64 KiB。
拉取部署用只读账号；发布用可推送账号，通过不同文件选择，不把管理员凭据默认扩散给全部组件。
当前只实现私有文件接口，**未新建账号、未复制真实口令、未声称默认文件已存在**。

`./sunmoon platform plan --cluster KIND` 和 `harbor client login` 默认计划不读取私有内容。
平台实际部署在准备 Secret 前检查凭据文件；文件缺失或格式错误会停止，不从旧建群配置偷偷补值。
现有 Secret 库仍接受调用者明确传入的旧参数作为兼容接口，但不再自行 source 总控/建群配置。
专用 JSON 序列化负责转义引号和反斜杠；生成的认证文件与 Docker Secret YAML 默认只有文件所有者可读写。

配置格式检查不代表账号可用、权限足够或新 Harbor 已接管；实际登录、节点拉取和 CI 发布另行验收。

## 收尾要求

本次重构临时目录和东京下载中转物料须在最终验收后清干净，见
[最终清理范围](../kind-infrastructure/docs/wsl-space-reclamation-plan.md#本次重构临时物料必须最终清理)。
正式配置、已提交操作文档和唯一离线物料属于交付物；历史代码/旧节点退出条件独立判定。

## 部署计划与干运行范围

总控仍使用 `./sunmoon platform plan --cluster KIND`；Data Platform 的既有位置参数计划也保留，
它们会读取本地配置列出开关/优先级，但不会执行组件。日常 `.conf` 和真实部署参数没有改格式。

所有平台的活动 Shell 部署入口（包括 Secret、Ingress、中间件）现在在加载配置、连接库、退出清理之前
通过 `utils/deploy-plan.sh` 识别计划。推荐统一使用命名参数：

```bash
bash sunmoonai/ops-platform/flower/deploy-flower/deploy-flower.sh --dry-run --cluster KIND deploy
bash sunmoonai/data-platform/postgresql/deploy-postgresql/secrets/postgresql-auth-secret/deploy-postgresql-auth-secret/deploy-postgresql-auth-secret.sh --dry-run
```

旧接口已有的位置 `dry_run=true` 继续生效，缺省仍保持原来行为，**这些旧脚本不因本次改动默认变成计划模式**。
不同脚本的 action/project/namespace 参数顺序有差异，不应把同一组位置参数直接套到所有脚本；
逐入口契约和范围见[完整覆盖说明](deployment-dry-run.md)及其 JSON 清单。
布尔值只接受 true/false；相互矛盾的命名、位置或继承参数会拒绝，不会退回实际执行。

普通组件计划仅输出请求，不加载它的 Shell `.conf`/私有凭据，不生成 Secret/values/证书，
不连接 Kubernetes、Docker、SSH、数据库，也不触发连接清理。
因此它不展示配置展开后的完整部署步骤，不代表 Helm 渲染、镜像可用或实际安装成功。
总控详细计划与正式应用的发布校验计划仍保留各自的只读本地配置解析。

Info/Knowledge/Investment 三个正式应用及角色入口共用 Python 解析器：旧格式
`deploy project namespace environment true` 与 `--dry-run` 都转到本地 `plan`。
`server-dry-run` 是另一种显式动作，会访问 API，不能等同于这里的离线计划。
新入口的 `--apply/--dry-run` 协议、身份/版本/恢复门禁继续保留，停用入口仍拒绝执行。

实际总控保留 `PREPARE_SECRETS_FROM_EXAMPLES` 开关及当前默认值；准备失败即停止。
模板复制成功不代表凭据可用。部署消费者的完整行为、凭据准入、云端实机验证仍要随迁移验收；
本批只做代码审阅与静态检查，没有执行入口、测试或部署。

镜像检查入口 `./sunmoon harbor images check --component <名称>` 支持同样的 `--config` 和 `--credentials-file`。
默认只打印；显式 C1/C2/C3 未提供仓库配置时拒绝，不隐式退回 WSL。详见 [组件镜像检查](../docs/harbor-component-image-ensure.md)。


## 平台部署的固定目标传递

实际总控部署准入使用 `utils/deploy-target.sh`：从已有 `--cluster`、`--kubeconfig`、`--kubectl`、`--expected-uid` 形成一份环境绑定，不增加另一份日常配置。现有 `k8s-admin.conf` 继续控制集群到 kubeconfig 的映射；`UNIFIED_CONFIG_FILE` 可显式指定同格式映射文件。

- kubeconfig 和 kubectl 先规范为实际绝对路径；记录 kubeconfig 内容 SHA256、集群选择和 kube-system UID。
- 总控进入子平台前、公共子脚本调用前、共享模板设置连接时重复检查映射/内容/UID；固定所选 kubectl 的 PATH 优先级。查询使用 10 秒请求期限、20 秒进程期限。
- 显式部署模式不读取/保存/删除 `.k8s-status`，不自行创建 SSH 隧道、不修改 hosts、不自动重连、不退回默认 context。异常停止；共享 EXIT 清理不介入原人工连接。
- 绑定通过 `SUNMOON_DEPLOY_BOUND_*` 传给后代；它们是单次运行状态，不是供人修改的配置。嵌套调用不能重新初始化已存在的绑定。
- 独立运行的人工连接工具仍保留其原有能力；本次没有将工具本身的旧实现宣称为已完成新版适配。

路径映射由 `utils/kubeconfig_path.py` 按数据读取，Shell 调用用 `kubeconfig-path-for-cluster.sh` 公共函数。不执行 `eval`，只允许绝对路径与 `~/`、`$HOME`、`${HOME}`；不接受多文件 KUBECONFIG。KIND 必须配置自身路径；云集群 DIRECT/BASTION 若同时存在必须指向同一路径，歧义则停止。选定段或 kubeconfig 键重复也会拒绝，不猜默认集群。

**验证边界**：本批只有 Shell/Python 静态检查和调用路径审阅，未运行真实连接、成功/失败用例或部署。绑定是共享部署调用边界的保护，不是沙箱；不能保证绕过公共入口直接运行的任意脚本或外部进程不会改变配置。实际子组件、helm、Python 子进程及云端操作仍要随迁移验收逐项核对。
