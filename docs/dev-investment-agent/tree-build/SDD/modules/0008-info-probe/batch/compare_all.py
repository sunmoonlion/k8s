"""认科目、勾稽、与数据集比对；每家公司一份明细，外加一张汇总表。
用法：python compare_all.py <代码> [<代码> ...]   （不给代码就处理 out/ 下所有公司）"""
import collections, glob, json, os, re, sqlite3, sys
HERE = os.path.expanduser("~/annual-report-probe/batch")
STATEMENTS = ("balance_sheet", "income_statement", "cash_flow")
FACTOR = {"元": 1.0, "千元": 1e3, "万元": 1e4, "百万元": 1e6}
# 附注编号的几种写法：（六十一）、五（一）、七、1、十七、（3）、六.12
NOTE = re.compile(r"([一二三四五六七八九十]+[、.．]?)?([（(][一二三四五六七八九十百零\d]+[)）]|\d+)$")
PREFIX = re.compile(r"^([一二三四五六七八九十]+、|[（(][一二三四五六七八九十]+[)）]|\d+[.．、]|其中：|加：|减：)+")
PAREN = re.compile(r"[（(][^（）()]*(填列|或股东权益|或股本|元/股)[^（）()]*[)）]?")
ALIASES = {"balance_sheet": {"实收资本": "share_capital", "股本": "share_capital", "实收资本股本": "share_capital",
                             "股东权益合计": "total_equity", "归属于母公司股东权益合计": "total_parent_equity",
                             "归属于母公司股东的权益合计": "total_parent_equity", "负债和股东权益总计": "total_liab_equity",
                             "负债及股东权益总计": "total_liab_equity"},
           "income_statement": {"归属于母公司股东的净利润": "parent_netprofit", "所得税费用": "income_tax"},
           "cash_flow": {"汇率变动对现金及现金等价物的影响": "rate_change_effect",
                         "年初现金及现金等价物余额": "begin_cce", "年末现金及现金等价物余额": "end_cce"}}
NOT_IN_STATEMENT = {"deduct_parent_netprofit"}
TERMS = {
 "R01": ("balance_sheet", [("total_assets", 1, 0), ("total_liabilities", -1, 0), ("total_equity", -1, 0)]),
 "R02": ("balance_sheet", [("total_assets", 1, 0), ("total_liab_equity", -1, 0)]),
 "R03": ("balance_sheet", [("total_equity", 1, 0), ("total_parent_equity", -1, 0), ("minority_equity", -1, 1)]),
 "R04": ("balance_sheet", [("total_assets", 1, 0), ("total_current_assets", -1, 0), ("total_noncurrent_assets", -1, 0)]),
 "R05": ("balance_sheet", [("total_liabilities", 1, 0), ("total_current_liab", -1, 0), ("total_noncurrent_liab", -1, 0)]),
 "R06": ("income_statement", [("netprofit", 1, 0), ("parent_netprofit", -1, 0), ("minority_interest", -1, 1)]),
 "R07": ("income_statement", [("netprofit", 1, 0), ("total_profit", -1, 0), ("income_tax", 1, 1)]),
 "R08": ("cash_flow", [("cce_add", 1, 0), ("netcash_operate", -1, 0), ("netcash_invest", -1, 0), ("netcash_finance", -1, 0), ("rate_change_effect", -1, 1)]),
 "R09": ("cash_flow", [("end_cce", 1, 0), ("begin_cce", -1, 0), ("cce_add", -1, 0)]),
}

def normalize(label):
    s = NOTE.sub("", label)
    s = PREFIX.sub("", s)
    s = PAREN.sub("", s)
    s = re.sub(r"[（）()“”\"－\-\s:：]", "", s)
    return s.replace("所有者", "股东")

def load_catalog(db):
    catalog = {t: {} for t in STATEMENTS}
    for r in db.execute("select source_table, field, display_name from field_dictionary where unit='元'"):
        catalog[r["source_table"]][normalize(r["display_name"])] = r["field"]
    for t in STATEMENTS:
        catalog[t].update(ALIASES[t])
    return catalog

def match(catalog, table, label):
    key = normalize(label)
    if key in catalog[table]:
        return catalog[table][key]
    if len(key) >= 10:
        hits = {f for name, f in catalog[table].items() if name.startswith(key)}
        if len(hits) == 1:
            return hits.pop()
    return None

