# 现在做什么

所有者在你窗口里说「看一下 `~/master/k8s/sunmoonai/docs/dev-agent-task/composition/protocol/GO.md`，照做」，就从这里开始。每个环节都一样。

⚠ **只认主线这一份。**你 worktree 里也有一份同名文件，但你的分支从 ① 起就不再跟进主线，那份是旧的。先自检：

```bash
diff <(git -C ~/master/k8s show master:sunmoonai/docs/dev-agent-task/composition/protocol/GO.md) \
     sunmoonai/docs/dev-agent-task/composition/protocol/GO.md >/dev/null \
  && echo "本地与主线一致" || echo "本地已过期，只读主线这份"
```

过期了就读主线这份。**不要把主线合并进你的分支**——会和主线上的记录文件冲突。

## 一、你是谁

```bash
pwd && git rev-parse --abbrev-ref HEAD
```

工作目录是 `~/worktrees/<名>/k8s`，这个 `<名>` 就是你。分支应当是 `<竞争名>/<名>`，竞争名看本次竞争的 `round.md`。对不上就停下来问，不要自己切分支。

产品名、模型名、界面上显示的名字，都不算身份依据。

## 二、现在是哪个环节

按 `competition-protocol.md`「收到『继续』时怎么办」定位。环节按协议「环节判定」一节的判据从 git 提交推出来，不看任何人的说法。

由组织者按上述判据核对，并在本环节通知里写明当前环节和还缺谁。**缺的名单里有你，这一步就是你的。**

## 三、读通知，照做

读组织者给出的本环节通知。通知写明交什么、交到哪、按什么判。

找不到通知时，当场 `ls` 本次竞争的目录确认，不要按以前的竞争推断有没有通知。

同目录下还有工单 `round.md` 和裁定 `rulings.md`，都在主线读。要处理的对象（别家产物、裁决稿）以通知里给的位置和提交为准，不以你自己的 `HEAD` 为准。

## 四、四条不能违反的

本节只是摘录，规则原文在协议里，两边不一致以协议为准。

1. 只写你自己的工作区，不写主线、不写别家（`competition-protocol.md` §17）。读主线用绝对路径，提交用 `git -C`。
2. 提案冻结之前，不读其他家的候选（`competition-protocol.md` §9）。
3. 交卷 = 你自己分支上已提交的 commit，没提交的不算（`competition-protocol.md` §8）。
4. 超出本次输入的断言，附一条可复跑的证据，否则标 ⚠（`competition-protocol.md` §12）。不要写「我之前查过」。

## 五、卡住了怎么办

所有者开着你的窗口。遇到下面任何一种情况，停下来把问题说清楚，不要猜着往下做：

- 判据看不懂，或两条判据互相矛盾；
- 需要的输入不存在，或和通知写的不一样；
- 要动的东西超出你自己的工作区；
- 命令失败了，你不确定原因。

## 六、交卷

```bash
W=~/worktrees/<你的名>/k8s
git -C $W add <产物路径>
git -C $W commit --author="<你的名> <<你的名>@agents.local>" -m "<环节> <竞争名> <产物名>（<你的名>）"

git -C $W show HEAD --stat                                                          # 产物应在这次提交里
git -C ~/master/k8s status --porcelain                                              # 应为空
```

`--author` 不能省：本机的 git 身份是所有者的，不署自己的名，你的提交会被当成所有者本人的提交。

提交之后一定核对一次：产物路径、分支都要和通知一致。路径或分支不对时，组织者认不出你的产物，而**没有任何东西会报错**——你会以为交了。
