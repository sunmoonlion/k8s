# 签名回执与三道边界

> 迁出自 `refact-fable.md`（`7e8464c2`，927 行，sha256[:16] `89303624bfd9ef27`）§3.13 与 §3.4。
> **那份文档的架构结论（A/B 分层）已被 `runtime` 轮推翻，但本文这几节没有被推翻**——
> 它们绑的是权力与边界，不绑那对部署形态。迁出后原文删除，历史在 `7e8464c2` 与
> `rounds/refact-fable/` 归档里。
>
> **当前状态与本文的关系**：S1 边界 spike 正在按本文执行；宿主取证见
> `rounds/_spike-sign/forensics.md`，其结论修订了本文 §3.13.1 的现状事实——
> **本机 `zym` 拥有免密 sudo 且在 docker 组**，因此本文所述「本地强制点」一律无效，
> 只有托管方的 key 作用域与账户公钥端点有效。读本文时以取证记录为准。

---

## 1. 人的通道：收件箱 + 回执

```text
sunmoonai/docs/dev-plan/rounds/<id>/inbox-owner.md     ← 引擎写，人读（与 call-<环节>.md 同构）
                                                          每条必备字段：interaction_id、transition、待决内容、截止判据；
                                                          凡产生回执仓回执的条目（H1–H6）另加 target_commit、diff_stat；H1/H5 再加冻结验收条编号表
                                                          （缺任一字段 = 条目无效，round-status.py 机械判）
签名回执（回执仓 main 上的签名 commit + yaml）           ← 人写，引擎读；rulings.md 只是它的人读缓存（H7 例外）
```

**字段分级：无默认的字段不得预填**（kimi D3，采纳——P3 说默认值属省事方向，预填等于把盖章做成阻力最小路径）：

| 分级 | 字段 | 规则 |
| --- | --- | --- |
| 无默认，必须显式填 | 验收条（H1 本身）、executors 名单（含 arbiter / acceptor）、`tier` | 收件箱留空；回执 target_commit 指向的工单里这三项为空即判无回执 |
| 可预填默认 | workspace 计划、预算窗、观察窗规则 | 预填值与人改后的值都落账，改动幅度是观察值 |

「T0 按版本化策略自动放行」与「T1/T2 收件箱预填人盖章」是两回事：前者有 `RouteDecision{policy_version, matched_rule}`
落账，且验收条来自已签策略；后者是默认漂移，禁止。

- 引擎判定「当前转换命中权力表」时，写收件箱并停下（Task `WAITING(APPROVAL)`）；分发脚本对 `kind = human`
  的条目输出的不是 argv，而是通知（终端提示、桌面通知、或将来的 IM）。**通知丢了不要紧，收件箱文件是真源**
  （对应产品 `F-DELIVERY-06`：流式通知不是结果唯一载体）。
- 人的回执**只认落盘**：对话里说「同意」不算，与 round-protocol「异议稿必须冻结提交」同理。
- 人不回执时的处置按 round-protocol「参与方不可用」：H1、H3–H7 等待，**不设超时默认**（最后一道关卡不默认通过）；
  只有 H2 在策略明确允许的 T0 场景可以按默认放行，且要落账。
- **每次 H 回执登记三个观察值**（kimi D7 / qoder D7 / cursor D5，采纳为观察值而非判据）：回执耗时（收件箱落盘 → 回执仓收到 tag）、
  相对预填值的改动项数、**每票签名次数按 H1/H2/H3–H4/H5/H6 分计**。⑦ 清理时汇总进 `rulings.md`，所有者自己看趋势；
  **不**由观测值自动触发 H6——H6 是权力，不是告警。签名次数是 C1 全表锚定的直接代价，T0 的主要摩擦预计在 H5 而不在 H2。

产品 Profile 里这一段的对应物已经全部定义好了：Interaction、`WAITING(APPROVAL)`、`resume_token_hash`、`AT-07`。
开发 Profile 先用文件与 tag 跑通同一形状。


