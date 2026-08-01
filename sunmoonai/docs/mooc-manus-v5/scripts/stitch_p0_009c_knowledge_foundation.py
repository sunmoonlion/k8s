#!/usr/bin/env python3
"""Post-overlay stitch for P0-009C Knowledge foundation adoption."""

from __future__ import annotations

import json
import re
import textwrap
from pathlib import Path

KN_ADMIN_BE = Path("/home/zymun/knowledge-app/knowledge-admin-backend")
KN_ADMIN_FE = Path("/home/zymun/knowledge-app/knowledge-admin-frontend")
KN_WEB_BE = Path("/home/zymun/knowledge-app/knowledge-web-backend")
KEEP_CFG = KN_ADMIN_BE / "docs/p0-009c-domain-keep/pre-kernel/core-config.py"
CFG = KN_ADMIN_BE / "app/core/config.py"
CELERY = KN_ADMIN_BE / "app/app/infrastructure/messaging/celery_producer.py"
ROUTES = KN_ADMIN_BE / "app/app/interfaces/endpoints/routes.py"
NAV = KN_ADMIN_FE / "app/lib/navigation.ts"


DOMAIN_FIELDS_BLOCK = '''
    # Service-to-service resource server boundary (Info -> Knowledge ingest).
    # Cross-app relation names must NOT be rewritten to knowledge-*.
    internal_auth_casdoor_application: str = "sunmoonai-info-knowledge-ingest"
    internal_auth_discovery_url: str | None = None
    internal_auth_backchannel_endpoint: str | None = None
    internal_auth_audience: str | None = None
    internal_auth_subject_allowlist: str = ""
    internal_auth_required_scope: str = "knowledge:ingest"

    # Independent Research worker -> Knowledge retrieval resource boundary.
    retrieval_auth_casdoor_application: str = "sunmoonai-research-knowledge-retrieve"
    retrieval_auth_discovery_url: str | None = None
    retrieval_auth_backchannel_endpoint: str | None = None
    retrieval_auth_audience: str | None = None
    retrieval_auth_subject_allowlist: str = ""
    retrieval_auth_required_scope: str = "knowledge:retrieve"

    # RAGFlow ingestion (unconfigured base/key only validates artifact; never fake success).
    ragflow_api_base: str | None = Field(default=None, validation_alias="RAGFLOW_API_BASE")
    ragflow_api_key: str | None = Field(default=None, validation_alias="RAGFLOW_API_KEY")
    ragflow_parse_timeout_seconds: int = Field(
        default=120, validation_alias="RAGFLOW_PARSE_TIMEOUT_SECONDS"
    )
    ragflow_parse_poll_interval_seconds: float = Field(
        default=1.0, validation_alias="RAGFLOW_PARSE_POLL_INTERVAL_SECONDS"
    )
    retrieval_dataset_allowlist: str = Field(
        default="default",
        validation_alias="RETRIEVAL_DATASET_ALLOWLIST",
    )
    retrieval_default_tenant_id: str = Field(
        default="sunmoonai",
        validation_alias="RETRIEVAL_DEFAULT_TENANT_ID",
    )
    retrieval_provider_timeout_seconds: float = Field(
        default=15.0,
        gt=0,
        le=120,
        validation_alias="RETRIEVAL_PROVIDER_TIMEOUT_SECONDS",
    )

    # S3 object storage (ingestion worker pulls upstream artifacts).
    s3_endpoint: str | None = Field(default=None, validation_alias="S3_ENDPOINT")
    s3_region: str = Field(default="us-east-1", validation_alias="S3_REGION")
    s3_access_key_id: str | None = Field(default=None, validation_alias="S3_ACCESS_KEY_ID")
    s3_secret_access_key: str | None = Field(
        default=None, validation_alias="S3_SECRET_ACCESS_KEY"
    )
    s3_force_path_style: bool = Field(default=True, validation_alias="S3_FORCE_PATH_STYLE")
    artifact_s3_allowed_buckets: str = Field(
        default="development-info-originals",
        validation_alias="ARTIFACT_S3_ALLOWED_BUCKETS",
    )
    artifact_s3_allowed_prefixes: str = Field(
        default="info/original/",
        validation_alias="ARTIFACT_S3_ALLOWED_PREFIXES",
    )
    artifact_max_size_bytes: int = Field(
        default=52_428_800,
        ge=1,
        le=52_428_800,
        validation_alias="ARTIFACT_MAX_SIZE_BYTES",
    )
    artifact_allowed_content_types: str = Field(
        default="text/markdown,text/plain",
        validation_alias="ARTIFACT_ALLOWED_CONTENT_TYPES",
    )
'''

