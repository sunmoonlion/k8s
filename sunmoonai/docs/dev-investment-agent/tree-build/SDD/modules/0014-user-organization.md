# 0014 · 普通用户放进单独的 Casdoor 组织

> 2026-10-10 远程（Fable）定稿。**本卡是落实已定的 [D21](../../decisions.md)（只设一个组织 `sunmoonai`），新部署系统把它丢了，见第二节第 7 条。**起因：所有者想给别人开账号，在 Casdoor 往 `built-in` 组织加人被拒——Casdoor 规定 built-in 里每个用户都是全局管理员。所有者决定：**账号由管理员添加**（不开注册）；**现在设计，卡 E 之后马上做**，做完再请第一批用户。待办账第 67 条由本文落地。
> 依据的 Casdoor 行为均读自 v4.12.0 源码（现网版本），出处写在各条后面。

## 一、现在的样子与问题

- 投资 / 资讯 / 知识 / 模板四个应用，每个在 Casdoor 有两个浏览器应用：`web`（用户网页）和 `admin`（管理后台），全部 `organization = built-in`；`provision.py.j2`、`prepare.yaml`、`infrastructure/applications/deploy.yaml`、`verify.yaml` 都断言 `identity_organization == 'built-in'`。
- 唯一的人是 `built-in/admin`（全局管理员）。想加普通人只能加进 built-in，加进去就是全局管理员（`object/check.go` `IsGlobalAdmin`；界面直接拒绝，要开「特权同意」才行——**不开**）。
- **管理后台的权限现在其实只靠「只有 built-in 的人能登录」撑着**：后端向 Casdoor 请求 `scope=openid profile email <app>:admin`，Casdoor 在应用没配「权限范围」时把请求的 scope 原样写进令牌（`object/token_oauth_util.go` `IsScopeValidAndExpand`：`len(application.Scopes)==0` 直接放行），后端 `auth_service._allowed_claims` 按白名单取 `scope` 就得到 `<app>:admin`。也就是说，**谁能登录 admin 应用，谁就是管理员**。

## 二、定下的设计

### 1. 新建用户组织 `sunmoonai`

由 Casdoor 组件的 GitOps 任务按 API 幂等创建（与现有 `provision.py.j2` 同一种写法：先查、不存在才建、存在则逐字段比对，不一致就停下要求显式迁移）：

| 字段 | 值 | 理由 |
| --- | --- | --- |
| `owner` / `name` | `admin` / `sunmoonai` | Casdoor 组织都挂在 `admin` 下 |
| `displayName` | `SunMoonAI` | 登录页显示 |
| `passwordType` | `bcrypt` | 与 built-in 相同（`object/init.go`） |
| `passwordOptions` | `["AtLeast8"]` | 比 built-in 的 6 位严一点；不强求字符种类，所有者要的是「好输入」 |
| `enableSoftDeletion` | `false` | 发布核对每次建一个临时成员、验完即删；软删除会让这些记录永远留着（2026-10-10 实施时改） |
| 注册 | 不开（注册开关在应用上，见下） | 所有者决定：管理员添加 |

### 2. 每个应用：`web` 挪到 `sunmoonai`，`admin` 留在 `built-in`

- `web` 应用：`organization = sunmoonai`。sunmoonai 的用户只能拿到 `organization == sunmoonai` 的应用的授权码（`object/token_oauth_util.go` `checkOAuthCodeUser` → `IsUserOfApplication`）。**更正（2026-10-10 实施时读源码）：** Casdoor 登录页按「应用所属组织」找人（`LoginPage.tsx` 提交 `organization: application.organization`），所以挪过去以后 `built-in/admin` **登不进网页端**；所有者日常改用自己的 sunmoonai 账号，admin 只用于管理后台和 Casdoor。
- `admin` 应用：保持 `organization = built-in`。sunmoonai 的人登录不了，所以拿不到 `<app>:admin`。
- 两边都保持 `enableSignUp: false`、`grantTypes: [authorization_code]`、`cert` 用现有 built-in 证书（JWKS 不变，签发者 `iss` 不变 = Casdoor 公网源）。
- 配置：各应用 `config.yaml` 保留 `identity_organization: built-in`（管理端），新增 `identity_user_organization: sunmoonai`（网页端），`identity_revision` v2→v3；`provision.py.j2` 按 surface 取组织（`CASDOOR_USER_ORGANIZATION`）；`prepare.yaml`、`deploy.yaml`、`verify.yaml` 增断言 `identity_user_organization == 'sunmoonai'`；后端 ConfigMap 新增 `WEB_CASDOOR_ORGANIZATIONS`。
- **迁移已有的 web 应用**：现在的 provision 遇到「已存在但字段不同」会停下（`explicit migration required`）。本卡加一条受控迁移：只允许 `organization` 一个字段从 `built-in` 改成 `sunmoonai`，其余字段必须已等于期望值，经 `/api/update-application` 改一次再读回比对；其它差异照旧停下。迁移幂等（已是 sunmoonai 就只核对）。

### 3. 后端加一道「令牌属于哪个组织」的检查（防配置写错）

