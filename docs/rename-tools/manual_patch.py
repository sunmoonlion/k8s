"""R1 的手工补丁：替换规则跑完之后执行（k8s/docs/rename.md R1）。参数：改名后的采集后端 app 目录、知识后端 app 目录、五组仓的上一级目录（重算契约哈希用）。

规则只能按字面改；这里是规则做不对、要看上下文的几处：
1. 采集后端的新迁移文件放进去；迁移链清单测试补上它。
2. 测历史迁移 0008 的测试：先退 0014 再退 0008、先升 0008 再升 0014；夹在旧结构时段里的 SQL 用旧表名。
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
NEW_MIGRATION = "20261015_0014_knowfeed_rename.py"


def edit(path: Path, pairs: list[tuple[str, str]]) -> None:
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        if old not in text:
            raise SystemExit(f"{path}: 找不到要改的原文：{old[:80]!r}")
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def rehash_contracts(root: Path) -> None:
    """契约文件内容随改名变了：knowbase 的契约清单与两个下游锁文件里的 sha256 按改完的文件重算（仓目录名到 R3 才改）。"""
    contracts = root / "knowledge-app/contracts"
    for manifest in sorted(contracts.rglob("contract-manifest.json")):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if "schema" in data:
            data["sha256"] = _sha(manifest.parent / data["schema"])
        for name in data.get("files", {}):
            data["files"][name] = _sha(manifest.parent / name)
        _write_json(manifest, data)
    lock = root / "info-app/contracts/knowbase-provider-lock.json"
    data = json.loads(lock.read_text(encoding="utf-8"))
    data["sha256"] = _sha(root / "knowledge-app" / data["schema"])
    _write_json(lock, data)
    lock = root / "investment-app/contracts/knowbase-retrieval-provider-lock.json"
    data = json.loads(lock.read_text(encoding="utf-8"))
    for name in data["schemas"]:
        data["schemas"][name] = _sha(contracts / "retrieval/v1" / name)
    _write_json(lock, data)


def rename_mcp_in_fixtures(root: Path) -> int:
    """投资网页录下来的样例里，工具调用事件带 MCP 服务名（"server": "sunmoon_knowledge"），网页测试按改名后的名字断言。

    样例整体不重录（早已过时，重录会带进大量无关变化）；这里只把服务名这一个词换成改名后后端会发的名字。
    """
    pattern = re.compile(r"(?<![\w-])sunmoon_knowledge(?![\w-])")
    hits = 0
    for path in sorted((root / "investment-app/investment-web-frontend/app/preview/fixtures").rglob("*.json")):
        text = path.read_text(encoding="utf-8")
        new, n = pattern.subn("sunmoon_knowbase", text)
        if n:
            path.write_text(new, encoding="utf-8")
            hits += n
    return hits


def main(backend: Path, knowbase: Path | None = None, root: Path | None = None) -> None:
    if root is not None:
        rehash_contracts(root)
        if rename_mcp_in_fixtures(root) == 0:
            raise SystemExit("投资网页样例里没找到 sunmoon_knowledge：样例变了，先看清再改")
    if knowbase is not None:
        # 数据集登记的期望键里那段是 source_app 的值（采集应用登记时发的 'info' → 'knowfeed'）
        edit(knowbase / "tests/test_dataset_registry_db.py", [
            ('f"active/600009/info/ingestion-1/{BY}"', 'f"active/600009/knowfeed/ingestion-1/{BY}"'),
        ])
    tests = backend / "tests"
    shutil.copy(HERE / "migrations/knowfeed_20261015_0014_rename.py", backend / "alembic/versions" / NEW_MIGRATION)

    edit(tests / "test_kernel_invariants.py", [
        ('        "20260929_0013_security_requests.py",\n',
         f'        "20260929_0013_security_requests.py",\n        "{NEW_MIGRATION}",\n'),
    ])

    edit(tests / "test_info_identity_db.py", [
        # 辅助函数：0014 包在 0008 外面
        ('''MIGRATION = (
    Path(__file__).resolve().parents[1]
    / "alembic/versions/20260912_0008_canonical_identity.py"
)


async def migrate(db, action):
    spec = importlib.util.spec_from_file_location("identity_migration", MIGRATION)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    async with db() as s, s.begin():
        connection = await s.connection()

        def apply(c):
            with Operations.context(MigrationContext.configure(c)):
                getattr(module, action)()

        await connection.run_sync(apply)''',
         f'''VERSIONS = Path(__file__).resolve().parents[1] / "alembic/versions"
MIGRATION = VERSIONS / "20260912_0008_canonical_identity.py"
# 改名迁移（0025）在 0008 之后把 info_* 表改成新名：测 0008 时先退它、升完 0008 再升它
RENAME = VERSIONS / "{NEW_MIGRATION}"


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


async def migrate(db, action):
    identity = _load(MIGRATION, "identity_migration")
    rename = _load(RENAME, "rename_migration")
    steps = (
        [rename.downgrade, identity.downgrade]
        if action == "downgrade"
        else [identity.upgrade, rename.upgrade]
    )
    async with db() as s, s.begin():
        connection = await s.connection()

        def apply(c):
            with Operations.context(MigrationContext.configure(c)):
                for step in steps:
                    step()

        await connection.run_sync(apply)'''),
        # 旧结构时段里写入旧数据
        ('"INSERT INTO knowfeed_document(id,canonical_url,title,status,metadata_json) VALUES (:id,:url,\'legacy\',\'active\',\'{}\')",',
         '"INSERT INTO info_document(id,canonical_url,title,status,metadata_json) VALUES (:id,:url,\'legacy\',\'active\',\'{}\')",'),
        ('''        "INSERT INTO knowfeed_document(id,canonical_url,title,status,metadata_json) "
        "SELECT gen_random_uuid(),'https://EXAMPLE.com:443/article/'||g||'#old','legacy','active','{}' "''',
         '''        "INSERT INTO info_document(id,canonical_url,title,status,metadata_json) "
        "SELECT gen_random_uuid(),'https://EXAMPLE.com:443/article/'||g||'#old','legacy','active','{}' "'''),
        # 0008 升级失败后库还在旧结构
        ('''        await migrate(db, "upgrade")
    assert await sql(db, "SELECT count(*) FROM knowfeed_document") == 2
    assert (
        await sql(
            db,
            "SELECT count(*) FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='knowfeed_document' AND column_name='canonical_identity'",''',
         '''        await migrate(db, "upgrade")
    assert await sql(db, "SELECT count(*) FROM info_document") == 2
    assert (
        await sql(
            db,
            "SELECT count(*) FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='info_document' AND column_name='canonical_identity'",'''),
        # 降级后（旧结构）新代码写不进去。新表名在本测试的模式里不存在时会落到 public 去找——测试库的 public
        # 常常迁移到了最新、有同名新表——所以写之前把查找路径限定在本测试的模式
        ('''    with pytest.raises(DBAPIError):
        async with db() as s:
            await document(s)
    assert await sql(db, "SELECT count(*) FROM knowfeed_document") == 0''',
         '''    with pytest.raises(DBAPIError):
        async with db() as s:
            await s.execute(text("SELECT set_config('search_path', current_schema(), false)"))
            await document(s)
    assert await sql(db, "SELECT count(*) FROM info_document") == 0'''),
        ("from sqlalchemy.exc import DBAPIError, IntegrityError\n",
         "from sqlalchemy import text\nfrom sqlalchemy.exc import DBAPIError, IntegrityError\n"),
        # 0008 在旧表上建的约束是旧名
        ('match="uq_knowfeed_document_canonical_identity"', 'match="uq_info_document_canonical_identity"'),
        # 预检扫描是为 0008 冻结的、只认旧表：往返后的预检放在降级后做
        ('''    await migrate(db, "downgrade")
    await migrate(db, "upgrade")
    assert (await audit_database(db))["ready"] is True''',
         '''    await migrate(db, "downgrade")
    # 预检扫描为 0008 冻结、只认旧表 info_document：在降级后的旧结构上做
    assert (await audit_database(db))["ready"] is True
    await migrate(db, "upgrade")'''),
    ])

    edit(tests / "test_info_delivery_db.py", [
        # 0007 的 SQL 认旧表名：每次跑 0007 都临时退掉改名迁移，跑完再升回；业务代码照常看新表名
        ('''    async def migrate(fn):
        async with db() as s, s.begin():
            connection = await s.connection()

            def apply(conn):
                with Operations.context(MigrationContext.configure(conn)):
                    fn()

            await connection.run_sync(apply)''',
         f'''    rename_path = ROOT / "alembic/versions/{NEW_MIGRATION}"
    rename_spec = importlib.util.spec_from_file_location("rename_migration", rename_path)
    rename = importlib.util.module_from_spec(rename_spec)
    rename_spec.loader.exec_module(rename)

    async def migrate(fn):
        async with db() as s, s.begin():
            connection = await s.connection()

            def apply(conn):
                with Operations.context(MigrationContext.configure(conn)):
                    rename.downgrade()
                    fn()
                    rename.upgrade()

            await connection.run_sync(apply)'''),
        # 0007 的守卫只认改名前的事件类型：这条历史测试里塞的事件用旧名
        ("VALUES (:id,'knowfeed.distribution.dispatch.v1','distribution_record',:record,",
         "VALUES (:id,'info.distribution.dispatch.v1','distribution_record',:record,"),
        ('''            topic="knowfeed.index.v1",
            key=str(version.id),
            payload={"document_version_id": str(version.id)},
            deduplication_key="migration-roundtrip-new-command",''',
         '''            topic="info.index.v1",
            key=str(version.id),
            payload={"document_version_id": str(version.id)},
            deduplication_key="migration-roundtrip-new-command",'''),
    ])


if __name__ == "__main__":
    main(*[Path(a).expanduser() for a in sys.argv[1:]])
