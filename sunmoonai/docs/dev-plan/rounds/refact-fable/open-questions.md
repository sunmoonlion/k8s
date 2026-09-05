# 待解问题清单 · refact-fable 实施

> 维护：opus ｜ 建立 2026-09-05 ｜ **活文件**：解决一条划掉一条并注明落点，不删行
>
> 基准：`refact-fable.md` 927 行 `sha256[:16] 89303624bfd9ef27`，冻结于 master `7e8464c2`。
> 已在 927 版解决的评审意见不入本清单（independence 三维拆分、T0 包 paths 限制、`_probe` 统一 dry-run 等）。

---

## A. 阻塞 S1 的（S1 卡住 → R1 → R3/R4/R5 全停）

### A1 ⛔ 签名在哪台机器上做：WSL 还是 Windows 原生

- **现状**：`refact-fable.md` §3.13.5 写「Windows 工作站（人）：签名私钥（仅此一份）」，
  §3.13.1 取证依据是会话资产路径 `c:\Users\zymun\...`。**全文 `grep -n "WSL"` 零命中。**
- **实际**：所有者 2026-09-05 说明「我是在 windows 的 WSL」。
- **为什么要紧**：两者在密钥可达性上不同——Windows 原生 `%APPDATA%\gnupg` 对 WSL 默认不可达；
  WSL 里的 `~/.gnupg` 则 WSL 内任何进程可读。边界③（gpg-agent TTL 0 / `IdentitiesOnly`）
  防的是「缓存被复用」，不防「同一用户下的进程旁路 pinentry」。
- **要答两问**：① 签名动作在 WSL 里还是 Windows 原生做？② 那一侧跑不跑 agent（Cursor 本地 agent / 任何 CLI）？

| 签名在 | 那侧跑 agent | 结论 |
| --- | --- | --- |
| Windows 原生 | 跑 | 边界③够用，文档现状成立，只需把「Windows 工作站」写准 |
| Windows 原生 | 不跑 | 最干净 |
| **WSL** | **跑** | ❌ **WSL 与 VM 同构，A 档在那里不成立**；需 Windows 原生签名或 C 档硬件密钥 |
| WSL | 不跑 | 成立，但 §3.13.4/3.13.5 的路径与命令要按 WSL 重写 |

- **处置**：属 S1 发现（spike 用途即此），记 `rulings.md`，**不必走 H6**（§8 九条未规定机器）。

### A2 ⛔ 双 remote：gitee 的写凭据未被边界②覆盖

- **实测**（2026-09-05，`--dry-run`，未真推）：

  ```text
  git push gitee --dry-run HEAD:refs/heads/_boundary_probe
  → * [new branch]  HEAD -> _boundary_probe      # 成功
  ```

- **现状**：`origin` = GitHub SSH（`id_rsa`，S1 计划撤销）；
  `gitee` = **HTTPS**，凭据在 `~/.git-credentials`（`600 zym:zym`，`credential.helper = store`）。
  四家 agent 跑的就是 `zym`，全部可读。
- **后果**：§3.13.2 边界②只写了「`sunmoonlion/k8s` 对 VM 只读」，**只覆盖 GitHub 一条路**。
  按现方案执行完 S1，agent 仍可 `git push gitee master`，**H5 整个绕过**。
- **处置**：S1 增第 ④ 项：

  ```text
  ④ 移除 gitee 写凭据
     · 删 ~/.git-credentials 中 gitee 行；git config --global --unset credential.helper
     · gitee remote 改只读接入（只读账号 / deploy key），或本机不配 gitee push
     · 验收：git push gitee --dry-run 被拒
  ```

- **归类**：又一次「覆盖不全」——边界写对了，覆盖范围少算一个 remote。

### A3 ⚠ 回执仓建在 GitHub 还是 gitee

- 现方案依赖 `https://github.com/<owner>.gpg` 在线取公钥集；而双 remote 的存在说明 GitHub 可达性不稳。
- GitHub 不可达时 fail-closed = 流程停住（§3.13.5 风险栏已登记「等」）。
- **未核 ⚠**：gitee 有无等价的账户公钥端点（`https://gitee.com/<user>.gpg` 之类）。
- **要答**：回执仓放哪；若放 GitHub，能否接受不可达即停。

