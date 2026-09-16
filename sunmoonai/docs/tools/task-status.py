#!/usr/bin/env python3
"""task-status：从任务目录推出进度视图。只读不写——进度是投影，不是另一份要维护的文件。

在仓根运行，判定基准是 git 索引（与 doc-gate 相同）：
    python3 sunmoonai/docs/tools/task-status.py [--json]

每个 turn 的状态按任务侧规定推出（dev-agent-task 见后端 agent-dev-guide 3.18「任务目录的状态怎么判」）：
待派（sent_at: pending）→ 已派工、未交回（没有 turn.md）→ 已交回、待验收 → 已通过 / 被打回 / 不可判（看
verifies 指向它的最新一份 UAT 的 verdict）；中断或失败看 turn.md 的 status。同一种交付物被打回满 3 次时提醒须人裁决。
⚠ 没查什么：设计「已通过」后是否真的整理进了 composition/、人的裁决是否写进了下一个 turn——这两件只列出，不判。
"""
import json, os, re, subprocess, sys
from collections import defaultdict

RE = re.compile(r"^(?P<task>sunmoonai/docs/.+)/thread/(?P<rest>.+)$")
TURN_DIR_RE = re.compile(r"^(?P<num>\d{4})(?:-.*)?$")      # 0001、0001-01k8f3m2qz
ATTEMPT_DIR_RE = re.compile(r"^(?P<alt>[a-z])(?:-.*)?$")   # 并行尝试 a-01k8h2r5bb
LABEL = {"pass": "已通过", "fail": "被打回", "undecidable": "不可判，交人"}


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True, check=True).stdout


def blob(p):
    try:
        return git("show", f":{p}")
    except subprocess.CalledProcessError:
        return None


def fm(text):
    lines = (text or "").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    out = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return {}


def verified(turns, ref):
    """verifies 指的可能是整次派工（03），而并行时交回按尝试分（03a、03b）。"""
    if ref in turns:
        return turns[ref]
    for t, v in turns.items():
        if ref and t.startswith(ref):
            return v
    return ({}, None)


def kinds(v):
    return {x.strip() for x in (v or "").strip("[]").split(",") if x.strip()}


def main(argv):
    top = git("rev-parse", "--show-toplevel").strip()
    if os.path.realpath(os.curdir) != os.path.realpath(top):
        print(f"task-status: 必须在仓根运行：cd {top} && python3 {os.path.relpath(__file__, top)}", file=sys.stderr)
        return 2
    tracked = set(git("ls-files", "-z").split("\0")) - {""}
    tasks = defaultdict(dict)
    for p in tracked:
        m = RE.match(p)
        if not m:
            continue
        parts = m["rest"].split("/")
        if len(parts) not in (2, 3):
            continue
        info = tasks[m["task"]].setdefault(parts[0], {"files": set(), "attempts": defaultdict(set)})
        if len(parts) == 2:
            info["files"].add(parts[1])
        else:
            info["attempts"][parts[1]].add(parts[2])
    report = []
    for task in sorted(tasks):
        # 键是本地号（0001、0003a）：目录名带执行环境 id，排序与引用都只用本地号
        turns = {}
        for tdir in sorted(tasks[task]):
            md = TURN_DIR_RE.match(tdir)
            if not md:
                continue
            base = f"{task}/thread/{tdir}"
            u = fm(blob(f"{base}/user-message.md"))
            info = tasks[task][tdir]
            if info["attempts"]:
                for aname in sorted(info["attempts"]):
                    ma = ATTEMPT_DIR_RE.match(aname)
                    if not ma:
                        continue
                    files = info["attempts"][aname]
                    r = fm(blob(f"{base}/{aname}/turn.md")) if "turn.md" in files else None
                    turns[md["num"] + ma["alt"]] = (u, r)
            else:
                r = fm(blob(f"{base}/turn.md")) if "turn.md" in info["files"] else None
                turns[md["num"]] = (u, r)
        turns = dict(sorted(turns.items()))
        verdicts = defaultdict(list)
        for t, (u, r) in turns.items():
            if u.get("verifies") and r and r.get("status") == "completed":
                verdicts[u["verifies"]].append((t, r.get("verdict", "?")))
        fails = defaultdict(int)
        rows = []
        for t, (u, r) in turns.items():
            k = kinds(u.get("deliverable"))
            if u.get("sent_at") == "pending":
                state = "待派"
            elif r is None:
                state = "已派工，未交回"
            elif r.get("status") != "completed":
                state = f"{r.get('status', '?')}（中断或失败）"
            elif "UAT" in k:
                state = f"验收 {u.get('verifies', '?')}：{r.get('verdict', '?')}"
                if r.get("verdict") == "fail":
                    for kk in kinds(verified(turns, u.get("verifies"))[0].get("deliverable")):
                        fails[kk] += 1
            elif verdicts.get(t) or (len(t) > 4 and verdicts.get(t[:4])):
                got = verdicts.get(t, []) + (verdicts.get(t[:4], []) if len(t) > 4 else [])
                state = LABEL.get(sorted(got)[-1][1], "?")
            else:
                state = "已交回，待验收"
            rows.append({"turn": t, "deliverable": u.get("deliverable", "?"), "agent": u.get("agent", "?"),
                         "executor": (r or {}).get("executor") or u.get("executor", "?"), "state": state})
        report.append({"task": task.removeprefix("sunmoonai/docs/"), "turns": rows, "fails": dict(fails),
                       "composition": any(p.startswith(task + "/composition/") for p in tracked),
                       "components": sorted({p[len(task) + 12:].split("/")[0] for p in tracked if p.startswith(task + "/components/")})})
    if "--json" in argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    for r in report:
        fail_txt = "、".join(f"{k} 打回 {n} 次" for k, n in sorted(r["fails"].items())) or "无打回"
        print(f"## {r['task']}   定稿：{'有' if r['composition'] else '无'}   子任务：{len(r['components'])}   {fail_txt}")
        for k, n in sorted(r["fails"].items()):
            if n >= 3:
                print(f"   ⚠ {k} 已被打回 {n} 次：须人裁决，裁决写进下一个 turn 的任务书后才能继续")
        for row in r["turns"]:
            print(f"   turn {row['turn']:<4} {row['deliverable']:<10} {row['agent']:<11} {row['executor']:<12} {row['state']}")
    print(f"（投影：{len(report)} 个任务、{sum(len(r['turns']) for r in report)} 个 turn；判定基准是 git 索引）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
