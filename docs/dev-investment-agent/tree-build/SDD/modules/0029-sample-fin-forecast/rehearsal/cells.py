"""把一份 Excel 按平台读表的样子（knowlab table_extract）写成 JSON，给 rehearse.py 用。

用法（在 knowlab-backend/app 下）：.venv/bin/python <本文件> <xlsx> <输出 json>
"""

from __future__ import annotations

import json
import sys

from app.infrastructure.documents.table_extract import extract_tables

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

tables = extract_tables(open(sys.argv[1], "rb").read(), XLSX)
out = {
    s.name: {
        "columns": list(s.columns),
        "rows": {r.label: {c: [v.raw, v.number] for c, v in r.cells.items()} for r in s.rows},
    }
    for s in tables.sheets
}
json.dump(out, open(sys.argv[2], "w"), ensure_ascii=False)
print({k: len(v["rows"]) for k, v in out.items()})
