# 跨机协作与审核

> 最后更新：2026-08-27 ｜ 每一步都在"零凭据隔离环境"实测通过
>
> 本项目由多个 AI 助手并行开发，每个助手一条分支，改动需要被其他助手或人复核。
> 本文件写清楚：改动怎么发出去、别人怎么拉下来、怎么审。

## 1. 仓库拓扑：为什么这件事不简单

一次完整审核涉及 **17 个 git 仓**，不是 5 个：

```
k8s                    单仓，无子模块
tpl-app                ├── tpl-backend
                       ├── tpl-admin-frontend      每个 App 父仓
                       └── tpl-web-frontend        含 3 个子模块
info-app               （同上 3 个）
knowledge-app          （同上 3 个）
investment-app         （同上 3 个）
                       = 5 + 12 = 17
```

两条硬约束：

- **五仓必须并列放在同一父目录**——`k8s` 的 render 脚本按
  `../tpl-app/k8s-deployment` 的相对路径引用，不并列直接失败。
- **推送顺序：子仓先，父仓后。**父仓的 gitlink 指向子仓的提交，
  先推父仓会让对方 `submodule update` 拉不到东西。

## 2. 远端

| 层 | origin（规范） | gitee（镜像） |
| --- | --- | --- |
| 5 个父仓 / k8s | `git@github.com:sunmoonlion/<仓>.git`（SSH） | `https://gitee.com/sunmoonlion/<仓>.git` |
| 12 个子仓 | 同上（SSH） | 同上 |

**17 个仓在两个远端均为公开**，匿名 HTTPS 可读——**审核方不需要任何凭据、
不需要任何特殊配置**。推送才需要凭据（SSH key 走 GitHub，Gitee 走 HTTPS）。

`.gitmodules` 里写的是 GitHub 的 HTTPS URL，所以 `--recurse-submodules` 走 GitHub。

## 3. 分支约定

一个助手一条分支：`cursor` / `kimi` / `luna` / `opus` / `qwen3.8`，主线是 `master`。

**子仓的分支不一定齐全。**只有实际改动过的子仓才会有对应分支；
其余子仓停在父仓 gitlink 钉住的提交上（detached HEAD）。这是正常状态，不必修。

## 4. 审核方：拉取

```bash
mkdir -p ~/review && cd ~/review
BRANCH=opus                      # 要审的分支

for r in k8s tpl-app info-app knowledge-app investment-app; do
  git clone -b "$BRANCH" --recurse-submodules \
    "https://github.com/sunmoonlion/$r.git"
done
```

网络不通时把 `github.com` 换成 `gitee.com`，两边内容一致。

### 更新已有检出

```bash
cd ~/review
for r in k8s tpl-app info-app knowledge-app investment-app; do
  git -C "$r" fetch origin
  git -C "$r" checkout "$BRANCH"
  git -C "$r" pull --ff-only
  git -C "$r" submodule update --init --recursive
done
```

### 对比（审核的核心动作）

```bash
git -C k8s diff master..opus --stat              # 相对主线改了什么
git -C k8s diff master..opus -- sunmoonai/docs/  # 只看文档
git -C k8s diff kimi..opus  -- sunmoonai/docs/   # 两个助手的方案差异
```

## 5. 提交方：推送

顺序不能反。**子仓只推有该分支的**（见 §3）：

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

### 子模块处于 detached HEAD 时怎么提交

本项目的子模块常处于游离状态。**直接 commit 会产生游离提交，可能丢失。**
先在**当前 HEAD 处**建分支：

```bash
git -C "$d" checkout -b "$B"     # 已存在则改用 git checkout "$B"
```

⚠ 必须在**当前 HEAD** 处建，**不能** `checkout master` 再建——
部分子仓的 HEAD 不等于 master（父仓钉的是历史提交），从 master 建会丢掉父仓钉的那个点。

## 6. 同一台机器上的多个分支

本机 `worktrees/*` 下各分支是同一对象库的 git worktree，**提交后立即互相可见，
不需要推送**：

```bash
git -C /home/zym/master/k8s worktree list        # 看有哪些工作区
git -C /home/zym/master/k8s log opus             # 直接读别的分支的提交
git -C /home/zym/worktrees/kimi/k8s diff master..opus
```

推送只在**审核方不在本机**时才必要。

## 7. 审核方要做什么

审核材料 = 提交方写的审核说明，其中应含**可直接运行的证伪命令**。
**首要动作是跑命令，不是读结论。**

拉下来后可跑：

```bash
cd ~/review

# 四仓后端完整测试（需要 uv）
for a in tpl info knowledge investment; do
  (cd "$a-app/$a-backend/app" && uv run --frozen pytest -q)
done

# 结构不变量（改架构必看）
for a in tpl info knowledge investment; do
  (cd "$a-app/$a-backend/app" && uv run --frozen pytest tests/test_kernel_invariants.py -q)
done

# 文档集链接完整性
cd k8s/sunmoonai/docs && python3 - <<'PY'
import re, pathlib
root = pathlib.Path('architecture').resolve(); bad = 0
for p in root.rglob('*.md'):
    for m in re.finditer(r'\]\(([^)]+)\)', p.read_text(encoding='utf-8')):
        link = m.group(1).split('#')[0].strip()
        if not link or link.startswith(('http','mailto')): continue
        if not (p.parent/link).resolve().exists():
            print('BROKEN', p.relative_to(root), '->', link); bad += 1
print('坏链:', bad)
PY
```

结论回流：写成文本交回，或在自己分支上提交一份审核报告再推。

## 8. 审核方没有终端时

网页对话式 AI 跑不了命令。给它三样东西：

1. 审核说明全文
2. 完整 diff：`git -C k8s diff master..opus > review.diff`
3. 提交方**已跑出的命令原始输出**（贴原文，不要只贴结论）

**这种审核只能验证逻辑一致性，不能验证事实**——它无法确认某个位置是否真的存在、
某条断言是否成立。提交方的说明里必须自陈"哪些断言未经第三方复核"。

## 9. 坑

| 坑 | 说明 |
| --- | --- |
| 推送顺序反了 | 子仓先、父仓后。反了对方 `submodule update` 失败 |
| 五仓没并列 | render 脚本按相对路径引用，会失败 |
| 在 detached HEAD 上直接 commit | 提交游离、可能丢失。先在当前 HEAD 建分支 |
| 从 master 建分支 | 部分子仓 HEAD ≠ master，会丢掉父仓钉的提交点 |
| 只推了 origin | 两个远端都要推，否则镜像不一致 |
| 某机器只能上 Gitee | 配一次重定向（**仓库已全部公开，通常不需要**）：<br>`git config --global url."https://gitee.com/sunmoonlion/".insteadOf "https://github.com/sunmoonlion/"` |
| **仓库是公开的** | 提交前确认没有凭据混入。历史一旦公开无法收回 |

## 10. 相关

- 请求怎么提、怎么验收：[`request-lifecycle.md`](request-lifecycle.md)
- 项目全貌：[`overall-architecture.md`](overall-architecture.md)
- 验证方法与本轮实测结果：[`verify.md`](verify.md)
