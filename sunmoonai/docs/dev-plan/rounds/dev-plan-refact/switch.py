#!/usr/bin/env python3
"""正式切换第 2 步：按 dev-plan-architecture.md 第八节，把五份要拆的源迁到目标文件。

读**当前工作区**的源正文（不是冻结版本），按 CONFIG 的栏目顺序组合；每节前留
`<!-- Ixx-xxx -->` 源坐标，可用 architecture 的 `show Ixx-xxx` 取冻结原文。只做三种改写：

1. 节标题去掉旧节号并调级（栏目是 `##`，源节是 `###` / `####`）；无正文的旧章标题不单列。
2. 现行文件里对 guide 旧节号的 `§N` 改写为「标题」，跨文件时前加落点路径。
   前面紧挨别的文件名的 `§N`（如 `refact-fable.md` §5.2）不动。
   `records/` 是冻结记录，`§N` 一律不改，文件头注明口径。
3. 相对链接按新目录重算。

用法（仓根）：
    python3 sunmoonai/docs/dev-plan/rounds/dev-plan-refact/switch.py           # 只报告
    python3 sunmoonai/docs/dev-plan/rounds/dev-plan-refact/switch.py --write   # 写入
README.md 的两节迁入历史记录；README 本身在第 3 步改成新入口，本脚本不写它。

**一次性**：只能在切换前的提交（`1d0adde3`）上跑。切换后源文件已是新正文，再跑会在定位
单元时失败——这是预期的。要复核，检出该提交后在仓根跑本脚本（不带 --write），
再与切换提交里的目标文件比对。
"""

import importlib.util
import json
import pathlib
import posixpath
import re
import subprocess
import sys

P = 'sunmoonai/docs/dev-plan/'
ARCH = pathlib.Path(P + 'dev-plan-architecture.md').read_text(encoding='utf-8')
CFG = json.loads(ARCH.split('<!-- CONFIG -->\n```json\n', 1)[1].split('\n```\n<!-- END CONFIG -->', 1)[0])
_spec = importlib.util.spec_from_file_location('inv', P + 'rounds/dev-plan-refact/make-inventory.py')
assert _spec and _spec.loader
INV = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(INV)

SPLIT = ['agent-dev-guide.md', 'development-plan.md', 'implementation-plan.md', 'handoff.md', 'README.md']
UNCHANGED = {'agent-dev-guide.md', 'development-plan.md', 'handoff.md'}  # 与冻结基线逐字节相同
# 基线之后新增的节（architecture 第八节末登记）
EXTRA = {'N4-OPS-01': dict(source='implementation-plan.md', title='后续运维接收 · N4-OPS-01 监控采集与告警送达',
                           target='implementation-plan.md', group='计划责任和产品工作单元', after='I07-001')}
# 新文件的一级标题；三份原位文件沿用自己的旧标题
H1 = {
    'design/runtime-tld.md': '运行时总体设计（TLD）',
    'design/executor-sdd.md': '执行器详细设计（SDD）',
    'design/authority-sdd.md': '授权详细设计（SDD）',
    'design/evidence-sdd.md': '证据与观测详细设计（SDD）',
    'agent-dev-guide.md': 'Agent 开发指导：一个工作单元怎样做完',
    'delivery/verification.md': '验证与验收规程',
    'records/development-history.md': '开发框架的历史记录',
}
NUM = re.compile(r'^(\d+[a-z]?(?:\.\d+)*)\.?\s+')
REF = re.compile(r'§ ?(\d+(?:\.\d+)*)(?:(\s*[–-]\s*)§ ?(\d+(?:\.\d+)*))?')
QUAL = re.compile(r'(\.md|lifecycle|合同|constraints|protocol|协议|task\.md|任务书|PRD|原 ?guide|v5|总览|'
                  r'runtime-architecture|refact-fable|`[\w.-]+`|源节|源稿|agent 文|human 文)[`）)\]」]* ?(（[^）]*）)? ?$')
LINK = re.compile(r'(\]\()([^)\s]+)(\))')
FENCE = re.compile(r'^\s*(```|~~~)')


def head():
    return subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], text=True).strip()


