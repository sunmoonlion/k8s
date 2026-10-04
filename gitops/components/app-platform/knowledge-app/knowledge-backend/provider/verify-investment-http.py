"""Verify the real Investment domain port through HTTPS and exact retrieval identity."""
import asyncio,json,logging,sys,uuid
import httpx
from core.config import get_settings
from app.domain.agent.knowledge import KnowledgeQuery
from app.infrastructure.external.knowledge_retrieval import get_knowledge_retrieval_client,KnowledgeRetrievalAuthorizationError
logging.basicConfig(level=logging.CRITICAL)
x=json.load(sys.stdin)
async def run():
    settings=get_settings();client=get_knowledge_retrieval_client();checks={}
    query=KnowledgeQuery(request_id=uuid.uuid4(),query='月球的引力会引起海洋什么现象？',dataset_keys=['default'],filters={'source_document_version_ids':[x['version_id']]},top_k=5,token_budget=2048,security_context={'tenant_id':'sunmoonai','actor_id':uuid.uuid4(),'actor_type':'service','policy_version':'service-acceptance-v1'})
    result=await client.retrieve(query)
    assert result.evidence and any('潮汐' in v.content for v in result.evidence)
    assert all(str(v.source_document_version_id)==x['version_id'] and str(v.source_document_id)==x['document_id'] and v.content_hash==x['artifact']['sha256'] for v in result.evidence)
    checks['actual_investment_domain_port_https_chinese_citations']=True
    for label,bad in [('foreign_tenant_http_denied',query.model_copy(update={'security_context':query.security_context.model_copy(update={'tenant_id':'forbidden-tenant'})})),('foreign_dataset_http_denied',query.model_copy(update={'dataset_keys':['forbidden']}))]:
        try:await client.retrieve(bad)
        except KnowledgeRetrievalAuthorizationError:checks[label]=True
        else:raise AssertionError(label)
    empty=query.model_copy(update={'filters':query.filters.model_copy(update={'source_document_version_ids':[uuid.uuid4()]})})
    assert not (await client.retrieve(empty)).evidence
    checks['unrelated_http_version_excluded']=True
    token=await client._token_provider.get_token()
    async with httpx.AsyncClient(timeout=25,follow_redirects=False) as http:
        denied=await http.post(settings.knowledge_retrieval_url.replace('/retrievals','/ingestions'),json={},headers={'Authorization':'Bearer '+token})
        assert denied.status_code==401,('retrieve_identity_ingest_denied',denied.status_code)
        checks['retrieve_identity_ingest_denied']=True
        browser=await http.get(settings.knowledge_retrieval_url.split('/api/internal/')[0]+'/api/knowledge/ingestions',headers={'Authorization':'Bearer '+token,'Host':'knowledge.sunmoonai.com:30443'})
        assert browser.status_code in (401,403),('service_identity_browser_denied',browser.status_code)
        checks['service_identity_browser_denied']=True
    print(json.dumps({'http_checks':checks}))
try:asyncio.run(run())
except Exception as error:
    print(json.dumps({'passed':False,'error_class':type(error).__name__}));sys.exit(1)
