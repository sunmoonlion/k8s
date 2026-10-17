"""R1 之后的残留盘点（0028）：改名范围内（与 rename_rules 同一范围、同一保留清单）还出现 investment 的行。

用法：python3 residual.py <八组仓的上一级目录>
应当一行都没有；有就逐行看是不是该进保留清单（领域词、原话），不是就补规则。
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rename_rules as rr  # noqa: E402

root = Path(sys.argv[1]).expanduser()
pat = re.compile(r"[Ii]nvestment|INVESTMENT")
count = 0
for rel in rr.scope(root):
    try:
        lines = (root / rel).read_text(encoding="utf-8").splitlines()
    except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
        continue
    for i, line in enumerate(lines, 1):
        masked = line
        for keep in rr.KEEP:
            masked = re.sub(keep, "", masked)
        if pat.search(masked):
            count += 1
            print(f"{rel}:{i}: {line.strip()[:150]}")
print(f"残留 {count} 行")