---

## 2. 签名回执的威胁模型与密钥分布

> 2026-09-05 补入，回应 opus 与 luna 评审；12:40 按五家终审重写（取证纠错、回执仓对象模型、发布权移出 VM、验签）。

**要防的三件事**（12:15 版只写了第一件，luna C2 / opus §3 / kimi F1 指出另两件）：

1. **伪造一条肯定的人类回执**（伪造否定回执等于不回执，流程只会停下等，不危险）；
2. **绕过回执直接产生不可逆 Side Effect**（有没有回执是一回事，没回执能不能 push 主线是另一回事）；
3. **签名动作被人的机器上的 agent 代做**（Windows 上的 Cursor 本地 agent 以人的账户运行）。

攻击者模型是**与人共享同一 credential domain、会流畅执行任何命令、不会犹豫的 agent 进程**——不是恶意，是「顺手代劳」。

### 2.0 取证声明（先于事实）

12:15 版（原 §3.13.1）写「本 VM 所有进程都是 root、`/home/zym` 属 root:root」——**错**。opus 与 luna 在同一台机器复核：
`uid=1003(zym)`，四家 CLI 均以 `zym` 运行。错因已查明：起草者（fable，经 Cursor）在 Cursor 沙箱内执行取证命令，
`cat /proc/self/uid_map` 输出 `0 1003 1`——沙箱用 user namespace 把宿主 uid 1003 映射为 0，所以沙箱内一切看起来都是 root。
取证工具自身有边界而未声明，正是 P4 禁止的事。由此立三条规则，也进 §8 第 9 条：

- 取证栏每条注明**主机、执行身份、是否在沙箱 / 容器内**（`hostname; id; cat /proc/self/uid_map`）；
- S1 的权限测试必须以**与生产 agent 完全相同的 OS 用户与进程环境**复跑，不在任何沙箱内；
- 边界的表述写成「agent 与人是否共享 credential domain」，不绑定「是不是 root」这个偶然事实。

### 2.1 现状事实（2026-09-05；宿主身份由 opus / luna 复核，S1 前须按 §2.0 重跑）

| 事实 | 取证 | 后果 |
| --- | --- | --- |
| 人的 shell、四家 CLI（`codex`、`claude`、`agent`、`qoder`）、vscode-server **全部以同一普通用户 `zym`（uid 1003）运行** | `id` → `uid=1003(zym)`；`ps -eo user,comm \| rg 'codex\|claude'` 全为 `zym`；`stat -c '%U:%G' /home/zym` → `zym:zym`（opus / luna 复核，宿主 shell） | **同 UID 即同权限**：`~/.gnupg`、`~/.ssh/id_rsa`、gpg-agent 套接字、仓内验证脚本、hook，agent 全部可读可改。结论与 12:15 版相同，理由不同 |
| `zym` 同时在 `sudo` 与 `docker` 组 | `id` 输出 `27(sudo),988(docker)`（opus 复核） | `docker` 组等价 root（可挂宿主文件系统）。B 档要成立，agent 专用用户必须**不在**这两个组 |
| 本机**没有 GPG 密钥**；已有 tag 全部未签名 | `gpg --list-secret-keys` 为空；`for-each-ref` 中 `refact/*` 与 `2.0.0` 无签名块 | 从零设计，没有兼容包袱 |
| `~/.ssh/id_rsa` 对 `git@github.com:sunmoonlion/k8s.git` **有写权限** | `git remote -v`；push 历史 | 任何 agent 都能以本机身份 push 分支与 tag 到主仓——这是要防的第二件事 |
| 人的第二台机器是 Windows 工作站（Cursor 客户端，经 Remote-SSH 连本 VM） | 会话资产路径 `c:\Users\zymun\...`；`last` 同一公网 IP | Windows 上**也运行 Cursor 本地 agent**，以人的账户运行；Git Credential Manager 若缓存了 GitHub 推送凭据，它不需要口令就能 push（kimi F1） |

