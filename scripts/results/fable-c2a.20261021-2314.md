# fable-c2a 回执：域名与端口参数化、值不变——开发站点渲染与 C1 结果一致（两处摘要修正已判定接受），六项只读入口通过（Fable 经隧道在本地跑）

WS=fable，分支 fable，代码提交 `ce33ccc1`。改前基线 = C1 的改后渲染（`~/sunmoon-probe-runs/c1-20261021-2008/after`，提交 24fe662b，代码与 C2a 前相同）；改后在本地主工作树从干净 `.build/components` 渲染（`~/sunmoon-probe-runs/c2a-20261021-2251/after`）。

## 一、字节对比

| 项 | 结果 |
| --- | --- |
| `diff -r` | 3 个文件：knowbench `domain.sops.yaml`、knowbench 与 knowfeed 的后端 `runtime/workload.yaml` |
| sops 文件 | 解密明文 sha256 before == after（`40e4198783be2cc2…`），密文差异为 sops 不确定性 |
| 两个 workload | 只有 `config-sha256` 注解变化。原因：这两份后端配置本来含 Jinja，旧摘要算的是 `lookup("file")` 重读的未展开原文，新摘要算 `lookup("template")` 展开后的值；Pod 的 env 一直是展开值。**判定接受**（下次发布这两个后端各滚动一次），记入 0039 C2a 实施记录 |
| PLAN | 除 make 回显的命令行前缀（上一轮 Cursor 的会话经 nsenter）外相同 |
| CONFIG | IDENTICAL（62 行） |

远程：`platform-plan OBJECT=all`、`edge-plan`（东京，只读）通过；`lookup("template", …, convert_data=False)` 在 Ansible 2.21.4 上实测把配置里的 `{{ site_domain }}`、`{{ public_port }}` 展开、键序不变。

## 二、只读入口（本地，HEAD ce33ccc1）

| 命令 | 结果 |
| --- | --- |
| `make cluster-dns-check` | `"passed": true` |
| `make platform-status OBJECT=all` | failed=0 |
| `make platform-account-plan OBJECT=registry` | failed=0 |
| `make platform-check OBJECT=data-platform/object-storage` | `"passed": true`，failed=0 |
| `make entry-status`（`entry_port` 已改为派生） | failed=0 |
| `make jenkins-agent-check` | render-check #129 <result>NOT_BUILT</result> diff=? |

日志在本地 `~/sunmoon-probe-runs/c2a-20261021-2251/`（checks/、diff.txt），不进 git；没有口令、密文进本页。

## 三、结论

C2a 关闭。下一步 C2b：开发站点改 `dev.sunmoonai.com`，要所有者先做三件事（公网 DNS、本机 hosts、Jenkins 点批），见 0039 C2 节。

exit=0
