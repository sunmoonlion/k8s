#!/usr/bin/env python3
"""anchor-gate：检查 `文件:行` 形式的锚点是否可解析。

**为什么需要它**：`doc-gate.py` 只检查 markdown 链接 `[文本](路径)`。
2026-09-05 实测：删掉 `refact-fable.md` 后 `doc-gate --all` 报「144 份通过」，
而当时 `runtime-architecture.md` 里 31 处对它的引用全部是纯文本锚点（`refact-fable.md @ ceb7291c:220`），
一条也没被发现。**一道门禁的存在理由就是防这件事，它却看不见**——
这是该轮记录的「判据在边界给假答案」的第六次。

判据（三档，只报能机械判的）：
  A 钉 commit 的锚 `文件.md @ <sha>:<行>`  → git show <sha>:<路径> 后行号必须存在      硬判
  B 裸路径带行号 `文件.md:<行>`            → 目标必须在 git 索引里，且行号存在         硬判
  C 章节号引用 `文件.md §N`                → 只计数，交人判（协议：引用按标题不按章节号） 软判

退出码：有硬判失败 → 1；否则 0。
"""
import re, subprocess, sys, pathlib

ROOT = subprocess.run(["git","rev-parse","--show-toplevel"],capture_output=True,text=True).stdout.strip()
DOCS = pathlib.Path(ROOT)/"sunmoonai/docs"
tracked = set(subprocess.run(["git","ls-files"],cwd=ROOT,capture_output=True,text=True).stdout.split())

def show(ref):
    r = subprocess.run(["git","show",ref],cwd=ROOT,capture_output=True,text=True)
    return r.stdout.splitlines() if r.returncode==0 else None

# 外部取证仓（round.md 的 anchor_roots）：这类锚点不在本仓索引里，但**可复跑**，
# 不能判失败。2026-09-05 首版漏了它，对 `adding-a-tool.md:40` 报假失败——
# 而同一文档 :441 就写着全路径 `~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md`。
EXTERNAL = [pathlib.Path.home()/"repo"/x for x in ("codex","deepseek-harness","openclaw")]

def resolve_external(name):
    for root in EXTERNAL:
        if not root.is_dir(): continue
        hits=list(root.rglob(name))
        if len(hits)==1: return hits[0]
    return None

def resolve(name, ref_rel):
    """按文件名在索引里找路径。**同目录优先**——`rulings.md` 这类基名在多个轮次目录里
    各有一份，一律判「不唯一」会产生假失败；而假失败多了门禁就没人看，那是另一种失效。"""
    hits=[t for t in tracked if t.endswith("/"+name) or t==name]
    if not hits: return None
    if len(hits)==1: return hits[0]
    d = str(pathlib.PurePosixPath(ref_rel).parent)
    same=[t for t in hits if str(pathlib.PurePosixPath(t).parent)==d]
    if len(same)==1: return same[0]
    # 再退一层：同一轮次目录树内
    near=[t for t in hits if t.startswith(d.rsplit("/",1)[0]+"/")]
    return near[0] if len(near)==1 else None

A = re.compile(r'`([\w.-]+\.md) @ ([0-9a-f]{7,40}):(\d+)(?:-(\d+))?`')
B = re.compile(r'`([\w.-]+\.md):(\d+)(?:-(\d+))?`')
C = re.compile(r'`([\w.-]+\.md)` §([\d.]+)')

def archived(rel):
    """`rounds/**` 与 `dev-plan/archive/**` 按归档：二者都是**冻结的历史记录**
    （前者是轮次产物：工单、通知、裁定、评审、处置、验收；后者是已被取代、
    且有逐节落点收据的文档），其锚点按成文时的状态解析，不因后续文档变动判失败——
    冻结物不可改，让门禁对它永久报红只会让人不再看门禁。
    但仍逐条列出供人判：**软判不是不判**。
    活跃文档集 = dev-plan/ 顶层 + working/ + project-guide/，那些硬判。
    ⚠ 2026-09-08：ai-dev-readiness/ 已整体并入 rounds/dev-plan-refact/inputs/，
    该目录取消，随之从活跃集移出——移入 rounds/ 即自动转为软判，见首句。

    ⚠ 2026-09-07 加入 archive/：该目录当天重建，收入两份归档件，其中
    runtime-architecture.md 带一处指向外部仓的存量失效锚（`task.md:214`，
    该文件现只有 20 行）。它是成文时可解析、之后外部仓变了——正是本函数
    要豁免的形状。**豁免的是判失败，不是豁免报出来**。"""
    return "/rounds/" in rel or "/dev-plan/archive/" in rel

