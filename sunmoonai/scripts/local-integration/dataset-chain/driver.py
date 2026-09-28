#!/usr/bin/env python3
"""联调的驱动：站在专家的位置上，经 MCP 查登记进来的数据集，并与直接读文件的结果逐条比对。

不含任何口令：令牌与存储凭据从状态目录的环境文件读，结果里只写结论。
"""

from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import sys
import tempfile
import time
from pathlib import Path

import boto3
import httpx
from botocore.config import Config
from botocore.exceptions import ClientError

STATE = Path(os.environ["STATE"])
KNOW = f"http://127.0.0.1:{os.environ['KNOW_PORT']}"
S3 = f"http://127.0.0.1:{os.environ['S3_PORT']}"
BUCKET = os.environ["INFO_BUCKET"]
ENV = dict(
    line.strip().split("=", 1)
    for line in (STATE / "env").read_text().splitlines()
    if "=" in line
)
HERE = Path(__file__).resolve().parent
KNOWLEDGE_APP = Path.cwd()

results: list[dict] = []


def record(name: str, ok: bool, detail: str = "") -> None:
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("通过" if ok else "未过") + " | " + name + (" | " + detail if detail else ""))


class Mcp:
    def __init__(self, token: str) -> None:
        self.client = httpx.Client(
            base_url=KNOW,
            timeout=60,
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        )
        self.n = 0

    def rpc(self, method: str, params: dict | None = None) -> dict:
        self.n += 1
        body = {"jsonrpc": "2.0", "id": self.n, "method": method, "params": params or {}}
        response = self.client.post("/api/mcp/knowledge", json=body)
        response.raise_for_status()
        return response.json()

    def call(self, tool: str, **arguments) -> tuple[bool, dict | str]:
        """返回（成功, 结构化结果或错误文字）。"""
        reply = self.rpc("tools/call", {"name": tool, "arguments": arguments})
        if "error" in reply:
            return False, reply["error"]["message"]
        result = reply["result"]
        if result.get("isError"):
            return False, result["content"][0]["text"]
        return True, result["structuredContent"]


def s3(key_name: str):
    return boto3.client(
        "s3",
        endpoint_url=S3,
        region_name="us-east-1",
        aws_access_key_id=ENV[f"{key_name}_S3_KEY"],
        aws_secret_access_key=ENV[f"{key_name}_S3_SECRET"],
        config=Config(s3={"addressing_style": "path"}, retries={"total_max_attempts": 2}),
    )


