"""改名替换引擎（k8s/docs/rename.md R1）。info → knowfeed、knowledge → knowbase。

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
    r"|/app/infrastructure/repositories/info_identity_v1\.py$"  # 为 0008 迁移冻结的扫描，跟已有迁移一样记录历史表名
    r"|^k8s/docs/rename|^k8s/docs/(竞品比较分析|专家市场架构对比分析和借鉴)\.md$"  # 手册自身；两份讨论稿在 R7 手工改
    r"|/tree-build/(decisions|owner-decisions-now)\.md$|/SDD/modules/0025-|/switch-test/inbox/[^/]+/[^/]*rename"  # 决定记录（原话与当时的名字）、改名方案与改名卡本身
    r"|(^|/)(pnpm-lock\.yaml|package-lock\.json)$"
)
# gitops 组件目录里的渲染产物：只随目录 git mv，内容由 R5 的 stage / 构建重新生成
RENDERED = re.compile(
    r"^k8s/gitops/components/.*/(workload\.yaml|kustomization\.yaml|image\.lock\.yaml|[^/]*\.sops\.yaml)$"
)
TEXT_SUFFIX = {
    ".py", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".yaml", ".yml", ".j2", ".toml", ".md", ".sh",
    ".txt", ".cfg", ".ini", ".env", ".example", ".conf", ".mdc", ".html", ".css", ".sql", ".lock", "",
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
    r"[Cc][Nn][Ii][Nn][Ff][Oo]", r"\w+_info\b", r"\binfo\.st_\w+", r"\b(log|logger|logging|console)\.info\b",
    r"\bexc_info\b", r"\bversion_info\b", r"(dist|egg)-info", r"userinfo", r"USERINFO", r"terminfo",
    r"Client-Cert-Info", r"cluster-info", r"node-exports-info",
    r"'error' \| 'info'",  # 网页提示框的类型
    r"notify\('info'",  # 网页提示框的调用
    r"\bt\('knowledge'\)",  # 投资设置页「本地知识库」的文案键
    r"for purpose in \['knowledge'",
    r"(?i)\blog[_.]?level\s*[:=]\s*[\"']?info\b",  # 日志级别
    # RAGFlow（共享服务）私有文件里的既有键：ragflow.yaml 已按 knowledge_* 存在，读它的地方不能换名（R5 前发现）
    r"(?<=from_yaml\)\.)knowledge_(token|password)\b", r"\['knowledge_(token|password)'\]", r"\"knowledge_(token|password)\"",
    r"\bknowledge_(token|password):", r"ragflow_credentials\.knowledge_\w+",  # ragflow 里两个超级用户的用途名（共享服务的既有账号，不随应用改名）
]

# ---------------------------------------------------------------- 改：按类按序
R: list[tuple[str, str, Any]] = []


def rule(cls: str, pattern: str, repl: Any) -> None:
    R.append((cls, pattern, repl))


# 0 开发连接串里「用户:口令」都是应用名：先于域名规则
rule("存储", r"://knowledge:knowledge@", "://knowbase:knowbase@")
rule("存储", r"://info:info@", "://knowfeed:knowfeed@")
# 1 域名
rule("域名", r"knowledge-admin\.(sunmoonai\.com|example\.test)", r"knowbase-admin.\1")
rule("域名", r"(?<![\w.-])knowledge\.(sunmoonai\.com|example\.test)", r"knowbase.\1")
rule("域名", r"info-admin\.(sunmoonai\.com|example\.test)", r"knowfeed-admin.\1")
rule("域名", r"(?<![\w.-])info\.(sunmoonai\.com|example\.test)", r"knowfeed.\1")
# 1b 令牌作用域（所有者改定：改；它是「应用名:动作」）
rule("作用域", r"(?<![\w.-])knowledge:(admin|ingest|retrieve|read)\b", r"knowbase:\1")
rule("作用域", r"(?<![\w.-])info:admin\b", "knowfeed:admin")
rule("域名", r"(?<=//)info\.example\b", "knowfeed.example")
rule("域名", r"(?<=//)knowledge\.example\b", "knowbase.example")
rule("域名", r"(?<=//)info(?=[:/\"'])", "knowfeed")
rule("域名", r"(?<=//)knowledge(?=[:/\"'])", "knowbase")
rule("应用身份", r"\bInfoAppBot\b", "KnowfeedBot")
rule("应用身份", r"\bInfoBot\b", "KnowfeedBot")
# 2 两个应用之间的身份（成对出现，先于单个规则）
for old, new in [
    ("sunmoonai-info-knowledge-ingest", "sunmoonai-knowfeed-knowbase-ingest"),
    ("sunmoon-info-knowledge-ingest", "sunmoon-knowfeed-knowbase-ingest"),
    ("sunmoon-workload-info-knowledge", "sunmoon-workload-knowfeed-knowbase"),
    ("info-knowledge-ingest-client", "knowfeed-knowbase-ingest-client"),
    ("info-knowledge-artifact", "knowfeed-knowbase-artifact"),
    ("info-knowledge-service", "knowfeed-knowbase-service"),
    ("knowledge-info-ingest-service-binding", "knowbase-knowfeed-ingest-service-binding"),
    ("CASDOOR_INFO_KNOWLEDGE_", "CASDOOR_KNOWFEED_KNOWBASE_"),
    ("sunmoon-workload-investment-knowledge", "sunmoon-workload-investment-knowbase"),
    ("'-knowledge-'", "'-knowbase-'"),  # 校验里按应用名拼出的身份名：'sunmoonai-' + application_name + '-knowledge-' + service_relation
    ("'-knowledge'", "'-knowbase'"),
    ("'knowledge:' + ", "'knowbase:' + "),  # 作用域按关系拼出
    (":knowledge:managed-by-gitops", ":knowbase:managed-by-gitops"),
]:
    rule("跨应用身份", re.escape(old), new)
# 3 MCP 服务名（所有者定：改）
rule("MCP", r"(?<![\w-])sunmoon_knowledge(?![\w-])", "sunmoon_knowbase")
rule("MCP", r"(?<![\w-])sunmoon-knowledge\b", "sunmoon-knowbase")  # MCP 服务对外报的名字
# 4 登录 cookie
rule("cookie", r"sunmoonai_knowledge_", "sunmoonai_knowbase_")
rule("cookie", r"sunmoonai_info_", "sunmoonai_knowfeed_")
# 5 环境变量（改名不改值）
rule("环境变量", r"(?<![A-Za-z0-9])KNOWLEDGE_", "KNOWBASE_")
rule("环境变量", r"(?<![A-Za-z0-9])KNOWLEDGE\b", "KNOWBASE")
rule("环境变量", r"(?<![A-Za-z0-9])INFO_(?=[A-Z0-9])", "KNOWFEED_")
rule("环境变量", r"(?<=[A-Z]_)INFO\b", "KNOWFEED")
# 6 配置字段（pydantic 字段名 = 环境变量名小写）
rule("配置字段", r"(?<![\w-])knowledge_(app|mcp|semantic|catalog|web_base_url)(?=_|\b)", r"knowbase_\1")
rule("配置字段", r"(?<![\w-])knowledge_dataset_(path|id|title|object|sha256|registry_enabled|allowed_buckets|cache_dir)\b", r"knowbase_dataset_\1")
# 7 部署配置键与应用名（gitops / ansible / Makefile）
rule("部署键", r"(?<![\w-])(info|knowledge)_(backend|web|admin)_deployment\b",
     lambda m: ("knowfeed" if m[1] == "info" else "knowbase") + f"_{m[2]}_deployment")
rule("部署键", r"(?<![\w-])info_deployment\b", "knowfeed_deployment")
rule("部署键", r"(?<![\w-])knowledge_deployment\b", "knowbase_deployment")
rule("部署键", r"(?<![\w-])knowledge_service(_receiver)?\b", r"knowbase_service\1")
rule("部署键", r"service_access_hosts\.knowledge\b", "service_access_hosts.knowbase")
rule("部署键", r"service_access_hosts\.info\b", "service_access_hosts.knowfeed")
rule("部署键", r"applications\.knowledge\b", "applications.knowbase")
rule("部署键", r"applications\.info\b", "applications.knowfeed")
rule("应用名", r"\bAPP=info\b", "APP=knowfeed")
rule("应用名", r"\bAPP=knowledge\b", "APP=knowbase")
rule("应用名", r"applications-info\b", "applications-knowfeed")
rule("应用名", r"applications-knowledge\b", "applications-knowbase")
# 8 组件与 k8s 对象名（kebab）
rule("组件", r"(?<![\w.-])info-app\b", "knowfeed-app")
rule("组件", r"(?<![\w.-])knowledge-app\b", "knowbase-app")
rule("组件", r"(?<![\w.])knowledge-(?=[a-z0-9])", "knowbase-")
rule("组件", r"(?<![\w.])info-(?=(backend|web|admin|api|runtime|worker|scheduler|producer|migration|migrate|tls|database|redis|rabbitmq|identity|storage|service|browser|celery|domain|r5|development|production|originals|sandboxes|source|smoke|object|derived|rw|ro|write|requests|crawl|securities|watchlist|scanner|user|password|information|schema)\b)", "knowfeed-")
# 9 存储名（乙）
rule("存储", r"(?<![\w-])info_(runtime|migrator|storage|source_reader)\b", r"knowfeed_\1")
rule("存储", r"(?<![\w-])knowledge_(runtime|migrator|source_reader|password)\b", r"knowbase_\1")
rule("存储", r"(?<![\w-])knowledge_token\b", "knowbase_token")
rule("存储", r"(?<=[\"' ])info:\*", "knowfeed:*")
rule("存储", r"(?<=[\"' ])knowledge:\*", "knowbase:*")
rule("存储", r"(?<=[\"' ])info:(?=[a-z])", "knowfeed:")
rule("存储", r"(?<![\w-])info\.(default|admin\.default)\b", r"knowfeed.\1")
rule("存储", r"(?<![\w-])knowledge\.(default|admin\.default)\b", r"knowbase.\1")
rule("存储", r"(?<=:5432/)knowledge\b", "knowbase")
rule("存储", r"(?<=:5432/)info\b", "knowfeed")
rule("存储", r"(?<![\w-])knowledge_backend\b", "knowbase_backend")
rule("存储", r"(?<![\w-])info_backend(?=_user\b|\b)", "knowfeed_backend")
rule("存储", r"(?<=[\"'`/ =])info/(?=(original|securities|samples)\b)", "knowfeed/")
rule("存储", r"\^info/(?=\()", "^knowfeed/")
rule("存储", r"(?<=-originals/)info/", "knowfeed/")  # 桶名先由组件规则改好，桶里的前缀跟着改  # 知识库只读前缀的校验：source_prefix is match('^info/(…)')
rule("存储", r"source_prefix: info/", "source_prefix: knowfeed/")
rule("存储", r"/sunmoon-kind/info\b", "/sunmoon-kind/knowfeed")
rule("存储", r"/sunmoon-kind/knowledge\b", "/sunmoon-kind/knowbase")
rule("存储", r"(database|rabbitmq_vhost): info\b", r"\1: knowfeed")
rule("存储", r"(database|rabbitmq_vhost): knowledge\b", r"\1: knowbase")
rule("应用名", r"(?m)^((?:AUTH_APP|APP_SLUG|NEXT_PUBLIC_APP_NAME|APP_DB_NAME)=)info$", r"\1knowfeed")
rule("应用名", r"(?m)^((?:AUTH_APP|APP_SLUG|NEXT_PUBLIC_APP_NAME|APP_DB_NAME)=)knowledge$", r"\1knowbase")
rule("应用名", r'(?<="app": ")info(?=")', "knowfeed")
rule("应用名", r'(?<="app": ")knowledge(?=")', "knowbase")
# 投资网页设置里 MCP 来源的键（后端 MCP_SOURCES 随引号规则改成 knowbase，网页这头是不带引号的属性名）
rule("应用名", r"mcp_sources\?\.knowledge\b", "mcp_sources?.knowbase")
rule("应用名", r"(?<=mcp_sources \?\? \{\}\), )knowledge(?=: )", "knowbase")
rule("应用名", r"(?<=mcp_sources: \{ )knowledge(?=: )", "knowbase")
# 10 source_app 的两种旧值（各自对应，不合并）
rule("source_app", r"(?<=[\"'])info-app(?=[\"'])", "knowfeed-app")
rule("source_app", r"(source_app[^\n\"'=]{0,24}=?\s*[\"'])info(?=[\"'])", r"\1knowfeed")
# 11 采集库带应用名前缀的表与事件（所有者定：改）
rule("表与事件", r"(?<![\w-])info_(collector|document_version|document|source)\b", r"knowfeed_\1")
rule("表与事件", r"(?<![\w-])(uq|ix|ck)_info_", r"\1_knowfeed_")
rule("表与事件", r"(?<![\w-])info\.((?:[a-z_]+\.)*[a-z_]+)\.v(\d+)\b", r"knowfeed.\1.v\2")
# 12 代码里指向另一个应用的名字
for old, new in [
    ("KnowledgeAppClient", "KnowbaseAppClient"), ("KnowledgeAppNotConfiguredError", "KnowbaseAppNotConfiguredError"),
    ("get_knowledge_app_client", "get_knowbase_app_client"), ("require_knowledge_admin", "require_knowbase_admin"),
    ("require_info_admin", "require_knowfeed_admin"), ("require_knowledge_ingest_service", "require_knowbase_ingest_service"),
    ("require_knowledge_retrieve_service", "require_knowbase_retrieve_service"),
]:
    rule("代码名", rf"\b{old}\b", new)
# 13 中文句子里夹着的 info / knowledge 几乎都指应用（「向 knowledge 重新登记」「只给 info 管理员」）
CJK = r"[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]"
rule("中文里的应用名", rf"(?<={CJK})\s?\bknowledge\b(?!-|_|\.)|\bknowledge\b(?=\s?{CJK})", lambda m: m[0].replace("knowledge", "knowbase"))
rule("中文里的应用名", rf"(?<={CJK})\s?\binfo\b(?!-|_|\.)|\binfo\b(?=\s?{CJK})", lambda m: m[0].replace("info", "knowfeed"))
# 14 采集管理端的页面路径（info 是应用名；知识库管理端的 /knowledge/… 是领域词，留）
rule("页面路径", r"(?<=/)info(?=/(crawl|securities|watchlist|requests)\b)", "knowfeed")
# 14b 页面英文文案里的应用名（只在网页的文案与页面文件里；「Knowledge ingestions」「Knowledge retrieval」是领域词，不在这里）
UI_FILES = re.compile(r"-frontend/app/(messages/[^/]+\.json|app/.*\.(tsx|ts)|components/.*\.tsx|features/.*\.tsx)$")
rule("页面文案", r"\bInfo Admin\b", "Knowfeed Admin")
rule("页面文案", r"\bKnowledge Admin\b", "Knowbase Admin")
rule("页面文案", r"(?<=['\"])info App(?=['\"])", "knowfeed App")
rule("页面文案", r"(?<=['\"])knowledge App(?=['\"])", "knowbase App")
rule("页面文案", r"\binfo web application\b", "knowfeed web application")
rule("页面文案", r"\bknowledge web application\b", "knowbase web application")
rule("页面文案", r"\bInfo crawl\b", "Knowfeed crawl")
rule("页面文案", r"\bfor Info sources\b", "for Knowfeed sources")
rule("页面文案", r"\bRegistered with knowledge\b", "Registered with knowbase")
rule("页面文案", r"\binfo(?= registers datasets| admin\b|”| \(|\.\s)", "knowfeed")
rule("页面文案", r"(?<=on )info\b", "knowfeed")
UI_RULES = set(range(len(R) - 11, len(R)))
rule("标题", r"\bInfo(?= (Backend|Admin Front|Web Front|App)\b)", "Knowfeed")
rule("标题", r"\bKnowledge(?= (Backend|Admin Front|Web Front)\b)", "Knowbase")
rule("标题", r"\bInfo(?= (->|to) Knowledge\b)", "Knowfeed")
rule("标题", r"\b((?:Knowfeed|Investment) (?:->|to) )Knowledge\b", r"\1Knowbase")
# 15 应用名作单词的配置值（只在部署机制里）：'info' / "knowledge"
DEPLOY_FILES = re.compile(r"^k8s/(infrastructure|gitops)/(?!.*/crds\.yaml$)|Makefile$"
                          r"|/core/config\.py$|/domain/cross_app\.py$|/tests/test_cross_app\.py$|/env/server-schema\.ts$|/lib/cross-app/[^/]+\.ts$"
                          r"|-backend/app/tests/[^/]+\.py$"  # 各后端的测试里，带引号的 info / knowledge 都指应用
                          r"|-backend/app/(app|core|scripts)/.+\.py$"
                          r"|-frontend/app/preview/preview\.config\.mjs$"
                          r"|-frontend/app/(?!messages/|node_modules/|preview/).+\.(ts|tsx)$")  # 网页代码里也是（AUTH_APP、expectedApp、契约、跨应用目标）；例外见保留清单  # 各后端代码里也是（2026-10-15 逐条核过：跨应用键、app_slug、app=、MCP 受众与来源、注释示例）
_deploy_start = len(R)
# 排序后比对的应用清单：改名后顺序变了，整句换（先于单个引号规则）
rule("应用名", r"\['casdoor','info','investment','knowledge','tpl'\]", "['casdoor','investment','knowbase','knowfeed','tpl']")
rule("应用名", r"(?<=[\"'])info(?=[\"'])", "knowfeed")
rule("应用名", r"(?<=[\"'])knowledge(?=[\"'])", "knowbase")
rule("应用名", r"(?m)^(\s*)info:(?=\s*$|\s+[\"'{])", r"\1knowfeed:")
rule("应用名", r"(?m)^(\s*)knowledge:(?=\s*$|\s+[\"'{])", r"\1knowbase:")
# 不带引号的写法：YAML 流式值与清单、Makefile 的取值表、标签值
rule("应用名", r"(?<=application_name: )info\b", "knowfeed")
rule("应用名", r"(?<=application_name: )knowledge\b", "knowbase")
rule("应用名", r"\btpl, info, knowledge\b", "tpl, knowfeed, knowbase")
rule("应用名", r"\btpl info knowledge\b", "tpl knowfeed knowbase")
rule("应用名", r"(?<=part-of: )knowledge\b", "knowbase")
rule("应用名", r"(?<=from=)info\b", "knowfeed")  # 地址参数 from=
rule("应用名", r"(?<=from=)knowledge\b", "knowbase")
ONLY_DEPLOY = set(range(_deploy_start, len(R)))
# 网页的预览配置与测试里，应用名作对象键：{ info: …, knowledge: … }（别处的「, info: 类型」是参数名，不碰）
FRONT_FILES = re.compile(r"-frontend/app/(tests/.+|preview/preview\.config\.mjs)$")
rule("应用名", r"(?<=[{,] )info(?=: )", "knowfeed")
rule("应用名", r"(?<=[{,] )knowledge(?=: )", "knowbase")
FRONT_ONLY = {len(R) - 2, len(R) - 1}


def scope(root: Path) -> list[str]:
    files: list[str] = []
    for repo in REPOS:
        out = subprocess.run(["git", "-c", "core.quotepath=off", "-C", str(root / repo), "ls-files", "--recurse-submodules"], capture_output=True, text=True)
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


LOCK_NAME = re.compile(r'(?m)^name = "(info|knowledge)-(backend)"$')


def apply(text: str, rel: str, counts: dict) -> str:
    if rel.endswith("uv.lock"):  # 锁文件只改项目自身名字那一行，其余锁定内容不碰
        new, n = LOCK_NAME.subn(lambda m: f'name = "{"knowfeed" if m[1] == "info" else "knowbase"}-{m[2]}"', text)
        if n:
            counts["锁文件"][rel] += n
        return new
    kept: list[str] = []

    def hide(m: re.Match) -> str:
        kept.append(m[0])
        return f"\x00{len(kept) - 1}\x00"

    for pat in KEEP:
        text = re.sub(pat, hide, text)
    for i, (cls, pat, repl) in enumerate(R):
        if i in ONLY_DEPLOY and not DEPLOY_FILES.search(rel):
            continue
        if i in UI_RULES and not UI_FILES.search(rel):
            continue
        if i in FRONT_ONLY and not FRONT_FILES.search(rel):
            continue
        text, n = re.subn(pat, repl, text)
        if n:
            counts[cls][rel] += n
    return re.sub(r"\x00(\d+)\x00", lambda m: kept[int(m[1])], text)


def moves(root: Path) -> dict[str, str]:
    """要 git mv 的：旧路径 → 新路径（仓的顶层目录名不在这里改，那是 R3）。

    先把规则套到范围内文件的路径上，得出每一级被改名的目录；再把这些目录对应关系套到**全部**跟踪文件上
    （不在替换范围里的文件——已有迁移、图片、锁文件——也要随目录走），每个文件按最近的已改名上级目录走。
    """
    dirs: dict[str, str] = {}
    renamed: dict[str, str] = {}
    for rel in scope(root):
        repo, rest = rel.split("/", 1)
        new = apply(rest, rel, defaultdict(lambda: defaultdict(int)))
        if new == rest:
            continue
        renamed[rel] = f"{repo}/{new}"
        old_parts, new_parts = rel.split("/"), f"{repo}/{new}".split("/")
        for i in range(1, len(old_parts)):
            if old_parts[:i] != new_parts[:i]:
                dirs["/".join(old_parts[:i])] = "/".join(new_parts[:i])
    out = {}
    for repo in REPOS:
        listing = subprocess.run(["git", "-c", "core.quotepath=off", "-C", str(root / repo), "ls-files", "--recurse-submodules"], capture_output=True, text=True).stdout
        for n in listing.splitlines():
            rel = f"{repo}/{n}"
            if rel in renamed:
                out[rel] = renamed[rel]
                continue
            parts = rel.split("/")
            for i in range(len(parts) - 1, 0, -1):  # 最近的已改名上级目录
                head = "/".join(parts[:i])
                if head in dirs:
                    out[rel] = dirs[head] + "/" + "/".join(parts[i:])
                    break
    return out


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
    if "--move" in sys.argv:  # 只用于单一 git 仓的副本；真仓里子仓目录由父仓 git mv（见 rename.md R1）
        for old_rel, new_rel in sorted(moves(root).items()):
            (root / new_rel).parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["git", "-C", str(root), "mv", old_rel, new_rel], check=True)
    summary = {cls: {"files": len(v), "hits": sum(v.values())} for cls, v in counts.items()}
    print(json.dumps(summary, ensure_ascii=False, indent=1))
    if report:
        Path(report).write_text(json.dumps({k: dict(v) for k, v in counts.items()}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
