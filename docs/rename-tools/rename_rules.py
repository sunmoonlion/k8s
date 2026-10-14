"""改名替换引擎（k8s/docs/rename.md R1）。info → knowcollector、knowledge → knowbase。

用法：python3 rename_rules.py <五组仓的上一级目录> [--apply] [--report 报告.json]
不加 --apply 只统计、不写盘。规则按「改与留的界线」分类，按顺序套用；先把要留的写法换成占位符保护起来，
套完再换回。每条规则对每个文件改了几处都进报告。
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------- 范围
REPOS = ["info-app", "knowledge-app", "investment-app", "k8s", "runtime", "tpl-app"]
# 冻结的旧体系、历史记录、录下来的样例、已有迁移文件（迁移记录的是历史表结构，改表名另写新迁移）
SKIP = re.compile(
    r"^k8s/sunmoonai/(app-platform|cicd-platform|data-platform|deploy-sunmoonai-all|infrastructure|"
    r"ingress-platform|kind-infrastructure|messaging-platform|operations|ops-platform|registry-platform)/"
    r"|^k8s/sunmoonai/CHECKPOINT-old-system"
    r"|/(results|thread|history|hold|node_modules|\.venv|\.next|dist)/|/switch-test/done/"
    r"|/eval/reports/|/preview/fixtures/|/alembic/versions/"
    r"|^k8s/docs/rename|^k8s/docs/(竞品比较分析|专家市场架构对比分析和借鉴)\.md$"  # 手册自身；两份讨论稿在 R7 手工改
    r"|(^|/)(pnpm-lock\.yaml|uv\.lock|package-lock\.json)$"
)
# gitops 组件目录里的渲染产物：只随目录 git mv，内容由 R5 的 stage / 构建重新生成
RENDERED = re.compile(
    r"^k8s/gitops/components/.*/(workload\.yaml|kustomization\.yaml|image\.lock\.yaml|[^/]*\.sops\.yaml)$"
)
TEXT_SUFFIX = {
    ".py", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".yaml", ".yml", ".j2", ".toml", ".md", ".sh",
    ".txt", ".cfg", ".ini", ".env", ".example", ".conf", ".mdc", ".html", ".css", ".sql", "",
}

# ---------------------------------------------------------------- 要留的写法（占位保护）
KEEP = [
    # knowledge 作领域词（所有者 2026-10-14 定：留）
    r"knowledge_(document|ingestion|dataset(?!_(path|id|title|object|sha256|registry_enabled|allowed_buckets|cache_dir)\b)|provider_operation|registered_at|registration_error|version_conflict"
    r"|registry_disabled|refused_registration|rejected_identity|request_failed|unreachable|unavailable|reply_unexpected"
    r"|grants|binding|audit_context|uuid_dependency|backlog_tests|delivery_migration|tool|mcp_tool_failed"
    r"|mcp_forbidden_tool|mcp_dataset_unavailable)\w*",
    r"Knowledge(Document|Ingestion|Dataset|Retrieval|Provider|Mcp|Shell|IngestionsPanel|Ingestions)\w*",
    r"(uq|ix|ck)_knowledge_\w+",
    r"knowledge(Ingestions|Datasets|Catalog|Hint)\w*",
    r"knowledge-(ingestions|catalog|retrieval-request|retrieval-response|upload|semantic|sample|v1|shell)\b[\w-]*",
    r"knowledge:ingest:(?=\{|\w)",  # 出站去重键前缀：库里已存的内部键，不改
    r"knowledge\.(ingest|dataset|catalog)\.?v?\d*",
    r"/api/(internal/v1/|admin/v1/)?knowledge\b",
    r"KNOWLEDGE_(DOCUMENT|VERSION)_NAMESPACE",  # 生成固定 ID 的 UUID 命名空间：名字也不动，值更不能动
    r"(stable|legacy)_knowledge_\w+",
    r"(retrieve|search|start|process|it|retrieve_internal)_knowledge\w*",
    r"create_knowledge_distribution",
    r"[Aa]cknowledg\w*|[Uu]nacknowledg\w*|\w+_unacknowledged|\w+_acknowledged",
    r"\d{4}-knowledge[\w-]*", r"\d{4}-info[\w-]*",  # 设计文档编号
    r"apps/(knowledge|info)\.md",
    # 无关的 info
    r"\b[Cc][Nn][Ii][Nn][Ff][Oo]\w*", r"\w+_info\b", r"\binfo\.st_\w+", r"\b(log|logger|logging|console)\.info\b",
    r"\bexc_info\b", r"\bversion_info\b", r"(dist|egg)-info", r"userinfo", r"USERINFO", r"terminfo",
    r"Client-Cert-Info", r"cluster-info", r"node-exports-info",
]

# ---------------------------------------------------------------- 改：按类按序
R: list[tuple[str, str, Any]] = []


def rule(cls: str, pattern: str, repl: Any) -> None:
    R.append((cls, pattern, repl))


# 1 域名
rule("域名", r"knowledge-admin\.(sunmoonai\.com|example\.test)", r"knowbase-admin.\1")
rule("域名", r"(?<![\w.-])knowledge\.(sunmoonai\.com|example\.test)", r"knowbase.\1")
rule("域名", r"info-admin\.(sunmoonai\.com|example\.test)", r"knowcollector-admin.\1")
rule("域名", r"(?<![\w.-])info\.(sunmoonai\.com|example\.test)", r"knowcollector.\1")
# 1b 令牌作用域（所有者改定：改；它是「应用名:动作」）
rule("作用域", r"(?<![\w.-])knowledge:(admin|ingest|retrieve|read)\b", r"knowbase:\1")
rule("作用域", r"(?<![\w.-])info:admin\b", "knowcollector:admin")
rule("域名", r"(?<=//)info\.example\b", "knowcollector.example")
rule("域名", r"(?<=//)knowledge\.example\b", "knowbase.example")
rule("域名", r"(?<=//)info(?=[:/\"'])", "knowcollector")
rule("域名", r"(?<=//)knowledge(?=[:/\"'])", "knowbase")
rule("应用身份", r"\bInfoAppBot\b", "KnowcollectorBot")
rule("应用身份", r"\bInfoBot\b", "KnowcollectorBot")
# 2 两个应用之间的身份（成对出现，先于单个规则）
for old, new in [
    ("sunmoonai-info-knowledge-ingest", "sunmoonai-knowcollector-knowbase-ingest"),
    ("sunmoon-info-knowledge-ingest", "sunmoon-knowcollector-knowbase-ingest"),
    ("sunmoon-workload-info-knowledge", "sunmoon-workload-knowcollector-knowbase"),
    ("info-knowledge-ingest-client", "knowcollector-knowbase-ingest-client"),
    ("info-knowledge-artifact", "knowcollector-knowbase-artifact"),
    ("info-knowledge-service", "knowcollector-knowbase-service"),
    ("knowledge-info-ingest-service-binding", "knowbase-knowcollector-ingest-service-binding"),
    ("CASDOOR_INFO_KNOWLEDGE_", "CASDOOR_KNOWCOLLECTOR_KNOWBASE_"),
]:
    rule("跨应用身份", re.escape(old), new)
# 3 MCP 服务名（所有者定：改）
rule("MCP", r"(?<![\w-])sunmoon_knowledge(?![\w-])", "sunmoon_knowbase")
# 4 登录 cookie
rule("cookie", r"sunmoonai_knowledge_", "sunmoonai_knowbase_")
rule("cookie", r"sunmoonai_info_", "sunmoonai_knowcollector_")
# 5 环境变量（改名不改值）
rule("环境变量", r"(?<![A-Za-z0-9])KNOWLEDGE_", "KNOWBASE_")
rule("环境变量", r"(?<![A-Za-z0-9])KNOWLEDGE\b", "KNOWBASE")
rule("环境变量", r"(?<![A-Za-z0-9])INFO_(?=[A-Z0-9])", "KNOWCOLLECTOR_")
rule("环境变量", r"(?<=[A-Z]_)INFO\b", "KNOWCOLLECTOR")
# 6 配置字段（pydantic 字段名 = 环境变量名小写）
rule("配置字段", r"(?<![\w-])knowledge_(app|mcp|semantic|catalog|web_base_url)(?=_|\b)", r"knowbase_\1")
rule("配置字段", r"(?<![\w-])knowledge_dataset_(path|id|title|object|sha256|registry_enabled|allowed_buckets|cache_dir)\b", r"knowbase_dataset_\1")
# 7 部署配置键与应用名（gitops / ansible / Makefile）
rule("部署键", r"(?<![\w-])(info|knowledge)_(backend|web|admin)_deployment\b",
     lambda m: ("knowcollector" if m[1] == "info" else "knowbase") + f"_{m[2]}_deployment")
rule("部署键", r"(?<![\w-])info_deployment\b", "knowcollector_deployment")
rule("部署键", r"(?<![\w-])knowledge_deployment\b", "knowbase_deployment")
rule("部署键", r"(?<![\w-])knowledge_service(_receiver)?\b", r"knowbase_service\1")
rule("部署键", r"service_access_hosts\.knowledge\b", "service_access_hosts.knowbase")
rule("部署键", r"service_access_hosts\.info\b", "service_access_hosts.knowcollector")
rule("部署键", r"applications\.knowledge\b", "applications.knowbase")
rule("部署键", r"applications\.info\b", "applications.knowcollector")
rule("应用名", r"\bAPP=info\b", "APP=knowcollector")
rule("应用名", r"\bAPP=knowledge\b", "APP=knowbase")
rule("应用名", r"applications-info\b", "applications-knowcollector")
rule("应用名", r"applications-knowledge\b", "applications-knowbase")
# 8 组件与 k8s 对象名（kebab）
rule("组件", r"(?<![\w.-])info-app\b", "knowcollector-app")
rule("组件", r"(?<![\w.-])knowledge-app\b", "knowbase-app")
rule("组件", r"(?<![\w.])knowledge-(?=[a-z0-9])", "knowbase-")
rule("组件", r"(?<![\w.])info-(?=(backend|web|admin|api|runtime|worker|scheduler|producer|migration|migrate|tls|database|redis|rabbitmq|identity|storage|service|browser|celery|domain|r5|development|production|originals|sandboxes|source|smoke|object|derived|rw|ro|write|requests|crawl|securities|watchlist|scanner|user|password|information|schema)\b)", "knowcollector-")
# 9 存储名（乙）
rule("存储", r"(?<![\w-])info_(runtime|migrator|storage|source_reader)\b", r"knowcollector_\1")
rule("存储", r"(?<![\w-])knowledge_(runtime|migrator|source_reader|password)\b", r"knowbase_\1")
rule("存储", r"(?<![\w-])knowledge_token\b", "knowbase_token")
rule("存储", r"(?<=[\"' ])info:\*", "knowcollector:*")
rule("存储", r"(?<=[\"' ])info:(?=[a-z])", "knowcollector:")
rule("存储", r"(?<![\w-])info\.(default|admin\.default)\b", r"knowcollector.\1")
rule("存储", r"(?<![\w-])knowledge\.(default|admin\.default)\b", r"knowbase.\1")
rule("存储", r"://knowledge:knowledge@", "://knowbase:knowbase@")
rule("存储", r"://info:info@", "://knowcollector:knowcollector@")
rule("存储", r"(?<=:5432/)knowledge\b", "knowbase")
rule("存储", r"(?<=:5432/)info\b", "knowcollector")
rule("存储", r"(?<![\w-])knowledge_backend\b", "knowbase_backend")
rule("存储", r"(?<![\w-])info_backend(?=_user\b|\b)", "knowcollector_backend")
rule("存储", r"(?<=[\"'`/ ])info/(?=(original|securities)\b)", "knowcollector/")
rule("存储", r"source_prefix: info/", "source_prefix: knowcollector/")
rule("存储", r"/sunmoon-kind/info\b", "/sunmoon-kind/knowcollector")
rule("存储", r"/sunmoon-kind/knowledge\b", "/sunmoon-kind/knowbase")
rule("存储", r"(database|rabbitmq_vhost): info\b", r"\1: knowcollector")
rule("存储", r"(database|rabbitmq_vhost): knowledge\b", r"\1: knowbase")
# 10 source_app 的两种旧值（各自对应，不合并）
rule("source_app", r"(?<=[\"'])info-app(?=[\"'])", "knowcollector-app")
rule("source_app", r"(source_app\W{1,12}[\"'])info(?=[\"'])", r"\1knowcollector")
# 11 采集库带应用名前缀的表与事件（所有者定：改）
rule("表与事件", r"(?<![\w-])info_(collector|document_version|document|source)\b", r"knowcollector_\1")
rule("表与事件", r"(?<![\w-])(uq|ix|ck)_info_", r"\1_knowcollector_")
rule("表与事件", r"(?<![\w-])info\.((?:[a-z_]+\.)*[a-z_]+)\.v(\d+)\b", r"knowcollector.\1.v\2")
# 12 代码里指向另一个应用的名字
for old, new in [
    ("KnowledgeAppClient", "KnowbaseAppClient"), ("KnowledgeAppNotConfiguredError", "KnowbaseAppNotConfiguredError"),
    ("get_knowledge_app_client", "get_knowbase_app_client"), ("require_knowledge_admin", "require_knowbase_admin"),
    ("require_info_admin", "require_knowcollector_admin"), ("require_knowledge_ingest_service", "require_knowbase_ingest_service"),
    ("require_knowledge_retrieve_service", "require_knowbase_retrieve_service"),
]:
    rule("代码名", rf"\b{old}\b", new)
# 13 中文句子里夹着的 info / knowledge 几乎都指应用（「向 knowledge 重新登记」「只给 info 管理员」）
CJK = r"[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]"
rule("中文里的应用名", rf"(?<={CJK})\s?\bknowledge\b(?!-|_|\.)|\bknowledge\b(?=\s?{CJK})", lambda m: m[0].replace("knowledge", "knowbase"))
rule("中文里的应用名", rf"(?<={CJK})\s?\binfo\b(?!-|_|\.)|\binfo\b(?=\s?{CJK})", lambda m: m[0].replace("info", "knowcollector"))
# 14 采集管理端的页面路径（info 是应用名；知识库管理端的 /knowledge/… 是领域词，留）
rule("页面路径", r"(?<=/)info(?=/(crawl|securities|watchlist|requests)\b)", "knowcollector")
# 15 应用名作单词的配置值（只在部署机制里）：'info' / "knowledge"
DEPLOY_FILES = re.compile(r"^k8s/(infrastructure|gitops/components/app-platform/common|gitops/clusters)/|Makefile$"
                          r"|/core/config\.py$|/domain/cross_app\.py$|/tests/test_cross_app\.py$|/env/server-schema\.ts$|/lib/cross-app/[^/]+\.ts$"
                          r"|/tests/test_security_request_routes_db\.py$|/tests/test_preview_fixtures\.py$")
rule("应用名", r"(?<=[\"'])info(?=[\"'])", "knowcollector")
rule("应用名", r"(?<=[\"'])knowledge(?=[\"'])", "knowbase")
rule("应用名", r"(?m)^(\s*)info:(?=\s*$|\s+[\"'{])", r"\1knowcollector:")
rule("应用名", r"(?m)^(\s*)knowledge:(?=\s*$|\s+[\"'{])", r"\1knowbase:")
ONLY_DEPLOY = {len(R) - 4, len(R) - 3, len(R) - 2, len(R) - 1}


def scope(root: Path) -> list[str]:
    files: list[str] = []
    for repo in REPOS:
        out = subprocess.run(["git", "-C", str(root / repo), "ls-files"], capture_output=True, text=True)
        names = out.stdout.splitlines() if out.returncode == 0 else [
            str(p.relative_to(root / repo)) for p in (root / repo).rglob("*") if p.is_file()]
        for n in names:
            rel = f"{repo}/{n}"
            if SKIP.search(rel) or RENDERED.search(rel):
                continue
            if Path(rel).suffix not in TEXT_SUFFIX and not Path(rel).name.startswith(("Makefile", "Dockerfile", ".env")):
                continue
            files.append(rel)
    return files


def apply(text: str, rel: str, counts: dict) -> str:
    kept: list[str] = []

    def hide(m: re.Match) -> str:
        kept.append(m[0])
        return f"\x00{len(kept) - 1}\x00"

    for pat in KEEP:
        text = re.sub(pat, hide, text)
    for i, (cls, pat, repl) in enumerate(R):
        if i in ONLY_DEPLOY and not DEPLOY_FILES.search(rel):
            continue
        text, n = re.subn(pat, repl, text)
        if n:
            counts[cls][rel] += n
    return re.sub(r"\x00(\d+)\x00", lambda m: kept[int(m[1])], text)


def main() -> None:
    root = Path(sys.argv[1]).expanduser()
    write = "--apply" in sys.argv
    report = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else None
    counts: dict = defaultdict(lambda: defaultdict(int))
    for rel in scope(root):
        path = root / rel
        try:
            old = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError):
            continue
        new = apply(old, rel, counts)
        if write and new != old:
            path.write_text(new, encoding="utf-8")
    summary = {cls: {"files": len(v), "hits": sum(v.values())} for cls, v in counts.items()}
    print(json.dumps(summary, ensure_ascii=False, indent=1))
    if report:
        Path(report).write_text(json.dumps({k: dict(v) for k, v in counts.items()}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
