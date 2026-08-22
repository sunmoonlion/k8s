#!/usr/bin/env python3
"""Post-overlay stitch for P0-009D Research foundation adoption."""

from __future__ import annotations

import json
import re
import shutil
import textwrap
from pathlib import Path

RS_ADMIN_BE = Path("/home/zymun/research-app/research-admin-backend")
RS_ADMIN_FE = Path("/home/zymun/research-app/research-admin-frontend")
RS_WEB_BE = Path("/home/zymun/research-app/research-web-backend")
RS_WEB_FE = Path("/home/zymun/research-app/research-web-frontend")
KEEP_CFG = RS_ADMIN_BE / "docs/p0-009d-domain-keep/pre-kernel/core-config.py"
CFG = RS_ADMIN_BE / "app/core/config.py"
CELERY = RS_ADMIN_BE / "app/app/infrastructure/messaging/celery_producer.py"
ROUTES = RS_ADMIN_BE / "app/app/interfaces/endpoints/routes.py"
NAV = RS_ADMIN_FE / "app/lib/navigation.ts"
KEEP_WEB_FE = RS_WEB_FE / "docs/p0-009d-domain-keep/pre-overlay-app"

DOMAIN_FIELDS_BLOCK = '''
    # Agent runtime (Research domain).
    agent_session_lock_ttl_seconds: int = Field(default=300, ge=1, le=3600)
    agent_v4_traffic_enabled: bool = Field(
        default=False, validation_alias="AGENT_V4_TRAFFIC_ENABLED"
    )
    agent_redis_key_prefix: str = Field(
        default="research:agent", validation_alias="AGENT_REDIS_KEY_PREFIX"
    )

    # Knowledge retrieval client (cross-app relation names must NOT be rewritten).
    knowledge_retrieval_url: str | None = Field(
        default=None, validation_alias="KNOWLEDGE_RETRIEVAL_URL"
    )
    knowledge_retrieval_service_application: str = Field(
        default="sunmoonai-research-knowledge-retrieve",
        validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION",
    )
    knowledge_retrieval_service_discovery_url: str | None = Field(
        default=None, validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL"
    )
    knowledge_retrieval_service_backchannel_endpoint: str | None = Field(
        default=None,
        validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT",
    )
    knowledge_retrieval_service_client_id: str | None = Field(
        default=None, validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID"
    )
    knowledge_retrieval_service_client_secret: str | None = Field(
        default=None, validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET"
    )
    knowledge_retrieval_service_scope: str = Field(
        default="knowledge:retrieve",
        validation_alias="KNOWLEDGE_RETRIEVAL_SERVICE_SCOPE",
    )
    knowledge_retrieval_timeout_seconds: float = Field(
        default=20.0,
        gt=0,
        le=120,
        validation_alias="KNOWLEDGE_RETRIEVAL_TIMEOUT_SECONDS",
    )
'''

DOMAIN_PROPS_BLOCK = '''
    @property
    def knowledge_retrieval_enabled(self) -> bool:
        return bool(
            self.knowledge_retrieval_url
            and self.knowledge_retrieval_service_client_id
            and self.knowledge_retrieval_service_client_secret
        )
'''


def stitch_config() -> None:
    text = CFG.read_text()
    if "knowledge_retrieval_service_application" in text and "agent_v4_traffic_enabled" in text:
        print("config already has research domain fields")
        return
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
    marker = "    model_config = SettingsConfigDict("
    if marker not in text:
        raise SystemExit("failed to locate model_config insertion point")
    if "def knowledge_retrieval_enabled" not in text:
        text = text.replace(marker, DOMAIN_PROPS_BLOCK + "\n" + marker, 1)
    CFG.write_text(text)
    print("stitched admin-backend domain config")


