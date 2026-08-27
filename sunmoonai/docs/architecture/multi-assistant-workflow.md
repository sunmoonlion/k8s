# 多助手协作流程

> 最后更新：2026-08-27 ｜ git 机制部分已在"零凭据隔离环境"实测通过
>
> 本项目由多个 AI 助手（cursor / kimi / luna / opus / qwen3.8 …）并行工作，
> 每个助手一条分支。本文件写清楚：怎么让多个助手对同一个需求各出方案、
> 怎么比较、怎么把改动发出去和拉下来。

## 1. 两种模式，别混

| | 并行提案（**主要**） | 定向审核（次要） |
| --- | --- | --- |
| 输入 | 同一个 request | 已有产物 |
| 参与方 | N 个助手**互不可见**，各自出方案 | 一个助手查另一个的产出 |
| 产出 | N 份独立方案 | 一份审核结论 |
| 用途 | 拿到多个独立信号，再比较、综合 | 验证已有工作是否成立 |

**两种模式共用同一套 git 机制（§5–§7），但对"给什么材料"的要求完全相反。**

## 2. 隔离原则

这是本文件最要紧的一条：**提案阶段，助手之间必须互相不可见。**

理由不是保密，是**信号质量**。B 若看到 A 的方案，产出会向 A 收敛——
得到的是"对 A 的改写"而不是独立判断。那样问 N 个助手的成本花了，
拿到的信息量却接近问一个。

同一条逻辑在本文档集内已有先例：`verify.md` §7 要求重写投影时
"只读代码，禁止读本文档集，否则产出会退化为对旧文本的改写"。

**三个阶段，可见性不同：**

```
① 提案   各助手只见 request + 项目总览        ← 互相不可见，这是硬要求
② 比较   把 N 份方案摆在一起找分歧点          ← 人或某个助手来做
③ 综合   允许读全部方案，产出最终版            ← 此时才解除隔离
```

③ 阶段允许读别人的方案，但**不得直接拼接**——现有方案只作"该核对什么"的
候选清单，结论仍须回代码取证重写（同 `verify.md` §7）。

## 3. 提案模式：发什么，不发什么

发给每个助手的**提案包**：

| 必给 | 说明 |
| --- | --- |
| 原始需求 | 用户原话，一字不改（见 [`request-lifecycle.md`](request-lifecycle.md) R1） |
| 验收标准 | 客观、第三方可判定（R5）。这是助手自检的依据 |
| 上下文入口 | 指向 [`overall-architecture.md`](overall-architecture.md)，让它自己按需深入 |
| 边界 | 含什么 / 不含什么 / 不含的归谁（R3） |

| **不给** | 为什么 |
| --- | --- |
| 其他助手的方案 | 破坏隔离（§2） |
| 提出方自己的倾向或初步结论 | 助手会向它收敛，等于白问 |
| 指定的检查点、"重点看这几处" | 划定了思考范围，没被点到的地方不会被想到 |

**判断标准**：给出去的东西应当只描述"要什么"和"怎么算做到了"，
不描述"我觉得该怎么做"。

## 4. 审核模式：分两阶段，避免锚定

定向审核有个隐蔽陷阱：**提交方写的"审核说明"会划定审核范围。**
提交方没想到要查的地方，审核方也不会去查——看起来独立，锚点其实全是提交方给的。
这比"自己验自己"更难察觉。

**因此拆成两阶段：**

| 阶段 | 给审核方 | 明确不给 |
| --- | --- | --- |
| **一 · 独立审** | 原始需求 · 产物位置 · 客观验收标准 | 提交方的结论、自评、自陈盲区、指定的检查点 |
| **二 · 对照** | 这时才给提交方的自陈盲区清单 | — |

第二阶段的价值是**双向查漏**：

- 审核方发现了提交方没自陈的 → 提交方确有盲区
- 提交方自陈了审核方没发现的 → 审核方的审核有盲区

两边都能被检验。若跳过第一阶段直接给全套说明，这个检验就做不成了。

## 5. 仓库拓扑：为什么发改动这件事不简单

一次完整同步涉及 **17 个 git 仓**，不是 5 个：

```
k8s                    单仓，无子模块
tpl-app                ├── tpl-backend
                       ├── tpl-admin-frontend      每个 App 父仓
                       └── tpl-web-frontend        含 3 个子模块
info-app / knowledge-app / investment-app  （各同上）
                       = 5 + 12 = 17
```

两条硬约束：

- **五仓必须并列放在同一父目录**——`k8s` 的 render 脚本按
  `../tpl-app/k8s-deployment` 的相对路径引用，不并列直接失败。
- **推送顺序：子仓先，父仓后。**父仓的 gitlink 指向子仓提交，
  先推父仓会让对方 `submodule update` 拉不到东西。

### 远端

| 层 | origin（规范） | gitee（镜像） |
| --- | --- | --- |
| 5 个父仓 / k8s | `git@github.com:sunmoonlion/<仓>.git`（SSH） | `https://gitee.com/sunmoonlion/<仓>.git` |
| 12 个子仓 | 同上 | 同上 |

