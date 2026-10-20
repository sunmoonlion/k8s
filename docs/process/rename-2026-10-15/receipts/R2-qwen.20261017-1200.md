# rename（0028）R2.1 回执 — Qwen（本地机）

- 手册 `docs/process/rename-2026-10-15/README.md` R2.1（GitHub 5 个、gitee 父仓 1 个），HEAD `9f089779`（R1 通过、R2.1 可以做）。执行者：Qwen（本地机），2026-10-17 11:57–12:00。
- 命令块照手册 163–180 行用 bash 跑（`/tmp/r2.sh`）；其中 `read -rs GITEE_TOKEN` 一行按该行注释授权改用 R0 的做法（`git credential fill` 取 `~/.git-credentials` 的 oauth2 令牌），其余逐字。令牌只在本机内存与 stdin，不进回执、不进日志、不进 Git。只改名，不新建、不删。

## 改名前基线（ls-remote，改前采集）

| 仓（旧名） | 平台 | master | qwen |
| --- | --- | --- | --- |
| investment-app | GitHub | 70af7cff | 3fa5a549 |
| investment-backend | GitHub | 9195b1bb | cc95605c |
| investment-web-frontend | GitHub | 25b3511a | ceb30875 |
| investment-admin-frontend | GitHub | 163fdbb1 | 45fcf79a |
| runtime | GitHub | 0e4b1c84 | 130c966a |
| investment-app | gitee | 70af7cff | 3fa5a549 |

qwen 五个值与 `R1-opus` 回执（`3fa5a549`/`cc95605c`/`ceb30875`/`45fcf79a`/`130c966a`）逐一相同；gitee investment-app 与 GitHub 相同。

## 改名动作与返回

- GitHub：`gh repo rename -R sunmoonlion/<旧> <新> --yes` 逐条，5 条全成功：

```
GitHub 改名  investment-app → knowbench-app
GitHub 改名  investment-backend → knowbench-backend
GitHub 改名  investment-web-frontend → knowbench-web-frontend
GitHub 改名  investment-admin-frontend → knowbench-admin-frontend
GitHub 改名  runtime → sunmoon-link
```

- gitee：`PATCH /api/v5/repos/sunmoonlion/investment-app`，body 同带 `name=knowbench-app` 与 `path=knowbench-app`（名称与路径两字段都改）→ **HTTP 200**：

```
gitee 改名  investment-app → knowbench-app  HTTP 200
```

## 改名后核对（新地址 ls-remote，脚本尾段原样输出）

```
knowbench-app              github qwen=3fa5a549 master=70af7cff
knowbench-backend          github qwen=cc95605c master=9195b1bb
knowbench-web-frontend     github qwen=ceb30875 master=25b3511a
knowbench-admin-frontend   github qwen=45fcf79a master=163fdbb1
sunmoon-link               github qwen=130c966a master=0e4b1c84
knowbench-app              gitee  qwen=3fa5a549 master=70af7cff
```

核对「要看到」：

- 5 行「GitHub 改名」✅；gitee `HTTP 200` ✅
- 新地址都列得出分支；`qwen` 五个值等于 `R1-opus` 记下的提交号 ✅；gitee knowbench-app 的 qwen 亦为 `3fa5a549` ✅
- `master` 与改名前基线逐仓相同（改名不动提交）✅

## 地址对照（旧 → 新）

| 平台 | 旧地址 | 新地址 |
| --- | --- | --- |
| GitHub | sunmoonlion/investment-app | sunmoonlion/knowbench-app |
| GitHub | sunmoonlion/investment-backend | sunmoonlion/knowbench-backend |
| GitHub | sunmoonlion/investment-web-frontend | sunmoonlion/knowbench-web-frontend |
| GitHub | sunmoonlion/investment-admin-frontend | sunmoonlion/knowbench-admin-frontend |
| GitHub | sunmoonlion/runtime | sunmoonlion/sunmoon-link |
| gitee | sunmoonlion/investment-app | sunmoonlion/knowbench-app |

## 其他

- R2.2（gitee 三子仓与 sunmoon-link）**未做**——手册写明等所有者定，定了再填命令。
- 改名窗口内未跑同步脚本；本地检出与 remote 指向的换名属 R3/R4，未动。
- 口令、令牌未出现在本回执与任何命令输出（gitee 返回码只记 HTTP 200）。
- 临时脚本 `/tmp/r2.sh` 为手册指定落点（/tmp，非工位目录），保留备 Opus 复核逐字性。

exit=0