fails=[]; archive_notes=[]; soft=0; okA=okB=0
for f in sorted(DOCS.rglob("*.md")):
    rel = str(f.relative_to(ROOT))
    if rel not in tracked: continue
    text = f.read_text(encoding="utf-8")
    for m in A.finditer(text):
        name,sha,a,b = m.group(1),m.group(2),int(m.group(3)),m.group(4)
        # **在那个 commit 里解析路径**，不在当前索引里——否则文件一删，
        # 连正确的钉 commit 锚也会报失败。这正是钉 commit 的意义所在。
        at = subprocess.run(["git","ls-tree","-r","--name-only",sha],cwd=ROOT,
                            capture_output=True,text=True).stdout.split()
        cand=[t for t in at if t.endswith("/"+name) or t==name]
        if len(cand)!=1:
            d=str(pathlib.PurePosixPath(rel).parent)
            near=[t for t in cand if str(pathlib.PurePosixPath(t).parent)==d] or \
                 [t for t in cand if t.startswith(d.rsplit("/",1)[0]+"/")]
            cand = near
        if len(cand)!=1: fails.append(f"{rel}: `{name} @ {sha}` 在该 commit 里找不到唯一路径"); continue
        p = cand[0]
        lines = show(f"{sha}:{p}")
        if lines is None: fails.append(f"{rel}: `{name} @ {sha}` 该 commit 取不到 {p}"); continue
        hi = int(b) if b else a
        if hi > len(lines): (archive_notes if archived(rel) else fails).append(f"{rel}: `{name} @ {sha}:{a}{'-'+b if b else ''}` 超出该版本行数 {len(lines)}")
        else: okA+=1
    for m in B.finditer(text):
        name,a,b = m.group(1),int(m.group(2)),m.group(3)
        p = resolve(name, rel)
        if not p:
            ext = resolve_external(name)
            if ext:
                n = len(ext.read_text(encoding="utf-8", errors="replace").splitlines())
                hi = int(b) if b else a
                if hi <= n: okB += 1
                else: (archive_notes if archived(rel) else fails).append(
                    f"{rel}: `{name}:{a}` 外部仓 {ext} 只有 {n} 行")
                continue
            (archive_notes if archived(rel) else fails).append(f"{rel}: `{name}:{a}` **裸路径锚，目标不在 git 索引里**（文件已删/改名，或同名多份无法消歧）"); continue
        lines = (pathlib.Path(ROOT)/p).read_text(encoding="utf-8").splitlines()
        hi = int(b) if b else a
        if hi > len(lines): (archive_notes if archived(rel) else fails).append(f"{rel}: `{name}:{a}{'-'+b if b else ''}` 超出当前行数 {len(lines)}")
        else: okB+=1
    soft += len(C.findall(text))

print(f"anchor-gate: 钉 commit 锚 {okA} 通过；裸路径行号锚 {okB} 通过；章节号引用 {soft} 处（软判，交人）")
for x in fails: print(f"  ❌ {x}")
if archive_notes:
    # **汇总而不是逐条列**：92 行噪音会让人不再看门禁，那是另一种失效。
    import collections, re as _re
    agg = collections.Counter()
    for x in archive_notes:
        m = _re.search(r'`([\w.-]+\.md)', x)
        agg[m.group(1) if m else "?"] += 1
    print(f"\n🔶 归档产物（`rounds/**`、`dev-plan/archive/**`）中 {len(archive_notes)} 处锚点在当前状态下解析不到——"
          f"**软判，不计失败**：归档是冻结的历史记录，锚点按成文时状态解析，不可改也不该改。")
    for name, n in agg.most_common():
        print(f"     {name:<36} {n:>3} 处")
    print("     （逐条明细：ANCHOR_GATE_VERBOSE=1 环境变量）")
    import os
    if os.environ.get("ANCHOR_GATE_VERBOSE"):
        for x in archive_notes: print(f"       {x}")
if fails: print(f"\n硬判失败 {len(fails)} 项。**裸路径锚在被引文件删除后必然失效，应改为 `文件.md @ <commit>:<行>`。**")
sys.exit(1 if fails else 0)