def locate():
    """按标题在当前正文里定位每个单元；未变的三份必须与 CONFIG 行号一致。"""
    units = {u['id']: dict(u) for u in CFG['units'] if u['source'] in SPLIT}
    units.update({k: dict(v, id=k, stage='S3') for k, v in EXTRA.items()})
    lines = {}
    for src in SPLIT:
        text = pathlib.Path(P + src).read_text(encoding='utf-8')
        lines[src] = text.splitlines()
        by_title = {u['title']: uid for uid, u in units.items() if u['source'] == src}
        secs = INV.sections(text)
        assert len(secs) == len(by_title), (src, len(secs), len(by_title))
        for i, (ln, _, title) in enumerate(secs):
            uid = by_title.pop(title)
            end = secs[i + 1][0] - 1 if i + 1 < len(secs) else len(lines[src])
            u = units[uid]
            if src in UNCHANGED:
                assert (u['line'], u['end']) == (ln, end), uid
            u['line'], u['end'] = ln, end
        assert not by_title, by_title
    return units, lines


def clean(title):
    return NUM.sub('', title)


def relink(line, src, tgt):
    sd, td = posixpath.dirname(src), posixpath.dirname(tgt)
    if sd == td:
        return line, 0
    n = 0

    def f(m):
        nonlocal n
        href = m.group(2)
        if re.match(r'^([a-z]+:|#|/|~)', href):
            return m.group(0)
        path, _, frag = href.partition('#')
        absp = posixpath.normpath(posixpath.join(sd, path))
        new = posixpath.relpath(absp, td or '.') + ('/' if path.endswith('/') else '')
        n += 1
        return m.group(1) + new + ('#' + frag if frag else '') + m.group(3)
    return LINK.sub(f, line), n


def build():
    units, lines = locate()
    gnum = {}
    for uid, u in units.items():
        if u['source'] == 'agent-dev-guide.md':
            m = NUM.match(u['title'])
            if m:
                gnum[m.group(1)] = uid
    empty = {uid for uid, u in units.items()
             if not any(x.strip() for x in lines[u['source']][u['line']:u['end']])}
    stats = {'rewrite': 0, 'chapter': 0, 'kept_qualified': [], 'relink': 0}

    def ref(num, cur):
        uid = gnum[num]
        u = units[uid]
        s = '「' + clean(u['title']) + '」' + ('一章' if uid in empty else '')
        if uid in empty:
            stats['chapter'] += 1
        return ('`' + u['target'] + '`' if u['target'] != cur else '') + s

    def fix_refs(line, cur, where):
        def f(m):
            if QUAL.search(line[:m.start()][-30:]):
                stats['kept_qualified'].append(where + ' …' + line[max(0, m.start() - 30):m.end()])
                return m.group(0)
            if m.group(1) not in gnum or (m.group(3) and m.group(3) not in gnum):
                raise ValueError('无法解析 §' + m.group(0) + ' @ ' + where)
            stats['rewrite'] += 1
            out = ref(m.group(1), cur)
            if m.group(3):
                stats['rewrite'] += 1  # 区间两端同一落点时，后一端不重复路径
                out += '至' + ref(m.group(3), units[gnum[m.group(1)]]['target'])
            return out
        return REF.sub(f, line)

    def unit_text(uid, cur):
        u = units[uid]
        body = lines[u['source']][u['line'] - 1:u['end']]
        m = re.match(r'^(#{1,4}) (.*)$', body[0])
        assert m, uid
        lvl = len(m.group(1))
        new = (3 if lvl <= 3 else 4) if u['source'] == 'agent-dev-guide.md' else (3 if lvl <= 2 else 4)
        if uid in empty:
            return ['<!-- ' + uid + '：原章标题「' + clean(m.group(2)) + '」无正文，不单列 -->', '']
        out = ['<!-- ' + uid + ' -->', '#' * new + ' ' + clean(m.group(2))]
        fence = False
        rewrite = u['source'] == 'agent-dev-guide.md' and not cur.startswith('records/')
        for i, line in enumerate(body[1:], u['line'] + 1):
            if FENCE.match(line):
                fence = not fence
            elif not fence:
                if rewrite:
                    line = fix_refs(line, cur, u['source'] + ':' + str(i))
                line, n = relink(line, u['source'], cur)
                stats['relink'] += n
            out.append(line)
        while out and not out[-1].strip():
            out.pop()
        return out + ['']

    sha = head()
    arch_rel = lambda tgt: posixpath.relpath('dev-plan-architecture.md', posixpath.dirname(tgt) or '.')
    docs = {}
    for d in CFG['docs']:
        if d['fixed']:
            continue
        tgt = d['path']
        groups = [dict(g, ids=list(g['ids'])) for g in d['groups']]
        for k, v in EXTRA.items():
            if v['target'] == tgt:
                g = next(g for g in groups if g['name'] == v['group'])
                g['ids'].insert(g['ids'].index(v['after']) + 1, k)
        own = [uid for g in groups for uid in g['ids']
               if units[uid]['source'] == tgt and units[uid]['line'] == 1]
        out = []
        if own:
            u = units[own[0]]
            body = lines[tgt][u['line'] - 1:u['end']]
            out += ['<!-- ' + own[0] + ' -->', body[0]] + body[1:]
            while out and not out[-1].strip():
                out.pop()
            out.append('')
        else:
            out += ['# ' + H1[tgt], '']
        out += ['> ' + d['type'] + '｜' + d['stage'] + '。' + d['why'],
                '>',
                '> 2026-09-14 按 [dev-plan-architecture.md](' + arch_rel(tgt) + ') 第八节从 `' + sha +
                '` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。']
        if tgt.startswith('records/'):
            out += ['>',
                    '> 本文件是冻结记录，只追加更正、不改原文。正文里未注文件名的 `§N` 指冻结基线 `baa28858` 时'
                    ' `agent-dev-guide.md` 的节号，今天的位置查 architecture 第八节。']
        out.append('')
        for g in groups:
            out += ['## ' + g['name'], '', g['rule'], '']
            for uid in g['ids']:
                if uid in own:
                    continue
                out += unit_text(uid, tgt)
        docs[tgt] = '\n'.join(out).rstrip('\n') + '\n'
    return units, lines, docs, empty, stats


