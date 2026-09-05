# 环节通知 ②：互评 — 轮次 runtime

> 组织者产物，落盘可复核。四要件（取件 / 对象事实 / 范围门槛 / 交付路径）齐。
> ① 已齐，隔离解除：本环节你**必须**读全部五份候选，包括你自己那份。

## 〇、先确认你是谁

```bash
cd ~/worktrees/<你的名>/k8s          # 必须在仓内，仓外那条命令吐垃圾不报错
r=$(git rev-parse --show-toplevel 2>/dev/null) \
  && basename "$(dirname "$r")" \
  || echo "❌ 不在 git 仓内"
```

三条硬规矩（`rulings.md` `R4` / `R5`，① 已出过一次事故）：

1. **命令跑不出名字就停下报告，不要推理。**
2. **产品名、模型名、你在哪个界面里，全都不是身份证据。**
   已经有一家据此把自己判成了另一家。
3. **只写你自己路径下的文件。**

## 一、对象事实

| 候选 | 分支 | commit | 行数 | sha256[:16] |
| --- | --- | --- | --- | --- |
| luna | `luna` | `1ddff5c2` | 544 | `03785aabb3a631f6` |
| kimi | `kimi` | `29b4f804` | 538 | `f0226bffd7517085` |
| cursor | `cursor` | `13f3d52b` | 586 | `5ba7ce8b14775aeb` |
| fable | `fable` | `f053bd84` | 646 | `b9bd7800cdcbcb05` |
| qwen | `qwen` | `1ae5b420` | 441 | `49380ab0427d8ad8` |

核对：`git show <分支>:sunmoonai/docs/dev-plan/runtime-architecture.md | sha256sum | cut -c1-16`

## 二、取件

```bash
for w in luna kimi cursor fable qwen; do
  echo "── $w ──"
  git show $w:sunmoonai/docs/dev-plan/runtime-architecture.md
done
git diff master luna -- sunmoonai/docs/dev-plan/runtime-architecture.md   # 逐家看改了什么
```

## 三、范围与门槛

对五份候选逐份评，**包括你自己那份**（上一轮漏了自评，本轮补上）。每份至少给出：

1. 它对 §8 十条验收标准的**逐条**满足情况——不满足的指出条号与位置；
2. 至少一条**可复核的**指摘：附 `file:line` 或可复跑命令。**休眠 / 未接线的代码不算能力证据**；
3. 对 OP-1 / OP-2 / OP-3 的处理是否成立——**有理由地推翻按加分记，附和不计分**；
4. 必答 Q 第 2 问的反例是否成立（给不出反例的候选按未回答处理，请指出）。

**评优**：给出你认为的优劣排序并说明依据。**你可以把自己排第一，但必须给出与评别家同样强度的依据。**

不受理：文件树重画、R0–R5 路线重排、`protocol-v2` 五条待决、`pipeline-task.md` 那一轮。

## 四、交付

写到你自己 worktree 的：

```
sunmoonai/docs/dev-plan/rounds/runtime/runtime-review-<你的名>.md
```

`<你的名>` 先跑判别命令拿到，**不得自创文件名**——不合命名的文件不进枚举，等同未交付。
首行同样是身份自证行。写完在自己分支 commit；**判定只看提交**。

## 五、独立性提醒

`cursor` 与 `fable` 来自同一厂商的两个产品，按分组键是两组但相关性未验证
（`task.md` §6.2.1）。**互评时若发现两者论证雷同，请明确指出**——那正是本轮要取的观察值。