> **在本 VM 上，任何本地验证（`git verify-tag`、读某个 pubkey 文件、跑 `round-status.py`、pre-push hook）都不是边界。**
> agent 能生成一把新钥、把公钥加进任何本地信任列表、改掉验证脚本或 hook、再签一条 tag。
> 「本地判定通过」只能作为**便利的参考显示**，不得作为任何 `auto_policy = 无` 行的强制点。

### 2.2 三道边界都要放在 agent 的 credential domain 之外

| 要防的 | 边界 | 为什么 agent 够不着 | 所有者裁定 |
| --- | --- | --- | --- |
| ① 伪造回执 | **回执仓** `<owner>/receipts`：VM 只持只读 deploy key；回执是仓内自己的**签名 commit**（§2.3）；VM 验签用的公钥集**在线取自 GitHub 账户端点**（`https://github.com/<owner>.gpg` / `.keys`），不落本地文件 | 写权限与账户端点都不在 VM；本地脚本可被改，但它改不了「回执仓里有没有那条 commit」 | 2026-09-05 采用 |
| ② 绕过回执发布 | **主仓写权限移出 VM**：`sunmoonlion/k8s` 对 VM 只读；agent 候选推到**候选仓** `<machine-user>/k8s-candidates`；⑦ 的主线 push 由 Windows 在签 H5 回执的同一动作里执行 | agent 根本发不起对主仓的写；H5 的强制点与签名点合一。不依赖 branch protection / ruleset（私有仓需 Pro） | **2026-09-05 采用**（luna C2 / opus §3；所有者「移」） |
| ③ 签名被代做 | Windows：gpg-agent `default-cache-ttl 0 / max-cache-ttl 0`；回执仓与主仓的推送**不走** Git Credential Manager，用带口令的专用 SSH key（`IdentitiesOnly yes`，不加进 ssh-agent）；或上 C 档硬件在场 | 每次签名与每次 push 都要人敲一次口令；Windows agent 拿不到 | 采用；C 档为加固 |

可选加固（不是替代）：

| 档 | 内容 | 现状评估 |
| --- | --- | --- |
| **A′. 工作仓 ruleset** | GitHub tag / branch ruleset 限定 `main` 与 `confirm/*` 只许所有者写 | **私有仓 ruleset 与 branch protection 都需 Pro 及以上**（官方文档「About rulesets」，已核）。所有者若在 Pro，可加做 |
| **B. 账户隔离** | 四家 CLI 各自以专用 Unix 用户运行、worktree 归各自用户，agent 用户**不在 `sudo` / `docker` 组** | 12:15 版写「运维改造大：以 root 跑」是基于错误取证。实际四家已是普通用户 `zym`，B 档成本 = 建四个用户 + 改 worktree 归属 + 拆组。仍不是本轮范围，但成本评估要改对（opus 2.2） |
| **C. 硬件在场** | YubiKey 等，签名与 SSH 认证需物理触碰 | 对 ①②③ 都是加强项 |

### 2.3 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag

12:15 版写「在工作仓里 `git tag -s confirm/<id> <commit>` 再 push 到回执仓、回执仓不含工作仓历史、`ls-remote` 读 message」——
luna C1 给了可复跑证据，三处都不成立：annotated tag 指向 git 对象，push 会把被指向 commit 的**全部可达历史**复制进回执仓；
`ls-remote` 只返回 OID，读不到 message；要读 message 必须 fetch tag 对象。改为：

```text
<owner>/receipts（私有；VM 只读 deploy key；Windows 带口令 SSH key 可写）
└── main（只追加；所有者自律不 force-push，纠错用新回执 supersedes 旧回执）
    └── receipts/<work_repo_id>/<round>/<seq>-<transitions>.yaml     # 每份回执 = 一个签名 commit（git commit -S）
        例：receipts/k8s/refact-2/01-H1+H2.yaml
            receipts/k8s/refact-2/02-H3.yaml
            receipts/k8s/refact-2/03-H5.yaml
```