**17 个仓在两个远端均为公开**，匿名 HTTPS 可读——**拉取方不需要任何凭据、
不需要任何特殊配置**。推送才需要凭据。

### 分支

一助手一条分支：`cursor` / `kimi` / `luna` / `opus` / `qwen3.8`，主线 `master`。

**子仓的分支不一定齐全**：只有实际改动过的子仓才有对应分支，
其余停在父仓 gitlink 钉住的提交上（detached HEAD）。这是正常状态，不必修。

## 6. 拉取

```bash
mkdir -p ~/work && cd ~/work
BRANCH=opus

for r in k8s tpl-app info-app knowledge-app investment-app; do
  git clone -b "$BRANCH" --recurse-submodules \
    "https://github.com/sunmoonlion/$r.git"
done
```

网络不通时把 `github.com` 换成 `gitee.com`，两边内容一致。

更新已有检出：

```bash
for r in k8s tpl-app info-app knowledge-app investment-app; do
  git -C "$r" fetch origin
  git -C "$r" checkout "$BRANCH" && git -C "$r" pull --ff-only
  git -C "$r" submodule update --init --recursive
done
```

比较（②比较阶段的核心动作）：

```bash
git -C k8s diff master..opus --stat            # 某助手相对主线改了什么
git -C k8s diff kimi..opus -- sunmoonai/docs/  # 两个助手的方案差异
```

## 7. 推送

顺序不能反。子仓只推有该分支的（见 §5）：

```bash
cd <你的工作区>
B=$(git -C k8s branch --show-current)

# 1) 子仓（12 个，跳过没有该分支的）
for a in tpl info knowledge investment; do
  for c in backend admin-frontend web-frontend; do
    d="$a-app/$a-$c"
    git -C "$d" rev-parse --verify -q "$B" >/dev/null 2>&1 || continue
    git -C "$d" push origin "$B" && git -C "$d" push gitee "$B"
  done
done

# 2) 父仓与 k8s
for r in tpl-app info-app knowledge-app investment-app k8s; do
  git -C "$r" push origin "$B" && git -C "$r" push gitee "$B"
done
```

### 子模块处于 detached HEAD 时

本项目的子模块常处于游离状态。**直接 commit 会产生游离提交，可能丢失。**
先在**当前 HEAD 处**建分支：

```bash
git -C "$d" checkout -b "$B"     # 已存在则改用 git checkout "$B"
```

⚠ 必须在**当前 HEAD** 处建，**不能** `checkout master` 再建——
部分子仓的 HEAD 不等于 master（父仓钉的是历史提交），从 master 建会丢掉那个点。

## 8. 同机的多个助手

本机 `worktrees/*` 下各分支是同一对象库的 git worktree，
**提交后立即互相可见，不需要推送**：

```bash
git -C <主检出>/k8s worktree list      # 有哪些工作区
git -C <主检出>/k8s log opus           # 直接读别的分支
```

⚠ 但这也意味着**同机隔离是靠自律的**：一个助手完全可以去读另一个分支的产出。
提案阶段要保证隔离，只能靠明确指令（"不得读其他分支"），机制上拦不住。
跨机时隔离是天然的。

## 9. 助手没有终端时

网页对话式 AI 跑不了命令。给它：原始需求 + 产物全文或 diff +
提交方**已跑出的命令原始输出**（贴原文，不是结论）。

**这种参与只能验证逻辑一致性，不能验证事实**——它无法确认某个位置是否真的存在。
因此它的结论里必须标注"未经实际验证"，不能与跑过命令的结论等同看待。

## 10. 坑

| 坑 | 说明 |
| --- | --- |
| 提案阶段泄露了别人的方案 | 得到的是趋同不是独立信号，等于白问（§2） |
| 审核说明写太全 | 划定了审核范围，看似独立实则锚定（§4） |
| 推送顺序反了 | 子仓先、父仓后。反了对方 `submodule update` 失败 |
| 五仓没并列 | render 脚本按相对路径引用，会失败 |
| 在 detached HEAD 上直接 commit | 提交游离、可能丢失。先在当前 HEAD 建分支 |
| 从 master 建分支 | 部分子仓 HEAD ≠ master，会丢掉父仓钉的提交点 |
| 只推了一个远端 | 两个都要推，否则镜像不一致 |
| 某机器只能上 Gitee | 配一次重定向（仓库已全部公开，通常不需要）：<br>`git config --global url."https://gitee.com/sunmoonlion/".insteadOf "https://github.com/sunmoonlion/"` |
| **仓库是公开的** | 提交前确认没有凭据混入。历史一旦公开无法收回 |

## 11. 相关

- 请求怎么提、怎么验收：[`request-lifecycle.md`](request-lifecycle.md)
- 项目全貌（发给助手的上下文入口）：[`overall-architecture.md`](overall-architecture.md)
- 验证方法与盲区：[`verify.md`](verify.md)