def registered(code: str) -> dict:
    """info 登记表里这只证券最新发布的数据集。"""
    import subprocess

    sql = (
        "select row_to_json(t) from (select dataset_id, data_version, bucket, object_key, "
        "version_id, sha256, size_bytes, knowledge_registered_at is not null as registered "
        f"from security_dataset where security_code='{code}' and status='published' "
        "order by built_at desc limit 1) t"
    )
    out = subprocess.run(
        ["docker", "exec", os.environ.get("PG_CONTAINER", "pgtest"), "psql", "-U", "t", "-d", "it_info", "-Atc", sql],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return json.loads(out)


def normalise(rows):
    def one(v):
        if isinstance(v, float):
            return round(v, 6)
        return v

    return [[one(v) for v in (r.values() if isinstance(r, dict) else r)] for r in rows]


def verify(code: str) -> None:
    dataset = registered(code)
    record("info 记下了登记成功", dataset["registered"], dataset["data_version"])
    record("数据集文件带着版本标识存进了对象存储", bool(dataset["version_id"]))

    # 知识服务的存储账号：只读
    reader = s3("KNOW")
    obj = reader.get_object(Bucket=dataset["bucket"], Key=dataset["object_key"], VersionId=dataset["version_id"])
    content = obj["Body"].read()
    record("知识服务的账号能读到文件，校验值与登记的一致", hashlib.sha256(content).hexdigest() == dataset["sha256"])
    try:
        reader.put_object(Bucket=dataset["bucket"], Key="it-write-probe", Body=b"x")
        record("知识服务的账号不能写 info 的桶", False, "写成功了")
    except ClientError as exc:
        record("知识服务的账号不能写 info 的桶", exc.response["Error"]["Code"] == "AccessDenied")
    try:
        reader.list_objects_v2(Bucket=dataset["bucket"], MaxKeys=1)
        record("知识服务的账号不能列 info 的桶", False, "列成功了")
    except ClientError as exc:
        record("知识服务的账号不能列 info 的桶", exc.response["Error"]["Code"] == "AccessDenied")

    expert = Mcp(ENV["MCP_TOKEN"])
    init = expert.rpc("initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "dataset-chain", "version": "1"}})
    record("MCP 握手", "result" in init)
    tools = {t["name"] for t in expert.rpc("tools/list")["result"]["tools"]}
    record("五个工具都在，含按口径名查询", tools == {"list_datasets", "describe_schema", "metric_definitions", "run_sql", "query_metric"}, "、".join(sorted(tools)))

    # 登记表每 30 秒重读一次
    deadline = time.time() + 45
    found = None
    while time.time() < deadline:
        ok, listed = expert.call("list_datasets")
        found = next((d for d in listed["datasets"] if d["dataset"] == dataset["dataset_id"]), None) if ok else None
        if found:
            break
        time.sleep(3)
    record("登记后专家能列出这个数据集", found is not None)
    if not found:
        return
    record("列出的版本就是 info 发布的版本", found["data_version"] == dataset["data_version"], found["data_version"])
    record("列出的内容不含对象位置", not any("s3://" in str(v) or "object" in k for k, v in found.items()))

    name = dataset["dataset_id"]
    ok, schema = expert.call("describe_schema", dataset=name)
    tables = {t["name"] if isinstance(t, dict) else t for t in (schema.get("tables") or [])} if ok else set()
    record("看得到三张报表", {"balance_sheet", "income_statement", "cash_flow"} <= tables, f"{len(tables)} 张表")

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "direct.sqlite"
        path.write_bytes(content)
        direct = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        truth = json.loads((KNOWLEDGE_APP / "tests/fixtures/semantic/fin_truth_queries.json").read_text())
        same = 0
        different = []
        for query in truth:
            want = normalise(direct.execute(query["sql"]).fetchall())
            ok, got = expert.call("run_sql", dataset=name, sql=query["sql"], max_rows=500)
            if ok and normalise(got["rows"]) == want:
                same += 1
            else:
                different.append(query["query_id"])
        record("真值查询经 MCP 的结果与直接读文件逐条相同", not different, f"{same}/{len(truth)}" + (("；不同：" + "、".join(different)) if different else ""))

        revenue_sql = "SELECT operate_income FROM income_statement WHERE report_type='年报' AND fiscal_year=2025"
        want = direct.execute(revenue_sql).fetchone()[0]
        ok, got = expert.call("run_sql", dataset=name, sql=revenue_sql)
        first = got["rows"][0] if ok and got["rows"] else None
        value = (list(first.values())[0] if isinstance(first, dict) else first[0]) if first else None
        record("2025 年营业收入与文件里的数相同", value == want, f"{want:.2f}")
        if code == "600009":
            record("上海机场 2025 年营业收入是年报上的 13346192164.12", want == 13346192164.12)

        year = [
            {"column": "report_type", "op": "eq", "value": "年报"},
            {"column": "fiscal_year", "op": "eq", "value": 2025},
        ]
        income = direct.execute("SELECT operate_income, operate_cost FROM income_statement WHERE report_type='年报' AND fiscal_year=2025").fetchone()
        balance = direct.execute("SELECT total_liabilities, total_assets FROM balance_sheet WHERE report_type='年报' AND fiscal_year=2025").fetchone()
        for metric, label, want in (
            ("gross_margin", "毛利率", (income[0] - income[1]) / income[0]),
            ("debt_ratio", "资产负债率", balance[0] / balance[1]),
        ):
            ok, got = expert.call("query_metric", dataset=name, metrics=[metric], filters=year)
            rows = got.get("rows") if ok else None
            values = list(_numbers(rows[0])) if rows else []
            record(f"按口径名算出的{label}与手算一致", any(abs(v - want) < 1e-9 for v in values), f"{want:.6f}" if rows else str(got)[:100])
            record(f"{label}带着是否适用", bool(rows) and "applicable" in json.dumps(rows[0]))
        ok, got = expert.call("query_metric", dataset=name, metrics=["gross_margin", "debt_ratio"], filters=year)
        record("两张表的口径放在一次查询里：拒绝并说明要分开查", not ok and "separately" in str(got), str(got)[:70])

    for sql, why in (
        ("DELETE FROM income_statement", "写操作"),
        ("SELECT * FROM income_statement; SELECT 1", "多条语句"),
        ("SELECT * FROM phys_income_statement", "物理表名"),
        ("SELECT * FROM read_csv('/etc/passwd')", "读服务器上的文件"),
    ):
        ok, got = expert.call("run_sql", dataset=name, sql=sql)
        record(f"拒绝：{why}", not ok, str(got)[:60])

    ok, got = expert.call("run_sql", dataset="sz000001-financials", sql="SELECT 1")
    record("没登记的数据集：明说没有，并提示先列清单", not ok and "list_datasets" in str(got), str(got)[:80])

    ok, default_schema = expert.call("describe_schema")
    default_tables = {t["name"] if isinstance(t, dict) else t for t in (default_schema.get("tables") or [])} if ok else set()
    record("不带数据集参数仍然是默认数据集（问数二十题不受影响）", ok and default_tables and "income_statement" not in default_tables, f"{len(default_tables)} 张表")
    ok, listed = expert.call("list_datasets")
    defaults = [d["dataset"] for d in listed["datasets"] if d.get("default")] if ok else []
    record("清单里恰好有一个默认数据集，不是新登记的这个", len(defaults) == 1 and defaults[0] != name, "、".join(defaults))
    others = sorted(d["dataset"] for d in listed["datasets"] if not d.get("default")) if ok else []
    record("清单里登记进来的数据集", name in others, "、".join(others))

    narrow = Mcp(ENV["MCP_TOKEN_NARROW"])
    ok, got = narrow.call("list_datasets")
    record("没被授予列清单的令牌列不了", not ok)
    ok, got = narrow.call("describe_schema", dataset=name)
    record("但它可以带数据集名查被授予的工具", ok)
    anonymous = httpx.post(f"{KNOW}/api/mcp/knowledge", json={"jsonrpc": "2.0", "id": 1, "method": "tools/list"}, timeout=20)
    record("不带令牌访问 MCP 被拒绝", anonymous.status_code == 401, str(anonymous.status_code))

    cache = STATE / "knowledge-datasets"
    files = list(cache.glob("*"))
    record("知识服务取回的文件按校验值命名，内容一致", any(f.name.startswith(dataset["sha256"]) and hashlib.sha256(f.read_bytes()).hexdigest() == dataset["sha256"] for f in files), f"{len(files)} 个文件")


def storage_denied(code: str) -> None:
    dataset = registered(code)
    expert = Mcp(ENV["MCP_TOKEN"])
    ok, got = expert.call("run_sql", dataset=dataset["dataset_id"], sql="SELECT 1")
    text = str(got)
    record("知识服务取不到文件时，专家得到的是「不可用」", not ok and "unavailable" in text, text[:80])
    leaked = [w for w in ("s3://", "AccessDenied", BUCKET, "127.0.0.1", dataset["object_key"][:20], "Traceback", "botocore") if w in text]
    record("这句话里没有桶名、地址、键、报错原文", not leaked, "、".join(leaked))
    ok, got = expert.call("describe_schema")
    record("默认数据集不受影响", ok)
    log = (STATE / "knowledge.log").read_text()
    record("细节写进了知识服务自己的日志", "knowledge_mcp_dataset_unavailable" in log or "knowledge_mcp_tool_failed" in log)


def overwritten(code: str) -> None:
    dataset = registered(code)
    writer = s3("INFO")
    before = writer.head_object(Bucket=dataset["bucket"], Key=dataset["object_key"])["VersionId"]
    writer.put_object(Bucket=dataset["bucket"], Key=dataset["object_key"], Body=b"SQLite format 3\x00 not the dataset")
    after = writer.head_object(Bucket=dataset["bucket"], Key=dataset["object_key"])["VersionId"]
    record("同一个键被写了新内容，成了新版本", before != after and before == dataset["version_id"])
    expert = Mcp(ENV["MCP_TOKEN"])
    ok, got = expert.call("run_sql", dataset=dataset["dataset_id"], sql="SELECT operate_income FROM income_statement WHERE report_type='年报' AND fiscal_year=2025")
    value = None
    if ok and got["rows"]:
        first = got["rows"][0]
        value = list(first.values())[0] if isinstance(first, dict) else first[0]
    record("知识服务取到的仍是登记时的那个版本", isinstance(value, float) and value > 0, str(got)[:80] if not ok else "")
    cache = STATE / "knowledge-datasets"
    record("取回的文件校验值与登记的一致", any(hashlib.sha256(f.read_bytes()).hexdigest() == dataset["sha256"] for f in cache.glob("*")))
    try:
        writer.delete_object(Bucket=dataset["bucket"], Key=dataset["object_key"], VersionId=after)
        record("info 的账号删不了已留存的版本", False, "删成功了")
    except ClientError as exc:
        record("info 的账号删不了已留存的版本", exc.response["Error"]["Code"] == "AccessDenied")
    (STATE / "junk-version").write_text(f"{dataset['object_key']}\n{after}\n")


def _numbers(value):
    if isinstance(value, bool):
        return
    if isinstance(value, (int, float)):
        yield float(value)
    elif isinstance(value, dict):
        for v in value.values():
            yield from _numbers(v)
    elif isinstance(value, list):
        for v in value:
            yield from _numbers(v)


def main() -> None:
    command, code = sys.argv[1], sys.argv[2]
    if command == "verify":
        verify(code)
    elif command == "storage-denied":
        storage_denied(code)
    elif command == "overwritten":
        overwritten(code)
    else:
        raise SystemExit(f"unknown command: {command}")
    out = STATE / f"{command}-{code}.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=1))
    failed = [r for r in results if not r["ok"]]
    print(f"合计 {len(results)} 项，未过 {len(failed)} 项")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