Casdoor 的 `JWT` 格式令牌带用户对象，含 `owner`（= 用户所属组织，`object/token_jwt.go` `Claims` 内嵌 `*User`）。在模板后端（tpl → 三个应用同步）的 `_load_or_create_user` 之前加：

- `admin` 面：`claims.owner` 必须等于配置的 `identity_organization_admin`（built-in），否则 403 `organization_not_allowed`。
- `web` 面：`claims.owner` 必须在**允许组织列表**里（`WEB_CASDOOR_ORGANIZATIONS`，现在只 `sunmoonai`），否则 403 `organization_not_allowed`。做成列表只是不把单值写死，正常就这一个（D21）。
- 后端新增两个环境变量（admin 单值、web 逗号分隔列表），由 GitOps 从配置写入；缺了或为空就启动失败。
- 这样就算哪天有人把 admin 应用的组织改错，sunmoonai 的人也拿不到管理权限。

### 4. 用户在后端怎么落库：不变

后端按 `(issuer, sub)` 建本地用户（`auth_service._load_or_create_user`），`sub` 是 Casdoor 用户 ID，跨组织唯一；项目、工作台、代理绑定（`relay_user`）都挂在本地用户上。所以新用户第一次登录自动有自己的空工作区。admin 名下现有的网页端数据（试用数据）**之后从网页看不到了**；不做迁移。所有者 2026-10-10 定：试用数据没用，不迁移，**清掉**（U4）。电脑代理要用新账号重新接一次。

### 5. 加人的操作（写进运维手册，给所有者）

Casdoor 管理界面 →「用户」→ 组织选 **sunmoonai** →「添加」→ 改名称、显示名 → 设初始密码 → 打开 **「需要更新密码」**（首次登录强制改密：`controllers/auth.go` 在 `NeedUpdatePassword` 时不发凭证，先要求改密）→ 保存。把登录名与初始密码当面或另一渠道给对方，不经聊天记录。

### 6. 不变的

- Casdoor 管理界面仍在公网（待办 65，另做）；本卡不碰边缘。
- 服务身份（`service-identity`，机器对机器）不动，仍在 built-in。
- 不开注册、不开邀请码、不接第三方登录。

### 7. 只有一个用户组织；客户与团队用群组（沿用决策 D21）

这条早已定过：[decisions.md D21](../../decisions.md)（2026-09-26 所有者定）——**只设一个组织 `sunmoonai`，所有应用挂在它下面；客户单位（租户）= 该组织下的顶层群组**，不走「每个客户一个组织」（跨组织要共享应用，而 Casdoor 只允许 built-in 的应用共享，且多应用共享要在每次登录时按客户拼组织名，代价大）。旧系统就是这么部署的（组织 `sunmoonai`）。

新部署系统重写时把所有应用放进了 `built-in`，**丢了 D21**——这是本卡要纠正的偏离，不是新设计。所以本卡的用户组织就叫 **`sunmoonai`**（与 D21、旧系统一致），且只有这一个；以后来客户按 D21 建群组，不开组织。后端 web 面允许组织仍做成配置项（第 3 条），但正常只配 `sunmoonai`。

## 三、卡与验收

| 卡 | 内容 | 验收 |
| --- | --- | --- |
| **U1 GitOps**（远程写，Cursor 发布） | 组织幂等创建（各应用的 identity Job 都确保它存在，并发建失败就回读核对）；web 应用挂 sunmoonai，admin 留 built-in；只改 `organization` 一列的受控迁移（`update-application?columns=organization`）；断言；`check-browser.py` 网页端改用**临时成员**（管理员会话建一个随机名、随机密码的 sunmoonai 成员，验完必删，不打印不落盘），并验该成员拿不到管理端授权码 | 本地集群发布后 `application-check` 全绿；重复发布无变化 |
| **U2 后端**（远程写，tpl 先改再同步三应用） | 第二节第 3 条的 `owner` 检查与配置校验；单测：admin 面非 built-in 全 403、built-in 通过；web 面列表内通过、列表外与缺 `owner` 403；组织配置空、非法、管理端多值都启动失败 | 各应用全量测试、ruff、pyright（改到的文件）、lint-imports |
| **U3 所有者验收** | 照第二节第 5 条建自己的 sunmoonai 账号（强制改密）→ 用它登录投资网页成功、是空工作区 → 用它打开投资管理后台被拒 → admin 仍能进管理后台 → 用新账号**重新接电脑代理**（C2 的输码配对）→ 网页上**重新拉起云端沙箱** → 发一句对话确认能用 | 所有者走完；结果记回执 |
| **U4 清理 admin 的网页端试用数据**（Cursor，U3 通过后当天做） | 先回收 admin 名下的云端沙箱；再按 admin 的本地用户 id 在投资 / 资讯 / 知识各库列出要删的行（各表行数）与会合点里的代理记录，**清单先交远程审**；审过后在一个事务里删，删前各库做一次备份（照现有备份目录，追加不覆盖）。只删 admin 网页端名下的数据：不碰 Casdoor 里的 admin 账号、不碰管理后台的数据、不碰其它用户 | 删后再列一次为 0；admin 仍能进管理后台；所有者新账号不受影响 |

U1、U2 一起发布（同一轮）。顺序：卡 E 发行验收之后，第一批外部用户之前。
