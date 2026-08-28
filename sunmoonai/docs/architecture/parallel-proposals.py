#!/usr/bin/env python3
"""模式 A（并行提案）的自动化实现——见 multi-assistant-workflow.md §1–§3。

把同一份提案包发给 N 个**互相隔离**的 Codex 实例，各自独立出方案，收集产出。

隔离靠机制而非自律：每个实例一个独立进程 + 独立 CODEX_HOME，
互相看不到对方的会话、历史与状态。这是 §2 隔离原则要求的形态——
在此之前同机隔离只能靠"不许读别的分支"这种约定，机制上拦不住。

用法：
    # 先装 SDK（会自带钉版 CLI 二进制）
    pip install openai-codex

    # 跑 5 路提案
    python3 parallel-proposals.py --request req.md --n 5 --out ./proposals

    # 指定模型与端点（经 CC Switch 一类的本地路由）
    python3 parallel-proposals.py --request req.md --n 3 \
        --model kimi-k3 --config model_provider=custom

提案包（--request 指向的文件）应当只含 §3 规定的四项：
原始需求 · 验收标准 · 上下文入口 · 边界。
**不得**含其他助手的方案、提出方的倾向、指定的检查点——那会破坏独立性。

产出：
    <out>/proposal-<i>.md      各实例的方案
    <out>/manifest.json        执行元数据（模型、耗时、token、状态）

manifest 是证据账的最小形态（request-lifecycle.md §7）：
每份产出可回答"谁跑的、哪个模型、跑了多久、花了多少"。
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import pathlib
import shutil
import sys
import tempfile
import time


def run_one(
    index: int,
    request_text: str,
    home_root: pathlib.Path,
    out_dir: pathlib.Path,
    codex_bin: str | None,
    model: str | None,
    config_overrides: tuple[str, ...],
    cwd: str | None,
) -> dict:
    """跑一路提案。返回该路的元数据。"""
    from openai_codex import Codex, CodexConfig  # 延迟导入，便于先给出友好报错

    home = home_root / f"instance-{index}"
    home.mkdir(parents=True, exist_ok=True)

    meta: dict = {"index": index, "codex_home": str(home)}
    started = time.time()
    try:
        cfg = CodexConfig(
            codex_bin=codex_bin,
            # ← 隔离的关键：每路一个 CODEX_HOME，会话/历史/状态互不可见
            env={"CODEX_HOME": str(home)},
            config_overrides=config_overrides,
            cwd=cwd,
        )
        with Codex(cfg) as cx:
            meta["server"] = getattr(cx.metadata, "userAgent", None)
            thread = cx.thread_start(model=model) if model else cx.thread_start()
            meta["thread_id"] = getattr(thread, "id", None)

            result = thread.run(input=request_text)

            meta["status"] = str(getattr(result, "status", "unknown"))
            meta["duration_ms"] = getattr(result, "duration_ms", None)
            usage = getattr(result, "usage", None)
            if usage is not None:
                meta["usage"] = (
                    usage.model_dump() if hasattr(usage, "model_dump") else str(usage)
                )
            text = getattr(result, "final_response", None) or ""
            (out_dir / f"proposal-{index}.md").write_text(text, encoding="utf-8")
            meta["output_chars"] = len(text)
            meta["ok"] = True
    except Exception as exc:  # noqa: BLE001 — 一路失败不应拖垮其余
        meta["ok"] = False
        meta["error_type"] = type(exc).__name__
        meta["error"] = str(exc)[:500]
    meta["wall_seconds"] = round(time.time() - started, 1)
    return meta


def main() -> int:
    ap = argparse.ArgumentParser(
        description="并行提案：N 路隔离的 Codex 实例对同一请求各出方案"
    )
    ap.add_argument("--request", required=True, help="提案包文件（见模块 docstring）")
    ap.add_argument("--n", type=int, default=3, help="并行路数，默认 3")
    ap.add_argument("--out", default="./proposals", help="产出目录")
    ap.add_argument("--codex-bin", default=None, help="指定 codex 可执行文件")
    ap.add_argument("--model", default=None, help="模型名")
    ap.add_argument(
        "--config",
        action="append",
        default=[],
        metavar="K=V",
        help="透传给 codex 的 --config，可多次",
    )
    ap.add_argument("--cwd", default=None, help="各实例的工作目录")
    ap.add_argument(
        "--keep-homes", action="store_true", help="保留各实例的 CODEX_HOME 以便排查"
    )
    a = ap.parse_args()

    import importlib.util

    if importlib.util.find_spec("openai_codex") is None:
        print(
            "未找到 openai_codex。先装：pip install openai-codex\n"
            "（它会自带钉版的 codex CLI 二进制；用系统已有的旧版 CLI 可能因"
            "响应字段不匹配而失败）",
            file=sys.stderr,
        )
        return 2

    request_path = pathlib.Path(a.request)
    if not request_path.is_file():
        print(f"提案包不存在：{request_path}", file=sys.stderr)
        return 2
    request_text = request_path.read_text(encoding="utf-8")

    out_dir = pathlib.Path(a.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    home_root = pathlib.Path(tempfile.mkdtemp(prefix="parallel-proposals-"))

    print(f"提案包 {request_path}（{len(request_text)} 字符）→ {a.n} 路隔离实例")
    print(f"隔离根目录 {home_root}\n")

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=a.n) as pool:
            futures = [
                pool.submit(
                    run_one,
                    i,
                    request_text,
                    home_root,
                    out_dir,
                    a.codex_bin,
                    a.model,
                    tuple(a.config),
                    a.cwd,
                )
                for i in range(a.n)
            ]
            metas = [f.result() for f in futures]
    finally:
        if not a.keep_homes:
            shutil.rmtree(home_root, ignore_errors=True)

    metas.sort(key=lambda m: m["index"])
    manifest = {
        "request_file": str(request_path),
        "request_chars": len(request_text),
        "instances": a.n,
        "model": a.model,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "results": metas,
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    ok = sum(1 for m in metas if m.get("ok"))
    for m in metas:
        if m.get("ok"):
            print(
                f"  ✓ 实例 {m['index']}: {m.get('output_chars', 0)} 字符"
                f"，{m['wall_seconds']}s"
            )
        else:
            print(f"  ✗ 实例 {m['index']}: {m.get('error_type')} — {m.get('error', '')[:120]}")

    print(f"\n{ok}/{a.n} 路成功。产出与 manifest 在 {out_dir}")
    if ok < 2:
        print(
            "\n⚠ 成功路数少于 2，无法比较。并行提案的价值在于**重叠与分歧**"
            "（见 multi-assistant-workflow.md §5.5）：\n"
            "  两路都提到的 → 大概率是真问题\n"
            "  只有一路提到的 → 需单独判定\n"
            "  两路发现几乎不相交 → 说明整体覆盖率低，不是审得全"
        )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