def stitch_celery() -> None:
    text = CELERY.read_text()
    if "dispatch_agent_graph" in text and "_delivery_options" in text:
        print("celery already stitched")
        return
    # Rewrite CeleryProducer class body to include delivery options + agent dispatch.
    CELERY.write_text(
        textwrap.dedent(
            '''
            """Celery producer — admin-backend API 向 RabbitMQ 投递异步任务。"""

            from __future__ import annotations

            import logging
            from functools import lru_cache

            from celery.result import AsyncResult

            from app.worker import celery_app, configure_celery, is_celery_configured
            from core.config import get_settings

            logger = logging.getLogger(__name__)


            class CeleryNotConfiguredError(RuntimeError):
                pass


            class CeleryProducer:
                def _ensure_ready(self) -> None:
                    if not configure_celery():
                        raise CeleryNotConfiguredError(
                            "Celery broker not configured (set CELERY_BROKER_URL)"
                        )

                @property
                def enabled(self) -> bool:
                    if is_celery_configured():
                        return True
                    return configure_celery()

                def _delivery_options(self) -> dict[str, str]:
                    queue = get_settings().celery_queue
                    return {
                        "queue": queue,
                        "exchange": queue,
                        "routing_key": queue,
                    }

                def dispatch_ping(self) -> str:
                    """投递 ping 任务，返回 Celery task_id。"""
                    self._ensure_ready()
                    from app.tasks.ping import ping

                    options = self._delivery_options()
                    async_result = ping.apply_async(**options)
                    logger.info(
                        "已投递 ping 任务 task_id=%s queue=%s",
                        async_result.id,
                        options["queue"],
                    )
                    return async_result.id

                def dispatch_agent_graph(
                    self,
                    run_id: str,
                    user_input: str | None = None,
                    security_context: dict | None = None,
                ) -> str:
                    """投递 Phase 0 agent graph 任务，返回 Celery task_id。"""
                    self._ensure_ready()
                    from app.tasks.agent_graph import run_agent_graph

                    async_result = run_agent_graph.apply_async(
                        args=[run_id, user_input, security_context],
                        **self._delivery_options(),
                    )
                    logger.info(
                        "已投递 agent graph 任务 task_id=%s run_id=%s queue=%s",
                        async_result.id,
                        run_id,
                        get_settings().celery_queue,
                    )
                    return async_result.id

                def get_task_result(self, task_id: str) -> AsyncResult:
                    self._ensure_ready()
                    return AsyncResult(task_id, app=celery_app)


            @lru_cache
            def get_celery_producer() -> CeleryProducer:
                return CeleryProducer()
            '''
        ).lstrip()
    )
    print("stitched celery dispatch_agent_graph")


def stitch_routes() -> None:
    ROUTES.write_text(
        textwrap.dedent(
            '''
            from fastapi import APIRouter, Depends

            from app.interfaces.endpoints.agent_routes import router as agent_router
            from app.interfaces.endpoints.auth_routes import router as auth_router
            from app.interfaces.endpoints.tasks_routes import router as tasks_router
            from app.interfaces.middleware.auth import require_research_admin

            router = APIRouter()

            router.include_router(auth_router)
            router.include_router(
                tasks_router, dependencies=[Depends(require_research_admin)]
            )
            router.include_router(
                agent_router, dependencies=[Depends(require_research_admin)]
            )
            '''
        ).lstrip()
    )
    print("stitched admin-backend routes (tasks + agent)")


def stitch_tasks_routes_identity() -> None:
    path = RS_ADMIN_BE / "app/app/interfaces/endpoints/tasks_routes.py"
    text = path.read_text().replace("require_tpl_admin", "require_research_admin")
    path.write_text(text)
    print("tasks_routes identity -> require_research_admin")


def stitch_oidc_public_jwks() -> None:
    oidc = RS_ADMIN_BE / "app/app/infrastructure/security/oidc.py"
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
        '        """Public JWKS accessor used by service clients/verifiers."""\n'
        "        return await self._get_key_set(metadata, force_refresh=force_refresh)\n"
        "\n"
    )
    oidc.write_text(text.replace(anchor, wrapper + anchor, 1))
    print("stitched oidc.get_key_set public wrapper")


def stitch_audit_context() -> None:
    src = Path("/home/zymun/master/tpl-app/tpl-admin-backend/app/app/application/audit_context.py")
    dst = RS_ADMIN_BE / "app/app/application/audit_context.py"
    dst.write_text(src.read_text())
    print("copied audit_context from template")


