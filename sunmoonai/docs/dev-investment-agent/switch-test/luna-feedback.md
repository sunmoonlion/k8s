# 远程对 luna 的审读意见（Windows 代理）

> 只追加，不改旧条。每条对应 `luna-task-windows-agent.md` 的一个停点。luna 读到「可以进下一段」就进；要改的，改完在下一个停点一起交。

## 2026-10-07 · 第 0 段（runtime `e9f194b`）

**结论：第 0 段通过，可以进第 1 段。**两问的判定我这样定：

| 问 | luna 的结论 | 远程的判定 |
| --- | --- | --- |
| 1 无管理员、unelevated、不跑 setup | undecidable（模型认证 403） | 接受不用模型。**改用直接发 `process/start`**：连 exec-server，`environment/add` 后发 `process/start`（沙箱 `workspaceWrite`、网络关），命令是往 cwd 外写文件（用户目录内、用户目录外各一个），再往 cwd 内写一个；elevated（已做过 setup 的家）、unelevated（新家、不 setup）各跑一遍。看的是内层 Codex 沙箱挡不挡。这一项并入第 1 段的第一件事，不另设停点 |
| 2 exec-server 包进外层 | pass（文件写边界） | 接受。`codex.exe sandbox --permission-profile … -- codex.exe exec-server …` 就是 Windows 上 bwrap 那一层的对等物，第 1 段的 `outerSandbox.ts` 按这个做。结论「只改执行端 config 不能给 `sandbox:null` 的文件请求加上限」是对的：产品里始终是外层 + 桥内过滤两层，和 Linux 一样 |

做得好的：不把「文件没生成」当通过；对照组；真实帧入仓；清理清单；没动产品代码。

**第 1 段里一并处理的（来自这次报告）：**

1. 过滤的判定只看 `params.path`（`agent/src/filter.ts` 第 83 行），所以 `data_base64` 和实际的 `dataBase64` 不影响放行与拒绝；但 fixture 要换成这次抓到的真实帧（`clientName`、`initialized`、`dataBase64`、`file:///C:/…`），`probe/frames.jsonl` 空着的就删掉或填上。
2. Windows 路径判定：`file:///C:/Users/...` 与白名单根比较要规范化盘符大小写、分隔符，并且不分大小写；用真实帧写测试（任务书第 1 段已列）。
3. 外层沙箱下嵌套执行（`process/start` 在被包住的 exec-server 里起子进程）能不能跑、`arg0`/PATH 的 `os error 5` 警告是不是真有影响：第 1 段联调时核，核完写进结果。
4. 干净 Windows、Windows 10 的覆盖放到第 3 段装安装包时做，第 1、2 段不需要。
5. 「本机历史上做过 elevated setup」这一条记着：第 1 段 `init` 探测沙箱模式时，要能区分「本机有 elevated 环境」和「没有」，别只看配置文件。

不用改的：报告与 CHECKPOINT 的写法保持；`scripts/results/` 继续只追加。

## 2026-10-07 晚 · 第 1 段中途（runtime `36ec68b`）：沙箱承载方案定了

**决定（所有者 2026-10-07 采纳 luna 的意见）：同意按「内层沙箱 + 严格协议过滤」继续第 1 段。Windows 不做外层，两层嵌套在 0.155.1 上起不来（`CreateRestrictedToken failed: 87`、elevated 超时），不再试。** 但下面几条补齐并通过攻击性用例之后才放开 Windows 启动；不能只凭一次真实路径解析就认定安全。

| 要补的 | 内容 |
| --- | --- |
| 命令权限检查完整 | `process/start` 不只看模式、cwd、workspaceRoots：请求里每一项实际写权限都核；关闭内层沙箱（`sandbox: null` / `none`）、扩大可写目录、放开网络，高于上限的一律拒 |
| 协议入口收紧 | 只放行明确列出的方法；未知方法、二进制帧、没列的消息一律拒并记日志。**读也限在白名单 + 代理自己的 codex-home**（`fs/readFile`、`fs/open`、`fs/readDirectory`、`fs/walk` 等目标在外面就拒）；这一条比 Linux 现状严，Linux 以后跟上 |
| 文件操作的目录联接与竞态 | 检查时路径在白名单内、执行前被换成联接指向外面，这种「检查后替换」要堵。**优先把 `fs/writeFile|createDirectory|remove|copy` 改为由受限执行环境实施**：桥不直接转发，而是在 Codex 的 Windows 沙箱里（白名单可写的 profile）跑一个小助手完成写入，由 OS 挡，竞态自然没了；做不到或代价太大，就必须用攻击用例证明别的办法挡得住替换（联接、符号链接、硬链接、大小写、8.3 短名、`\\?\` 前缀各试） |
| 验收 | 加一组攻击性用例（上面每一项至少一个），全部被拒才算；写进 `agent/test/`，Windows 上跑 |

说明：「和 Codex 自己给 Windows 用户的做法一样」说过头了，只是复用了它的内层沙箱；我们的请求来自远端，安全性取决于桥。官方也说 `unelevated` 隔离较弱——所以 `init` 探测到本机有 elevated 环境时优先用 elevated，没有才用 unelevated，并在状态里写明用的是哪一种。

两处顺手的：

1. 任务书里会合点端口写错了：网页「设置」发的 `init` 命令是 `wss://relay.sunmoonai.com:30443`（走入口），不是 30471。任务书已改，以网页发的为准。
2. Windows 启动「准入没过就拒绝」是对的，保留；上面四条做完、用例全过，再放开。`--no-outer-sandbox` 这个开关在 Windows 上没有意义，去掉或忽略即可。

设计文档 `SDD/modules/0005-agent.md`「本地上限由谁挡」已加 Windows 一段。

## 2026-10-08 · 第 1 段中途：文件写助手不用 Python；应用控制拦未签名 exe

1. **不加 Python 依赖。** 用户机器上只装一个东西（`0005-agent`「分发与安装」），Node、Python、Git 都不要求。助手用我们本来就带的 Node 跑：一个 `helper.mjs`，写入命令是 `codex.exe sandbox --permission-profile <白名单可写> -- node.exe helper.mjs <参数>`。边界由 Codex 沙箱在 OS 层挡，助手里普通 `fs.writeFile` 即可，不需要句柄级接口——联接跟出去会被沙箱拒，这正是把写入放进沙箱的目的。开发时用本机 Node 24；安装包里带官方签名的 `node.exe`。攻击用例照样全跑。
2. **应用控制把新编译的未签名 exe 拦了，这是打包的硬约束。** 说明开着 Smart App Control / WDAC 的机器上，「不签名、点仍要运行」这条路也走不通。所以第 3 段打包**不编译自己的 exe**：包里只放签过名的 `node.exe`、`codex.exe` 和我们的 JS；启动与开机自启走计划任务拉 `node.exe`，快捷方式也指向它；托盘若必须是原生窗口再单独议。把这台机器的应用控制状态（`Get-MpComputerStatus`、Smart App Control 开关、是否有 WDAC 策略）记进结果，第 3 段要在这种机器上装一次。
