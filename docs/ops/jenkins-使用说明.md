# Jenkins 使用说明（给所有者，从打开页面讲起）

> 地图位置：宿主层（Jenkins 控制器、宿主代理）与横切的交付链。维护者看 [README](../../infrastructure/jenkins/README.md)；设计看 [SDD 0033](../design/SDD/modules/0033-jenkins-on-host.md)。本页只讲「怎么用」，随 B 段每一步更新：2026-10-20 有只读任务 `render-check` 和完整的 `release`（第五 b 节，中间等您点批）。

## 一、它是什么、现在能干什么

Jenkins 是跑流水线的机器。我们把它装在本地机宿主上，分两半：**控制器**（容器里，管页面、任务、历史，自己不干活）和**代理**（宿主上以 zymun 身份跑的进程，真正执行命令）。两个任务：

| 任务 | 干什么 | 会改什么 |
|---|---|---|
| `render-check` | 每 10 分钟看一眼 fable 分支有没有新提交；有就对六个应用核一遍数据库迁移头、把要部署的清单重新生成一遍，和 `gitops/` 里已提交的比，差异存成一个文件给人看 | 什么都不改。不发布、不碰集群、不碰 Harbor |
| `release` | 一张发布卡从头到尾，第 8 阶段停下等您点批（第五 b 节） | 批了才动：提交、发到 Harbor、改指针、集群同步、推分支 |

页面是英文的（没装汉化插件，也不打算装），下面把会碰到的词都写出来。

## 二、打开它

1. **前提**：本机 Windows 的 hosts 文件里要有 `127.0.0.1 jenkins.dev.sunmoonai.com`（10-21 晚 C2b 改名时已加；旧名 `jenkins.sunmoonai.com` 的那行留给将来的生产站点）；重装系统或换电脑要再加（`switch-test/windows_hosts_add.ps1`）。
2. 浏览器开 **`https://jenkins.dev.sunmoonai.com:30443/`**（C2b 起开发站点全部用 `*.dev.sunmoonai.com`）。证书是平台自己的 CA 签的，和 Harbor 一样，装过 CA 的浏览器不会报警。
3. 登录：用户名 `admin`，密码是密码修改表第 13 项。
4. 只在内网能开。从公网（东京边缘）开同一个地址会报证书错误，这是对的，不是坏了。

## 三、页面长什么样

进去后左边一列菜单，中间一张任务表：

| 看到的 | 意思 |
|---|---|
| 中间表格里的 **render-check** | 唯一的任务。点名字进任务页 |
| 任务名左边的小圆球 | 上一次的结果：蓝/绿 = 成功，红 = 失败，灰 = 没跑（分支没变）或还没跑过 |
| 左边 **Build Executor Status**（有的版本叫 **Executors**） | 下面列着 **host**，这是宿主代理。它在线时能看到 `1 Idle`（一个执行器，空闲）；正在跑时显示任务名和进度条 |
| 左边 **Manage Jenkins** | 管理页。**日常不要进去改东西**，见第七节 |
| 右上 **admin** | 您自己。点开可改密码，别在这里建 API token 给别人 |

点进 **render-check** 任务页：

| 看到的 | 意思 |
|---|---|
| 左边 **Build with Parameters** | 手动跑一次（第四节） |
| 左边 **Build History** | 构建历史，一行一次，`#19` 这样的号。点号进构建页 |
| 中间 **Stage View** | 一张表：行是每次构建，列是五个阶段（同步应用仓 / 有没有新东西 / 迁移头核对 / 渲染候选 / 候选与已提交的差异），格子绿是过了、红是倒在这一步、格子的数字是耗时 |
| 左边 **Configure** | 任务配置。**别改**，任务体在仓里 `ci/render-check.groovy`，改那个文件就是改任务 |

## 四、手动跑一次

1. 任务页左边 **Build with Parameters**。
2. 三个参数：