def check(units, lines, docs, empty):
    """独立复核：每个单元恰好出现一次；除三种改写外正文逐行相同。"""
    seen = {}
    groups = {g['name'] for d in CFG['docs'] for g in d['groups']}
    for tgt, text in docs.items():
        for m in re.finditer(r'^<!-- ([A-Z0-9-]+?)(：| -->)', text, re.M):
            seen.setdefault(m.group(1), []).append(tgt)
    for d in CFG['docs']:
        if d['path'] in docs:  # 栏目标题与归属判据按 CONFIG 原样、按序出现
            text, pos = docs[d['path']], 0
            for g in d['groups']:
                pos = text.index('\n## ' + g['name'] + '\n\n' + g['rule'] + '\n', pos) + 1
    assert set(seen) == set(units), set(units) ^ set(seen)
    assert all(len(v) == 1 for v in seen.values()), {k: v for k, v in seen.items() if len(v) > 1}
    # 只剥改写可能产生的字面串（已知 guide 标题），两边同样处理；泛化的「…」会吃错跨度。
    titles = sorted({re.escape(clean(u['title'])) for u in units.values()
                     if u['source'] == 'agent-dev-guide.md'}, key=len, reverse=True)
    one = r'(?:`[\w./-]+\.md`)?「(?:' + '|'.join(titles) + r')」(?:一章)?'
    norm_ref = re.compile(r'§ ?\d+(?:\.\d+)*(?:\s*[–-]\s*§ ?\d+(?:\.\d+)*)?|' + one + '(?:至' + one + ')?')
    norm = lambda s: LINK.sub('](', norm_ref.sub('', s)).rstrip()
    for uid, u in units.items():
        tgt = seen[uid][0]
        text = docs[tgt]
        if uid in empty:
            continue
        start = text.index('<!-- ' + uid + ' -->\n') + len('<!-- ' + uid + ' -->\n')
        # 单元止于下一个源坐标注释或真正的栏目标题；模板代码块里的 `## ` 不算
        # 原位三份的旧标题节后面紧跟迁入说明（`> 类型｜…`），也是止点
        ends = [text.find(x, start) for x in ['\n<!-- '] + ['\n## ' + g + '\n' for g in groups]
                + ['\n> ' + d['type'] + '｜' for d in CFG['docs']]]
        stop = min([x for x in ends if x >= 0] or [len(text)])
        got = text[start:stop].split('\n')[1:]
        want = lines[u['source']][u['line']:u['end']]
        g = [norm(x) for x in got if x.strip()]
        w = [norm(x) for x in want if x.strip()]
        assert g == w, (uid, next((a, b) for a, b in zip(g + [''], w + ['']) if a != b))
    return len(seen)


def main():
    units, lines, docs, empty, stats = build()
    n = check(units, lines, docs, empty)
    for tgt, text in docs.items():
        print(f'{tgt}: {text.count(chr(10))} 行')
    print(f'单元 {n}（含基线后新增 {len(EXTRA)}）；无正文章标题 {len(empty)}；§ 改写 {stats["rewrite"]}'
          f'（其中指向无正文章 {stats["chapter"]}）；链接重算 {stats["relink"]}')
    for q in stats['kept_qualified']:
        print('保留（紧挨别的文件名）：', q)
    if '--write' in sys.argv:
        for tgt, text in docs.items():
            p = pathlib.Path(P + tgt)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding='utf-8')
        print('已写入', len(docs), '份')


if __name__ == '__main__':
    main()
