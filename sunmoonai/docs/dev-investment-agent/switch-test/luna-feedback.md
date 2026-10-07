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
