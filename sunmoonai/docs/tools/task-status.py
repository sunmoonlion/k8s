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
THREAD_RE = re.compile(r"^(?P<num>\d{4})-(?P<stage>[a-z]+)(?:-.*)?$")   # 0003-sdd-01k8f3m2qz
TURN_RE = re.compile(r"^(?P<num>\d{4})(?:-.*)?$")                        # 0002-01k8h9t1cc
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


def kinds(v):
    return {x.strip() for x in (v or "").strip("[]").split(",") if x.strip()}


def main(argv):
    top = git("rev-parse", "--show-toplevel").strip()
    if os.path.realpath(os.curdir) != os.path.realpath(top):
        print(f"task-status: 必须在仓根运行：cd {top} && python3 {os.path.relpath(__file__, top)}", file=sys.stderr)
        return 2
    tracked = set(git("ls-files", "-z").split("\0")) - {""}
    tasks = defaultdict(lambda: defaultdict(dict))
    for p in tracked:
        m = RE.match(p)
        if not m:
            continue
        parts = m["rest"].split("/")
        if len(parts) < 3:
            continue
        tasks[m["task"]][parts[0]].setdefault(parts[1], set()).add("/".join(parts[2:]))
    report = []
    for task in sorted(tasks):
        # 键是本地号「文档 thread/turn」，如 0001/0002：目录名带运行时 id，引用只用本地号
        turns = {}
        for dt in sorted(tasks[task]):
            mt = THREAD_RE.match(dt)
            if not mt:
                continue
            for du in sorted(tasks[task][dt]):
                mu = TURN_RE.match(du)
                if not mu:
                    continue
                base = f"{task}/thread/{dt}/{du}"
                files = tasks[task][dt][du]
                u = fm(blob(f"{base}/user-message.md"))
                r = fm(blob(f"{base}/turn.md")) if "turn.md" in files else None
                turns[f"{mt['num']}/{mu['num']}"] = (u, r, mt["stage"])
        turns = dict(sorted(turns.items()))
        verdicts = defaultdict(list)
        for t, (u, r, _st) in turns.items():
            if u.get("verifies") and r and r.get("status") == "completed":
                verdicts[u["verifies"]].append((t, r.get("verdict", "?")))
        fails = defaultdict(int)
        rows = []
        for t, (u, r, stage) in turns.items():
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
                    for kk in kinds(turns.get(u.get("verifies"), ({}, None, ""))[0].get("deliverable")):
                        fails[kk] += 1
            elif verdicts.get(t):
                state = LABEL.get(sorted(verdicts[t])[-1][1], "?")
            else:
                state = "已交回，待验收"
            rows.append({"turn": t, "stage": stage, "deliverable": u.get("deliverable", "?"), "agent": u.get("agent", "?"),
                         "executor": u.get("executor", "?"), "state": state})
        report.append({"task": task.removeprefix("sunmoonai/docs/"), "turns": rows, "fails": dict(fails),
                       "final": sorted({p[len(task) + 1:].split("/")[0] for p in tracked
                                         if p.startswith(task + "/PRD/") or p.startswith(task + "/SDD/")}),
                       "modules": sorted({p[len(task) + 13:].split("/")[0] for p in tracked if p.startswith(task + "/SDD/modules/")})})
    if "--json" in argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    for r in report:
        fail_txt = "、".join(f"{k} 打回 {n} 次" for k, n in sorted(r["fails"].items())) or "无打回"
        print(f"## {r['task']}   定稿：{'、'.join(r['final']) or '无'}   子任务：{len(r['modules'])}   {fail_txt}")
        for k, n in sorted(r["fails"].items()):
            if n >= 3:
                print(f"   ⚠ {k} 已被打回 {n} 次：须人裁决，裁决写进下一个 turn 的任务书后才能继续")
        for row in r["turns"]:
            print(f"   turn {row['turn']:<10} {row['stage']:<5} {row['agent']:<11} {row['executor']:<12} {row['state']}")
    print(f"（投影：{len(report)} 个任务、{sum(len(r['turns']) for r in report)} 个 turn；判定基准是 git 索引）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
