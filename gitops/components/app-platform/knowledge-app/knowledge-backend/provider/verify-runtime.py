"""Actual Knowledge service/worker integration, distinct from cross-App HTTP authentication."""
import asyncio,hashlib,json,logging,sys,time,uuid
from datetime import UTC,datetime,timedelta
from sqlalchemy import select,text,delete
from botocore.exceptions import ClientError
import boto3
from core.config import get_settings
from app.infrastructure.storage.postgres import get_postgres
from app.infrastructure.external.artifact_content import resolve_artifact_content
from app.infrastructure.external.ragflow import check_ragflow_config
from app.application.ports.knowledge_provider import ArtifactError
from app.application.dto.knowledge import KnowledgeIngestionCreate
from app.application.dto.retrieval import KnowledgeRetrievalRequest
from app.application.services.knowledge_ingestion_service import submit_ingestion,TERMINAL_STATUSES
from app.application.services.knowledge_retrieval_service import retrieve_knowledge
from app.application.services.provider_delivery import upload_identity
from app.infrastructure.models.knowledge import KnowledgeIngestionJob,KnowledgeDocument,KnowledgeDocumentVersion,KnowledgeProviderOperation
from app.application.errors.exceptions import ForbiddenError
from app.domain.security import Principal
logging.basicConfig(level=logging.CRITICAL)
logging.getLogger().setLevel(logging.CRITICAL)
inputs=json.load(sys.stdin);checks={};stage='configure';job_id=None;provider_id=None;identity=None
async def run():
    global stage,job_id,provider_id,identity
    settings=get_settings();assert settings.ragflow_enabled
    assert settings.s3_access_key_id=='knowledge_source_reader'
    config=await check_ragflow_config(settings)
    assert config.enabled and config.reachable and config.has_default_embedding
    checks['actual_backend_provider_ready']=True
    source=inputs['artifact'];ref={key:value for key,value in source.items() if key not in ('key','bucket')}
    stage='immutable_source'
    artifact=await resolve_artifact_content(settings=settings,source_artifact_refs=[ref],title=None,canonical_url=None,metadata_json={},source_document_version_id=inputs['version_id'])
    assert hashlib.sha256(artifact.content).hexdigest()==ref['sha256'] and '潮汐' in artifact.content.decode()
    checks['original_version_and_digest_verified']=True
    try:
        await resolve_artifact_content(settings=settings,source_artifact_refs=[ref | {'sha256':'0'*64}],title=None,canonical_url=None,metadata_json={},source_document_version_id=inputs['version_id'])
    except ArtifactError:checks['wrong_original_hash_denied']=True
    else:raise AssertionError('Wrong source digest accepted')
    reader=boto3.client('s3',endpoint_url=settings.s3_endpoint,region_name=settings.s3_region,aws_access_key_id=settings.s3_access_key_id,aws_secret_access_key=settings.s3_secret_access_key,verify='/etc/sunmoon/provider/ca.crt')
    try:
        for name,method,args in [('original_write_denied',reader.put_object,{'Bucket':source['bucket'],'Key':source['key'],'Body':b'forbidden'}),('original_list_denied',reader.list_objects_v2,{'Bucket':source['bucket'],'Prefix':'info/original/','MaxKeys':1}),('foreign_bucket_denied',reader.get_object,{'Bucket':'ragflow-derived','Key':'forbidden'}),('bucket_management_denied',reader.get_bucket_versioning,{'Bucket':source['bucket']})]:
            try:method(**args)
            except ClientError as error:assert error.response['Error']['Code']=='AccessDenied';checks[name]=True
            else:raise AssertionError('Source reader exceeded its boundary')
    finally:reader.close()
    now=datetime.now(UTC)
    principal=Principal(actor_type='service',subject='operator-component-acceptance',issuer='urn:sunmoon:component-acceptance',app='knowledge',surface='internal',audience='component-acceptance',scopes=frozenset({'knowledge:retrieve'}),authenticated_at=now,expires_at=now+timedelta(minutes=15),policy_version='component-acceptance-v1')
    payload=KnowledgeIngestionCreate(contract_version=1,operation='upsert',distribution_id=uuid.UUID(inputs['distribution_id']),source_app='info-app',source_document_id=uuid.UUID(inputs['document_id']),source_document_version_id=uuid.UUID(inputs['version_id']),artifact=ref,dataset_key='default',idempotency_key='sunmoon-provider-acceptance:'+inputs['version_id'],correlation_id=uuid.UUID(inputs['correlation_id']),document={'title':'中文潮汐知识部署验收','canonical_url':'https://info.sunmoonai.com:30443/acceptance/'+inputs['document_id'],'content_hash':ref['sha256'],'metadata':{}})
    pg=get_postgres();await pg.init();stage='submit_durable_ingestion'
    try:
        async with pg.session_factory() as session:
            job=await submit_ingestion(session,payload)
            job_id=str(job.id);identity=str(upload_identity(job))
            duplicate=await submit_ingestion(session,payload);assert str(duplicate.id)==job_id
            try:await submit_ingestion(session,payload.model_copy(update={'document':payload.document.model_copy(update={'title':'different intent'})}))
            except ValueError:await session.rollback();checks['conflicting_idempotency_denied']=True
            else:raise AssertionError('Conflicting ingestion intent accepted')
            checks['same_intent_same_job']=True
        stage='wait_real_worker';end=time.monotonic()+inputs['timeout_seconds']
        while time.monotonic()<end:
            async with pg.session_factory() as session:
                job=await session.get(KnowledgeIngestionJob,uuid.UUID(job_id))
                if job.status in TERMINAL_STATUSES:
                    assert job.status=='succeeded', 'Durable ingestion terminated unsuccessfully'
                    provider_id=job.ragflow_document_id
                    assert provider_id and job.knowledge_document_id
                    checks['actual_scheduler_outbox_worker_parse_completed']=True
                    break
            await asyncio.sleep(3)
        else:raise RuntimeError('Business ingestion deadline exceeded')
        stage='domain_retrieve'
        request=KnowledgeRetrievalRequest(contract_version=1,request_id=uuid.uuid4(),query='月球的引力会引起海洋什么现象？',dataset_keys=['default'],filters={'source_document_version_ids':[inputs['version_id']]},top_k=5,token_budget=2048,security_context={'tenant_id':settings.retrieval_default_tenant_id,'actor_id':str(uuid.uuid4()),'actor_type':'service','policy_version':'component-acceptance-v1'})
        async with pg.session_factory() as session:
            response=await retrieve_knowledge(session,request,service_principal=principal)
            assert response.evidence and any('潮汐' in row.content for row in response.evidence)
            assert all(str(row.source_document_version_id)==inputs['version_id'] and str(row.source_document_id)==inputs['document_id'] and row.content_hash==ref['sha256'] for row in response.evidence)
            checks['chinese_domain_evidence_and_original_citation']=True
            for label,bad,badprincipal in [('foreign_tenant_denied',request.model_copy(update={'security_context':request.security_context.model_copy(update={'tenant_id':'forbidden-tenant'})}),principal),('foreign_dataset_denied',request.model_copy(update={'dataset_keys':['forbidden']}),principal),('missing_relation_scope_denied',request,principal.model_copy(update={'scopes':frozenset()}))]:
                try:await retrieve_knowledge(session,bad,service_principal=badprincipal)
                except ForbiddenError:checks[label]=True
                else:raise AssertionError('Unauthorized domain retrieval accepted')
            empty=request.model_copy(update={'filters':request.filters.model_copy(update={'source_document_version_ids':[uuid.uuid4()]})})
            assert not (await retrieve_knowledge(session,empty,service_principal=principal)).evidence
            checks['unrelated_version_excluded']=True
        print(json.dumps({'passed':True,'checks':checks,'job_id':job_id,'upload_identity':identity,'provider_document_id':provider_id,'scope':'Real application service, scheduler/outbox/worker and domain retrieval; cross-App HTTP identity is not exercised'}))
    finally:await pg.shutdown()
try:asyncio.run(run())
except Exception as error:
    print(json.dumps({'passed':False,'stage':stage,'error_class':type(error).__name__,'job_id':job_id,'upload_identity':identity,'provider_document_id':provider_id,'checks':checks}))
    sys.exit(1)
