"""Bounded initialization Job for exactly the pinned RAGFlow version."""
import hashlib
import inspect
import json
import sys
from pathlib import Path

sys.path.insert(0, '/sunmoon')
from runtime import initialize_logging
initialize_logging()
from common import settings
settings.init_settings()
from api.db import db_models as models
from api.db.init_data import init_web_data, init_superuser
from api.db.services.user_service import UserService
from api.db.services.tenant_model_provider_service import TenantModelProviderService as Providers
from api.db.services.tenant_model_instance_service import TenantModelInstanceService as Instances
from api.db.services.tenant_model_service import TenantModelService as Models
inputs = json.loads(Path('/run/bootstrap/input.json').read_text())
models.init_database_tables()
init_web_data()
tables = [obj for _, obj in inspect.getmembers(models, inspect.isclass)
          if obj != models.DataBaseModel and issubclass(obj, models.DataBaseModel)]
assert tables and all(obj.table_exists() for obj in tables)

def identifier(value):
    return hashlib.sha256(value.encode()).hexdigest()[:32]

for purpose in ['knowledge', 'acceptance']:
    email = purpose + '-ragflow@sunmoonai.local'
    init_superuser(nickname='sunmoon-' + purpose, email=email, password=inputs[purpose + '_password'])
    users = UserService.query(email=email)
    assert len(users) == 1
    user = users[0]
    # Service identities do not gain the global administrator privilege.
    models.User.update(is_superuser=False).where(models.User.id == user.id).execute()
    provider_id = identifier('sunmoon/' + user.id + '/HuggingFace')
    instance_id = identifier('sunmoon/' + user.id + '/cpu')
    model_id = identifier('sunmoon/' + user.id + '/embedding')
    if not Providers.query(id=provider_id):
        Providers.insert(id=provider_id, provider_name='HuggingFace', tenant_id=user.id)
    if not Instances.query(id=instance_id):
        Instances.insert(id=instance_id, provider_id=provider_id, instance_name='sunmoon-cpu',
                         api_key='local-no-key', extra=json.dumps({'base_url': inputs['embedding_url']}))
    if not Models.query(id=model_id):
        Models.insert(id=model_id, model_name=inputs['embedding_model'], provider_id=provider_id,
                      instance_id=instance_id, model_type=2, extra=json.dumps({'max_tokens': 8192}))
    models.Tenant.update(embd_id=inputs['embedding_model'] + '@sunmoon-cpu@HuggingFace',
                         tenant_embd_id=model_id).where(models.Tenant.id == user.id).execute()
    token = inputs[purpose + '_token']
    existing = list(models.APIToken.select().where(models.APIToken.token == token))
    assert not existing or (len(existing) == 1 and existing[0].tenant_id == user.id)
    if not existing:
        models.APIToken.create(tenant_id=user.id, token=token, source='none')

with models.DB.connection_context():
    models.DB.execute_sql('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ragflow_runtime')
    models.DB.execute_sql('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ragflow_runtime')
print(json.dumps({'schema_initialized': True, 'service_tenants': 2, 'embedding_provider': 'HuggingFace', 'runtime_ddl': False}))
