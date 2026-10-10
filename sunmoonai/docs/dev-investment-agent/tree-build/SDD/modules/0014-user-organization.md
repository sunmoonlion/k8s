# 0014 · 普通用户放进单独的 Casdoor 组织

> 2026-10-10 远程（Fable）定稿。起因：所有者想给别人开账号，在 Casdoor 往 `built-in` 组织加人被拒——Casdoor 规定 built-in 里每个用户都是全局管理员。所有者决定：**账号由管理员添加**（不开注册）；**现在设计，卡 E 之后马上做**，做完再请第一批用户。待办账第 67 条由本文落地。
> 依据的 Casdoor 行为均读自 v4.12.0 源码（现网版本），出处写在各条后面。

## 一、现在的样子与问题

- 投资 / 资讯 / 知识 / 模板四个应用，每个在 Casdoor 有两个浏览器应用：`web`（用户网页）和 `admin`（管理后台），全部 `organization = built-in`；`provision.py.j2`、`prepare.yaml`、`infrastructure/applications/deploy.yaml`、`verify.yaml` 都断言 `identity_organization == 'built-in'`。
- 唯一的人是 `built-in/admin`（全局管理员）。想加普通人只能加进 built-in，加进去就是全局管理员（`object/check.go` `IsGlobalAdmin`；界面直接拒绝，要开「特权同意」才行——**不开**）。
- **管理后台的权限现在其实只靠「只有 built-in 的人能登录」撑着**：后端向 Casdoor 请求 `scope=openid profile email <app>:admin`，Casdoor 在应用没配「权限范围」时把请求的 scope 原样写进令牌（`object/token_oauth_util.go` `IsScopeValidAndExpand`：`len(application.Scopes)==0` 直接放行），后端 `auth_service._allowed_claims` 按白名单取 `scope` 就得到 `<app>:admin`。也就是说，**谁能登录 admin 应用，谁就是管理员**。

## 二、定下的设计

### 1. 新建用户组织 `sunmoon`

由 Casdoor 组件的 GitOps 任务按 API 幂等创建（与现有 `provision.py.j2` 同一种写法：先查、不存在才建、存在则逐字段比对，不一致就停下要求显式迁移）：

| 字段 | 值 | 理由 |
| --- | --- | --- |
| `owner` / `name` | `admin` / `sunmoon` | Casdoor 组织都挂在 `admin` 下 |
| `displayName` | `SunMoonAI` | 登录页显示 |
| `passwordType` | `bcrypt` | 与 built-in 相同（`object/init.go`） |
| `passwordOptions` | `["AtLeast8"]` | 比 built-in 的 6 位严一点；不强求字符种类，所有者要的是「好输入」 |
| `enableSoftDeletion` | `true` | 删人可恢复 |
| 注册 | 不开（注册开关在应用上，见下） | 所有者决定：管理员添加 |

### 2. 每个应用：`web` 挪到 `sunmoon`，`admin` 留在 `built-in`

- `web` 应用：`organization = sunmoon`。sunmoon 的用户只能登录 `organization == sunmoon` 的应用（`object/check.go` `IsUserOfApplication`：`user.Owner == application.Organization`，或全局管理员，或共享应用）。全局管理员 `built-in/admin` 仍能登录任何应用，所以所有者原来的数据照常可用。
- `admin` 应用：保持 `organization = built-in`。sunmoon 的人登录不了，所以拿不到 `<app>:admin`。
- 两边都保持 `enableSignUp: false`、`grantTypes: [authorization_code]`、`cert` 用现有 built-in 证书（JWKS 不变，签发者 `iss` 不变 = Casdoor 公网源）。
- 配置：各应用 `config.yaml` 的 `identity_organization: built-in` 拆成 `identity_organization_web: sunmoon`、`identity_organization_admin: built-in`；`provision.py.j2` 的 `desired['organization']` 按 surface 取；四处 `== 'built-in'` 断言改为「admin 面 == built-in，web 面 == sunmoon，管理员账号在 built-in」。
- **迁移已有的 web 应用**：现在的 provision 遇到「已存在但字段不同」会停下（`explicit migration required`）。本卡加一条受控迁移：只允许 `organization` 一个字段从 `built-in` 改成 `sunmoon`，其余字段必须已等于期望值，经 `/api/update-application` 改一次再读回比对；其它差异照旧停下。迁移幂等（已是 sunmoon 就只核对）。

### 3. 后端加一道「令牌属于哪个组织」的检查（防配置写错）

Casdoor 的 `JWT` 格式令牌带用户对象，含 `owner`（= 用户所属组织，`object/token_jwt.go` `Claims` 内嵌 `*User`）。在模板后端（tpl → 三个应用同步）的 `_load_or_create_user` 之前加：