| 参数 | 默认 | 什么时候改 |
|---|---|---|
| `BRANCH` | fable | 想核别的分支时改 |
| `APPS` | `tpl knowfeed knowbase knowbench knowlab knowmart` | 只想核一个应用就只留一个名字 |
| `FORCE` | 不勾 | 分支头没变也想跑一遍就勾上；不勾且没新提交会直接灰色 NOT_BUILT |

3. 点 **Build**。左边 Build History 里出现新的一行，先是闪烁的球（在跑），6 到 7 分钟后定下来。
4. 等的时候可以点那一行的号，再点左边 **Console Output** 看它在干什么（滚动的命令输出，就是 Ansible 的那些 TASK 行）。

命令行也能跑同一件事，由维护者在本地机 `~/worktrees/fable/sunmoonun` 下执行：`make -C infrastructure jenkins-agent-check`。它强制跑一次、等结束、把控制台存到 `infrastructure/.build/jenkins/render-check-<号>.log`，SUCCESS 或 NOT_BUILT 才退出 0。

## 五、读结果

构建页（点 Build History 里的号）：

| 看到的 | 意思 |
|---|---|
| 顶上 **Success** / **Failed** / **Not built** | 成功 / 失败 / 没跑（分支没变，灰色，是正常的，每 10 分钟会有一次） |
| 标题像 `#19 fable@4f3dc6824b` | 第 19 次，核的是 fable 分支的 4f3dc682 提交 |
| **Build Artifacts → diff.txt** | 成功时才有。点开是候选清单和已提交的 `gitops/` 之间的差异 |
| **Console Output** | 完整日志 |

**diff.txt 怎么读**：

- 空文件（0 行）= 渲染出来的和已提交的完全一样，没有待发布的变化。
- 有 `@@ … @@` 和 `+`/`-` 行 = 某个应用的声明渲染出来和已提交的不一样，`+` 是候选多出来的，`-` 是已提交有但候选没有的。这说明**有变化还没走发布**，不说明坏了。
- 有 `NEW <应用>/<文件>` 行 = 候选里有 `gitops/` 还没有的新文件。
- 10-20 晚第 19 次的 22 行就是一个例子：tpl-app 两个 ingress 候选里多了 `/api/internal` 一段，是模板改了而 tpl 的声明还没重新暂存发布。

**失败了怎么看**：构建页 **Console Output**，拉到最底，倒数几十行里有 `ERROR:` 或 Ansible 的 `fatal:` / `failed=1` 那段，就是停下的原因。Stage View 里红格子告诉您倒在哪个阶段。把构建号告诉维护者即可，日志在服务器上留着。

## 五 b、release 任务：一张发布卡从头到尾，中间等您点一下

首页中间表格里第二个任务 **release**。它就是以前 Qwen 手敲的发布卡，一段段对应：

