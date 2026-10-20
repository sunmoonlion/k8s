# rename（0028）R4 回执 — Qwen（本地机）

- 手册 `docs/process/rename-2026-10-15/README.md` R4（本地机 Qwen），HEAD `63cdfa5c`（R3 通过）。执行者：Qwen（本地机），2026-10-17 12:28。
- 命令照手册 281–283 行用 bash 跑；repos.conf 只读核对（toolboxes 的 git 不碰）；最后跑 `WS=qwen bash ~/switch-test/human-local.sh`（窗口结束验证）。

## 1. config.sh 改名（含备份）

备份：`cp config.sh config.sh.bak-rename-0028`。diff 恰好两行（与 R4-opus 一致）：

```
22,23c22,23
<   "investment-app"
<   "runtime"
---
>   "knowbench-app"
>   "sunmoon-link"
```

改后 REPOS 数组全文：

```
REPOS=(
  "tpl-app"
  "knowbase-app"
  "k8s"
  "knowfeed-app"
  "knowbench-app"
  "sunmoon-link"
  "knowlab-app"
  "knowmart-app"
)
```

## 2. repos.conf 核对（只读）

`grep -n "master/" ~/toolboxes/Vlinux/utils/set-up-tools/model-switch/repos.conf`：

```
3:$HOME/master/k8s
4:$HOME/master/knowfeed-app
5:$HOME/master/knowbench-app
6:$HOME/master/knowbase-app
7:$HOME/master/tpl-app
8:$HOME/master/sunmoon-link
9:$HOME/master/knowlab-app
10:$HOME/master/knowmart-app
```

旧名（investment-app / runtime）零命中。toolboxes 已由所有者拉到 `a558370`（repos.conf 新名入库）。

## 3. WS=qwen bash ~/switch-test/human-local.sh

exit=0。八仓远程+本地全 OK：

```
==> 检查远程五仓
  OK  tpl-app
  OK  knowbase-app
  OK  k8s
  OK  knowfeed-app
  OK  knowbench-app
  OK  sunmoon-link
  OK  knowlab-app
  OK  knowmart-app

==> 检查本地五仓（目标端）
  OK  tpl-app
  OK  knowbase-app
  OK  k8s
  OK  knowfeed-app
  OK  knowbench-app
  OK  sunmoon-link
  OK  knowlab-app
  OK  knowmart-app
```

knowbench-app、sunmoon-link 均 Already up to date（R3 已是最新）。同步汇总：

```
==> 同步完成：远程 -> 本地
  k8s                          63cdfa5c
  knowfeed-app                 cf687a0
  knowbench-app                3fa5a54
  knowbase-app                 25942e2
  tpl-app                      65b8b11
  knowlab-app                  2011125
  knowmart-app                 fcf8613
  knowbench-app/knowbench-backend cc95605
  knowbase-app/knowbase-backend 6d71e10
  sunmoon-link                 130c966
```

最后一句：

```
===== 同步完成。对哪个助手说「请看 inbox/<它的名字>」，它就只看那个箱子。（每条做完自己本地提交；推回用 human-remote.sh）
```

改名窗口结束。inbox/qwen 有一条待办：`2026-10-16-qwen-004-sso.md`（单点登录上线）。

exit=0
