# S1 边界 spike ⑤：宿主取证

> 2026-09-05 ｜ 执行者 opus ｜ 按 `refact-fable.md @ 7e8464c2` §3.13.0「取证声明（先于事实）」。
> **每条附主机身份与可复跑命令。不打印任何凭据值，只查存在性、权限与授予的能力。**

## 0. 执行环境（3.13.0 要求每行附）

```text
hostname          VM-0-13-ubuntu
id                uid=1003(zym) gid=1003(zym) groups=1003(zym),27(sudo),100(users),988(docker)
cat /proc/self/uid_map    0 0 4294967295      # 未映射，是真实 uid，不是沙箱内的伪 root
```

⚠ 与 `runtime` 轮一份候选的取证声明对照：那次同一执行者在**助手自带沙箱**内 `id` 报 `uid=0(root)`、
`uid_map` 为 `0 1003 1`（伪 root）。本次是宿主 shell，`uid_map` 为恒等映射——**两者必须靠 `uid_map` 区分**，
只看 `id` 会误判。这正是 3.13.0 存在的原因（上一轮的沙箱 uid 误判）。

## 1. 事实

| # | 事实 | 复跑命令 | 结果 |
| --- | --- | --- | --- |
| F1 | **`zym` 有免密 sudo** | `sudo -n -l` | `(ALL : ALL) ALL` / `(ALL) NOPASSWD: ALL` |
| F2 | **`zym` 在 docker 组且 docker 可用** | `id`；`docker info` | Server 29.1.2；`docker run -v /:/host` 等价 root |
| F3 | **`~/.ssh/id_rsa` 无口令** | `head -c 200 ~/.ssh/id_rsa \| grep -i ENCRYPTED` | 无匹配；600 权限 |
| F4 | **`~/.git-credentials` 明文存在，指向 gitee** | `stat -c %a ~/.git-credentials`；`git config --global credential.helper` | 600；`store` |
| F5 | **VM 身份可推 GitHub 主仓** | `git push origin --dry-run HEAD:refs/heads/_s1_probe` | `* [new branch] HEAD -> _s1_probe`（**未被拒**） |
| F6 | **VM 身份可推 gitee 主仓** | `git push gitee --dry-run HEAD:refs/heads/_s1_probe` | `* [new branch]`（**未被拒**） |
| F7 | 宿主无 GPG 密钥 | `gpg --list-secret-keys` | 0 个 |

F5 / F6 是 S1 验收判据 ⓪ 的**当前反面**：判据要求「VM 身份对主仓与回执仓 `push --dry-run` 均被拒」，
现在两个主仓都推得动。

## 2. 推论：本地强制点对 agent 无效

F1 与 F2 各自独立地把 agent 提到 root。由此：

| 强制点位置 | 对 agent 是否有效 | 理由 |
| --- | --- | --- |
| 托管方的 deploy key 作用域 / 分支保护 | **✅ 有效** | 在 agent 的 credential domain 之外，`sudo` 够不着 |
| 托管方的签名验证（在线公钥集） | **✅ 有效**（前提：验证方也在 agent 域外） | 同上 |
| VM 上的脚本 / hook / 门禁（`check-no-owner-creds.sh`、`doc-gate`、`round-status.py --verify`） | **❌ 无效** | agent 可 `sudo` 改写其内容或返回值 |
| VM 上的文件权限（600、只读挂载） | **❌ 无效** | 同上 |
| VM 上的「独占工作区」约定 | **❌ 无效** | `runtime-architecture.md` §4.5 已如实登记为 `convention` |

**这条推论是 `refact-fable.md @ 7e8464c2` §8 第 2 条「强制点必须在凭据层或回执仓，VM 上可改的脚本与 hook 不算强制点」
的实证基础**——此前那是设计判断，现在有复跑证据。

## 3. 对 S1 五个动作的影响

| 动作 | 影响 |
| --- | --- |
| ① 建回执仓、候选仓 | 不受影响 |
| ② VM 换三把 key，撤销 `id_rsa` | **成立且必要**。强制点在托管方的 key 作用域，agent 改不了。这是 S1 里唯一真正有效力的一步 |
| ③ 所有者在 Windows 用带口令 key 签两份测试回执 | **成立，但前置未满足**——见 §4 |
| ④ `check-no-owner-creds.sh` 首版 | **成立，但必须降级定位**：它是**卫生检查**，抓意外泄漏；**不是边界**，抓不了对手（agent 可改它）。脚本自己必须写明这一点，否则下一轮会有人把它当边界 |
| ⑤ 宿主取证 | 本文 |

## 4. `runtime` 轮 `R2` 前置的当前状态：**未满足**

`R2` 裁定：先有 agent 够不着的操作面，再谈回执仓与三把 key，否则是同一信任域里搬家。

现状：所有者的 Cursor 与 Qoder 均 Remote 连入本 VM（`~/.cursor-server`、`~/.qoder-server`），
在其中开的终端就是本 VM 的 shell，与 agent 同机、同用户、同免密 sudo。
**所以「在 Windows 上签」若通过 Remote 终端执行，等于在 VM 上签。**

满足该前置只有两条路（都要所有者做，agent 无法代劳）：

| 路 | 内容 | 代价 |
| --- | --- | --- |
| **A** | 在 Windows **本地** shell（非 Remote）操作：本地 clone 回执仓、本地生成带口令签名 key、本地签、本地 push | 需要 Windows 侧有 git 与 gpg/ssh-keygen；签名私钥永不上 VM |
| **B** | 收紧本机：移除 `zym` 的免密 sudo 与 docker 组，另建专用低权用户跑 agent | 改变你自己的日常操作方式；且 agent 当前就在 `zym` 下跑，收紧过程本身要在 agent 够不着的时机做 |

**A 是 S1 的直接路径，B 是让本地强制点重新有意义的路径。二者不互斥，但 A 必须先做**——
没有 A，③ 的两份测试回执与 VM 上 agent 造的回执不可区分，S1 验收判据②③失去意义。

## 5. 覆盖声明

**查了**：`sudo -n -l`、`docker info`、`id`、`/proc/self/uid_map`、`~/.ssh/` 私钥加密状态与权限、
`~/.git-credentials` 存在性与权限与目标域名、`git config --global credential.helper`、
`gpg --list-secret-keys`、两个 remote 的 `push --dry-run`。

**没查**：托管方侧的 key 列表与作用域（需登录 GitHub / gitee，凭据在所有者手里）；
Windows 侧是否已装 git / gpg；gitee 是否提供 `.gpg` 公钥端点（`runtime` 轮开放问题 `A3`，仍未验证）。

**没做**：未实际 push（全部 `--dry-run`）；未修改 sudoers、docker 组或任何凭据；未生成任何 key。
