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
| Harbor 实例及恢复输入 | `registry-platform/config/harbor-main-local.json` | 保留已有 JSON 配置和摘要核验；实例初始化后不能靠改路径冒充同一个实例 |
| TLS 分流入口 | `registry-platform/config/sni-local-*.json` | 区分候选、过渡和正式方案；正式入口仍受维护窗口门禁保护 |
| 云端节点、步骤与物料 | `infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf` 及 materials 锁文件 | 保留；实际云部署未经实机验证，闭包门禁仍关闭 |
| KIND 的版本与离线物料 | `kind-infrastructure/isolated/profile.json` / `artifacts.lock.json` | 已固定版本和 SHA；改版本要同时备齐物料并更新锁，不能只改字符串 |
| 正式 KIND 的集群名、挂载、端口 | 当前仍有 `formal/prepare.py` 迁移专用常量 | **尚未完成配置化**。后续移到正式配置，保留存储 UUID、旧节点保护和实例身份核验；不能沿用旧 `deploy-kind.conf` 重建 |

普通控制项可在配置中日常调整；身份、物料摘要和存储绑定等受控项需要相应准入流程。
修改配置不自动执行部署、不自动重建、不自动清数据。

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