- **每份回执一个签名 commit**，commit 只改动这一个文件；`target_commit` 是 yaml 里的**普通字段**，不是跨仓对象引用，
  回执仓不含工作仓任何对象。
- VM 侧：`git fetch receipts main`（只读）→ 读 yaml → 用在线取得的所有者公钥集验证该 commit 签名 →
  用 `target_commit` 对照本地工作仓对象。三步任一失败、fetch 失败、端点不可达，一律 fail-closed，退出码单列。
- **按 transition 查找靠字段不靠文件名**：脚本扫该轮目录，`transitions` 字段含 `H3` 的即 H3 回执；组合回执
  （`[H1, H2]`、`[H5, H3]`）天然可被每个 transition 各自查到——这解决 cursor F2 的命名空间问题，不需要多重 ref。
- **只增不改**：纠错写新回执并填 `supersedes: <seq>`；旧文件不动，`round-status.py` 取「未被 supersede 的最新」。
- Windows 侧一次回执的动作：填 yaml（收件箱条目已给全字段，人只填结论）→ `git commit -S` → `git push receipts main`。
  可用一个本地脚本把「读收件箱 → 生成 yaml 骨架」自动化；签名与 push 两次口令不自动化。

### 2.4 回执 schema

```yaml
receipt_version: 1
work_repo: sunmoonlion/k8s
round: <id>
transitions: [H1, H2]        # H1 | H2 | H3 | H4 | H5 | H6，可组合；H7（取消）不进回执仓——3.3 表内唯一例外
target_commit: <sha>         # 工作仓 commit；必须等于收件箱条目里列的 commit
                             # H3/H4/H6：是新增该条 rulings.md 行的 commit；脚本校验该 commit 的 diff 恰好新增该行
work_order_digest: <sha256>  # 工单 FROZEN 版本的哈希；H1/H2 必填
ruling_sha256: <sha256>      # H3/H4/H6 必填：裁定行文本哈希，防 rulings.md 事后被改
policy_version: <n>          # H2 记按哪版策略；T0 自动放行不产生回执，只落 RouteDecision
issued_at: <ISO>
expires: <ISO>               # 缺省 = 收件箱条目的截止判据；条目无截止则 issued_at + 24h（kimi F5 / opus 5.2）
                             # 只约束「该回执可用于放行的窗口」；放行发生后不追溯，不因过期回滚
supersedes: <seq>            # 可选；纠错时指向被取代的回执
acceptance:                  # H5 必填：对每条冻结验收条的结论，编号集合必须等于工单 acceptance 的编号集合
  A1: pass
  A2: pass
  A3: waived <理由>          # waived 是省事方向 = 一条 H3；本回执 transitions 必须含 H3，且 rulings.md 有对应行
```

缺字段、字段不匹配、签名不在公钥集、过期、`acceptance` 编号集合与冻结集合不等，一律判「无回执」，不判「可疑」——P4。

`acceptance` 块是**内容门**（qoder D3 + kimi D9）：回执存在只证明「所有者做了签名推送动作」，不证明读过；
把逐条结论写进被签的文件，人至少要对每条验收条各写一个词。它放在回执仓而不放 `rulings.md`，
是因为 `rulings.md` 在工作仓，agent 能写。

### 2.5 两台机器的身份与凭据分布

