#!/usr/bin/env python3
"""生成 `dev-plan/` 的节级清单，作为 dev-plan-refact 轮的共同输入。

**为什么由机器做**：枚举「现有 dev-plan 有哪些节」与任何流程框架无关。
让五家各做一遍是浪费；更要紧的是各家计法一旦不同，②互评就无法逐条对齐。

**计法**（与任务书 §8 固定口径一致，不得在此改）：
    排除代码块（``` / ~~~ 围栏）之后的 `^#{1,4} ` 行。

用法：
    cd sunmoonai/docs/dev-plan
    python3 rounds/dev-plan-refact/make-inventory.py > rounds/dev-plan-refact/inventory.md
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

# §3 只读输入的 9 份。改这张表就是改本轮范围——须先过裁定。
DOCS = [
    ("working/request-lifecycle.md", "内核 · 需求全生命周期"),
    ("agent-dev-guide.md", "现行规范 · 这条谱系唯一活文档"),
    ("protocol/round-protocol.md", "流程规范 · 轮次协议"),
    ("protocol/README.md", "协议目录说明"),
    ("constraints.md", "架构约束"),
    ("development-plan.md", "路线图 + 架构取向（混合）"),
    ("implementation-plan.md", "交付计划"),
    ("handoff.md", "交接"),
    ("README.md", "dev-plan 目录入口"),
]


def sections(text: str) -> list[tuple[int, int, str]]:
    out: list[tuple[int, int, str]] = []
    in_fence = False
    for no, line in enumerate(text.split("\n"), 1):
        if re.match(r"^\s*(```|~~~)", line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = re.match(r"^(#{1,4}) (.*)$", line)
        if m:
            out.append((no, len(m.group(1)), m.group(2).strip()))
    return out


def main() -> int:
    missing = [d for d, _ in DOCS if not pathlib.Path(d).exists()]
    if missing:
        print(f"make-inventory: 不在当前目录下（请 cd 到 dev-plan/）：{missing}",
              file=sys.stderr)
        return 2

    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()

    print(f"""# `dev-plan/` 节级清单 · 本轮共同输入

> **本文由脚本生成，不手写、不评论、不分类。**基线 `{head}`。
>
> 计法固定为任务书 §8 的口径：**排除代码块（``` / ~~~ 围栏）后的 `^#{{1,4}} ` 行**。
>
> **它为什么存在**：枚举「现有 `dev-plan/` 有哪些节」是与任何流程框架无关的苦工。
> 让五家各做一遍是浪费；更要紧的是各家计法一旦不同，②互评就无法逐条对齐。
> 所以由机器做一次，五家共用。
>
> ⚠ **清单只列事实，不含任何归属判断。**每一节归到你提出的哪一类、
> 哪一份文档、哪个阶段——那是 ①b 要你回答的，不是本文替你回答的。
> 谁把本文的行序当成建议的组织顺序，是自己读错了。
>
> 行号是本基线下的行号，引用时连基线一起引。重新生成见文末。

## 0. 总表

| # | 路径 | 行 | 节 | 性质 |
| --- | --- | --- | --- | --- |""")

    total_lines = total_secs = 0
    blocks = []
    for i, (d, desc) in enumerate(DOCS, 1):
        raw = pathlib.Path(d).read_text(encoding="utf-8")
        n_lines = len(raw.split("\n")) - 1 if raw.endswith("\n") else len(raw.split("\n"))
        secs = sections(raw)
        print(f"| {i} | `{d}` | {n_lines} | {len(secs)} | {desc} |")
        total_lines += n_lines
        total_secs += len(secs)
        blocks.append((i, d, secs))
    print(f"| — | **合计** | **{total_lines}** | **{total_secs}** | |")
    print("\n---\n")

    for i, d, secs in blocks:
        print(f"## {i}. `{d}` — {len(secs)} 节\n")
        print("| 行 | 级 | 标题 |")
        print("| --- | --- | --- |")
        for no, lv, title in secs:
            print(f"| {no} | {'#' * lv} | {title.replace('|', chr(92) + '|')} |")
        print()

    print("""---

## 重新生成

```bash
cd sunmoonai/docs/dev-plan
python3 rounds/dev-plan-refact/make-inventory.py > rounds/dev-plan-refact/inventory.md
```

基线变了就重跑；**不要手工改本文**——手改过的清单不能再当共同输入。""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
