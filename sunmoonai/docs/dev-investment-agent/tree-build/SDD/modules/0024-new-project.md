# 新建项目：在电脑上建好文件夹、拉取 git 仓库（0024）

> 状态：所有者 2026-10-14 定（「直接做代理建文件夹」「按你的建议做，ssh 以后再说」「令牌可以用已有的，没有应该弹框让用户填」），远程写设计并实施代理、后端、网页三处；Windows 真机由所有者机器上的 Qwen / Cursor 验。接 0017 §三（新建、拉取仓库）、0022（回环口、服务流）。

## 一、为什么

10-14 现网：所有者新建项目「财务预测」，路径 `C:\Users\zymun\Desktop\myproject`。工作台只把名字和路径记进账（`project_service.create` 只核路径在白名单里），电脑上没有这个文件夹。之后让工作对话写 `hello.txt`，代理反复报「Windows 工作目录不存在」；模型换别的目录起命令，被白名单挡住，就请求提权；审批选了「停下」，什么都没做成。日志证明的是**目录不存在**，不是需要管理员权限。

## 二、决定

| 项 | 定了什么 |
| --- | --- |
| 新建的三种来源 | ① 在电脑上建文件夹（已存在的空文件夹或已有项目文件夹也行，就是「用这个文件夹」）；② 拉取 git 仓库；③ ssh 到远程 —— **以后做**，见第七节 |
| 谁去碰电脑 | 本地代理。网页（在装着代理的那台电脑上打开）经回环口直接请代理做，与 0022 乙案同一个口、同一张本机访问票。工作台不经手文件，也不经手 git 令牌 |
| 先建后记 | 代理建好或拉好、确认是文件夹，网页才去工作台登记项目。工作台登记前再经服务流 `fs/getMetadata` 核一次：明确不在 → 不登记，回 `project_directory_missing`；问不到（代理离线、没配通道）→ 照登记（老路，代理新版装上前不至于建不了项目） |
| 别的设备上开网页 | 探不到本机代理时，对话框说「要在装着代理的那台电脑上新建」，不提供新建（老的「只登记」入口撤掉，免得再登记出不存在的目录） |
| 写在哪 | 只能在**工作区**（`roots`）下，不能在本地知识库目录、代理配置目录、`codex-home` 下；目标路径按现有 `canonicalPath` 与 helper 的身份检查（符号链接、junction、8.3 短名、设备名、ADS 一律拒） |
| 本地上限 | 本机设置的沙箱是「只读」时两种都拒（`local_read_only`），提示去「这台电脑上的设置」改。**联网开关不管 clone**：那个开关管的是 Codex 在沙箱里起的进程；clone 是用户当面点的、代理自己跑的 git，默认联网关着也要能拉 |
| git 凭据 | 先用电脑上已有的（git 凭据管理器、ssh key）。没有、或已有的不对 → 代理回 `auth_required`，网页弹框请用户填用户名（可空）和令牌；令牌经回环口交给代理用这一次，**不进工作台、不进日志、不进命令行参数**；勾「记住」才交给电脑上的 git 凭据管理器存（`git credential approve`）。ssh 地址认证失败不弹令牌框（令牌对 ssh 没用），说「用 ssh 地址要先在电脑上配好 ssh key，或改用 https 地址」 |
| 拉取多久 | 一次请求同步等，上限 15 分钟；网页显示「正在拉取…」与「取消」；取消或超时代理杀掉 git，删掉这次新建出来的那个文件夹（只删本次确认原本不存在的那一个） |

## 三、回环口新接口（浏览器 → 代理）

门与 0022 第三节相同：`Origin` 必须等于 `web_origin`、要票、同秒 > 20 次 429。`/local/v1/info` 的 `capabilities` 多一项 `local-project-v1`，网页据此判断代理是不是新版。