- `admin` 面：`claims.owner` 必须等于配置的 `identity_organization_admin`（built-in），否则 403 `organization_not_allowed`。
- `web` 面：`claims.owner` 必须在**允许组织列表**里（现在 = `[sunmoon, built-in]`；built-in 是为了让所有者用管理员看网页），否则 403。**做成列表而不是单值**，以后多一个组织只改配置（见第 7 条）。
- 后端新增两个环境变量（admin 单值、web 逗号分隔列表），由 GitOps 从配置写入；缺了或为空就启动失败。
- 这样就算哪天有人把 admin 应用的组织改错，sunmoon 的人也拿不到管理权限。

### 4. 用户在后端怎么落库：不变

后端按 `(issuer, sub)` 建本地用户（`auth_service._load_or_create_user`），`sub` 是 Casdoor 用户 ID，跨组织唯一；项目、工作台、代理绑定（`relay_user`）都挂在本地用户上。所以：新用户第一次登录自动有自己的空工作区；所有者的 admin 账号下的数据不动。**不做数据迁移**：所有者可以继续用 admin 看旧数据，日常改用自己在 sunmoon 的账号（新账号要重新接一次电脑代理）。

### 5. 加人的操作（写进运维手册，给所有者）

Casdoor 管理界面 →「用户」→ 组织选 **sunmoon** →「添加」→ 改名称、显示名 → 设初始密码 → 打开 **「需要更新密码」**（首次登录强制改密：`controllers/auth.go` 在 `NeedUpdatePassword` 时不发凭证，先要求改密）→ 保存。把登录名与初始密码当面或另一渠道给对方，不经聊天记录。

### 6. 不变的

- Casdoor 管理界面仍在公网（待办 65，另做）；本卡不碰边缘。
- 服务身份（`service-identity`，机器对机器）不动，仍在 built-in。
- 不开注册、不开邀请码、不接第三方登录。

### 7. 以后再开一个组织怎么办（2026-10-10 所有者问）

先分清 Casdoor「组织」是什么：它是**一套登录规则**（谁来管账号、密码策略、能不能接对方公司自己的统一登录），不是「一个客户 / 一个团队」。

- **客户、团队、部门**：放在 `sunmoon` 里用 Casdoor 的「群组」区分（令牌里带 `groups`），应用里要分隔数据时按群组或应用自己的工作区做。**不为每个客户开组织。**
- **真要开新组织的情况**：对方要自己管账号（自己的管理员）、要不同密码规则、或要接他们公司自己的统一登录（企业微信 / 飞书 / AD 等）。这时：
  1. 建组织 `<新组织>`（同第 1 条的写法，进 GitOps）；
  2. 把各应用的 `web` 应用设为**共享应用**（Casdoor `isShared`；`IsUserOfApplication` 对共享应用放行其它组织的用户）。共享应用给其它组织登录时的客户端写法与回调要按 Casdoor 当时版本的文档和源码核实后再定，**到时另写一页设计，不在本卡做**；
  3. 后端只需把新组织加进 web 允许列表（第 3 条），代码不改；
  4. admin 应用永远只在 built-in，不共享。
- 所以本卡要做的只有一件为以后留口子的事：**web 允许组织做成列表**（第 3 条已改）。

## 三、卡与验收

| 卡 | 内容 | 验收 |
| --- | --- | --- |
| **U1 GitOps**（Cursor） | 建 `sunmoon` 组织的幂等任务；四个应用配置拆两组织；provision 按 surface 取组织 + 只改 `organization` 一个字段的受控迁移；四处断言改写；`verify.yaml` 增加只读核对（四个 web 应用属 sunmoon、四个 admin 应用属 built-in、组织字段如上表） | 渲染与门禁测试；在本地集群发布后核对脚本全绿；重复发布无变化 |
| **U2 后端**（Cursor，tpl 先改再同步三应用） | 第二节第 3 条的 `owner` 检查与两个环境变量；单测覆盖：admin 面 sunmoon 令牌 403、built-in 令牌通过；web 面列表内两种都通过、列表外组织 403、列表配两个以上组织也正确；缺 `owner` 403 | 各应用全量测试、ruff、pyright（改到的文件）、lint-imports |
| **U3 所有者验收** | 照第二节第 5 条建自己的 sunmoon 账号（强制改密）→ 用它登录投资网页成功、是空工作区 → 用它打开投资管理后台被拒（登录页就拒或后端 403）→ admin 登录网页仍看到旧数据 | 所有者走完；结果记回执 |

U1、U2 一起发布（同一轮）。顺序：卡 E 发行验收之后，第一批外部用户之前。
