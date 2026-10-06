"""Native Knowledge integration acceptance. Secrets are read from stdin, never argv."""
import argparse,json,os,re,selectors,shutil,subprocess,sys,tempfile,time,uuid
from pathlib import Path
ap=argparse.ArgumentParser()
for key in ('kubectl','kubeconfig','app-namespace','data-namespace','mc','ca'):ap.add_argument('--'+key,required=True)
ap.add_argument('--http-service-identities',action='store_true')
args=ap.parse_args();secret=json.load(sys.stdin);root=Path(__file__).resolve().parent
kube=[args.kubectl,'--kubeconfig='+args.kubeconfig,'--context=kind-sunmoon-kind','--request-timeout=30s']
env=dict(os.environ)
for key in ['HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy']:env.pop(key,None)
env['NO_PROXY']='*'
records={key:str(uuid.uuid4()) for key in ('document_id','version_id','distribution_id','correlation_id')}
records['timeout_seconds']=360
# Persist only probe identities, never bearer tokens or cleanup credentials.
private_root=Path(secret['binding_path']).parent
assert private_root.is_dir() and not private_root.is_symlink() and private_root.stat().st_uid==0 and private_root.stat().st_mode & 0o777==0o700
journal=private_root/('acceptance-'+records['correlation_id']+'.json')
def save_probe():
    temporary=journal.with_suffix('.tmp')
    descriptor=os.open(temporary,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(descriptor,'w') as handle:
        json.dump(records,handle);handle.flush();os.fsync(handle.fileno())
    os.replace(temporary,journal)
save_probe()

def execute(app,code,data=None,timeout=450):
    out=subprocess.run(kube+['exec','-i','deployment/'+app,'-n',args.app_namespace,'--','python','-c',code],input=json.dumps(data or records),capture_output=True,text=True,env=env,timeout=timeout)
    try:result=json.loads(out.stdout.strip().splitlines()[-1])
    except Exception:
        errors=re.findall(r'(?m)^([A-Za-z]+Error):',out.stderr)
        raise RuntimeError('Invalid '+app+' verifier response; rc='+str(out.returncode)+'; error_class='+(errors[-1] if errors else 'unavailable')) from None
    if out.returncode or result.get('passed') is False:
        if app=='knowledge-api':
            for key in ('job_id','upload_identity','provider_document_id'):
                if result.get(key):records[key]=result[key]
        save_probe()
        raise RuntimeError(json.dumps(result))
    return result

source_code=r"""
import hashlib,json,sys
from app.infrastructure.storage.object_storage import ObjectStorage
x=json.load(sys.stdin);store=ObjectStorage();assert store.bucket=='info-originals'
key='info/original/sunmoon-acceptance/'+x['version_id']+'/chinese.txt'
content=('月球引力与海洋潮汐\n月球的引力是引起海洋潮汐的重要原因。太阳的引力也会影响潮汐，海水周期性的涨落被称为潮汐。').encode()
record=store.put_bytes(object_key=key,data=content,content_type='text/plain')
print(json.dumps({'artifact_type':'text_plain','uri':'s3://'+record.bucket+'/'+key,'storage_version':record.version_id,'sha256':record.sha256,'size_bytes':record.size_bytes,'content_type':record.content_type,'bucket':record.bucket,'key':key}))
"""
cleanup_provider_code="""
import json,sys,requests,re
from pathlib import Path
from ruamel.yaml import YAML
import boto3,psycopg2
x=json.load(sys.stdin);assert re.fullmatch('[a-f0-9]{32}',x['dataset_id']) and re.fullmatch('[a-f0-9]{32}',x['provider_document_id'])
cfg=YAML(typ='safe').load(Path('/ragflow/conf/service_conf.yaml').read_text())
pg=cfg['postgres'].copy();pg['dbname']=pg.pop('name');pg.pop('max_connections',None);pg.pop('stale_timeout',None)
with psycopg2.connect(**pg) as db:
 with db.cursor() as c:
  c.execute('SELECT name,location FROM document WHERE id=%s AND kb_id=%s',(x['provider_document_id'],x['dataset_id']));row=c.fetchone()
assert row and row[0]==x['filename'] and row[1]==x['filename']
client=requests.Session();client.trust_env=False;client.verify='/run/tls/ca.crt'
response=client.delete(x['base']+'/api/v1/datasets/'+x['dataset_id']+'/documents',json={'ids':[x['provider_document_id']]},headers={'Authorization':'Bearer '+x['token']},timeout=30)
response.raise_for_status();assert response.json().get('code')==0
with psycopg2.connect(**pg) as db:
 with db.cursor() as c:
  c.execute('SELECT count(*) FROM document WHERE id=%s',(x['provider_document_id'],));assert c.fetchone()[0]==0
storage=cfg['s3'];s3=boto3.client('s3',endpoint_url=storage['endpoint_url'],aws_access_key_id=storage['access_key'],aws_secret_access_key=storage['secret_key'],region_name=storage['region'],verify='/run/tls/ca.crt')
key=storage['prefix_path'].rstrip('/')+'/'+x['dataset_id']+'/'+x['filename']
for number,page in enumerate(s3.get_paginator('list_object_versions').paginate(Bucket=storage['bucket'],Prefix=key)):
 assert number<10
 objects=[{'Key':v['Key'],'VersionId':v['VersionId']} for v in page.get('Versions',[])+page.get('DeleteMarkers',[]) if v['Key']==key]
 if objects:assert not s3.delete_objects(Bucket=storage['bucket'],Delete={'Objects':objects,'Quiet':True}).get('Errors')
remaining=s3.list_object_versions(Bucket=storage['bucket'],Prefix=key)
assert not [v for v in remaining.get('Versions',[])+remaining.get('DeleteMarkers',[]) if v['Key']==key]
print(json.dumps({'temporary_provider_document_and_versions_removed':True}))
"""
tunnel=None;source=None;result=None
try:
    source=execute('info-api',source_code,records,90);records['artifact']=source;save_probe()
    if args.http_service_identities:
        records.update(execute('info-api',(root/'verify-info-http.py').read_text(),records,90));save_probe()
    result=execute('knowledge-api',(root/'verify-runtime.py').read_text(),records)
    records.update(result);save_probe()
    if args.http_service_identities:
        # fable 的 investment 后端没有 HTTP 检索端口（知识检索改走沙箱里的 MCP），原来的 verify-investment-http.py 已删；检索绑定的撤销见账 21
        result['scope']='Actual Info HTTPS ingestion with Casdoor token, real Scheduler/Outbox/Worker'
    # Clean derived content using the provider's own DML/S3 identity, not an App administrator.
    binding=json.loads(Path(secret['binding_path']).read_text())
    cleanup={**records,'dataset_id':binding['dataset_id'],'filename':'knowledge-'+uuid.UUID(result['upload_identity']).hex+'-'+source['sha256']+'.txt','base':'https://ragflow.'+args.data_namespace+'.svc.cluster.local:9380','token':secret['ragflow']['knowledge_token']}
    out=subprocess.run(kube+['exec','-i','deployment/ragflow-api','-n',args.data_namespace,'--','python','-c',cleanup_provider_code],input=json.dumps(cleanup),capture_output=True,text=True,env=env,timeout=90)
    assert out.returncode==0, 'Exact temporary provider cleanup failed'
    result['cleanup']=json.loads(out.stdout.strip().splitlines()[-1])
    result['cleanup'].update(execute('knowledge-api',(root/'cleanup-runtime.py').read_text(),records,90));records['cleanup']=result['cleanup'];save_probe()
finally:
    # Keep the original and journal if an accepted job has not been cleaned safely.
    if source and result and result.get('cleanup',{}).get('temporary_domain_records_removed'):
        host='object-storage.'+args.data_namespace+'.svc.cluster.local'
        tunnel=subprocess.Popen(kube+['-n',args.data_namespace,'port-forward','--address=127.0.0.1','service/object-storage','0:9000'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,env=env)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(tunnel.stdout,selectors.EVENT_READ);port=None;end=time.monotonic()+20
                while time.monotonic()<end and tunnel.poll() is None:
                    if selector.select(timeout=0.5):
                        match=re.search(r'Forwarding from 127\.0\.0\.1:(\d+)',tunnel.stdout.readline())
                        if match:port=int(match.group(1));break
            assert port and source['key']=='info/original/sunmoon-acceptance/'+records['version_id']+'/chinese.txt' and source['bucket']=='info-originals'
            with tempfile.TemporaryDirectory(prefix='sunmoon-knowledge-check-') as folder:
                path=Path(folder);ca=path/'certs/CAs';ca.mkdir(parents=True,mode=0o700);shutil.copyfile(args.ca,ca/'platform.crt')
                cfg={'version':'10','aliases':{'owned':{'url':'https://'+host+':'+str(port),'accessKey':secret['storage']['root_user'],'secretKey':secret['storage']['root_password'],'api':'S3v4','path':'on'}}}
                (path/'config.json').write_text(json.dumps(cfg));(path/'config.json').chmod(0o600)
                out=subprocess.run([args.mc,'--config-dir',folder,'--resolve',host+':'+str(port)+'=127.0.0.1','--json','rm','--version-id',source['storage_version'],'owned/info-originals/'+source['key']],capture_output=True,text=True,env=env,timeout=45)
                assert out.returncode==0 and all(json.loads(line).get('status')!='error' for line in out.stdout.splitlines()), 'Exact temporary original cleanup failed'
            result.setdefault('cleanup',{})['temporary_original_version_removed']=True
            journal.unlink();result['cleanup']['temporary_probe_journal_removed']=True
        finally:
            tunnel.terminate()
            try:tunnel.wait(timeout=5)
            except subprocess.TimeoutExpired:tunnel.kill();tunnel.wait()
print(json.dumps(result))
