"""改名 info → knowgather 的库内部分（k8s/docs/rename.md R1，0025）

- 采集库四张带应用名前缀的表改名，连同名字里带它们的约束、索引、序列；
- 原文桶 info-originals → knowgather-originals（开发库的 development-info-originals 同理），对象键前缀 info/ → knowgather/
  （桶里的对象在 R5.2 已按新键复制好）；
- 采集申请里由采集服务自己发起的 source_app 'info-app' → 'knowgather-app'。

库名与角色名的改动不在迁移里，由 R5.2 在停服时用 ALTER DATABASE / ALTER ROLE 做。

Revision ID: 20261015_0014
Revises: 20260929_0013
"""

from __future__ import annotations

import re

import sqlalchemy as sa
from alembic import op

revision = "20261015_0014"
down_revision = "20260929_0013"
branch_labels = None
depends_on = None

TABLES = ("info_source", "info_collector", "info_document", "info_document_version")
BUCKET_TABLES = ("raw_artifact", "extracted_content", "security_dataset")
BUCKETS = {"info-originals": "knowgather-originals", "development-info-originals": "development-knowgather-originals"}
NAME = {
    "up": re.compile(r"(^|_)info_(source|collector|document_version|document)(?=_|$)"),
    "down": re.compile(r"(^|_)knowgather_(source|collector|document_version|document)(?=_|$)"),
}


def _rename_objects(direction: str) -> None:
    """约束先改（主键、唯一约束背后的索引随之改名），再改剩下的索引与序列。只动 public 模式里名字匹配的对象。"""
    new = "knowgather_" if direction == "up" else "info_"
    pattern = NAME[direction]
    bind = op.get_bind()
    constraints = bind.execute(sa.text(
        "select c.conname, t.relname from pg_constraint c join pg_class t on t.oid = c.conrelid "
        "join pg_namespace n on n.oid = t.relnamespace where n.nspname = 'public'"
    )).all()
    for name, table in constraints:
        if pattern.search(name):
            fixed = pattern.sub(lambda m: m[1] + new + m[2], name)
            op.execute(f'ALTER TABLE "{table}" RENAME CONSTRAINT "{name}" TO "{fixed}"')
    for kind, word in (("i", "INDEX"), ("S", "SEQUENCE")):
        rows = bind.execute(sa.text(
            "select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace "
            "where n.nspname = 'public' and c.relkind::text = :k"
        ), {"k": kind}).scalars().all()
        for name in rows:
            if pattern.search(name):
                fixed = pattern.sub(lambda m: m[1] + new + m[2], name)
                op.execute(f'ALTER {word} "{name}" RENAME TO "{fixed}"')


def upgrade() -> None:
    for table in TABLES:
        op.rename_table(table, table.replace("info_", "knowgather_", 1))
    _rename_objects("up")
    for table in BUCKET_TABLES:
        for old, new in BUCKETS.items():
            op.execute(sa.text(f"UPDATE {table} SET bucket = :new WHERE bucket = :old").bindparams(old=old, new=new))
        op.execute(f"UPDATE {table} SET object_key = 'knowgather/' || substr(object_key, 6) WHERE object_key LIKE 'info/%'")
    op.execute("UPDATE security_request_requester SET source_app = 'knowgather-app' WHERE source_app = 'info-app'")


def downgrade() -> None:
    op.execute("UPDATE security_request_requester SET source_app = 'info-app' WHERE source_app = 'knowgather-app'")
    for table in BUCKET_TABLES:
        op.execute(f"UPDATE {table} SET object_key = 'info/' || substr(object_key, 12) WHERE object_key LIKE 'knowgather/%'")
        for old, new in BUCKETS.items():
            op.execute(sa.text(f"UPDATE {table} SET bucket = :old WHERE bucket = :new").bindparams(old=old, new=new))
    _rename_objects("down")
    for table in TABLES:
        op.rename_table(table.replace("info_", "knowgather_", 1), table)
