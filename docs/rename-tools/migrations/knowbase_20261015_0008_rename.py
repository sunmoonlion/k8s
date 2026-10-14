"""改名 info → knowgather、knowledge → knowbase 在知识库里留下的值（k8s/docs/rename.md R1，0025）

表名不动（knowledge 作领域词，所有者 2026-10-14 定：留）；只换存着的、指向旧应用或旧存储的值：
- source_app 两种旧值：'info-app' → 'knowgather-app'，'info' → 'knowgather'（各自对应，不合并）；
- 数据集的桶与对象键：info-originals → knowgather-originals（含开发库前缀），键前缀 info/ → knowgather/；
- 文档版本的 source_uri、入库任务的 canonical_url 里的旧桶、旧前缀、旧域名。

Revision ID: 20261015_0008
Revises: 20260927_0007
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20261015_0008"
down_revision = "20260927_0007"
branch_labels = None
depends_on = None

SOURCE_APP_TABLES = ("knowledge_ingestion_job", "knowledge_document", "knowledge_document_version", "knowledge_dataset")
SOURCE_APP = (("info-app", "knowgather-app"), ("info", "knowgather"))
BUCKETS = (("info-originals", "knowgather-originals"), ("development-info-originals", "development-knowgather-originals"))
# 文本列里的替换：先长后短，桶 + 前缀一起换，避免只换一半
TEXT = (
    ("s3://development-info-originals/info/", "s3://development-knowgather-originals/knowgather/"),
    ("s3://info-originals/info/", "s3://knowgather-originals/knowgather/"),
    ("//info-admin.sunmoonai.com", "//knowgather-admin.sunmoonai.com"),
    ("//info.sunmoonai.com", "//knowgather.sunmoonai.com"),
)
TEXT_COLUMNS = (("knowledge_document_version", "source_uri"), ("knowledge_ingestion_job", "canonical_url"))


def _swap(pairs, reverse: bool):
    return [(b, a) for a, b in pairs] if reverse else list(pairs)


def _run(reverse: bool) -> None:
    for table in SOURCE_APP_TABLES:
        for old, new in _swap(SOURCE_APP, reverse):
            op.execute(sa.text(f"UPDATE {table} SET source_app = :new WHERE source_app = :old").bindparams(old=old, new=new))
    for old, new in _swap(BUCKETS, reverse):
        op.execute(sa.text("UPDATE knowledge_dataset SET bucket = :new WHERE bucket = :old").bindparams(old=old, new=new))
    old_prefix, new_prefix = ("knowgather/", "info/") if reverse else ("info/", "knowgather/")
    op.execute(sa.text(
        "UPDATE knowledge_dataset SET object_key = :new || substr(object_key, :n) WHERE object_key LIKE :like"
    ).bindparams(new=new_prefix, n=len(old_prefix) + 1, like=old_prefix + "%"))
    for table, column in TEXT_COLUMNS:
        for old, new in _swap(TEXT, reverse):
            op.execute(sa.text(
                f"UPDATE {table} SET {column} = replace({column}, :old, :new) WHERE {column} LIKE :like"
            ).bindparams(old=old, new=new, like=f"%{old}%"))


def upgrade() -> None:
    _run(reverse=False)


def downgrade() -> None:
    _run(reverse=True)
