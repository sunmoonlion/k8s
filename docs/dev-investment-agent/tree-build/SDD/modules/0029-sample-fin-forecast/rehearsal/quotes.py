"""第 3 稿预演（第 6 步对照管理层讨论）的 knowlab 那一半：用 knowlab 真实的抽取与找原话代码。

在 knowlab-backend/app 下：
  PYTHONPATH=. .venv/bin/python <本文件> pages <map.json> <out.json>
      map.json：{数据 id: PDF 路径}；out.json：每份的 PDF 页文字与按标题找到的管理层讨论（第几页到第几页）
  PYTHONPATH=. .venv/bin/python <本文件> find <map.json>   （标准输入一串 {dataset_id, page, text}）
      照 knowbot-data/v1 quotes 回每条 {dataset_id, page, found, reason, version, sha256}
"""

from __future__ import annotations

import hashlib
import json
import re
import sys

from app.domain.knowbots.data_read import find_quote, pdf_pages
from app.infrastructure.documents.text_extract import extract_text

TITLES = ("管理层讨论与分析", "经营情况讨论与分析", "董事会报告")
HEAD = re.compile(r"^\s*第[一二三四五六七八九十]+节\s*(\S+)", re.M)


def load(path: str) -> tuple[dict[int, str], str]:
    data = open(path, "rb").read()
    return pdf_pages(extract_text(data, "application/pdf").text), hashlib.sha256(data).hexdigest()


def section(pages: dict[int, str]) -> dict | None:
    """正文里各节的开头（目录页一页有好几节，跳过）；按标题认管理层讨论，到下一节开头前一页止。"""
    heads = [(n, found[0]) for n, t in pages.items() if len(found := HEAD.findall(t)) == 1]
    for i, (start, title) in enumerate(heads):
        if title.startswith(TITLES):
            end = heads[i + 1][0] - 1 if i + 1 < len(heads) else max(pages)
            return {"title": title, "first_page": start, "last_page": end}
    return None


def main() -> None:
    mode, mapping = sys.argv[1], json.load(open(sys.argv[2]))
    if mode == "pages":
        out = {}
        for dataset_id, path in mapping.items():
            pages, _ = load(path)
            out[dataset_id] = {"section": section(pages), "pages": {str(n): t for n, t in pages.items()}}
        json.dump(out, open(sys.argv[3], "w"), ensure_ascii=False)
        return
    loaded = {d: load(p) for d, p in mapping.items()}
    result = []
    for q in json.load(sys.stdin):
        pages, sha = loaded[q["dataset_id"]]
        reason = find_quote(pages, q["page"], q["text"])
        result.append({"dataset_id": q["dataset_id"], "page": q["page"], "found": reason is None, "reason": reason, "version": "1", "sha256": sha})
    json.dump(result, sys.stdout, ensure_ascii=False)


main()