def rewrite_identity_in_tests() -> None:
    replacements = [
        ("sunmoonai_tpl_admin_sid", "sunmoonai_research_admin_sid"),
        ("sunmoonai_tpl_admin_oidc_tx", "sunmoonai_research_admin_oidc_tx"),
        ("sunmoonai_tpl_web_sid", "sunmoonai_research_web_sid"),
        ("sunmoonai_tpl_web_oidc_tx", "sunmoonai_research_web_oidc_tx"),
        ("tpl:admin", "research:admin"),
        ("tpl:web", "research:web"),
        ('"app": "tpl"', '"app": "research"'),
        ("'app': 'tpl'", "'app': 'research'"),
        ('app="tpl"', 'app="research"'),
        ("app='tpl'", "app='research'"),
        ("app_slug='tpl'", "app_slug='research'"),
        ('app_slug="tpl"', 'app_slug="research"'),
        ("sunmoonai-tpl-admin", "sunmoonai-research-admin"),
        ("sunmoonai-tpl-web", "sunmoonai-research-web"),
        ("tpl-admin-v1", "research-admin-v1"),
        ("tpl-web-v1", "research-web-v1"),
        ("tpl.admin.default", "research.admin.default"),
        ("tpl-admin-backend", "research-admin-backend"),
        ("tpl-web-backend", "research-web-backend"),
        ('session_key_prefix == "tpl:auth:admin:session:"',
         'session_key_prefix == "research:auth:admin:session:"'),
        ('session_key_prefix == "tpl:auth:web:session:"',
         'session_key_prefix == "research:auth:web:session:"'),
    ]
    for base in (RS_ADMIN_BE / "app/tests", RS_WEB_BE / "app/tests"):
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
    page = RS_ADMIN_FE / "app/app/[locale]/(dashboard)/research/runtime/page.tsx"
    panel = RS_ADMIN_FE / "app/components/research/research-runtime-panel.tsx"
    page.parent.mkdir(parents=True, exist_ok=True)
    panel.parent.mkdir(parents=True, exist_ok=True)
    page.write_text(
        textwrap.dedent(
            '''
            import type { Metadata } from 'next'

            import { ResearchRuntimePanel } from '@/components/research/research-runtime-panel'
            import { requireAnyRole } from '@/lib/server/auth-session'

            export const dynamic = 'force-dynamic'
            export const revalidate = 0

            export const metadata: Metadata = {
              title: 'Research runtime',
              robots: { index: false, follow: false },
            }

            export default async function ResearchRuntimePage({
              params,
            }: {
              params: Promise<{ locale: string }>
            }) {
              const { locale } = await params
              await requireAnyRole(locale, ['admin', 'operator'])
              return (
                <div>
                  <div className="admin-page-heading">
                    <h1 className="text-2xl font-semibold">Research runtime</h1>
                    <p className="text-muted-foreground">
                      Minimal Runtime/Agent governance surface. Common Admin shell comes from the
                      frozen Next Admin template; Vue demo UI remains archived under
                      docs/p0-009d-domain-keep.
                    </p>
                  </div>
                  <ResearchRuntimePanel />
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

            export function ResearchRuntimePanel() {
              const t = useTranslations('ResearchRuntime')
              return (
                <section className="mt-6 space-y-3 rounded-lg border border-border p-4">
                  <h2 className="text-lg font-medium">{t('title')}</h2>
                  <p className="text-sm text-muted-foreground">{t('description')}</p>
                  <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
                    <li>Admin API: POST /api/agent/sessions</li>
                    <li>Runs: POST /api/agent/sessions/&#123;id&#125;/runs + resume</li>
                    <li>SSE: GET /api/agent/sessions/&#123;id&#125;/stream</li>
                    <li>Knowledge retrieval client uses sunmoonai-research-knowledge-retrieve</li>
                  </ul>
                </section>
              )
            }
            '''
        ).lstrip()
    )
    nav = NAV.read_text()
    if "researchRuntime" not in nav:
        nav = nav.replace(
            "  Settings,\n  TableProperties,\n  type LucideIcon,\n} from 'lucide-react'",
            "  Cpu,\n  Settings,\n  TableProperties,\n  type LucideIcon,\n} from 'lucide-react'",
        )
        nav = nav.replace(
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings'",
            "labelKey: 'dashboard' | 'reference' | 'richReference' | 'settings' | 'researchRuntime'",
        )
        insert = textwrap.dedent(
            '''
              {
                key: 'research-runtime',
                path: '/research/runtime',
                labelKey: 'researchRuntime',
                icon: Cpu,
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
    for locale in ("zh-CN.json", "en.json"):
        path = RS_ADMIN_FE / "app/messages" / locale
        msg = json.loads(path.read_text())
        msg.setdefault("Navigation", {})
        msg["Navigation"]["researchRuntime"] = (
            "运行时治理" if locale.startswith("zh") else "Research runtime"
        )
        msg.setdefault("ResearchRuntime", {})
        msg["ResearchRuntime"]["title"] = msg["Navigation"]["researchRuntime"]
        msg["ResearchRuntime"]["description"] = (
            "Research Admin Runtime/Agent 控制台（最小域壳）"
            if locale.startswith("zh")
            else "Research Admin Runtime/Agent control surface (minimal shell)"
        )
        path.write_text(json.dumps(msg, indent=2, ensure_ascii=False) + "\n")
    print("added research admin domain shell page")


def restore_web_agent_console() -> None:
    """Reattach archived agent-console onto the new Next Web base."""
    src = KEEP_WEB_FE / "components/agent/agent-console.tsx"
    if not src.exists():
        # archive may nest under app/
        alt = KEEP_WEB_FE / "app/components/agent/agent-console.tsx"
        src = alt if alt.exists() else src
    if not src.exists():
        print("WARN: agent-console archive missing; skip restore")
        return
    dst_dir = RS_WEB_FE / "app/components/agent"
    dst_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst_dir / "agent-console.tsx")
    # Prefer archived dashboard page if it wires AgentConsole; else patch template dashboard.
    archived_dash = KEEP_WEB_FE / "app/[locale]/(dashboard)/dashboard/page.tsx"
    if not archived_dash.exists():
        archived_dash = KEEP_WEB_FE / "[locale]/(dashboard)/dashboard/page.tsx"
    dash = RS_WEB_FE / "app/app/[locale]/(dashboard)/dashboard/page.tsx"
    if archived_dash.exists() and "AgentConsole" in archived_dash.read_text():
        dash.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(archived_dash, dash)
        print("restored dashboard page with AgentConsole")
    else:
        # Minimal mount if template dashboard exists
        if dash.exists() and "AgentConsole" not in dash.read_text():
            content = dash.read_text()
            if "export default" in content:
                content = (
                    "import { AgentConsole } from '@/components/agent/agent-console'\n"
                    + content
                )
                content = content.replace(
                    "return (",
                    "return (\n    <>\n      <AgentConsole />\n",
                    1,
                )
                # naive close - only if single return fragment; safer append section
                dash.write_text(content)
                print("patched dashboard to include AgentConsole (best-effort)")
    print("restored web agent-console")


def write_admin_dockerignore() -> None:
    path = RS_ADMIN_BE / ".dockerignore"
    path.write_text(
        "app/.venv\napp/.env\napp/.env.*\napp/tests\n"
        "db-access-bootstrap/.env.local.*\n**/__pycache__\n**/*.pyc\n**/*.pyo\n"
        "app/.pytest_cache\napp/.mypy_cache\n"
    )


def main() -> None:
    raise SystemExit(
        "retired unsafe one-shot stitch; use verify_p0_009e_convergence.py "
        "for freeze-tag clean-room replay"
    )
    if not CFG.exists():
        raise SystemExit("run apply_p0_009d_research_foundation.sh first")
    stitch_audit_context()
    stitch_config()
    stitch_celery()
    stitch_oidc_public_jwks()
    stitch_tasks_routes_identity()
    stitch_routes()
    rewrite_identity_in_tests()
    add_admin_domain_shell()
    restore_web_agent_console()
    write_admin_dockerignore()
    print("P0-009D stitch complete")


if __name__ == "__main__":
    main()
