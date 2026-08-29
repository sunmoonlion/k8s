# 跨机与多仓协作机制

> 最后更新：2026-08-29 ｜ 已在"零凭据隔离环境"实测通过
>
> 本文件只讲**操作机制**：17 个仓怎么拉、怎么推、子模块的坑。
> 多个助手**怎么协作**（隔离原则、提案包构造、评审两阶段、吸收处置）
> 属于智能体的运作纪律，见 [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md)。

## 1. 仓库拓扑：为什么发改动这件事不简单

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

## 2. 拉取

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

比较（用于比较不同助手的方案）：

```bash
git -C k8s diff master..opus --stat            # 某助手相对主线改了什么
git -C k8s diff kimi..opus -- sunmoonai/docs/  # 两个助手的方案差异
```

## 3. 推送

顺序不能反。子仓只推有该分支的（见 §1）：

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

## 4. 同机的多个助手

本机 `worktrees/*` 下各分支是同一对象库的 git worktree，
**提交后立即互相可见，不需要推送**：

```bash
git -C <主检出>/k8s worktree list      # 有哪些工作区
git -C <主检出>/k8s log opus           # 直接读别的分支
```

⚠ 但这也意味着**人工执行时，同机隔离是靠自律的**：一个助手完全可以去读另一个分支的产出。
提案阶段要保证隔离，只能靠明确指令（"不得读其他分支"），机制上拦不住。
跨机时隔离是天然的。

**脚本化执行则不然**——[`../dev-plan/parallel-proposals.py`](../dev-plan/parallel-proposals.py)
给每路独立进程与独立 `CODEX_HOME`，隔离由机制保证（见 [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md) §3.1）。

## 5. 助手没有终端时

网页对话式 AI 跑不了命令。给它：原始需求 + 产物全文或 diff +
提交方**已跑出的命令原始输出**（贴原文，不是结论）。

**这种参与只能验证逻辑一致性，不能验证事实**——它无法确认某个位置是否真的存在。
因此它的结论里必须标注"未经实际验证"，不能与跑过命令的结论等同看待。

## 6. 坑

| 坑 | 说明 |
| --- | --- |
| 提案阶段泄露了别人的方案 | 得到的是趋同不是独立信号，等于白问（见 [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md) §2） |
| 审核说明写太全 | 划定了审核范围，看似独立实则锚定（同上 §4） |
| 评审没声明所审提交号与覆盖范围 | 评审天然滞后；未覆盖区被误当作已审（同上 §5.2） |
| 吸收方判"误报"却不举证 | 被告当法官。误报判定本身必须可复核（同上 §5.3） |
| 吸收完不回跑评审方的验收标准 | 循环没闭合，无从证明真的吸收了（同上 §5.4） |
| 把"经过评审"说成"已验证" | 评审方漏了什么无从得知，不构成背书（同上 §5.6） |
| 推送顺序反了 | 子仓先、父仓后。反了对方 `submodule update` 失败 |
| 五仓没并列 | render 脚本按相对路径引用，会失败 |
| 在 detached HEAD 上直接 commit | 提交游离、可能丢失。先在当前 HEAD 建分支 |
| 从 master 建分支 | 部分子仓 HEAD ≠ master，会丢掉父仓钉的提交点 |
| 只推了一个远端 | 两个都要推，否则镜像不一致 |
| 某机器只能上 Gitee | 配一次重定向（仓库已全部公开，通常不需要）：<br>`git config --global url."https://gitee.com/sunmoonlion/".insteadOf "https://github.com/sunmoonlion/"` |
| **仓库是公开的** | 提交前确认没有凭据混入。历史一旦公开无法收回 |

## 7. 相关

- 请求怎么提、怎么验收：[`request-lifecycle.md`](request-lifecycle.md)
- 项目全貌（发给助手的上下文入口）：[`overall-architecture.md`](../project-guide/overall-architecture.md)