| 方法与路径 | 请求体（JSON） | 回 | 规矩 |
| --- | --- | --- | --- |
| `POST /local/v1/projects/folder` | `{ path }` | `{ path, created: true\|false }` | 逐级建（`recursive`）；已存在且是文件夹回 `created:false`；已存在但是文件 409 `not_a_directory`；工作区外 403 `outside_whitelist`；只读 403 `local_read_only` |
| `POST /local/v1/projects/clone` | `{ url, path, auth?: { username?, token, remember? } }` | `{ path, branch }` | `path` 必须不存在或是空文件夹，否则 409 `target_not_empty`；`url` 只认 `https://…`、`ssh://…`、`user@host:path` 三种，带用户名密码的 https 地址拒（400 `invalid_url`，请用令牌框）；认证失败 401 `auth_required`（https）/ 401 `ssh_auth_failed`（ssh）；找不到仓库 404 `repo_not_found`；主机密钥没认过 409 `host_key_unknown`；电脑上没装 git 503 `git_missing`；超时 504 `clone_timeout`；别的 502 `clone_failed`（不回 git 的原文，原文里可能有地址与用户名） |

预检 `OPTIONS` 照旧回 `GET, POST, PUT`。请求体上限 64 KiB（同设置）。

### 3.1 建文件夹怎么做

- Windows：另起一个**可写**的 helper（同 0022 读文件用的那个 helper 程序，`writable = 沙箱上限不是只读`，`roots` 只给工作区、不含知识库目录），调它现有的 `fs/createDirectory`（`recursive: true`）——与 Codex 改文件同一条已审过的路：目录钉住、身份检查、操作系统沙箱兜底。建完用 `service/getMetadata` 确认是文件夹。
- Linux（单测与以后的 Linux 代理）：逐级 `mkdir`，每一级 `lstat` 不许是链接，`realpath` 必须等于自身。

### 3.2 拉取怎么做

- 代理直接起 `git`（`PATH` 里的；Windows 上是 Git for Windows），**不经 shell**，参数写死：
  `git -c protocol.allow=never -c protocol.https.allow=always -c protocol.ssh.allow=always [-c credential.helper= -c credential.helper=<一次性>] clone --no-recurse-submodules -- <url> <path>`
  只放行 https 与 ssh 两种传输（挡 `file://`、`ext::` 之类能跑本机命令的）；不拉子模块；`--` 之后才是地址，挡以 `-` 开头的参数注入。
- 环境：`GIT_TERMINAL_PROMPT=0`、`GCM_INTERACTIVE=never`（不弹 git 自己的窗、不卡住等输入）；ssh 加 `-o BatchMode=yes`（只在用户没配 `GIT_SSH_COMMAND` / `core.sshCommand` 时）。
- 用户填了令牌：先清空已配的凭据助手，再挂一个只回这一对用户名、令牌的一次性助手；令牌放在 git 子进程的环境变量里，不进参数、不进日志。用户名空时按主机给默认（GitHub `x-access-token`，其余 `oauth2`）。成功且勾了「记住」：把 `protocol/host/username/password` 经 stdin 交给 `git credential approve`，由用户自己配的凭据管理器存。
- 失败分类只看 git 的退出码与 stderr 里的固定英文片段（`Authentication failed`、`could not read Username`、`terminal prompts disabled`、`Permission denied (publickey)`、`Host key verification failed`、`Repository not found` / `not found`），stderr 原文不回网页、不进日志。
- 不在 Codex 沙箱里跑：git 要用用户的凭据管理器和 ssh key，沙箱身份拿不到；它只按用户当面给的地址拉到用户选的新文件夹，等于用户自己敲了一条 `git clone`。clone 不跑仓库里带来的钩子（git 本来就不跑）。

## 四、后端

| 改什么 | 说明 |
| --- | --- |
| `ProjectService.create` | 登记前经服务流 `fs/getMetadata` 核目录：`dir` → 登记；明确不在或不是文件夹 → `ProjectDirectoryMissing`（409，`project_directory_missing`），不登记；问不到 → 照登记并记一条 warning 日志 |
| 建项目接口 | 多一个可选的 `origin`（`folder` / `git`），只记不判；git 的地址不记（可能带私有主机名，用户需要时看仓库自己的 `.git/config`） |

## 五、网页

新建项目对话框（`features/projects/ui/new-project-dialog.tsx`）：

