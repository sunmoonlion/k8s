# qwen-005 停点回执（第二节 exit=1，不重试不退回）

- 卡：docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-005-small-release-0030.md
- 工位/分支：~/worktrees/qwen/k8s @ qwen，HEAD=f48b1aff
- 时间：2026-10-18 00:52 CST
- 结论：**停在第二节**。第一节全过；第二节改钉脚本 exit=1（AssertionError），sources.yaml 未被写入；第三/四/五节未执行。R5.4 第 5 步仍停在 b。

## 一、核对（只读）——全过

- k8s：git pull --ff-only 到 f48b1aff；工作区仅两张未跟踪走查截图（R5.4 a/b 归档，与本卡无关）。
- knowlab-app sync exit=0；HEAD=65860ae8d84af36f638aa548a568796b90f6c0ae；submodule：admin 371abcee、backend 4e39358a、web 01514759（与卡要求逐字一致）。
- knowbench-app sync exit=0；HEAD=f6614342b1250347d2549a3f311963da8a516cab；submodule：admin 45fcf79a、backend 7f5aa4e4、web 13f15c3d（一致）。
- make -C infrastructure platform-status：status exit=0（PLAY RECAP ok=7 changed=0 unreachable=0 failed=0）。

## 二、改钉——exit=1，停

脚本与卡 42-61 行逐字一致（diff=0）。运行输出原样：

    Traceback (most recent call last):
      File "<stdin>", line 15, in <module>
    AssertionError: ('knowlab', 'parent_revision')
    s2 exit=1

未重试、未退回、未手改 sources.yaml。

### 根因（只读取证，未改）

- 卡内 python 的块正则 `(?ms)^  {app}:\n(?:(?!^  \S).*\n?)*` 带 re.S，`.` 匹配换行，故「块」从 `  knowlab:` 一路吞到文件末尾，而非止于下一个 2 空格键。
- knowlab 之后还有 knowmart（qwen-003 实例化），于是块内 `    parent_revision:` 命中 2 次（sources.yaml 第 42 行 knowlab、第 51 行 knowmart），re.subn 的 n=2，断言 n == 1 失败。
- 佐证：`sed -n '41,$p' sources.yaml | grep -c '^    parent_revision: '` = 2。
- `p.write_text(s)` 在断言之后，异常先抛出，故 sources.yaml 未被写入：`git status --short infrastructure/applications/sources.yaml` 与 `git diff --stat` 对该文件均空。

### 交 Opus 的修法建议（我不代改）

块正则去掉 re.S、或改成只吞 4 空格缩进行使其止于本应用块，例如 `(?m)^  {app}:\n(?:^    .*\n)*`；或改钉时逐键在全文件唯一定位行。

## 未执行

第三（build/stage/plan）、第四（提交/发布/晋级/apply/wait/check/push）、第五（浏览器走查）均未执行。

## 关联

- R5.4 第 5 步停在 b（a、b 已完成不重做）；本卡通过后从 c 接着走。
- knowlab 管理端「读取失败」= 账 134，修复在本卡 knowlab 后端 4e39358；因本卡停在二节，尚未上线。