```text
Windows 工作站（人）                                  VM-0-13-ubuntu（agent × 4 + 人经 SSH，全部 uid 1003 zym）
────────────────────────                              ────────────────────────────────────────────────────
签名私钥（GPG 或 SSH 签名；仅此一份）                  无签名私钥；无所有者账户凭据
  · 口令保护；gpg-agent TTL = 0；或硬件密钥            ~/.ssh/candidates_rw   → <machine-user>/k8s-candidates  读写
GitHub 所有者账户登录态                                ~/.ssh/k8s_ro          → sunmoonlion/k8s              只读
~/.ssh/owner_push（带口令，IdentitiesOnly，不进 agent） ~/.ssh/receipts_ro     → <owner>/receipts             只读
  → sunmoonlion/k8s 主线 push                          原 id_rsa（对主仓可写）：**撤销**
  → <owner>/receipts push
                                                       round-status.py：
回执动作：                                               git fetch receipts main → 读 yaml → 在线公钥集验签
  填 yaml → git commit -S → git push receipts main         → target_commit 对照本地对象 → 成立 / 未确认（fail-closed）
⑦ 发布动作（H5 回执之后，同一会话）：                   round-dispatch.py 与整合方：
  git fetch candidates <整合分支>                          只 push 候选仓；对主仓的 push 在凭据层面不可能
  round-status.py --verify-receipt H5 <sha>              本地 verify 只做参考显示
  git push origin <sha>:master
```

三点必须写进规则：

1. **强制点在凭据层，不在脚本层。**VM 上的 `round-status.py`、hook 可以被改，但改了也发不起对主仓与回执仓的写；
   Windows 上的发布脚本同样可被本地 agent 改，所以发布前的 `--verify-receipt` 也只是便利，真正的门是「push 要人敲口令」。
2. **Windows 上的本地 agent 同样是威胁。**签名口令不缓存、推送 key 不进 ssh-agent、不用 GCM。任一条不满足，③ 就破了。
3. **VM 上不得存在所有者账户的任何凭据**：`scripts/check-no-owner-creds.sh`（kimi D10；修改按 T2）。**它是配置卫生检查，不是边界**
   （qoder C5）——agent 能改它，它防的是人为疏漏。首版覆盖：`~/.ssh/` 全部私钥指纹对照、`~/.git-credentials`、`~/.netrc`、
   `credential.helper`、`~/.config/gh/hosts.yml`、shell rc 中的 `GH_TOKEN` / `GITHUB_TOKEN`、`~/.vscode-server` 凭据存储、
   `~/.docker/config.json`；再对主仓与回执仓各做一次 `git push --dry-run`，**任一成功即失败**。

### 2.6 剩余风险（如实登记）

| 风险 | 说明 | 处置 |
| --- | --- | --- |
| 人被 agent 的输出误导而签了错的 commit | 边界防伪造与绕过，不防误签 | 收件箱 `target_commit` / `diff_stat` 必备（3.4）；`acceptance` 内容门（3.13.4）；L3「人抽三样」最后一道 |
| VM 上的判定代码被改（opus §3） | `round-status.py` / hook 全在 agent 可写面 | 不再是边界：改了也发不起主仓与回执仓的写。判定代码的正确性靠 §8 第 8 条「首跑与人工对照」与 L0 测试，不靠它不可改 |
| GitHub 不可用 | 信任锚与公钥端点都在外部 | 等。⑥ 本来就「不设逾期默认」；fail-closed。第二锚（自托管 bare 仓，所有者机器持写权限）列为可选 |
| 所有者账户被盗 | 超出本文范围 | 2FA；通用实践 |
| 回执仓 / 主仓的 VM 侧 key 漂移成可写 | 配置漂移 | 每轮 ⑦ 用 VM 身份对两仓各 `git push --dry-run`（**统一为 dry-run**，opus 5.1：真 push 一旦成功会永久留下假回执），任一成功即报警停轮 |
| 所有者把可写 key 复制到 VM「图方便」 | 人为绕过 | `check-no-owner-creds.sh` 的 dry-run 项 |
| 候选仓与主仓分离后，人在 Windows 多一步 fetch + push | 摩擦 | 与 H5 签名同一会话，不增触点；耗时进观察值 |
| Windows 本地 agent 在人敲口令的窗口内插入动作 | ③ 的残余 | TTL=0 把窗口缩到单次操作；彻底解决只有 C 档 |

---

