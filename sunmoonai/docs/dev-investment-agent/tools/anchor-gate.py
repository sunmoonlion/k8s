#!/usr/bin/env python3
"""anchor-gate：检查 `文件:行` 形式的锚点是否可解析。

**为什么需要它**：`doc-gate.py` 只检查 markdown 链接 `[文本](路径)`。
实测：删掉 `refact-fable.md` 后 `doc-gate --all` 报「144 份通过」，
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
# 不能判失败。首版漏了它，对 `adding-a-tool.md:40` 报假失败——
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

# ⚠ 首版把行号写成 `(\d+)(?:-(\d+))?`，只认单行与 `a-b` 区间。实跑中协议里写的是
# `runtime-architecture.md @ ceb7291c:454/458/461`——**斜杠列表一条也没被匹配**，
# 门报「0 处锚点」而文中有 8 处。这正是本门存在的理由在本门自己身上又犯一次：
# 判据覆盖不全，比没有判据更危险，因为它报「通过」。
LINES = r'(\d+(?:[-/]\d+)*)'
A = re.compile(r'`([\w.-]+\.md) @ ([0-9a-f]{7,40}):' + LINES + r'`')
B = re.compile(r'`([\w.-]+\.md):' + LINES + r'`')
C = re.compile(r'`([\w.-]+\.md)` §([\d.]+)')

def hi_of(spec):
    """`454/458/461` 或 `23-29` 或 `40` → 需要存在的最大行号。"""
    return max(int(x) for x in re.split(r'[-/]', spec))

fails=[]; soft=0; okA=okB=0; frozen=0
for f in sorted(DOCS.rglob("*.md")):
    rel = str(f.relative_to(ROOT))
    if rel not in tracked: continue
    # 与 doc-gate 一致：任务目录下 thread/ 是冻结原件，只对交回那一刻负责，不查。
    if "/thread/" in rel: frozen += 1; continue
    text = f.read_text(encoding="utf-8")
    for m in A.finditer(text):
        name,sha,spec = m.group(1),m.group(2),m.group(3)
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
        if hi_of(spec) > len(lines): fails.append(f"{rel}: `{name} @ {sha}:{spec}` 超出该版本行数 {len(lines)}")
        else: okA+=1
    for m in B.finditer(text):
        name,spec = m.group(1),m.group(2)
        p = resolve(name, rel)
        if not p:
            ext = resolve_external(name)
            if ext:
                n = len(ext.read_text(encoding="utf-8", errors="replace").splitlines())
                if hi_of(spec) <= n: okB += 1
                else: fails.append(
                    f"{rel}: `{name}:{spec}` 外部仓 {ext} 只有 {n} 行")
                continue
            fails.append(f"{rel}: `{name}:{spec}` **裸路径锚，目标不在 git 索引里**（文件已删/改名，或同名多份无法消歧）"); continue
        lines = (pathlib.Path(ROOT)/p).read_text(encoding="utf-8").splitlines()
        if hi_of(spec) > len(lines): fails.append(f"{rel}: `{name}:{spec}` 超出当前行数 {len(lines)}")
        else: okB+=1
    soft += len(C.findall(text))

print(f"anchor-gate: 钉 commit 锚 {okA} 通过；裸路径行号锚 {okB} 通过；章节号引用 {soft} 处（软判，交人）" + (f"；另有 {frozen} 份在 thread/ 下，冻结原件不查" if frozen else ""))
for x in fails: print(f"  ❌ {x}")
if fails: print(f"\n硬判失败 {len(fails)} 项。**裸路径锚在被引文件删除后必然失效，应改为 `文件.md @ <commit>:<行>`。**")
sys.exit(1 if fails else 0)