```text
[电脑]（只有一台就跳过） → [工作区] → 两个标签：[新建文件夹] [拉取仓库]
  新建文件夹：子目录 + 名字（照旧）              → 按「新建」：代理建 → 工作台登记
  拉取仓库：  仓库地址 + 子目录（默认取仓库名）+ 名字 → 按「拉取」：代理 clone → 工作台登记
    401 auth_required → 弹「这个仓库要登录」：用户名（可空）、令牌、[ ] 记住在这台电脑上 → 再拉
```

- 先探本机代理（`connectLocalAgent`，0022）：探不到 → 「要在装着代理的那台电脑上新建」；探到的代理不是这台机器（`userId` 对不上，或所选电脑不是它）→ 同样说明；代理是旧版（`capabilities` 没有 `local-project-v1`）→ 「电脑上的代理要更新到 0.4.1 才能新建项目」。
- 令牌只在内存里、只发往 `127.0.0.1`；对话框关掉即清。
- 错误码各有一句人话（第三节的码 + `project_directory_missing`）。

## 六、要验的

| 项 | 在哪验 |
| --- | --- |
| 代理：两个接口的门、白名单、只读拒、目标非空拒、URL 校验、认证失败分类、取消后删目录 | 远程 Linux 单测（假 git 脚本 + 本地裸仓库） |
| Windows：建文件夹走可写 helper、`C:\Users\…\Desktop\新项目` 建成；拉公开仓库；拉私有仓库先 `auth_required`、填令牌成功、勾记住后第二次不再问 | 所有者机器（Qwen），代理 0.4.1 |
| 后端：目录明确不在不登记；问不到照登记 | 远程单测 |
| 网页：两个标签、令牌弹框、代理不在 / 旧版的说明 | 远程组件测试；真机由所有者 |
| 端到端：新建项目后工作对话写 `hello.txt` 一次成功 | 所有者 |

## 七、以后：ssh 到远程

所有者 2026-10-14 定以后再说。要做时走「远程机也装代理」：远程服务器当作另一台电脑，装代理、配对，在它的工作区里新建项目，命令就在远程跑；安全模型不变（远程机自己守白名单与沙箱）。要补的：Linux 代理的安装、自启（systemd）与沙箱；无浏览器配对；放开「一个账号同一时刻一台电脑」（账 91 甲）与会合点身份模型；右边栏「文件」「工作底稿」在浏览器不在那台机器时另开读文件的路。「本地代理经 ssh 转发每条命令」不走：本地沙箱与白名单管不到远程，安全模型要重写。

## 八、卡

| 段 | 谁 | 做什么 |
| --- | --- | --- |
| 1 | 远程 | 代理两个接口（runtime，0.4.1）+ 后端核目录 + 网页对话框；单测、组件测试 |
| 2 | 所有者机器（Qwen） | 代理 0.4.1 装到 Windows，按第六节 Windows 那行真机验，回执 |
| 3 | Cursor | 后端、网页发布（代理新版装好后再发网页，否则对话框说「要更新代理」） |

| 段 | 状态 |
| --- | --- |
| 1 | 2026-10-14 远程做完：代理 runtime `f09ec89`（0.4.1，Linux 323 过）；后端 `260c3d9`（全量 1004 过）；网页 `9337a29`（263 过、`next build` 过）；父仓 `dad0041` |
| 2 | 2026-10-14 Qwen 回执 runtime `778d857`（`scripts/results/windows-agent-0.4.1-projects.20261014-155506.md`），远程审读：**Windows 项目探针 12 项全过**（中文多层、保留大小写、已有不重建、根可作项目、工作区外与知识库拒、文件挡路 409、junction 拒、只读拒、公开 clone、非空拒、file 传输拒、超时清理）；运行依赖逐文件对 0.4.0 发行清单核过。**Windows 全量单测未跑**（执行者在复制未完时启动依赖安装，顺序错误，非代码问题；按卡停下未重试，处理正确）——要补跑卡第四节，过了才发卡 48。私有仓库可选未验。探针直接构造 `LocalProjects`，未经常驻进程里 `cli.ts` 的接线（可写助手），这一段由卡 48 真人验收第 1 条覆盖 |
| 3 | 卡 48（先代理后应用），等段 2 回执审过、卡 47 上线后执行 |
