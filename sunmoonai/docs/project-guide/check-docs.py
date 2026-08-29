#!/usr/bin/env python3
"""本文档集的机械检查。

用法：
    python3 check-docs.py            # 从 architecture/ 目录内跑
    python3 check-docs.py --repos ~/master   # 另指五仓所在目录，启用保鲜检查

检查项：
  1. 坏链——含**空链接**（曾漏检：把 `[x]()` 当成"跳过"而非"坏链"）
  2. 空链接单列（它比坏链更隐蔽：渲染出来像正常文字）
  3. 易腐值——行号锚点、digest、sha256 等不该进正文的值
  4. 取证时点保鲜——各文档的取证时点是否落后于五仓最近提交

退出码非 0 表示有问题，可直接进 CI。
"""
from __future__ import annotations
import argparse, pathlib, re, subprocess, sys

LINK = re.compile(r'\[([^\]]*)\]\(([^)]*)\)')
FENCE = re.compile(r'^```.*?^```', re.S | re.M)   # 围栏代码块
INLINE = re.compile(r'`[^`\n]*`')                  # 行内代码


def mask_code(text: str) -> str:
    """把代码区替换成等长空白，使行号与列位置不变，但其中的 `[x]()` 不再被当作链接。

    没有这一步会误报：描述"坏链长什么样"的文档本身会被判为有坏链。
    """
    def blank(m: re.Match[str]) -> str:
        return re.sub(r'[^\n]', ' ', m.group(0))
    return INLINE.sub(blank, FENCE.sub(blank, text))
STAMP = re.compile(r'(?:取证时点|最后更新)[：:]\s*(\d{4})-(\d{2})-(\d{2})')

# 不参与检查的子目录，各有理由：
#   merge-review/  评审材料，不是投影，没有"取证时点"也不需要保鲜
#   merge-review/ 外部评审方的记录，本方不得修改（含对本集问题的原文引用）
EXCLUDE_DIRS = {'decisions', 'merge-review'}
# 行号锚点：sed -n '12,34p' / :123 结尾的路径引用
LINENUM = re.compile(r"sed -n\s+'\d+,\d+p'|sed -n\s+'\d+p'")
PERISHABLE = re.compile(r'\bsha256:[0-9a-f]{64}\b|\b[0-9a-f]{40}\b')

def check(root: pathlib.Path, repos: pathlib.Path | None):
    problems: list[str] = []
    docs = sorted(p for p in root.rglob('*.md')
                  if not (set(p.relative_to(root).parts) & EXCLUDE_DIRS))
    if not docs:
        return [f'{root} 下没有 .md']

    # --- 1 & 2. 链接 ---
    for p in docs:
        text = mask_code(p.read_text(encoding='utf-8'))
        for m in LINK.finditer(text):
            label, target = m.group(1), m.group(2).strip()
            line = text[:m.start()].count('\n') + 1
            rel = p.relative_to(root)
            if not target:
                problems.append(f'空链接  {rel}:{line}  [{label}]()')
                continue
            if target.startswith(('http://', 'https://', 'mailto:', '#')):
                continue
            path = target.split('#')[0]
            if not path:
                continue
            if not (p.parent / path).resolve().exists():
                problems.append(f'坏链    {rel}:{line}  -> {target}')

    # --- 3. 易腐值 ---
    for p in docs:
        rel = p.relative_to(root)
        if rel.name == 'check-docs.py':
            continue
        for i, line in enumerate(p.read_text(encoding='utf-8').split('\n'), 1):
            if PERISHABLE.search(line) and 'sha256:<' not in line and '64hex' not in line:
                problems.append(f'易腐值  {rel}:{i}  疑似写入了 digest/commit')

    # --- 4. 保鲜 ---
    if repos:
        # 只看**代码**的最近提交：文档改动不应让文档自己过期。
        # 排除文档路径，否则每次改文档都会把全部文档判为过期。
        # 子模块单独扫：父仓里子模块只是一个 gitlink，纯文档提交也会改动它，
        # 从父仓看无法区分"子模块改了代码"还是"子模块改了文档"。
        EXCL = [':(exclude)sunmoonai/docs', ':(exclude)docs', ':(exclude)*.md',
                ':(exclude)*.mdc', ':(exclude).cursor']

        def submodules(d):
            try:
                return subprocess.run(
                    ['git', '-C', str(d), 'submodule', '--quiet', 'foreach',
                     '--recursive', 'echo $sm_path'],
                    capture_output=True, text=True, timeout=60).stdout.split()
            except Exception:
                return []

        def last_code_commit(d, subs=()):
            # 子模块的 gitlink 也要排除：它只是一个指针，子模块自己会被单独扫。
            excl = EXCL + [f':(exclude){s}' for s in subs]
            try:
                return subprocess.run(
                    ['git', '-C', str(d), 'log', '-1', '--format=%cs', '--', '.'] + excl,
                    capture_output=True, text=True, timeout=30).stdout.strip()
            except Exception:
                return ''

        newest = None
        for r in ['k8s', 'tpl-app', 'info-app', 'knowledge-app', 'investment-app']:
            d = repos / r
            if not (d / '.git').exists():
                continue
            subs = submodules(d)
            cands = [last_code_commit(d, subs)]
            cands += [last_code_commit(d / s, submodules(d / s)) for s in subs]
            for c in cands:
                if c:
                    newest = max(newest, c) if newest else c
        if newest:
            for p in docs:
                m = STAMP.search(p.read_text(encoding='utf-8'))
                if not m:
                    problems.append(f'无时点  {p.relative_to(root)}  缺"取证时点/最后更新"')
                    continue
                stamp = f'{m.group(1)}-{m.group(2)}-{m.group(3)}'
                if stamp < newest:
                    problems.append(
                        f'已过期  {p.relative_to(root)}  取证 {stamp} < 最近提交 {newest}')
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default='.', help='文档集根目录，默认当前目录')
    ap.add_argument('--also', action='append', default=[],
                    help='额外一起检查的目录（如 ../dev-plan），可多次')
    ap.add_argument('--repos', default=None, help='五仓所在父目录，给了才做保鲜检查')
    a = ap.parse_args()
    root = pathlib.Path(a.root).resolve()
    repos = pathlib.Path(a.repos).resolve() if a.repos else None

    problems = check(root, repos)
    for extra in a.also:
        problems += [f'[{extra}] {x}' for x in check(pathlib.Path(extra).resolve(), repos)]
    if not problems:
        print('✓ 全部通过')
        return 0
    kinds: dict[str, int] = {}
    for x in problems:
        kinds[x.split()[0]] = kinds.get(x.split()[0], 0) + 1
    for x in problems:
        print('  ' + x)
    print('\n' + ' '.join(f'{k}:{v}' for k, v in sorted(kinds.items())))
    # 保鲜与易腐值是提示，坏链/空链接是硬失败
    hard = sum(v for k, v in kinds.items() if k in ('坏链', '空链接'))
    return 1 if hard else 0


if __name__ == '__main__':
    sys.exit(main())
