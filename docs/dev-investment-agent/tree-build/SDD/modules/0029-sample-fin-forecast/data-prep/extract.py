"""从贵州茅台定期报告原件（巨潮）抽合并三张表与主要会计数据，写成 JSON。

用法：python -I extract.py <reports.json> <原件目录> <输出 json>
每期只取「本期」那一栏；报表按页面上的标题分合并与母公司，只取合并的。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import pdfplumber

HEADINGS = [
    ("合并资产负债表", "资产负债表"),
    ("母公司资产负债表", None),
    ("合并利润表", "利润表"),
    ("母公司利润表", None),
    ("合并现金流量表", "现金流量表"),
    ("母公司现金流量表", None),
    ("合并所有者权益变动表", None),
]
NUM = re.compile(r"^-?\(?[\d,]+(\.\d+)?\)?$")
PREFIX = re.compile(r"^(?:[一二三四五六七八九十]+、|（[一二三四五六七八九十]+）|\([一二三四五六七八九十]+\)|\d+[\.、]|其中：|其中:|加：|加:|减：|减:)+")


def clean(label: str) -> str:
    return PREFIX.sub("", re.sub(r"\s+", "", label or "")).strip()


def number(cell: str | None) -> str | None:
    text = re.sub(r"\s+", "", cell or "")
    if not text or not NUM.match(text):
        return None
    return text


def heading_positions(page) -> list[tuple[float, str | None, str]]:
    """这一页上各个报表标题的纵坐标。"""
    text_lines = page.extract_text_lines() if hasattr(page, "extract_text_lines") else []
    found = []
    for line in text_lines:
        t = re.sub(r"\s+", "", line["text"])
        for title, sheet in HEADINGS:
            if t == title or (t.startswith(title) and len(t) <= len(title) + 2):
                found.append((line["top"], sheet, title))
    return sorted(found)


def cur_column(header: list[str]) -> int | None:
    """表头里第一个期间栏的位置（跳过「项目」「附注」）。"""
    for i, cell in enumerate(header):
        c = re.sub(r"\s+", "", cell or "")
        if i == 0 or c in ("", "附注", "项目"):
            continue
        if re.search(r"20\d\d|期末|期初|本期|上期|年度|季度", c):
            return i
    return None


def statements(pdf, start: int) -> tuple[dict[str, list[tuple[str, str, str | None]]], dict[str, int]]:
    """从合并资产负债表那页起，按顺序读到合并现金流量表结束。"""
    out: dict[str, list] = {"资产负债表": [], "利润表": [], "现金流量表": []}
    pages: dict[str, int] = {}
    current: str | None = None
    col: int | None = None
    done = False
    for pno in range(start, min(start + 25, len(pdf.pages))):
        page = pdf.pages[pno]
        marks = heading_positions(page)
        tables = page.find_tables()
        events = [(m[0], "head", m) for m in marks] + [(t.bbox[1], "table", t) for t in tables]
        for _, kind, obj in sorted(events, key=lambda e: e[0]):
            if kind == "head":
                _, sheet, title = obj
                if current == "现金流量表" and sheet != "现金流量表":
                    done = True
                    break
                current = sheet
                col = None
                if sheet and sheet not in pages:
                    pages[sheet] = pno + 1
                continue
            if current is None:
                continue
            rows = obj.extract()
            for row in rows:
                cells = [(c or "").replace("\n", "") for c in row]
                if not cells:
                    continue
                if re.sub(r"\s+", "", cells[0]) == "项目":
                    col = cur_column(cells)
                    continue
                if col is None or col >= len(cells):
                    continue
                label = clean(cells[0])
                if not label:
                    continue
                out[current].append((label, re.sub(r"\s+", "", cells[0]), number(cells[col])))
        if done:
            break
    return out, pages


def key_figures(pdf, limit: int = 12) -> tuple[dict[str, str | None], int | None]:
    """「主要会计数据和财务指标」里的五项（本期那一栏）。"""
    want = {
        "营业收入": "营业收入",
        "归属于上市公司股东的净利润": "归属于上市公司股东的净利润",
        "归属于上市公司股东的扣除非经常性损益的净利润": "归属于上市公司股东的扣除非经常性损益的净利润",
        "经营活动产生的现金流量净额": "经营活动产生的现金流量净额",
        "加权平均净资产收益率": "加权平均净资产收益率",
    }
    found: dict[str, str | None] = {}
    page_no = None
    for pno in range(min(limit, len(pdf.pages))):
        page = pdf.pages[pno]
        if "主要会计数据" not in (page.extract_text() or ""):
            continue
        for table in page.extract_tables():
            for row in table:
                cells = [re.sub(r"\s+", "", c or "") for c in row]
                if not cells or not cells[0]:
                    continue
                for name, key in want.items():
                    if key in found:
                        continue
                    if cells[0].startswith(name) and (name != "营业收入" or cells[0] in ("营业收入",)):
                        vals = [number(c) for c in cells[1:]]
                        vals = [v for v in vals if v is not None]
                        if vals:
                            found[key] = vals[0]
                            page_no = page_no or pno + 1
        if len(found) == len(want):
            break
    return found, page_no


def first_statement_page(pdf) -> int:
    """合并资产负债表正文所在页：标题单独成行、页上有「编制单位」或表头「项目」。"""
    for pno, page in enumerate(pdf.pages):
        for top, sheet, title in heading_positions(page):
            if title == "合并资产负债表":
                text = page.extract_text() or ""
                if "编制单位" in text or "项目" in text:
                    return pno
    raise SystemExit("no consolidated balance sheet")


def main() -> None:
    reports = json.loads(Path(sys.argv[1]).read_text())
    raw = Path(sys.argv[2])
    result = []
    for r in reports:
        with pdfplumber.open(raw / f"{r['period']}.pdf") as pdf:
            start = first_statement_page(pdf)
            st, pages = statements(pdf, start)
            kf, kf_page = key_figures(pdf)
        result.append({**r, "statements": st, "pages": pages, "key_figures": kf, "key_page": kf_page})
        print(r["period"], {k: len(v) for k, v in st.items()}, pages, "key", len(kf), kf_page, file=sys.stderr)
    Path(sys.argv[3]).write_text(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