### A4 ⛔ 谁来建回执仓与候选仓

- **我建不了 GitHub**：VM 上无 `gh` CLI、无 `~/.config/gh`、无 API token；SSH key 只能推代码不能建仓。
- **我技术上能建 gitee**（`~/.git-credentials` 里有凭据），**但不建议由我做**——那把凭据正是 S1 要拔掉的。
- **要答**：确认由所有者在自己机器上建；我只做 VM 侧准备（生成 key、写检查脚本、配 remote 不带凭据）。

### A5 三把 key 的生成与挂载

- 我可生成：`candidates_rw`、`k8s_ro`、`receipts_ro`（私钥不出 VM）。
- 你需在两个平台各贴公钥并设权限；`receipts_ro` **不得勾写权限**。
- 依赖 A3、A4 定下来。

---

## B. 我能立刻做、不被 A 阻塞的

| # | 事 | 状态 |
| --- | --- | --- |
| B1 | **R0**：修脚本↔协议三处不一致（命名、`--stage`、退出码）+ 合并 `protocol-v2` | 待开工，范围已收敛（第 4 项拆为 R0′） |
| B2 | **R2**：执行架构迁出 `executor-architecture.md` | `refact-fable` 明标「不依赖 R1」 |
| B3 | `scripts/check-no-owner-creds.sh` 首版 | 纯 VM 侧；**须覆盖 gitee**（见 A2） |
| B4 | R5 的前四条删除条件（纯文档：三份新文过门禁、13 文件引用清零、migration-map 零缺口、§11.3 八条可寻） | 只有第 5 条（实跑 T0/T1）依赖 R4 |

---

## C. 待所有者裁定

| # | 事 | 我的判断 |
| --- | --- | --- |
| C1 | **路线并行化**：把「文档线 R0→R2→R5 前四条」与「机制线 S1→R1→R3→R4」解耦并行 | §8 九条不含实施顺序，**不需 H6**；但应记 `rulings.md`。方向中性偏严谨（不减任何检查） |
| C2 | **R0′ 何时开**（协议补「机器可读块」，已裁定按 T2） | 建议排在 R0 之后、不阻塞 R2 |
| C3 | `protocol-v2` 我请你审的五条待拍板，被 `refact-fable` 覆盖了多少 | 至少「档位判据偏紧」那条未被覆盖，见 C4 |
| C4 | **档位判据是否偏紧**：「权威层」几乎覆盖 `dev-plan/` 全部文件，导致路线里三轮 T2 | 我认为该改判据，而不是靠新增 `bootstrap` 档回避 |

---

## D. 已发现、待落盘或待再现

| # | 事 | 处置 |
| --- | --- | --- |
| D1 | **删除被引用文档时须跑 `doc-gate.py --all`**：2026-09-05 删 `refact-task.md`，`--staged` 通过而 `readiness.md` 链接已断，全量扫描才抓到 | 候选规则。机理与前两次（正则漏项）不同——是**覆盖范围与动作影响范围不重合**。按「裁量是规则的孵化器」，再现一次即升级进 `round-protocol` |
| D2 | A1 / A2 两条要记进 `rounds/refact-fable/rulings.md` | 待办 |

---

## 已关闭

| # | 事 | 关闭方式 |
| --- | --- | --- |
| ✅ | `independence` 二元取值歧义（luna/kimi 同 codex 二进制） | 927 版拆为 `provider` / `runtime` / `model_family` |
| ✅ | T0 任务类包 `paths` 过宽，可覆盖 `constraints.md` 等 | 927 版禁止覆盖权威层文件与门禁脚本 |
| ✅ | `_probe` 探测用 `push` 还是 `--dry-run` 两处不一致 | 927 版统一 dry-run |
| ✅ | A 档只防伪造 tag、未防伪造判定（判定脚本在仓内可改） | 927 版采纳为**边界②**（主仓写权限移出 VM + 候选仓） |
| ✅ | §3.13.1「本 VM 全 root」三处取证错 | 927 版已改为「同一普通用户 `zym`（uid 1003）」，并加 `sudo`/`docker` 组一行 |
| ✅ | §8 把行数当验收标准 | 改为观察值 |
| ✅ | `refact-task.md` 是否删除 | 已删（master `38d24fda`），内容在标签 `refact/integration` |