DOMAIN_PROPS_BLOCK = '''
    @property
    def internal_auth_subjects(self) -> frozenset[str]:
        return frozenset(
            item.strip()
            for item in self.internal_auth_subject_allowlist.split(",")
            if item.strip()
        )

    @property
    def retrieval_auth_subjects(self) -> frozenset[str]:
        return frozenset(
            item.strip()
            for item in self.retrieval_auth_subject_allowlist.split(",")
            if item.strip()
        )

    @property
    def ragflow_enabled(self) -> bool:
        return bool(self.ragflow_api_base and self.ragflow_api_key)

    @property
    def retrieval_datasets(self) -> frozenset[str]:
        return frozenset(
            value.strip()
            for value in self.retrieval_dataset_allowlist.split(",")
            if value.strip()
        )

    @property
    def artifact_bucket_allowlist(self) -> frozenset[str]:
        return frozenset(
            value.strip()
            for value in self.artifact_s3_allowed_buckets.split(",")
            if value.strip()
        )

    @property
    def artifact_prefix_allowlist(self) -> tuple[str, ...]:
        return tuple(
            value.strip().lstrip("/")
            for value in self.artifact_s3_allowed_prefixes.split(",")
            if value.strip()
        )

    @property
    def artifact_content_type_allowlist(self) -> frozenset[str]:
        return frozenset(
            value.strip().lower()
            for value in self.artifact_allowed_content_types.split(",")
            if value.strip()
        )
'''


def stitch_config() -> None:
    text = CFG.read_text()
    if "retrieval_auth_casdoor_application" in text and "ragflow_api_base" in text:
        print("config already has knowledge domain fields")
        return
    if "celery_result_backend" not in text:
        raise SystemExit("unexpected config shape: missing celery_result_backend")
    # Insert domain fields after celery_result_backend block.
    pattern = re.compile(
        r'(celery_result_backend: str \| None = Field\(\n'
        r'        default=None, validation_alias="CELERY_RESULT_BACKEND"\n'
        r'    \)\n)',
        re.M,
    )
    m = pattern.search(text)
    if not m:
        raise SystemExit("failed to locate celery_result_backend insertion point")
    text = text[: m.end()] + DOMAIN_FIELDS_BLOCK + text[m.end() :]
    # Insert domain properties before model_config.
    marker = "    model_config = SettingsConfigDict("
    if marker not in text:
        raise SystemExit("failed to locate model_config insertion point")
    if "def internal_auth_subjects" not in text:
        text = text.replace(marker, DOMAIN_PROPS_BLOCK + "\n" + marker, 1)
    CFG.write_text(text)
    if not KEEP_CFG.exists():
        print("WARN: pre-kernel config archive missing")
    print("stitched admin-backend domain config")


def stitch_celery() -> None:
    text = CELERY.read_text()
    if "dispatch_knowledge_ingestion" in text:
        print("celery already has knowledge dispatch")
        return
    if "import uuid" not in text:
        text = text.replace(
            "from functools import lru_cache\n",
            "from functools import lru_cache\nimport uuid\n",
            1,
        )
    method = (
        "    def dispatch_knowledge_ingestion(self, ingestion_id: uuid.UUID) -> str:\n"
        '        """投递 knowledge ingestion 处理任务，返回 Celery task_id。"""\n'
        "        self._ensure_ready()\n"
        "        from app.tasks.knowledge_ingestion import process_knowledge_ingestion\n"
        "\n"
        "        queue = get_settings().celery_queue\n"
        "        async_result = process_knowledge_ingestion.apply_async(\n"
        "            args=[str(ingestion_id)], queue=queue\n"
        "        )\n"
        "        logger.info(\n"
        '            "已投递 process_knowledge_ingestion 任务 task_id=%s ingestion_id=%s queue=%s",\n'
        "            async_result.id,\n"
        "            ingestion_id,\n"
        "            queue,\n"
        "        )\n"
        "        return async_result.id\n"
        "\n"
    )
    # Insert before get_task_result
    anchor = "    def get_task_result(self, task_id: str) -> AsyncResult:"
    if anchor not in text:
        raise SystemExit("celery producer missing get_task_result")
    text = text.replace(anchor, method + anchor, 1)
    CELERY.write_text(text)
    print("stitched celery dispatch_knowledge_ingestion")