| 阶段（Stage View 的列） | 干什么 | 停下的条件 |
|---|---|---|
| 1 核对 | 工作区干净、应用仓更新到分支头、`platform-status` | 工作区脏、集群不在 |
| 2 改钉 | 按 PIN 改 `sources.yaml`，把应用仓检到钉的提交；逐应用核数据库迁移头 | 迁移头和声明对不上，不进构建 |
| 3 构建 | 每个应用构建后端、网页、管理端三个镜像，推进 Harbor | 任一构建失败 |
| 4 暂存 | 把渲染出的清单拷进 `gitops/` 工作区，存产物 | 清单里出现密钥字样 |
| 5 计划 | 再核一次迁移头；**什么都没变就灰色结束，不发** | — |
| 6 提交 | 在代理的仓里提交 `deploy(应用): 您的 NOTE（release #号）` | — |
| 7 发布 | 把已提交的声明打成不可变的包发到 Harbor（候选） | 发布器拒绝（比如明文 Secret） |
| **8 人批** | **停下来等您**。页面上摆出说明、提交号、候选摘要、产物链接。只有 admin 能点；默认 24 小时没人点就中止。**点哪里**：任务页 Stage View 第 8 列格子上弹出的对话框，或构建页左侧多出的 **Paused for Input**，或 Console Output 底部的 `Proceed` 链接，三处任选，点 **批准发布**（Jenkins 默认叫 Proceed，流水线里改了名）。弹出框里只显示说明的**第一行**（发布号、说明、提交号、应用），完整内容（候选摘要、产物链接）在这次构建 **Console Output** 的最底下 | 您点「中止」或超时 |
| — 通知 | 到第 8 阶段时，您的 Windows 屏幕右下角会**弹一条通知并响一声**（标题「发布 #号 等你批准」，一直留在屏幕上），点「打开」直接进批准页；发布完成、失败、没批中止也各弹一条。通知只在这台电脑上，不发手机 | — |
| 9 写指针 | 把候选写进指针文件，提交 `release(kind): 晋级到 …`，打 tag `release-日期-序号` | — |
| 10 部署 | 让集群同步到新指针，等各应用就绪 | 同步失败或超时 |
| 11 检查 | 每个应用跑一遍协议检查 | 检查不过（**不自动退回**，见下） |
| 12 推送与回执 | 自动写一份回执到 `scripts/results/`，把提交、tag、回执一起推到分支 | 推不上去（分支被别人推过） |

**怎么跑**：任务页 → **Build with Parameters**：

| 参数 | 默认 | 意思 |
|---|---|---|
| `BRANCH` | fable | 分支 |
| `APPS` | tpl | 要发哪几个应用，空格分隔；空 = 六个全发 |
| `PIN` | keep | `keep` = 按已提交的 `sources.yaml` 钉（重发同一版，或只发声明变化）；`heads` = 钉到各应用在这个分支上的最新提交（发新代码） |
| `NOTE` | 空 | 一句话说明，会进提交说明、构建说明和回执；不要带引号 |
| `APPROVAL_TIMEOUT_MINUTES` | 1440 | 第 8 阶段等您多久，分钟 |

**怎么批**：构建跑到第 8 阶段会停下，Stage View 里那一列显示「Paused for Input」。进构建页，中间会有一块文字：说明、提交号、候选（repository / digest / revision）、产物链接。先点产物链接看三样：`2-sources.diff`（改了哪些钉）、`4-gitops.stat`（动了哪些文件）、`4-workload.diff`（声明到底变了什么）。没问题点 **批准发布**；有问题点 **Abort**，构建中止，集群不动。等待期间不占执行器，render-check 照常跑。

**跑完怎么确认**：构建说明写着「已发布：release-日期-序号，指针 …，回执 scripts/results/release-号.时间.md」。回执里有改钉、镜像锁、声明差异、候选与指针、部署与检查的尾部。本地仓 `git pull` 后能看到三个新提交（deploy、晋级、回执）和 tag。 回执在构建页的 Build Artifacts 里也有一份。说明末尾若写「镜像站没推上」，GitHub 上是全的，只是 Gitee 镜像没同步，维护者照 `12-push.txt` 里那行补推即可。

**没走完怎么办**（构建说明会写明是哪种）：

| 说明里写的 | 意思 | 要做什么 |
|---|---|---|
| 无差异，不发 | 这组钉已经在线上，灰色 | 不用管 |
| 第 8 阶段未获批准 | 您没批或超时，提交留在代理仓的 `abandoned/release-号` 分支，候选留在 Harbor | 不用管；要发就再跑一次 |
| 后半段停下：集群未动 | 第 9 阶段写指针失败 | 看控制台，告诉维护者 |
| 后半段停下：集群可能已是新版而 Git 还没推 | 第 10 到 12 阶段某步没过。**集群已经动了** | 让维护者看：检查没过就决定退回（指针改回上一版再 `make -C infrastructure flux-source-apply`，人做）；推送没过就手工从 `abandoned/release-号` 推 |
| 产物里出现了秘密的样子 | 日志里有像密钥的东西，已打码 | 告诉维护者查哪一段 |

