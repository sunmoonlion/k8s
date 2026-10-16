"""「冻结解除之后」第 4 条（k8s/docs/rename.md）：把 k8s/sunmoonai/ 里还活着的几块搬出来，改好各仓的引用。

用法（远程机 qwen 工位，k8s 仓根）：
  python3 docs/rename-tools/moveout_sunmoonai.py plan     # 只报：要挪的文件、要改的引用、指向将删除区域的链接、改不了的残留
  python3 docs/rename-tools/moveout_sunmoonai.py apply    # git mv + 改引用（不提交）

改引用的范围是 qwen 工位六组仓（含子仓）里 git 跟踪的文本文件，两遍：
  1. markdown 相对链接：按文件原来的位置解析出目标，目标或文件本身挪了就按新位置重算相对路径（#锚点保留）；
  2. 文中写的路径：`sunmoonai/<旧>`（前面是 `k8s/`、`$K8S/`、反引号、空白等）换成新路径；其他仓没有自己的 sunmoonai/，都指 k8s 的。
不改：turn 冻结原件（/thread/）、改名回执与手册、要删的目录与文件、所有者的密码表；
component-images.yaml 的 context 要与钉的提交一起改（下次重建时），这里不动。
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

K8S = Path(__file__).resolve().parents[2]
WS = K8S.parent
REPOS = ["k8s", "runtime", "knowfeed-app", "knowbase-app", "investment-app", "tpl-app"]

MOVES = [  # k8s 仓内：旧 → 新（以 / 结尾的是目录）
    ("sunmoonai/docs/dev-investment-agent/", "docs/dev-investment-agent/"),
    ("sunmoonai/docs/project-guide/", "docs/project-guide/"),
    ("sunmoonai/docs/ai-tools/mcp-touyan-comparison.md", "docs/reference/行业/mcp-touyan-comparison.md"),
    ("sunmoonai/app-platform/info-app/docs/spider-reference/", "docs/reference/采集与数据/spider-reference/"),
    ("sunmoonai/app-platform/info-app/docs/仿wind的数据库报表体系设计.md", "docs/reference/采集与数据/仿wind的数据库报表体系设计.md"),
    ("sunmoonai/docs/Celery监控机制说明.md", "docs/reference/技术笔记/Celery监控机制说明.md"),
    ("sunmoonai/ops-platform/flower/Flower使用文档.md", "docs/reference/技术笔记/Flower使用文档.md"),
    ("sunmoonai/docs/文档转换服务技术栈对比.md", "docs/reference/技术笔记/文档转换服务技术栈对比.md"),
    ("sunmoonai/ingress-platform/traefik/KUBERNETES-PORT-FORWARDING-GUIDE.md", "docs/reference/运维笔记/KUBERNETES-PORT-FORWARDING-GUIDE.md"),
    ("sunmoonai/kind-infrastructure/mount/wsl_interop.py", "infrastructure/host/wsl_interop.py"),
    ("sunmoonai/relay-platform/README.md", "infrastructure/applications/component-images/relay/PLATFORM.md"),
    ("sunmoonai/relay-platform/relay/", "infrastructure/applications/component-images/relay/"),
    ("sunmoonai/sandbox-platform/README.md", "infrastructure/applications/component-images/sandbox-platform/README.md"),
    ("sunmoonai/sandbox-platform/bridge/", "infrastructure/applications/component-images/sandbox-platform/bridge/"),
    ("sunmoonai/sandbox-platform/image/", "infrastructure/applications/component-images/sandbox-platform/image/"),
    ("sunmoonai/sandbox-platform/provisioner/", "infrastructure/applications/component-images/sandbox-platform/provisioner/"),
    ("sunmoonai/scripts/local-integration/", "scripts/local-integration/"),
    ("sunmoonai/scripts/results/", "scripts/results/"),
]
# 这些写法在文中出现时也改（目录本身不挪、只是整体的称呼）
ALIASES = [
    ("sunmoonai/relay-platform/", "infrastructure/applications/component-images/relay/"),
    ("sunmoonai/sandbox-platform/", "infrastructure/applications/component-images/sandbox-platform/"),
]
SKIP_FILES = {
    "k8s/docs/rename.md", "k8s/密码修改表.md", "k8s/CHECKPOINT.md",
    "k8s/infrastructure/applications/component-images.yaml",
    "k8s/docs/rename-tools/moveout_sunmoonai.py", "k8s/docs/rename-tools/rename_rules.py",
    "k8s/sunmoon", "k8s/image-management-design.md", "k8s/k8s持久化方式及本项目持久化方案设计.md",
}
SKIP_PREFIX = ("k8s/docs/rename-receipts/", "k8s/legacy/", "k8s/utils/")
TEXT_EXT = {".md", ".py", ".sh", ".yaml", ".yml", ".json", ".mdc", ".txt", ".toml", ".j2", ".ps1", ".ts", ".tsx", ""}
LINK = re.compile(r"(\]\()([^)\s]+)((?:\s+\"[^\"]*\")?\))")


def git(repo: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, check=True).stdout


def repo_dirs() -> list[Path]:
    out = []
    for r in REPOS:
        d = WS / r
        out.append(d)
        if (d / ".gitmodules").exists():
            for line in git(d, "config", "-f", ".gitmodules", "--get-regexp", r"^submodule\..*\.path$").split("\n"):
                if line.strip():
                    out.append(d / line.split()[1])
    return out


def map_old(rel_k8s: str) -> str | None:
    """k8s 仓内的旧路径 → 新路径（不在 MOVES 里返回 None）。"""
    for old, new in MOVES:
        if old.endswith("/") and rel_k8s.startswith(old):
            return new + rel_k8s[len(old):]
        if old.endswith("/") and rel_k8s == old.rstrip("/"):
            return new.rstrip("/")
        if rel_k8s == old:
            return new
    return None


def doomed(rel_k8s: str) -> bool:
    return rel_k8s.startswith("sunmoonai/") and map_old(rel_k8s) is None


def skipped(rel_ws: str) -> bool:
    if rel_ws in SKIP_FILES or rel_ws.startswith(SKIP_PREFIX) or "/thread/" in rel_ws:
        return True
    if rel_ws.startswith("k8s/sunmoonai/"):
        return map_old(rel_ws[len("k8s/"):]) is None  # 要删的不改
    return False


def new_location(abs_path: Path) -> Path:
    try:
        rel = abs_path.relative_to(K8S).as_posix()
    except ValueError:
        return abs_path
    m = map_old(rel)
    return K8S / m if m else abs_path


def rewrite_links(text: str, file_old: Path, file_new: Path, report: dict) -> str:
    def sub(m: re.Match) -> str:
        href = m.group(2)
        if re.match(r"^[a-z]+:", href) or href.startswith(("#", "/", "<")):
            return m.group(0)
        path, frag = (href.split("#", 1) + [""])[:2]
        if not path:
            return m.group(0)
        target_old = Path(os.path.normpath(file_old.parent / path))
        target_new = new_location(target_old)
        try:
            rel_k8s = target_old.relative_to(K8S).as_posix()
        except ValueError:
            rel_k8s = None
        if rel_k8s and doomed(rel_k8s) and target_old.exists():
            report["doomed_links"].append(f"{file_new.relative_to(WS)} -> {rel_k8s}")
        if target_new == target_old and file_new == file_old:
            return m.group(0)
        newhref = os.path.relpath(target_new, file_new.parent).replace(os.sep, "/") + (f"#{frag}" if frag else "")
        if path.endswith("/") and not newhref.endswith("/"):
            newhref += "/"
        return m.group(1) + newhref + m.group(3)
    return LINK.sub(sub, text)


def rewrite_text(text: str) -> str:
    # 其他仓没有自己的 sunmoonai/ 目录，文中出现的都指 k8s 仓的（`k8s/sunmoonai/…`、`$K8S/sunmoonai/…`、`k8s 仓 \`sunmoonai/…\``）
    for old, new in MOVES + ALIASES:
        text = re.sub(r"(?<![\w.-])" + re.escape(old), new, text)
        if old.endswith("/"):  # 目录写成不带斜杠的（`cd sunmoonai/relay-platform/relay`）
            text = re.sub(r"(?<![\w.-])" + re.escape(old.rstrip("/")) + r"(?![\w./-])", new.rstrip("/"), text)
    return text


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in ("plan", "apply"):
        print(__doc__)
        return 2
    report = {"moved": 0, "changed": [], "doomed_links": [], "residual": []}
    tracked_k8s = git(K8S, "ls-files").split("\n")
    moves = [(p, n) for p in tracked_k8s if p and (n := map_old(p))]
    report["moved"] = len(moves)
    for old, new in MOVES:
        if not any(p == old or (old.endswith("/") and p.startswith(old)) for p, _ in moves):
            print(f"STOP 没有找到要挪的 {old}")
            return 3
        if (K8S / new).exists() and not new.endswith("/"):
            print(f"STOP 目标已存在 {new}")
            return 3
    edits = []
    for repo in repo_dirs():
        for rel in git(repo, "ls-files").split("\n"):
            if not rel:
                continue
            f = repo / rel
            rel_ws = f.relative_to(WS).as_posix()
            if skipped(rel_ws) or f.suffix.lower() not in TEXT_EXT or f.is_symlink() or not f.is_file():
                continue
            try:
                text = f.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            f_new = new_location(f)
            out = rewrite_links(text, f, f_new, report)
            out = rewrite_text(out)
            if out != text:
                edits.append((f, f_new, out))
                report["changed"].append(f_new.relative_to(WS).as_posix())
            for line_no, line in enumerate(out.splitlines(), 1):
                for old, _ in MOVES + ALIASES:
                    if old in line:
                        report["residual"].append(f"{f_new.relative_to(WS)}:{line_no}: {line.strip()[:160]}")
                        break
    print(f"== 挪动 {report['moved']} 个文件；改引用 {len(report['changed'])} 个文件")
    for c in report["changed"]:
        print(f"  edit {c}")
    print(f"== 指向将删除区域（sunmoonai/ 里不搬的部分）的链接 {len(report['doomed_links'])} 条")
    for d in sorted(set(report["doomed_links"])):
        print(f"  doomed {d}")
    print(f"== 改完仍写着旧路径的行 {len(report['residual'])} 条（手工看）")
    for r in report["residual"]:
        print(f"  residual {r}")
    if mode == "apply":
        for old, new in moves:
            (K8S / new).parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["git", "-C", str(K8S), "mv", old, new], check=True)
        for f, f_new, out in edits:
            f_new.write_text(out, encoding="utf-8")
        print("== 已 git mv 并写回；未提交")
    print("exit=0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
