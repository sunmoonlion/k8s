"""第二步：从每份年报里抽出三张合并报表的每一行（科目、本期、上期）。
按页面上的坐标判断数字属于哪一列：数字右对齐，所以用右边缘分两组。
只读留存的原件；不访问网络。"""
import glob, json, os, re, sys, logging
import pdfplumber
logging.getLogger("pdfminer").setLevel(logging.ERROR)
ROOT = os.path.expanduser("~/info-smoke-storage/development-info-originals/info/securities/code=600009/source=cninfo")
HERE = os.path.expanduser("~/annual-report-probe")
STATEMENTS = [("balance_sheet", "合并资产负债表", "母公司资产负债表"),
              ("income_statement", "合并利润表", "母公司利润表"),
              ("cash_flow", "合并现金流量表", "母公司现金流量表")]
AMOUNT = re.compile(r"^-?\(?-?\d{1,3}(,\d{3})*\.\d{2}\)?$|^-?\(?-?\d+\.\d{2}\)?$")
CJK = re.compile(r"[一-鿿]")

def squeeze(s): return re.sub(r"\s+", "", s)

def first_page(pages, title):
    for p in pages:
        if any(squeeze(l) == title for l in p["text"].split("\n")):
            return p["page"]
    return None

def amount(token):
    t = token.replace(",", "")
    negative = t.startswith("-") or t.startswith("(")
    t = t.strip("()-")
    v = float(t)
    return -v if negative else v

def lines_of(page):
    words = page.extract_words(x_tolerance=1.5, y_tolerance=2, keep_blank_chars=False)
    rows = {}
    for w in words:
        key = round(w["top"] / 3)
        rows.setdefault(key, []).append(w)
    merged = []
    for key in sorted(rows):
        ws = sorted(rows[key], key=lambda w: w["x0"])
        if merged and abs(ws[0]["top"] - merged[-1][0]["top"]) < 3:
            merged[-1] = sorted(merged[-1] + ws, key=lambda w: w["x0"])
        else:
            merged.append(ws)
    return merged

def extract(path, year, pages_text):
    result = {"year": year, "statements": {}, "problems": []}
    with pdfplumber.open(path) as doc:
        for name, title, following in STATEMENTS:
            start, end = first_page(pages_text, title), first_page(pages_text, following)
            if start is None or end is None or not (0 < end - start <= 6):
                result["problems"].append(f"{name}: section not located ({start}, {end})")
                continue
            raw = []
            unit = None
            for number in range(start, end + 1):
                page = doc.pages[number - 1]
                text = pages_text[number - 1]["text"]
                m = re.search(r"单位[:：]\s*(百万元|万元|千元|元)", text)
                if m and unit is None and number == start:
                    unit = m.group(1)
                started = number != start
                for ws in lines_of(page):
                    joined = squeeze("".join(w["text"] for w in ws))
                    if not started:
                        started = joined == title
                        continue
                    if joined == following:
                        break
                    raw.append((number, ws))
            amounts = [w["x1"] for _, ws in raw for w in ws if AMOUNT.match(w["text"])]
            if not amounts or unit is None:
                result["problems"].append(f"{name}: no amounts or unit not stated")
                continue
            # 同一张表跨页时，两页的列位置可能不同（2022 年利润表就是），所以每页单独分列
            splits = {}
            for number in sorted({n for n, _ in raw}):
                xs = [w["x1"] for n, ws in raw if n == number for w in ws if AMOUNT.match(w["text"])]
                if not xs:
                    continue
                # 数字右对齐：取右边缘最集中的两处作为两列；正文里夹着的金额不在这两处，不算
                bins = {}
                for x in xs:
                    bins.setdefault(round(x / 8), []).append(x)
                ranked = sorted(bins.values(), key=len, reverse=True)
                first = sum(ranked[0]) / len(ranked[0])
                others = [g for g in ranked[1:] if abs(sum(g) / len(g) - first) > 40]
                if not others:
                    result["problems"].append(f"{name} p{number}: only one column has amounts, cannot tell which")
                    continue
                second = sum(others[0]) / len(others[0])
                splits[number] = (min(first, second), max(first, second))
            rows = []
            for number, ws in raw:
                left, right = splits.get(number, (None, None))
                label = "".join(w["text"] for w in ws if CJK.search(w["text"]) and not AMOUNT.match(w["text"]))
                current = [w for w in ws if AMOUNT.match(w["text"]) and left is not None and abs(w["x1"] - left) <= 12]
                prior = [w for w in ws if AMOUNT.match(w["text"]) and right is not None and abs(w["x1"] - right) <= 12]
                stray = [w for w in ws if AMOUNT.match(w["text"]) and w not in current and w not in prior]
                if stray and (current or prior):
                    result["problems"].append(f"{name} p{number}: amount outside both columns: {squeeze(label)}")
                    continue
                if len(current) > 1 or len(prior) > 1:
                    result["problems"].append(f"{name} p{number}: two amounts in one column: {squeeze(label)}")
                    continue
                if not label and not current and not prior:
                    continue
                rows.append({"page": number, "label": squeeze(label),
                             "current": amount(current[0]["text"]) if current else None,
                             "prior": amount(prior[0]["text"]) if prior else None})
            result["statements"][name] = {"pages": [start, end - 1 if end > start else start], "unit": unit,
                                          "columns_x": {k: [round(v[0], 1), round(v[1], 1)] for k, v in splits.items()}, "rows": rows}
    return result

if __name__ == "__main__":
    years = [int(a) for a in sys.argv[1:]] or list(range(2017, 2026))
    for path in sorted(glob.glob(ROOT + "/sha256=*/*/annual-*.pdf")):
        year = int(os.path.basename(path).split("-")[1])
        if year not in years:
            continue
        pages_text = json.load(open(f"{HERE}/cache/text-{year}.json"))["pages"]
        out = extract(path, year, pages_text)
        json.dump(out, open(f"{HERE}/out/rows-{year}.json", "w"), ensure_ascii=False, indent=1)
        print(year, {k: (v["pages"], v["unit"], len(v["rows"]), sum(1 for r in v["rows"] if r["current"] is not None)) for k, v in out["statements"].items()}, "problems:", out["problems"][:3])
