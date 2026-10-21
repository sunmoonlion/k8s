# fable-c1 回执：C1 集群身份与路径参数化——开发站点渲染逐字节相同，五项只读入口通过（Fable 经隧道在本地跑）

WS=fable，分支 fable，代码提交 `76a6334f` → 修一 `fc37a4e8` → 修二 `c86f5739`，判定提交 `24fe662b`。改前基线 `c2d0dbb5`（Cursor 在临时 worktree 冷渲染，`~/sunmoon-probe-runs/c1-20261021-2008/before`），改后由 Cursor 从干净 `.build/components` 渲染（`after`）；第三节判定与第四节由远程 Fable 经反向隧道在本地执行（所有者 2026-10-21 夜定：平台线不再派卡给本地助手）。

## 一、字节对比（Cursor 第三轮 + 远程判定）

| 项 | 结果 |
| --- | --- |
| `diff -r before/components after/components` | 只剩 `app-platform/knowbench-app/knowbench-backend/runtime/domain.sops.yaml` 一个文件 |
| 该文件解密后明文 sha256（备份 age 身份，只打印哈希） | before `40e4198783be2cc2…` == after `40e4198783be2cc2…`；已提交那份 `0a0310dad870afd6…`（输入早已变过，两边都重新加密，密文差异为 sops 不确定性） |
| PLAN | IDENTICAL |
| CONFIG | IDENTICAL（62 行） |
| **判定** | **RENDER 视为 IDENTICAL**（规矩补入 0039：`*.sops.yaml` 比明文哈希） |

三轮比对各抓到一个真问题并已修：① 应用配置被 `lookup("file")` 重读不过 Jinja（修一：路径字段改由加载处推出）；② 运行配置摘要按键序算（修二：插回原位）；③ 主工作树 `.build` 残留候选（卡改为冷目录起步）。

## 二、第四节：改到的入口各跑一次（只读，本地 `~/worktrees/fable/sunmoonun/infrastructure`，HEAD 24fe662b）

| 命令 | 结果 |
| --- | --- |
| `make cluster-dns-check` | `"passed": true`，`max_ms: 5.6`（check-dns.py 只读站点文件） |
| `make platform-status OBJECT=all` | 两段 recap 均 failed=0 |
| `make platform-account-plan OBJECT=registry` | failed=0（账号路径守卫改读 `SUNMOON_DATA_ROOT`） |
| `make platform-check OBJECT=data-platform/object-storage` | `"passed": true`，三段 recap failed=0（verify.py 新 `--context` 参数） |
| `make jenkins-agent-check` | Jenkins render-check **#124 SUCCESS**，`diff.txt` 0 行（排队等了前面的定时构建约 20 分钟） |

原始日志在本地 `~/sunmoon-probe-runs/c1-20261021-2008/section4/`（dns.log、status.log、account-plan.log、object-storage-check.log、render-check.log），不进 git；没有口令、密文进本页。

## 三、结论

C1 关闭：开发站点渲染与改前逐字节相同（sops 文件按明文），五项只读入口通过，render-check SUCCESS。卡移 done。下一步 C2（域名与端口参数化，开发站点改 `*.dev.sunmoonai.com`）。

exit=0