## 六、常见状况

| 状况 | 看到的 | 怎么办 |
|---|---|---|
| 代理掉线 | 首页左边 host 旁边是红叉或写 `offline`；新构建一直 pending | 等一分钟（代理单元会自己重连）；还不行让维护者 `make -C infrastructure jenkins-agent-status`，再 `jenkins-agent-start` |
| 构建一直在排队 | Build History 里好几个闪烁的球 | 代理只有一个执行器，一个一个来；定时的那几次会很快灰掉。想取消某一次：构建页左边 **Abort**（或 Build History 行末的红 ×）。取消只停这一次，不伤任何东西 |
| 整个页面打不开 | 浏览器连不上 | 先确认是内网、hosts 那行在；再让维护者 `make -C infrastructure jenkins-status`，不行 `jenkins-start` |
| 登录不上 | 密码错 | 用密码表第 13 项；表改了要重新 `platform-account-import OBJECT=jenkins` 并重装控制器才生效，不在页面上改 |
| 灰色一长串 | 全是 Not built | 正常，分支没新提交 |

## 七、不要做的

- **Manage Jenkins → Plugins** 里不要装、不要升级插件。76 个插件都是物料锁里钉住的，页面上装的下次重装就没了，而且会联网。
- **Manage Jenkins → Security** 不要动：匿名读是关着的，控制器执行器是 0，都是设计。
- 不要在任务页 **Configure** 里改脚本；要改就改仓里 `ci/render-check.groovy`，下一次构建自动用新的。
- 不要在页面上建新任务、建凭据。将来的 `release` 任务也由首启脚本建。
- 看到 `diff.txt` 有差异，不要自己去点什么「发布」——现在也没有这个按钮；发布是 B3 以后的 `release` 任务，带人批。
- 构建页左侧的 **Pause/resume** 不要点：它是 Jenkins 自带的「冻结流水线」开关，构建在跑时一直在，和第 8 阶段的批准无关；点了流水线停在当前一步，部署中途点会把集群晾在半新半旧。是不是在等批，只看左侧有没有 **Paused for Input**、Stage View 第 8 列有没有弹框、Console Output 最后一行是不是 `批准发布 or Abort`。要停一次发布，在第 8 阶段点 Abort。
- **Delete Pipeline**、**Delete build** 不要点：前者删整个任务连同全部历史（每次发布的日志、产物、审批记录），后者删一次的记录，跑着的会当场中止。任务由首启脚本按“没有就建”重建（`infrastructure/jenkins/templates/03-render-check.groovy.j2`、`04-release.groovy.j2`），历史找不回；要清旧历史就在模板里配保留规则。
- **发布在跑时不往发布分支推任何提交**（文档、待办账也不行）：第 12 阶段从代理克隆直接 `git push origin HEAD:<分支>`，不先拉取；中途推一条会让它在部署之后推送被拒（2026-10-22 #14），只能再发一次补 Git。

## 八、维护者命令对照（本地机 `~/worktrees/fable/sunmoonun`）

| 要干什么 | 命令 |
|---|---|
| 控制器状态 / 启 / 停 | `make -C infrastructure jenkins-status` / `jenkins-start` / `jenkins-stop` |
| 代理状态 / 启 / 停 | `make -C infrastructure jenkins-agent-status` / `jenkins-agent-start` / `jenkins-agent-stop` |
| 强制跑一次 render-check 并等结果 | `make -C infrastructure jenkins-agent-check` |
| 跑一次 release 并等结果（人批仍在页面点） | `make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="一句话" APPROVAL_TIMEOUT_MINUTES=1440` |
| 全平台状态 | `make -C infrastructure platform-status` |
| 控制台日志 | `infrastructure/.build/jenkins/render-check-<号>.log`（不进 git） |
| 产物原件 | `/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure/.build/render-check/diff.txt` |
| 回执 | `scripts/results/fable-b1*.md`、`fable-b2*.md` |
