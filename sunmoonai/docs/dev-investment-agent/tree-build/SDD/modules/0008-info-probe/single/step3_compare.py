"""第三步：把抽出的行对上科目目录，过勾稽，再与现有数据集逐项比对。
数据集里的报表数来自东方财富；这里比的是「年报原文抽出的数」与它是否一致。"""
import json, os, re, sqlite3, collections
HERE = os.path.expanduser("~/annual-report-probe")
DATASET = os.path.expanduser("~/worktrees/fable/investment-app/investment-backend/app/eval/fixtures/sh600009-financials-v2.dataset.bin")
TOLERANCE = 1.0
STATEMENTS = ("balance_sheet", "income_statement", "cash_flow")
NOTE = re.compile(r"[一二三四五六七八九十]*[（(][一二三四五六七八九十百零]+[)）]$")
PREFIX = re.compile(r"^([一二三四五六七八九十]+、|[（(][一二三四五六七八九十]+[)）]|\d+[.．、]|其中：|加：|减：)+")
PAREN = re.compile(r"[（(][^（）()]*(填列|或股东权益|或股本|元/股)[^（）()]*[)）]?")
ALIASES = {"实收资本": "share_capital", "股本": "share_capital", "实收资本股本": "share_capital"}

def normalize(label):
    s = NOTE.sub("", label)
    s = PREFIX.sub("", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[（）()“”\"－\-\s]", "", s)
    return s.replace("所有者", "股东")

db = sqlite3.connect(f"file:{DATASET}?mode=ro", uri=True); db.row_factory = sqlite3.Row
catalog = {t: {} for t in STATEMENTS}
for r in db.execute("select source_table, field, display_name from field_dictionary where unit='元'"):
    catalog[r["source_table"]][normalize(r["display_name"])] = r["field"]
for t in STATEMENTS:
    for k, v in ALIASES.items():
        if v in catalog[t].values():
            catalog[t][k] = v
fields = {t: sorted(set(catalog[t].values())) for t in STATEMENTS}
NOT_IN_STATEMENT = {"deduct_parent_netprofit"}   # 扣非净利润不在报表里，在「主要会计数据」里

def match(table, label):
    key = normalize(label)
    if key in catalog[table]:
        return catalog[table][key]
    if len(key) >= 10:      # 折行：只抽到科目名的前半截
        hits = {f for name, f in catalog[table].items() if name.startswith(key)}
        if len(hits) == 1:
            return hits.pop()
    return None

def resolve(table, rows):
    """每个带数字的行对到一个科目；标签折行时把上下两行只有文字的行拼起来再认。"""
    found, unmatched = {}, []
    used = set()   # 已经被某一行用掉的「只有文字」的行，不再给别的行用
    for i, row in enumerate(rows):
        if row["current"] is None and row["prior"] is None:
            continue
        before = rows[i - 1]["label"] if i and rows[i - 1]["current"] is None and rows[i - 1]["prior"] is None else ""
        after = rows[i + 1]["label"] if i + 1 < len(rows) and rows[i + 1]["current"] is None and rows[i + 1]["prior"] is None else ""
        own = NOTE.sub("", row["label"])
        if i - 1 in used: before = ""
        field = match(table, own) if own else None
        taken = ()
        if field is None:
            # 自己有标签：可能是折行的前半截或后半截；自己没标签：数字夹在两行标签中间
            options = ([(before + own, (i - 1,)), (own + after, (i + 1,)), (before + own + after, (i - 1, i + 1))]
                       if own else [(before + after, (i - 1, i + 1))])
            for candidate, neighbours in options:
                if candidate and candidate != own:
                    field = match(table, candidate)
                if field:
                    taken = neighbours
                    break
        used.update(taken)
        if field is None:
            unmatched.append(row["label"] or f"（无标签：{before}|{after}）")
            continue
        if field in found:
            # 同名科目出现两次（例如利润表里金融类的「利息收入」与财务费用下的「利息收入」）：都不要
            found[field] = "ambiguous"
            continue
        found[field] = row
    return {k: v for k, v in found.items() if v != "ambiguous"}, [k for k, v in found.items() if v == "ambiguous"], unmatched

RULES = [r for r in db.execute("select rule_id, rule, source_table, residual_expression from reconciliation_rules")]
TERMS = {
 "R01": [("total_assets", 1, 0), ("total_liabilities", -1, 0), ("total_equity", -1, 0)],
 "R02": [("total_assets", 1, 0), ("total_liab_equity", -1, 0)],
 "R03": [("total_equity", 1, 0), ("total_parent_equity", -1, 0), ("minority_equity", -1, 1)],
 "R04": [("total_assets", 1, 0), ("total_current_assets", -1, 0), ("total_noncurrent_assets", -1, 0)],
 "R05": [("total_liabilities", 1, 0), ("total_current_liab", -1, 0), ("total_noncurrent_liab", -1, 0)],
 "R06": [("netprofit", 1, 0), ("parent_netprofit", -1, 0), ("minority_interest", -1, 1)],
 "R07": [("netprofit", 1, 0), ("total_profit", -1, 0), ("income_tax", 1, 1)],
 "R08": [("cce_add", 1, 0), ("netcash_operate", -1, 0), ("netcash_invest", -1, 0), ("netcash_finance", -1, 0), ("rate_change_effect", -1, 1)],
 "R09": [("end_cce", 1, 0), ("begin_cce", -1, 0), ("cce_add", -1, 0)],
}

def reconcile(values, table):
    out = []
    for rule in RULES:
        if rule["source_table"] != table:
            continue
        total, complete = 0.0, True
        for name, sign, optional in TERMS[rule["rule_id"]]:
            v = values.get(name)
            if v is None:
                if optional: continue
                complete = False; break
            total += sign * v
        out.append((rule["rule_id"], None if not complete else round(total, 2)))
    return out

extracted = {}      # (报告年度, 表, 列) -> {科目: 数}
summary = {"reports": {}, "unmatched": collections.Counter(), "ambiguous": collections.Counter()}
for year in range(2017, 2026):
    data = json.load(open(f"{HERE}/out/rows-{year}.json"))
    info = {"problems": data["problems"], "statements": {}}
    for table in STATEMENTS:
        st = data["statements"].get(table)
        if not st:
            info["statements"][table] = {"located": False}; continue
        found, ambiguous, unmatched = resolve(table, st["rows"])
        for a in ambiguous: summary["ambiguous"][(table, a)] += 1
        for u in unmatched: summary["unmatched"][(table, normalize(u) or u)] += 1
        expected = [f for f in fields[table] if f not in NOT_IN_STATEMENT]
        cur = {f: r["current"] for f, r in found.items() if r["current"] is not None}
        pri = {f: r["prior"] for f, r in found.items() if r["prior"] is not None}
        extracted[(year, table, "current")] = cur
        extracted[(year, table, "prior")] = pri
        info["statements"][table] = {
            "located": True, "pages": st["pages"], "unit": st["unit"],
            "rows_with_numbers": sum(1 for r in st["rows"] if r["current"] is not None or r["prior"] is not None),
            "catalog_fields": len(expected), "matched_fields": sorted(found),
            "missing_fields": [f for f in expected if f not in found],
            "reconcile_current": reconcile(cur, table), "reconcile_prior": reconcile(pri, table),
        }
    summary["reports"][year] = info

# 与数据集比对
dataset = {}
for table in STATEMENTS:
    for r in db.execute(f"select * from {table} where report_type='年报' and fiscal_year between 2016 and 2025"):
        dataset[(r["fiscal_year"], table)] = dict(r)
compare = []
for (year, table, column), values in sorted(extracted.items()):
    fiscal = year if column == "current" else year - 1
    row = dataset.get((fiscal, table))
    if row is None:
        continue
    for field, value in sorted(values.items()):
        theirs = row.get(field)
        compare.append({"report_year": year, "column": column, "fiscal_year": fiscal, "table": table, "field": field,
                        "pdf": value, "dataset": theirs, "dataset_basis": row["basis"],
                        "same": theirs is not None and abs(theirs - value) <= TOLERANCE,
                        "dataset_missing": theirs is None})
json.dump({"summary": {"reports": summary["reports"],
                       "unmatched": [[list(k), v] for k, v in summary["unmatched"].most_common()],
                       "ambiguous": [[list(k), v] for k, v in summary["ambiguous"].most_common()]},
           "compare": compare}, open(f"{HERE}/out/compare.json", "w"), ensure_ascii=False, indent=1)

# ---------------- 打印
print("== 一、定位与认科目")
for year, info in summary["reports"].items():
    parts = []
    for table in STATEMENTS:
        s = info["statements"][table]
        parts.append(f"{table}: {len(s['matched_fields'])}/{s['catalog_fields']}" + (f" 缺{s['missing_fields']}" if s["missing_fields"] else ""))
    print(year, " | ".join(parts), "| 抽取报错", len(info["problems"]))
print("== 二、勾稽（年报原文抽出的数自己平不平）")
bad = 0; total = 0; skipped = 0
for year, info in summary["reports"].items():
    for table in STATEMENTS:
        for col in ("reconcile_current", "reconcile_prior"):
            for rule_id, residual in info["statements"][table][col]:
                if residual is None: skipped += 1; continue
                total += 1
                if abs(residual) > TOLERANCE:
                    bad += 1; print("  不平", year, col, rule_id, residual)
print(f"  检查 {total} 次，不平 {bad} 次，缺科目无法检查 {skipped} 次")
print("== 三、与数据集比对")
def rate(rows):
    rows = [r for r in rows if not r["dataset_missing"]]
    return f"{sum(r['same'] for r in rows)}/{len(rows)}" if rows else "0/0"
for column in ("current", "prior"):
    rows = [r for r in compare if r["column"] == column]
    print(f"  {column}: 一致 {rate(rows)}；数据集里没有这个数 {sum(r['dataset_missing'] for r in rows)}")
by = collections.defaultdict(list)
for r in compare: by[(r["fiscal_year"], r["column"], r["dataset_basis"])].append(r)
for key in sorted(by):
    print("   会计年度", key[0], "来自", "当年年报本期列" if key[1] == "current" else "下一年年报上期列", "| 数据集口径", key[2], "| 一致", rate(by[key]))
print("== 四、没认出来的带数字的行（按出现次数）")
for (table, label), n in summary["unmatched"].most_common(60):
    print("  ", n, table, label)
print("== 五、同名出现两次而放弃的科目", dict(summary["ambiguous"]))
