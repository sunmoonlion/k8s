"""按公司批量抽取：一遍扫过年报，找到三张合并报表，按页面坐标抽每一行。
只读留存的原件；不访问网络。用法：python extract_company.py <代码> [<代码> ...]"""
import glob, json, os, re, sys, time, logging
import pdfplumber
logging.getLogger("pdfminer").setLevel(logging.ERROR)
STORE = os.path.expanduser("~/info-smoke-storage/development-info-originals/info/securities")
OUT = os.path.expanduser("~/annual-report-probe/batch/out")
WANTED = {"合并资产负债表": "balance_sheet", "合并利润表": "income_statement", "合并现金流量表": "cash_flow"}
OTHER = re.compile(r"^(母公司|公司|本公司)?(资产负债表|利润表|现金流量表|所有者权益变动表|股东权益变动表)$|^合并(所有者权益变动表|股东权益变动表)$")
COMBINED = re.compile(r"^合并及(母公司|公司)(资产负债表|利润表|现金流量表)$")
COMBINED_NAME = {"资产负债表": "balance_sheet", "利润表": "income_statement", "现金流量表": "cash_flow"}
NUMBER = re.compile(r"^[-－—]?[（(]?[-－]?\d{1,3}(,\d{3})*(\.\d+)?[)）]?$|^[-－—]?[（(]?[-－]?\d+(\.\d+)?[)）]?$")
STRONG = re.compile(r"[,.]")            # 带千分位或小数点的，才拿来判断列的位置
UNIT = re.compile(r"(百万元|千元|万元|元)")
UNIT_LINE = re.compile(r"单位为?[:：]?(人民币)?(百万元|千元|万元|元)|人民币(百万元|千元|万元|元)")
# 有的年报只在财务报表开头说一次「财务附注中报表的单位为：千元」，后面每张表不再写
DECLARED = re.compile(r"报表的?单位为?[:：]?(人民币)?(百万元|千元|万元|元)")
CJK = re.compile(r"[一-鿿]")
FIRST_PAGE, MAX_SECTION_PAGES = 12, 8

def squeeze(s): return re.sub(r"\s+", "", s)

NUMBERING = re.compile(r"^(\d+[、.．]|[（(][一二三四五六七八九十\d]+[)）]|[一二三四五六七八九十]+、)")
PERIOD = re.compile(r"^\d{4}年(度|\d{1,2}月\d{1,2}日)?")
CONTINUED = re.compile(r"[（(]续[)）]$")
def title_of(joined):
    """认标题前去掉：序号（「1、合并资产负债表」）、印在同一行的期间（「2024年度合并及公司利润表」）、
    续页的「(续)」。去掉之后要是不以「表」结尾，就不是标题，原样返回。"""
    t = CONTINUED.sub("", PERIOD.sub("", NUMBERING.sub("", joined)))
    return t if t.endswith("表") and len(t) <= 14 else joined

def lines_of(page):
    rows = {}
    for w in page.extract_words(x_tolerance=1.5, y_tolerance=2, keep_blank_chars=False):
        rows.setdefault(round(w["top"] / 3), []).append(w)
    merged = []
    for key in sorted(rows):
        ws = sorted(rows[key], key=lambda w: w["x0"])
        if merged and abs(ws[0]["top"] - merged[-1][0]["top"]) < 3:
            merged[-1] = sorted(merged[-1] + ws, key=lambda w: w["x0"])
        else:
            merged.append(ws)
    return merged

def page_unit(page_lines):
    """单位可能写在标题上面（「金额单位为人民币千元」），也可能写在标题下面。"""
    for ws in page_lines:
        m = UNIT_LINE.search(squeeze("".join(w["text"] for w in ws)))
        if m:
            return m.group(2) or m.group(3)
    return None

def value(token):
    t = token.replace(",", "").replace("（", "(").replace("）", ")").replace("－", "-").replace("—", "-")
    negative = "-" in t or "(" in t
    t = t.strip("()-")
    return -float(t) if negative else float(t)

def columns(tokens, wanted=2):
    """数字右对齐：右边缘最集中的两处是两列。
    合并与母公司并排的版式有四列，左边两列是合并的本期与上期。"""
    bins = {}
    for x in tokens:
        bins.setdefault(round(x / 8), []).append(x)
    centres = sorted(((len(v), sum(v) / len(v)) for v in bins.values()), reverse=True)
    picked = []
    for count, centre in centres:
        if all(abs(centre - c) > 30 for _, c in picked):
            picked.append((count, centre))
    if wanted == 4:
        dense = [c for n, c in picked if n >= 0.3 * picked[0][0]]
        if len(dense) != 4:
            return None, f"expected_four_columns_found_{len(dense)}"
        return tuple(sorted(dense)[:2]), None
    if len(picked) < 2:
        return None, "one_column"
    if len(picked) >= 3 and picked[2][0] >= 0.4 * picked[0][0]:
        return None, "more_than_two_columns"
    return tuple(sorted(c for _, c in picked[:2])), None