def resolve(catalog, table, rows):
    found, unmatched, used = {}, [], set()
    empty = lambda r: r["current"] is None and r["prior"] is None
    for i, row in enumerate(rows):
        if empty(row):
            continue
        before = rows[i - 1]["label"] if i and empty(rows[i - 1]) and i - 1 not in used else ""
        after = rows[i + 1]["label"] if i + 1 < len(rows) and empty(rows[i + 1]) else ""
        own = NOTE.sub("", row["label"])
        field = match(catalog, table, own) if own else None
        taken = ()
        if field is None:
            options = ([(before + own, (i - 1,)), (own + after, (i + 1,)), (before + own + after, (i - 1, i + 1))]
                       if own else [(before + after, (i - 1, i + 1))])
            for candidate, neighbours in options:
                if candidate and candidate != own:
                    field = match(catalog, table, candidate)
                if field:
                    taken = neighbours; break
        used.update(taken)
        if field is None:
            unmatched.append(normalize(own) or "（无标签）"); continue
        found[field] = "ambiguous" if field in found else row
    return ({k: v for k, v in found.items() if v != "ambiguous"},
            [k for k, v in found.items() if v == "ambiguous"], unmatched)

def process(code):
    path = f"{HERE}/datasets/{code}.sqlite"
    reports = sorted(glob.glob(f"{HERE}/out/{code}/rows-*.json"))
    line = {"code": code, "reports": len(reports), "dataset": os.path.exists(path)}
    if not reports:
        return line | {"note": "没有年报"}
    # 没有第三方数据可比的公司：科目目录借用别家的（目录对所有公司相同），只做勾稽
    db = sqlite3.connect(f"file:{path if line['dataset'] else HERE + '/datasets/600009.sqlite'}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    catalog = load_catalog(db)
    dataset = {(r["fiscal_year"], t): dict(r) for t in STATEMENTS
               for r in db.execute(f"select * from {t} where report_type='年报'")} if line["dataset"] else {}
    detail = {"reports": {}, "compare": [], "unbalanced": [], "missed": [], "unmatched": collections.Counter()}
    located = checks = numeric = matched = problems = 0
    units = set()
    for file in reports:
        data = json.load(open(file)); year = data["year"]
        problems += len(data["problems"])
        info = {"problems": data["problems"], "statements": {}}
        for table in STATEMENTS:
            st = data["statements"].get(table)
            if not st:
                continue
            located += 1; units.add(st["unit"]); factor = FACTOR[st["unit"]]
            found, ambiguous, unmatched = resolve(catalog, table, st["rows"])
            for u in unmatched: detail["unmatched"][f"{table}:{u}"] += 1
            numeric += sum(1 for r in st["rows"] if r["current"] is not None or r["prior"] is not None)
            matched += len(found)
            info["statements"][table] = {"matched": sorted(found), "ambiguous": ambiguous}
            for column, fiscal in (("current", year), ("prior", year - 1)):
                values = {f: r[column] * factor for f, r in found.items() if r[column] is not None}
                for rule_id, (rule_table, terms) in TERMS.items():
                    if rule_table != table:
                        continue
                    total, complete = 0.0, True
                    for name, sign, optional in terms:
                        v = values.get(name)
                        if v is None:
                            if optional: continue
                            complete = False; break
                        total += sign * v
                    if complete:
                        checks += 1
                        if abs(total) > max(1.0, factor):
                            detail["unbalanced"].append([year, column, rule_id, round(total, 2)])
                row = dataset.get((fiscal, table))
                if row is None:
                    continue
                for field, v in sorted(values.items()):
                    theirs = row.get(field)
                    if theirs is None:
                        continue
                    tolerance = max(1.0, factor)
                    detail["compare"].append({"report_year": year, "column": column, "fiscal_year": fiscal, "table": table,
                                              "field": field, "pdf": v, "dataset": theirs, "basis": row["basis"],
                                              "same": abs(theirs - v) <= tolerance,
                                              "sign_only": abs(theirs - v) > tolerance and abs(abs(theirs) - abs(v)) <= tolerance})
                if column == "current" and row["basis"] == "原始披露":
                    for field in catalog_fields(catalog, table):
                        if field not in values and row.get(field) not in (None, 0):
                            detail["missed"].append([year, table, field, row[field]])
        detail["reports"][year] = info
    detail["unmatched"] = detail["unmatched"].most_common()
    json.dump(detail, open(f"{HERE}/out/{code}/compare.json", "w"), ensure_ascii=False, indent=1)
    # 归类：同一年、同一科目，当年年报的本期列与下一年年报的上期列各是多少
    own = {(r["fiscal_year"], r["table"], r["field"]): r["pdf"] for r in detail["compare"] if r["column"] == "current"}
    later = {(r["fiscal_year"], r["table"], r["field"]): r["pdf"] for r in detail["compare"] if r["column"] == "prior"}
    for r in detail["compare"]:
        key = (r["fiscal_year"], r["table"], r["field"])
        a, b = own.get(key), later.get(key)
        restated = a is not None and b is not None and abs(a - b) > max(1.0, 1000.0 if "千元" in units else 1.0)
        if r["same"]:
            r["kind"] = "same"
        elif r["sign_only"]:
            r["kind"] = "sign"                  # 数相同，正负号相反：列报习惯不同
        elif restated or (r["column"] == "current" and r["basis"] == "追溯调整后"):
            r["kind"] = "restated"              # 两份年报对这一年这个科目给的数不同，或数据集这一年本来就是调整后的数
        elif abs(r["dataset"] - r["pdf"]) <= 10000 and abs(r["dataset"] - r["pdf"]) <= 1e-5 * max(1.0, abs(r["pdf"])):
            r["kind"] = "rounding"              # 差在万元以内且不到十万分之一：对方取的是按万元或千元列示的数
        else:
            r["kind"] = "unexplained"
    kinds = collections.Counter(r["kind"] for r in detail["compare"])
    json.dump(detail, open(f"{HERE}/out/{code}/compare.json", "w"), ensure_ascii=False, indent=1)
    cur = [r for r in detail["compare"] if r["column"] == "current"]
    pri = [r for r in detail["compare"] if r["column"] == "prior"]
    cur_same_basis = [r for r in cur if r["basis"] == "原始披露"]
    return line | {
        "statements": f"{located}/{len(reports) * 3}", "units": "、".join(sorted(units)), "problems": problems,
        "checks": checks, "unbalanced": len(detail["unbalanced"]),
        "prior": f"{sum(r['same'] for r in pri)}/{len(pri)}",
        "current_original": f"{sum(r['same'] for r in cur_same_basis)}/{len(cur_same_basis)}",
        "current_other_basis": f"{sum(r['same'] for r in cur if r['basis'] != '原始披露')}/{len(cur) - len(cur_same_basis)}",
        "missed": len(detail["missed"]), "rows": numeric, "matched": matched,
        "compared": len(detail["compare"]), "same": kinds["same"], "sign": kinds["sign"],
        "restated": kinds["restated"], "rounding": kinds["rounding"], "unexplained": kinds["unexplained"],
    }

def catalog_fields(catalog, table):
    return sorted(set(catalog[table].values()) - NOT_IN_STATEMENT)

if __name__ == "__main__":
    codes = sys.argv[1:] or sorted(os.path.basename(p) for p in glob.glob(f"{HERE}/out/*") if os.path.isdir(p))
    names = {l.split("\t")[0]: l.rstrip("\n").split("\t") for l in open(f"{HERE}/companies.tsv")}
    names.setdefault("600009", ["600009", "上海机场", "上交所主板", "机场"])
    lines = [process(c) for c in codes]
    json.dump(lines, open(f"{HERE}/out/summary.json", "w"), ensure_ascii=False, indent=1)
    head = "代码 | 公司 | 年报 | 表 | 单位 | 抽取报错 | 勾稽(不平/次数) | 能比的数 | 相同 | 重述或重新归类 | 只差正负号 | 精度 | 没解释 | 漏抽 | 带数字的行 | 对上目录"
    print(head)
    for l in lines:
        n = names.get(l["code"], [l["code"], "?"])[1]
        if "statements" not in l:
            print(l["code"], "|", n, "|", l["reports"], "|", l.get("note")); continue
        print(" | ".join(str(x) for x in (l["code"], n, l["reports"], l["statements"], l["units"], l["problems"],
              f"{l['unbalanced']}/{l['checks']}", l["compared"], l["same"], l["restated"], l["sign"], l["rounding"], l["unexplained"],
              l["missed"], l["rows"], l["matched"])))