def stitch_routes() -> None:
    ROUTES.write_text(
        textwrap.dedent(
            '''
            from fastapi import APIRouter, Depends

            from app.interfaces.endpoints.auth_routes import router as auth_router
            from app.interfaces.endpoints.knowledge_routes import (
                internal_router as knowledge_internal_router,
                router as knowledge_router,
            )
            from app.interfaces.endpoints.tasks_routes import router as tasks_router
            from app.interfaces.middleware.auth import require_knowledge_admin

            router = APIRouter()

            router.include_router(auth_router)
            router.include_router(
                tasks_router, dependencies=[Depends(require_knowledge_admin)]
            )
            router.include_router(
                knowledge_router, dependencies=[Depends(require_knowledge_admin)]
            )
            router.include_router(knowledge_internal_router)

            # 在此注册其他业务模块路由
            '''
        ).lstrip()
    )
    print("stitched admin-backend routes (tasks + knowledge)")


def rewrite_identity_in_tests() -> None:
    tests_dir = KN_ADMIN_BE / "app/tests"
    web_tests = KN_WEB_BE / "app/tests"
    replacements = [
        ("sunmoonai_tpl_admin_sid", "sunmoonai_knowledge_admin_sid"),
        ("sunmoonai_tpl_admin_oidc_tx", "sunmoonai_knowledge_admin_oidc_tx"),
        ("sunmoonai_tpl_web_sid", "sunmoonai_knowledge_web_sid"),
        ("sunmoonai_tpl_web_oidc_tx", "sunmoonai_knowledge_web_oidc_tx"),
        ("tpl:admin", "knowledge:admin"),
        ("tpl:web", "knowledge:web"),
        ('"app": "tpl"', '"app": "knowledge"'),
        ("'app': 'tpl'", "'app': 'knowledge'"),
        ("app_slug='tpl'", "app_slug='knowledge'"),
        ('app_slug="tpl"', 'app_slug="knowledge"'),
        ("sunmoonai-tpl-admin", "sunmoonai-knowledge-admin"),
        ("sunmoonai-tpl-web", "sunmoonai-knowledge-web"),
        ("tpl-admin-v1", "knowledge-admin-v1"),
        ("tpl-web-v1", "knowledge-web-v1"),
        ("tpl.admin.default", "knowledge.admin.default"),
        ("tpl-admin-backend", "knowledge-admin-backend"),
        ("tpl-web-backend", "knowledge-web-backend"),
        # principal fixtures often use app="tpl"
        ("Principal(app='tpl'", "Principal(app='knowledge'"),
        ('Principal(app="tpl"', 'Principal(app="knowledge"'),
    ]
    for base in (tests_dir, web_tests):
        if not base.exists():
            continue
        for path in base.rglob("*.py"):
            text = path.read_text()
            orig = text
            for a, b in replacements:
                text = text.replace(a, b)
            if text != orig:
                path.write_text(text)
                print(f"identity rewrite {path}")


