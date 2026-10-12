# 给 astra：代理 0.4.0 服务流——文件只读 + 设置写入（账 87，SDD 0022）

> 所有者 2026-10-12 「开工 87」后远程写本页。**2026-10-12 晚改一处**：读文件一次 ≤ 512 KiB 原文（你回执里的帧上限问题，远程算错，谢谢），其余不变；基线仍 `ef6f33f`。设计全文在 [`tree-build/SDD/modules/0022-agent-service-channel.md`](../../../tree-build/SDD/modules/0022-agent-service-channel.md)，**方法名、参数、错误码、限额都以它为准，不要改形状；设计走不通先停下写清楚交远程**。`runtime` 仓，fable 分支，基线 0.3.1 = `5ccca65`。本地提交，不 push，不合并别的分支；版本三处改 **0.4.0**。每段一个或几个提交，提交说明写清改了什么、怎么验的；做完写回执，所有者同步回去，远程审读。

## 一、要做的（两段，段 1 过了再做段 2）

### 段 1：服务流 + 三个只读方法

| 处 | 做什么 |
| --- | --- |
| `relayProtocol.ts` | `ControlMessage` 的 `open` 加可选 `kind?: "service"`；控制通道 hello 加 `capabilities: ["service-v1"]`（新字段，旧会合点忽略） |
| `relayClient.ts` | `openStream(conn, kind)`：`kind === "service"` 时**不连 exec-server**，把上行文本帧交给 `ServiceHandler`，回包发回同一条流；服务流计数独立（`stats.service`），同时最多 2 条，第 3 条直接关掉并记日志；沙箱流那条代码路径一个字节不动 |
| `service.ts`（新） | JSON-RPC 2.0 分发；限速：每流 4 个未完成请求、每秒 50 个（超了回 `-32013`）；单帧 > 1 MiB 直接断流；方法：`service/hello`、`fs/readDirectory`、`fs/getMetadata`、`fs/readFile`，字段与错误码按 0022 第三节 |
| 白名单检查 | 路径是用户电脑上的绝对路径（不是 URI）；`canonicalPath` 规整后必须在 `roots` ∪ `libraryDir` 之下（`libraryDir` 段 2 才有，段 1 只有 `roots`）；`codexHome`、`CONFIG_DIR`、`.sandbox-secrets`、`auth.json` 一律拒；符号链接 / junction / 8.3 短名 / 设备名 / ADS 按现有 helper 的身份检查拒 |
| 读 | Windows 上经**现有的沙箱内文件助手**（`WindowsFiles.call`，目录钉住与身份检查都在）；Linux 上直接 `node:fs`（只为单测）。`fs/readFile` 一次 ≤ **512 KiB 原文**（`length` 默认与上限 `524288`，超过回 `-32602`；base64 后约 683 KiB，稳在 1 MiB 帧内——你 17:38 回执指出的 1 MiB 原文超帧问题，远程 2026-10-12 晚已改合同），`offset/length` 分段，文件 > 64 MiB 回 `-32011`；目录 > 2000 项截断并 `truncated:true` |
| 日志 | 只记方法名、错误码、次数，不记路径与内容 |

**单测**（`test/service.test.ts` + `relayClient.test.ts` 补一组）：白名单外路径；符号链接指向白名单外；`..` 与大小写 / 短名变体；超大文件拒绝；`length` 超 512 KiB 回 `-32602`；分段读拼回原文；512 KiB 原文的回包帧 < 1 MiB；目录截断；每秒 51 个第 51 个 `-32013`；5 个并发第 5 个 `-32013`；单帧 1 MiB + 1 字节断流；第 3 条服务流被关；`open` 不带 `kind` 仍走 exec-server。

**真机**（Windows）：用远程给的本地会合点（段 0，见下）或你自己照 0022 第六节改一份 `relay.py` 起在本机，用一个小脚本当工作台连 `/service`：`service/hello` 回 roots；读白名单下一个中文文件名的文件；读一个 5 MiB 文件分 10 段；读 `%USERPROFILE%\.codex` 下的文件被拒；读白名单外被拒；`curl` 不带令牌连 `/service` 被拒。

### 段 2：设置读写

| 处 | 做什么 |
| --- | --- |
| `service.ts` | `settings/read`（与托盘「设置」窗同一份：`machineName, roots, rootChoices, ceiling, autostart, libraryDir, version`）；`settings/write`：校验复用 `preferences()` 那套（目录存在、≤ 32、选项 ⊆ 候选、沙箱只 `read-only`/`workspace-write`）；**放宽判定按 0022 第四节**——有放宽项就弹本机确认窗（前台 `localConfirm`、后台 `windowsConfirm`，随机码、60 秒，无 TTY/超时/断线即拒），**一次合成一窗**；拒绝或超时整条不写；收窄直接写；一条流同时只处理一个 `settings/write`，第二个回 `busy` |
| 应用 | 写 `config.json` 后先回 `{applied:true, restart:true}`，再触发常驻进程重启（现有 stop-request + 自启 / `startResident`），重连时 hello 重报 roots 与 ceiling |
| `libraryDir` | `config.json` 新字段（可空）；`validate` 校验是本地绝对路径且存在；加入白名单检查的集合；**不**加进 `roots`（它只读，0019 N1 的 Codex `reads` 由远程那头做） |
| `autostart` | 读写复用现有 `autostart enable|disable|status` |
| 托盘「设置」窗 | 加「本地知识库目录」一项（选目录 / 清空），和白名单同一处（0019 §二 第 19 行说的） |

**单测**：放宽项（加目录、抬沙箱、开网络、设知识库目录、开自启）各一例需确认；收窄项各一例直写；多项放宽只问一次；确认拒绝后 `config.json` 字节不变；`busy`；无效输入 `-32602` 且不弹窗。
**真机**：从一个小脚本发 `settings/write` 加目录 → 确认窗出现、文案含目录名 → 同意 → 代理重启 → 托盘「设置」里出现该目录 → 控制通道 hello 的 roots 含它；再发去掉该目录 → 不弹窗、直接生效；发抬沙箱但在窗里拒绝 → 配置不变、回 `local_denied`。

## 二、段 0（远程做，不用等）

会合点 `/service` 路径与 `open.kind` 远程**已改好**（k8s fable，`sunmoonai/relay-platform/relay/relay.py`，说明在同目录 `service-v1.md`，测试 `tests/test_service.py`）；你的单测用假会合点即可，真机联调时 `git -C ~/worktrees/fable/k8s pull` 拿最新 `relay.py` 在本机起（`python relay.py`，环境变量见其文件头），不必等发布。

## 三、规矩

- 不改 `filter.ts`、`windowsPolicy.ts`、`windowsBridge.ts`、配对协议、令牌处理；服务流**不起进程、不写文件**（`settings/write` 只写 `config.json`）。
- 路径与文件内容不进日志、不进回执。
- 不结束与 SunMoon 无关的进程；zip 与回退目录放 `~/sunmoon-probe-runs/`，不进任何 git 仓；不动现装的 0.3.x（真机测试用源码跑 `start`，或装到临时目录）。
- 回执放 `runtime/scripts/results/windows-agent-0.4.0-*.20261012.md`（或当天日期）：每段原文输出、真机证据、没做到的明说，不写「应该可以」。
- 版本：`agent/package.json`、`src/cli.ts` 的 `VERSION`、`distribution/windows-x64.json` 改 **0.4.0**。
