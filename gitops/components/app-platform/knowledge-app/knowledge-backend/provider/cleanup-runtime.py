"""Remove only the completed synthetic ingestion owned by the supplied exact identities."""
import asyncio,json,sys,uuid,logging
from sqlalchemy import text,select,delete
from app.infrastructure.storage.postgres import get_postgres
from app.infrastructure.models.knowledge import KnowledgeIngestionJob,KnowledgeDocumentVersion,KnowledgeDocument,KnowledgeProviderOperation
from app.application.services.provider_delivery import upload_identity
logging.basicConfig(level=logging.CRITICAL)
inputs=json.load(sys.stdin)
async def run():
    pg=get_postgres();await pg.init()
    try:
        async with pg.session_factory() as s:
            job=await s.get(KnowledgeIngestionJob,uuid.UUID(inputs['job_id']))
            assert job is not None and job.status=='succeeded' and job.source_document_id==uuid.UUID(inputs['document_id']) and job.source_document_version_id==uuid.UUID(inputs['version_id'])
            assert job.idempotency_key=='sunmoon-provider-acceptance:'+inputs['version_id']
            identity=str(upload_identity(job));assert identity==inputs['upload_identity']
            keys={'resource':'knowledge.ingest.v1:'+identity,'job':inputs['job_id']}
            messages=(await s.execute(text("SELECT id FROM outbox_message WHERE topic='knowledge.ingest.v1' AND payload->>'ingestion_id'=:job"),keys)).scalars().all()
            assert not (await s.execute(text('SELECT 1 FROM outbox_execution WHERE resource_key=:resource AND expires_at>clock_timestamp()'),keys)).first()
            for message in messages:
                await s.execute(text('DELETE FROM inbox_message WHERE message_id=:id'),{'id':message})
                await s.execute(text('DELETE FROM outbox_dead_letter WHERE message_id=:id'),{'id':message})
                await s.execute(text('DELETE FROM outbox_execution WHERE message_id=:id'),{'id':message})
                await s.execute(text('DELETE FROM outbox_message WHERE id=:id'),{'id':message})
            await s.execute(delete(KnowledgeProviderOperation).where((KnowledgeProviderOperation.operation_key=='upload:'+identity)|(KnowledgeProviderOperation.operation_key.startswith('parse:'+identity+':'+inputs['job_id']+':'))))
            await s.execute(delete(KnowledgeDocumentVersion).where(KnowledgeDocumentVersion.ingestion_id==job.id))
            document_ids=(await s.execute(select(KnowledgeDocument.id).where(KnowledgeDocument.source_document_id==job.source_document_id))).scalars().all()
            assert len(document_ids)==1
            assert not (await s.execute(select(KnowledgeDocumentVersion.id).where(KnowledgeDocumentVersion.knowledge_document_id==document_ids[0]))).first()
            await s.execute(delete(KnowledgeDocument).where(KnowledgeDocument.id==document_ids[0]))
            await s.delete(job);await s.commit()
            assert await s.get(KnowledgeIngestionJob,uuid.UUID(inputs['job_id'])) is None
        print(json.dumps({'temporary_domain_records_removed':True,'outbox_messages_removed':len(messages)}))
    finally:await pg.shutdown()
try:asyncio.run(run())
except Exception as error:
    print(json.dumps({'passed':False,'error_class':type(error).__name__}));sys.exit(1)
