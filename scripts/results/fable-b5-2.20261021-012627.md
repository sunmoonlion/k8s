# fable-b5-2 回执：docs 新路径与转发器（luna）

2026-10-21 Asia/Shanghai，WS=fable，分支 fable，基线 `46b400c03`。初始工作区干净，`git pull --ff-only origin fable` exit=0，从 38cb06ecb 快进到基线。

结果：**新目录、转发器、两项门禁通过；坏链数量与 12 条基线一致，但“全部在 done”的描述不符，交远程核对，不自行改判据。** 没有为了坏链去改历史卡或其它文档。

## 一、目录与基线

原始输出 `fable-b5-2.20261021-012627.01-path-verification.txt`：

```text
docs: README.md design ops process project-guide reference 总纲
docs/process: README.md pipeline.md rename-2026-10-15 switch-test tools turn
docs/ops: README.md jenkins-使用说明.md
ls: cannot access 'docs/dev-investment-agent': No such file or directory
old path ls exit=2
check-links: 12 broken link(s)
check-links exit=1
```

`ls` 退出 2 和 check-links 退出 1 都是本卡已知预期：旧目录不在、存在 12 条基线坏链。检查工具输出原文完整保留。

实际分布 **9 条在 docs/process/switch-test/done，2 条在 docs/reference/技术笔记/Flower使用文档.md，1 条在 infrastructure/services/README.md**。卡称“都是 done 里的历史卡”，所以我对该项的断言失败，整份 `.01` exit=1，未掩盖失败。没有去修坏链、调整断言后重新报全过。

另外三条原文为：

```text
docs/reference/技术笔记/Flower使用文档.md: ../../../sunmoonai/app-platform/docs/Celery监控机制说明.md
docs/reference/技术笔记/Flower使用文档.md: ../../../sunmoonai/messaging-platform/rabbitmq/README.md
infrastructure/services/README.md: layout.yaml
```

只读补核：这三个引用在迁移前提交 38cb06ecb 的同路径文档中已存在，当前引用目标都不存在；没有把它们判成此次迁移新引入的坏链，也没有据此宣称基线完全相同已获远程审定。

第一节其余项目单独完成：上两张卡 B4b / B5-1 的 tracked done 文件计数为 2，infrastructure/README.md 第三行以 `> 地图位置` 开头。原始输出 `fable-b5-2.20261021-012627.02-path-remainder.txt`，exit=0。

## 二、重写两个转发器

严格按卡的 here-document 写回：

```text
/home/zymun/switch-test/human-local.sh:4:exec bash "$HOME/worktrees/$WS/k8s/docs/process/switch-test/human-local.sh" "$@"
/home/zymun/switch-test/human-remote.sh:4:exec bash "$HOME/worktrees/$WS/k8s/docs/process/switch-test/human-remote.sh" "$@"
```

两个文件可执行，WS 必填的 guard 与参数转发保留，仓内两个目标都存在；没有调用同步脚本或使用 --after-sync，没有删除 switch-test 下其它内容。

原始输出 `fable-b5-2.20261021-012627.03-forwarders.txt`，exit=0。另逐个执行 `bash -n <转发器>`，各 exit=0，只解析语法；`fable-b5-2.20261021-012627.05-forwarder-syntax.txt` exit=0。初次一次 bash -n 带两个路径只会把第二个当参数，故补了逐文件检查，没有声称跑过同步。

## 三、新路径门禁与本机配置

起始 `git config --get core.hooksPath` exit=1、值为空，并不是卡预期的 .githooks。按新门禁说明和钩子文件中已有安装指令执行：

```bash
git config --local core.hooksPath .githooks
git config core.hooksPath
python3 docs/process/tools/doc-gate.py docs/process/switch-test/README.md docs/ops/README.md
python3 docs/process/tools/anchor-gate.py
```

输出：

```text
.githooks
doc-gate: 活文档 2 份检查通过
anchor-gate: 钉 commit 锚 2 通过；裸路径行号锚 0 通过；章节号引用 0 处（软判，交人）
```

各命令 exit=0，原始输出 `fable-b5-2.20261021-012627.04-new-path-gates.txt` exit=0。保留完整输出，不用 tail 掩盖上游退出码。

## 四、就地修了什么

未改仓内源码或通过标准。按卡重写两个仓外转发器；按现有安装说明启用原来未设置的本机 core.hooksPath。这是共享仓的本地配置，会供该仓 linked worktree 使用，不变更其它工位分支或工作区文件；没有覆盖既有非空 hooksPath，没有绕过门禁。

没有动控制器、代理、集群、gitops 或 Harbor。尚待远程核对的是卡对 12 条基线的分布说明，不是请求清理或修复历史内容。

## 五、交回

回执、5 份原始输出、远程核对请求与本卡移动一并提交推 origin/fable。卡移 done 表示执行已交回，不代表那条基线描述已由本地改判。新收件箱路径从此使用 docs/process/switch-test/inbox/luna/；历史回执不改路径。

exit=0