def add_admin_domain_shell() -> None:
    page = KN_ADMIN_FE / "app/app/[locale]/(dashboard)/knowledge/ingestions/page.tsx"
    panel = KN_ADMIN_FE / "app/components/knowledge/knowledge-ingestions-panel.tsx"
    page.parent.mkdir(parents=True, exist_ok=True)
    panel.parent.mkdir(parents=True, exist_ok=True)
    page.write_text(
        textwrap.dedent(
            '''
            import type { Metadata } from 'next'

            import { KnowledgeIngestionsPanel } from '@/components/knowledge/knowledge-ingestions-panel'
            import { requireAnyRole } from '@/lib/server/auth-session'

            export const dynamic = 'force-dynamic'
            export const revalidate = 0

            export const metadata: Metadata = {
              title: 'Knowledge ingestions',
              robots: { index: false, follow: false },
            }

            export default async function KnowledgeIngestionsPage({
              params,
            }: {
              params: Promise<{ locale: string }>
            }) {
              const { locale } = await params
              await requireAnyRole(locale, ['admin', 'operator'])
              return (
                <div>
                  <div className="admin-page-heading">
                    <h1 className="text-2xl font-semibold">Knowledge ingestions</h1>
                    <p className="text-muted-foreground">
                      Minimal Dataset/Ingestion control surface. Common Admin shell comes from the
                      frozen Next Admin template; full Vue domain UI remains archived under
                      docs/p0-009c-domain-keep.
                    </p>
                  </div>
                  <KnowledgeIngestionsPanel />
                </div>
              )
            }
            '''
        ).lstrip()
    )
    panel.write_text(
        textwrap.dedent(
            '''
            'use client'

            import { useTranslations } from 'next-intl'

            export function KnowledgeIngestionsPanel() {
              const t = useTranslations('KnowledgeIngestions')
              return (
                <section className="mt-6 space-y-3 rounded-lg border border-border p-4">
                  <h2 className="text-lg font-medium">{t('title')}</h2>
                  <p className="text-sm text-muted-foreground">{t('description')}</p>
                  <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
                    <li>Admin API: GET/POST /api/knowledge/ingestions*</li>
                    <li>RAGFlow check: GET /api/knowledge/ragflow/config-check</li>
                    <li>Internal ingest: POST /api/internal/v1/knowledge/ingestions</li>
                    <li>Internal retrieval: POST /api/internal/v1/knowledge/retrievals</li>
                  </ul>
                </section>
              )
            }
            '''
        ).lstrip()
    )
    nav = NAV.read_text()
    if "knowledgeIngestions" not in nav:
        nav = nav.replace(
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings' | 'infoCrawl'",
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings' | 'knowledgeIngestions'",
        )
        # template may not have infoCrawl
        nav = nav.replace(
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings'",
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings' | 'knowledgeIngestions'",
        )
        if "Database" not in nav and "BookOpen" not in nav:
            nav = nav.replace(
                "  Settings,\n  TableProperties,\n  type LucideIcon,\n} from 'lucide-react'",
                "  BookOpen,\n  Settings,\n  TableProperties,\n  type LucideIcon,\n} from 'lucide-react'",
            )
        insert = textwrap.dedent(
            '''
              {
                key: 'knowledge-ingestions',
                path: '/knowledge/ingestions',
                labelKey: 'knowledgeIngestions',
                icon: BookOpen,
                requiredRoles: ['admin', 'operator'],
              },
            '''
        )
        nav = nav.replace(
            "  {\n    key: 'reference',\n",
            insert + "  {\n    key: 'reference',\n",
            1,
        )
        NAV.write_text(nav)
    # Ensure Navigation i18n key exists in message consumers that type labelKey
    for locale in ("zh-CN.json", "en.json"):
        path = KN_ADMIN_FE / "app/messages" / locale
        msg = json.loads(path.read_text())
        msg.setdefault("Navigation", {})
        if "knowledgeIngestions" not in msg["Navigation"]:
            msg["Navigation"]["knowledgeIngestions"] = (
                "知识入库" if locale.startswith("zh") else "Knowledge ingestions"
            )
        path.write_text(json.dumps(msg, indent=2, ensure_ascii=False) + "\n")
    print("added knowledge admin domain shell page")


def stitch_oidc_public_jwks() -> None:
    oidc = KN_ADMIN_BE / "app/app/infrastructure/security/oidc.py"
    text = oidc.read_text()
    if "async def get_key_set(" in text:
        print("oidc already exposes get_key_set")
        return
    anchor = "    async def _get_key_set(\n"
    if anchor not in text:
        raise SystemExit("oidc missing _get_key_set")
    wrapper = (
        "    async def get_key_set(\n"
        "        self, metadata: OidcMetadata, *, force_refresh: bool = False\n"
        "    ) -> KeySet:\n"
        '        """Public JWKS accessor used by service-to-service verifiers."""\n'
        "        return await self._get_key_set(metadata, force_refresh=force_refresh)\n"
        "\n"
    )
    oidc.write_text(text.replace(anchor, wrapper + anchor, 1))
    print("stitched oidc.get_key_set public wrapper")


def stitch_audit_context() -> None:
    src = Path("/home/zymun/tpl-app/tpl-admin-backend/app/app/application/audit_context.py")
    dst = KN_ADMIN_BE / "app/app/application/audit_context.py"
    if not src.exists():
        raise SystemExit("tpl audit_context missing")
    dst.write_text(src.read_text())
    print("copied audit_context from template")


def stitch_tasks_routes_identity() -> None:
    path = KN_ADMIN_BE / "app/app/interfaces/endpoints/tasks_routes.py"
    text = path.read_text()
    text2 = text.replace("require_tpl_admin", "require_knowledge_admin")
    if text2 != text:
        path.write_text(text2)
        print("tasks_routes identity -> require_knowledge_admin")
    else:
        print("tasks_routes already knowledge-scoped")


def main() -> None:
    raise SystemExit(
        "retired unsafe one-shot stitch; use verify_p0_009e_convergence.py "
        "for freeze-tag clean-room replay"
    )
    if not CFG.exists():
        raise SystemExit("run apply_p0_009c_knowledge_foundation.sh first")
    stitch_audit_context()
    stitch_config()
    stitch_celery()
    stitch_oidc_public_jwks()
    stitch_tasks_routes_identity()
    stitch_routes()
    rewrite_identity_in_tests()
    add_admin_domain_shell()
    print("P0-009C stitch complete")


if __name__ == "__main__":
    main()
