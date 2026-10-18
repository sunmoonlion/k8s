import json, re, sys
d = json.load(open(sys.argv[1]))
want = {}
for a in d:
    t = re.sub(r"</?em>", "", a["title"])
    if any(x in t for x in ("摘要", "英文", "正文")):
        continue
    m = re.search(r"(20\d\d)年(年度报告|半年度报告|第一季度报告|第三季度报告)$", t)
    if not m:
        continue
    y, k = m.group(1), m.group(2)
    end = {"第一季度报告": "03-31", "半年度报告": "06-30", "第三季度报告": "09-30", "年度报告": "12-31"}[k]
    period = f"{y}-{end}"
    if "2021-03-31" <= period <= "2026-06-30":
        want[period] = {"period": period, "title": t, "url": "https://static.cninfo.com.cn/" + a["url"]}
json.dump([want[p] for p in sorted(want)], sys.stdout, ensure_ascii=False, indent=1)