def extract(path):
    sections, problems, current, done, declared = {}, [], None, set(), None
    with pdfplumber.open(path) as doc:
        total = len(doc.pages)
        for number in range(FIRST_PAGE, total + 1):
            if len(done) == 3 and current is None:
                break
            page_lines = lines_of(doc.pages[number - 1])
            doc.pages[number - 1].flush_cache()
            for ws in page_lines:
                raw = squeeze("".join(w["text"] for w in ws))
                said = DECLARED.search(raw)
                if said:
                    declared = said.group(2)
                joined = title_of(raw)
                both = COMBINED.match(joined)
                name = COMBINED_NAME[both.group(2)] if both else WANTED.get(joined)
                if name and name not in done and current is None:
                    current = name
                    sections[current] = {"start": number, "lines": [], "unit": page_unit(page_lines), "wide": bool(both), "declared": declared}
                    continue
                if current and (OTHER.match(joined) or (name and name != current)):
                    done.add(current)
                    current = None
                    if name and name not in done:
                        current = name
                        sections[current] = {"start": number, "lines": [], "unit": page_unit(page_lines), "wide": bool(both), "declared": declared}
                    continue
                if current:
                    sec = sections[current]
                    if number - sec["start"] >= MAX_SECTION_PAGES:
                        problems.append(f"{current}: 超过 {MAX_SECTION_PAGES} 页还没结束，放弃")
                        sections.pop(current); current = None
                        continue
                    if sec["unit"] is None:
                        sec["unit"] = page_unit([ws])
                    sec["lines"].append((number, ws))
    result = {"file": os.path.basename(path), "pages": total, "problems": problems, "statements": {}}
    for name, sec in sections.items():
        if name not in done:
            result["problems"].append(f"{name}: 没找到结束位置"); continue
        if sec["unit"] is None:
            sec["unit"] = sec.get("declared")
        if sec["unit"] is None:
            result["problems"].append(f"{name}: 没写单位"); continue
        per_page, bad, sparse = {}, False, []
        for number in sorted({n for n, _ in sec["lines"]}):
            xs = [w["x1"] for n, ws in sec["lines"] if n == number for w in ws
                  if NUMBER.match(w["text"]) and STRONG.search(w["text"])]
            if len(xs) < 4:
                sparse.append(number)       # 这一页只有表头下面的一两行：借相邻页的列位置
                continue
            cols, why = columns(xs, 4 if sec["wide"] else 2)
            if cols is None:
                result["problems"].append(f"{name} p{number}: {why}"); bad = bad or why != "one_column"
                continue
            per_page[number] = cols
        if bad or not per_page:
            continue
        for number in sparse:
            nearest = min(per_page, key=lambda n: abs(n - number))
            if abs(nearest - number) == 1:
                per_page[number] = per_page[nearest]
        rows = []
        for number, ws in sec["lines"]:
            cols = per_page.get(number)
            label = "".join(w["text"] for w in ws if CJK.search(w["text"]))
            nums = [w for w in ws if NUMBER.match(w["text"]) and not CJK.search(w["text"])]
            cur = [w for w in nums if cols and abs(w["x1"] - cols[0]) <= 12]
            pri = [w for w in nums if cols and abs(w["x1"] - cols[1]) <= 12]
            if len(cur) > 1 or len(pri) > 1:
                result["problems"].append(f"{name} p{number}: 一列里有两个数：{squeeze(label)[:20]}"); continue
            if not label and not cur and not pri:
                continue
            rows.append({"page": number, "label": squeeze(label),
                         "current": value(cur[0]["text"]) if cur else None,
                         "prior": value(pri[0]["text"]) if pri else None})
        result["statements"][name] = {"start": sec["start"], "unit": sec["unit"], "rows": rows, "side_by_side": sec["wide"],
                                      "columns_x": {k: [round(v[0], 1), round(v[1], 1)] for k, v in per_page.items()}}
    return result

if __name__ == "__main__":
    for code in sys.argv[1:]:
        files = sorted(glob.glob(f"{STORE}/code={code}/source=cninfo/sha256=*/*/annual-*.pdf"))
        latest = {}
        for path in files:                      # 同一年有多份（更正版）时取公告编号最大的
            _, year, ident = os.path.basename(path)[:-4].split("-")
            if year not in latest or int(ident) > latest[year][0]:
                latest[year] = (int(ident), path)
        os.makedirs(f"{OUT}/{code}", exist_ok=True)
        started = time.time()
        for year, (_, path) in sorted(latest.items()):
            target = f"{OUT}/{code}/rows-{year}.json"
            if os.path.exists(target):
                continue
            try:
                result = extract(path)
            except Exception as exc:           # 一份读不了不影响别的
                result = {"file": os.path.basename(path), "pages": 0, "statements": {}, "problems": [f"读不了：{type(exc).__name__}"]}
            result["year"] = int(year); result["versions"] = sum(1 for p in files if f"annual-{year}-" in p)
            json.dump(result, open(target, "w"), ensure_ascii=False)
        print(code, "reports", len(latest), "seconds", round(time.time() - started, 1), flush=True)
