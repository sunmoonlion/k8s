# fable-c2b 回执：开发站点改到 `*.dev.sunmoonai.com`——已上线、已验收（发布 #8–#15；Fable 起、Opus 5.5 收尾，经隧道在本地跑）

WS=fable，分支 fable。设计与按根因的复盘在 SDD 0039 第四节「C2b 实施记录」，本页只记事实与证据。日志在本地 `~/sunmoon-probe-runs/c2b-20261022-0920/`，不进 git；本页没有口令、令牌、密文。

## 一、结论

| 验收项（SDD 0039 C2b） | 结果 |
| --- | --- |
| release SUCCESS | #13（六应用，提交 115b5933，tag `release-20261022-4`，回执 `release-13.20261022-200425.md`）；#15（knowbench，26c09b6b，`release-20261022-6`，`release-15.20261022-205742.md`） |
| 所有者浏览器用新名字登录 | 所有者 2026-10-22 晚登录 `knowbench.dev.sunmoonai.com:30443` 成功 |
| `application-check` | #13 第 11 阶段六应用通过；另以直接调用（只打报错行）核过六应用的完整登录流程 rc 0，knowbench `admin_list_read`、`install_command_issued` 为 true |
| 东京公网入口（远程机实测） | knowbench.dev 307（去登录）、casdoor.dev `/` 403（管理界面不对公网）、relay.dev 426（要求 WebSocket）、`/api/health` ready；Let's Encrypt 证书到 2027-01-20 |
| Windows 本地代理重连 | 0.5.1，`wss://relay.dev.sunmoonai.com:30443/`，connected（所有者重装并重新配对） |
| 测试电脑重连 | 0.5.1，同一地址，connected（旧配置改名 `config.json.retired-20261022-c2b`，删 Pod，所有者用 knowbot-tester 配对，approved 21:15） |
| 集群 | Flux Kustomization 未就绪 0；六应用 v5 身份任务 Complete，`domain_migrated: ["web","admin"]` |

## 二、提交

sunmoonun：5551dc2c（tls-retire）、1bba26b9（`site_domain: dev.sunmoonai.com`）、47bd654d（casdoor 备份按文件刷新）、10e43489（27 份平台声明重新暂存）、65a7b8f5（tls-retire 可退私钥）、1a15cadb（第三种身份迁移 + 桌面通知 + Jenkins 根地址）、edab078f（identity_revision v4→v5）、a68cdbea（浏览器验收端口）、e91ca24c（代理 0.5.1 发行配置 + 测试电脑 hostAliases 派生）、4509a99c（待办账 157），以及发布写回的 deploy/release 提交。sunmoon-link：7d1e2fc（0.5.1：两份站点文件改新域名）。

## 三、发布经过

| 发布 | 停在 | 原因 → 处置 |
| --- | --- | --- |
| #8 | 第 3 阶段 | Windows 容量守卫 → 所有者授权 prune（构建缓存 125 GB、镜像 43 GB）+ 离线压缩，C 盘 192→313 GB；prune 删掉的 `pull=never` 工具镜像按物料恢复 |
| #9 | 第 10 阶段 | 六个身份任务「Existing browser application differs」→ 1a15cadb |
| #10 | 人为中止 | 审批时限 4 小时不够所有者晚上回来 |
| #11 | 第 10 阶段 | 同名失败 Job 不重跑 → edab078f |
| #12 | 第 11 阶段 | `check-browser.py` 端口 → a68cdbea |
| #13 | — | SUCCESS |
| #14 | 第 12 阶段 | 推送被拒：我在它运行中推了 4509a99c；第 11 阶段检查已过，集群即 #14 内容；tag `release-20261022-5` 单独上了远端（保留，见待办账 160） |
| #15 | — | SUCCESS，写回 Git |

## 四、本地代理 0.5.1

| 项 | Windows | Linux（测试电脑） |
| --- | --- | --- |
| 源码 | sunmoon-link 7d1e2fc，Windows 新检出（`C:\Users\zymun\sunmoon-probe-runs\windows-agent-051-release\src-7d1e2fc`），Windows pnpm 10.24.0 冻结安装 | WSL `~/worktrees/fable/sunmoon-link`，同一提交、porcelain 空 |
| 组包 | 官方 node.exe 24.19.0（摘要 3602f2bb… 与锁定一致）；109 个文件；自检 pass（agent 0.5.1、codex 0.155.1）；编码探针 probe ok | 133 个文件；`verify-linux` verified |
| 包摘要 | zip `2b34d9ca9a0499aabc815018168d5528bf01a7e88635a256dc3e5e518fbcbe9b`，175341351 字节；manifest `1ae548396016aabcd1555f6e9e35d23ab52e41df3eba05841262cb176606ccae` | tarball `7df8d1d22dae49cc894ce79c30e508deb1bd76202827c3533eeee88abb30ec49`，139174222 字节；manifest `46f723b914ee2bde006258e466ea633220c2cccff1fdcff5e338bd1510bfdc27` |
| 上传 | uploaded、readback_verified、writer_read_denied、reader_write_denied 均 true | 同左 |
| 站点 | `dev-kind`：`https://knowbench.dev.sunmoonai.com:30443`、`wss://relay.dev.sunmoonai.com:30443`，内置 CA 不变（与平台 CA 逐字节相同） | `edge-public`：同两地址，系统信任 |

sunmoon-link 测试：typecheck 0；先 build 再 vitest 328 通过、33 跳过（`cli.test.ts` 跑 `dist/cli.js`，不先 build 会有 6 个失败）。

## 五、集群里手工做的（都按名字、有留底）

- 删除 6 个 v4 失败身份 Job 与 6 个 v4 脚本 ConfigMap（所有者同意；删前核过不在任何 Flux 清单里；定义备份在 `retired-identity-v4/`）。
- 测试电脑 `/data/home/.sunmoon-link/config.json` 改名 `config.json.retired-20261022-c2b`，删 Pod 让它重新 init 与配对（所有者定方案 A）。

## 六、我自己做错的（如实）

1. 改注册脚本没升 `identity_revision`（#11 白跑）；提交说明里还写了「v4 失败 Job 会被 Flux 清掉」——错的，集群声明是 `prune: false`。
2. C2a 的 `check-browser.py` 端口改错，C2a 也没跑真实 application-check（#12 白跑）。
3. C2 摸底没扫 sunmoon-link 仓与 test-computer 模板。
4. 发布运行中往 fable 推提交（#14 只能再发 #15）。已记长期规矩。
5. Windows 组包时有一条命令带了 `-ExecutionPolicy Bypass`（只对那一个进程，策略本身是 CurrentUser RemoteSigned、本不需要）；之后都不带。

## 七、留下的事

待办账 157（发布不检查搭车的平台组件）、158（换站点不自动重新配对）、159（sunmoon-link 站点文件派生）、160（原子推送、批前核分支）、161（入口默认后端）、162（prune 保留工具镜像）。c0d 第四节（Windows 重启核对）仍待下次重启。下一段 C4（虚拟机上 kubeadm）。
