"""R1 之后的残留盘点：改名范围内（与 rename_rules 同一范围、同一保留清单）还单独出现 info / knowledge 的行。

用法：python3 residual.py <五组仓的上一级目录> cfg|code   （cfg：配置、环境、脚本、说明以外的文本；code：.py/.ts/.tsx/.js/.mjs）
逐行人工过：剩下的应是领域词（knowledge_provider、/api/mcp/knowledge…）、日志级别、局部变量名、去重键等，不是应用名。
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rename_rules as rr  # noqa: E402

root, mode = Path(sys.argv[1]).expanduser(), sys.argv[2]
pat = re.compile(r"(?<![\w.-])(info|knowledge)(?![\w-])")
for rel in rr.scope(root):
    if rel.endswith((".md", ".mdc")) or "/messages/" in rel:
        continue
    is_code = Path(rel).suffix in (".py", ".ts", ".tsx", ".js", ".mjs", ".cjs")
    if (mode == "cfg") == is_code:
        continue
    try:
        lines = (root / rel).read_text(encoding="utf-8").splitlines()
    except (UnicodeDecodeError, FileNotFoundError):
        continue
    for i, line in enumerate(lines, 1):
        masked = line
        for keep in rr.KEEP:
            masked = re.sub(keep, "", masked)
        if pat.search(masked):
            print(f"{rel}:{i}: {line.strip()[:150]}")
