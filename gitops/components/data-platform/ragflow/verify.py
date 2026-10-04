"""Live RAGFlow ingestion/retrieval acceptance; credentials travel over stdin only."""
import argparse,json,subprocess,sys,re

POD_SOURCE = r"""
import json,sys,time,uuid,requests
from ruamel.yaml import YAML
from pathlib import Path
import boto3,psycopg2
from botocore.config import Config
from botocore.exceptions import ClientError
inputs=json.load(sys.stdin)
config=YAML(typ='safe').load(Path('/ragflow/conf/service_conf.yaml').read_text())
base=inputs['base'].rstrip('/')+'/api/v1'
client=requests.Session();client.trust_env=False;client.verify='/run/tls/ca.crt'
client.headers['Authorization']='Bearer '+inputs['acceptance_token']

def call(method,path,**kwargs):
    response=client.request(method,base+path,timeout=35,**kwargs)
    if not response.ok:raise RuntimeError('RAGFlow HTTP '+str(response.status_code)+' '+method+' '+path)
    data=response.json()
    if data.get('code',0)!=0:raise RuntimeError('RAGFlow rejected '+method+' '+path+' (code '+str(data.get('code'))+')')
    return data.get('data')

# An error token must be rejected even if upstream wraps errors with HTTP200.
unauthorized=client.get(base+'/datasets',headers={'Authorization':'Bearer deliberately-wrong'},timeout=10)
assert unauthorized.status_code in (401,403) or unauthorized.json().get('code') not in (None,0)
pg=config['postgres'].copy();pg['dbname']=pg.pop('name');pg.pop('max_connections',None);pg.pop('stale_timeout',None)
pg['connect_timeout']=10
with psycopg2.connect(**pg) as db:
    with db.cursor() as cursor:
        cursor.execute("SELECT has_schema_privilege(current_user,'public','CREATE'),has_database_privilege(current_user,current_database(),'CREATE'),(SELECT rolsuper OR rolcreaterole OR rolcreatedb FROM pg_roles WHERE rolname=current_user)")
        assert cursor.fetchone()==(False,False,False)
        cursor.execute('SAVEPOINT deny_ddl')
        try:cursor.execute('CREATE TABLE public.sunmoon_forbidden_ddl(value text)')
        except psycopg2.errors.InsufficientPrivilege:cursor.execute('ROLLBACK TO SAVEPOINT deny_ddl')
        else:raise AssertionError('Runtime DDL was permitted')
        cursor.execute('RELEASE SAVEPOINT deny_ddl')

s3cfg=config['s3'];s3=boto3.client('s3',endpoint_url=s3cfg['endpoint_url'],region_name='us-east-1',aws_access_key_id=s3cfg['access_key'],aws_secret_access_key=s3cfg['secret_key'],verify='/run/tls/ca.crt',config=Config(signature_version='s3v4',s3={'addressing_style':'path'}))
s3.head_bucket(Bucket=s3cfg['bucket'])
for operation,args in [(s3.head_bucket,{'Bucket':'info-originals'}),(s3.get_bucket_versioning,{'Bucket':s3cfg['bucket']})]:
    try:operation(**args)
    except ClientError as error:assert error.response['ResponseMetadata']['HTTPStatusCode']==403
    else:raise AssertionError('RAGFlow S3 identity exceeded its boundary')

dataset_id=None
try:
    dataset=call('POST','/datasets',json={'name':'sunmoon-acceptance-'+uuid.uuid4().hex,'language':'Chinese','chunk_method':'naive','permission':'me','parser_config':{'chunk_token_num':128,'layout_recognize':'Plain Text','auto_keywords':0,'auto_questions':0,'raptor':{'use_raptor':False},'graphrag':{'use_graphrag':False}}})
    dataset_id=dataset['id']
    foreign=client.get(base+'/datasets',params={'id':dataset_id},headers={'Authorization':'Bearer '+inputs['knowledge_token']},timeout=10)
    foreign.raise_for_status();foreign_data=foreign.json();assert foreign_data.get('code',0)!=0 or not foreign_data.get('data')
    text='月球引力与海洋潮汐\n月球的引力是引起海洋潮汐的重要原因。太阳的引力也会影响潮汐，海水周期性的涨落被称为潮汐。\n\n数据库事务与数据一致性\n数据库事务能够在发生错误时回滚未提交的修改。PostgreSQL支持事务提交和回滚。'
    docs=call('POST','/datasets/'+dataset_id+'/documents',files={'file':('sunmoon-live-chinese.txt',text.encode('utf-8'),'text/plain')})
    assert len(docs)==1;doc_id=docs[0]['id']
    call('POST','/datasets/'+dataset_id+'/documents/parse',json={'document_ids':[doc_id]})
    end=time.monotonic()+inputs['timeout_seconds'];observed=None
    while time.monotonic()<end:
        state=call('GET','/datasets/'+dataset_id+'/documents',params={'id':doc_id})
        rows=state['docs'];assert len(rows)==1;observed=rows[0]
        if str(observed.get('run')).upper() in ('4','FAIL') or float(observed.get('progress',0))<0:raise RuntimeError('RAGFlow document parsing failed')
        if str(observed.get('run')).upper() in ('3','DONE') and float(observed.get('progress',0))>=1:break
        time.sleep(3)
    else:raise RuntimeError('RAGFlow ingestion timed out')
    retrieval=call('POST','/retrieval',json={'question':'月球的引力会引起海洋的什么现象？','dataset_ids':[dataset_id],'top_k':5,'similarity_threshold':0.1,'vector_similarity_weight':0.7})
    chunks=retrieval['chunks'];assert chunks and any('潮汐' in row.get('content','') for row in chunks)
    assert all(row.get('document_id')==doc_id for row in chunks)
    foreign_retrieval=client.post(base+'/retrieval',json={'question':'月球引力','dataset_ids':[dataset_id]},headers={'Authorization':'Bearer '+inputs['knowledge_token']},timeout=30)
    assert foreign_retrieval.status_code in (401,403) or foreign_retrieval.json().get('code') not in (None,0)
    result={'passed':True,'chinese_upload_parse_retrieve':True,'worker_ingestion_completed':True,'runtime_ddl_denied':True,'invalid_token_denied':True,'cross_tenant_denied':True,'s3_originals_and_management_denied':True,'retrieved_chunks':len(chunks),'scope':'RAGFlow derived retrieval protocol; business domain integration and restart/rebuild not claimed'}
finally:
    if dataset_id:
        call('DELETE','/datasets',json={'ids':[dataset_id]})
        assert not call('GET','/datasets',params={'id':dataset_id})
print(json.dumps(result))
"""

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--kubectl',required=True);parser.add_argument('--kubeconfig',required=True);parser.add_argument('--namespace',required=True);parser.add_argument('--base',required=True);parser.add_argument('--timeout',type=int,default=300);args=parser.parse_args()
    private=json.load(sys.stdin)
    data={'base':args.base,'timeout_seconds':args.timeout,'acceptance_token':private['acceptance_token'],'knowledge_token':private['knowledge_token']}
    command=[args.kubectl,'--kubeconfig='+args.kubeconfig,'--context=kind-sunmoon-kind','--request-timeout=30s','-n',args.namespace,'exec','-i','deployment/ragflow-api','-c','api','--','/ragflow/.venv/bin/python3','-c',POD_SOURCE]
    proc=subprocess.run(command,input=json.dumps(data),text=True,capture_output=True,timeout=args.timeout+180)
    if proc.returncode:
        # Never print arbitrary upstream tracebacks or request configuration.
        lines=re.findall(r'File "<string>", line ([0-9]+)',proc.stderr)
        exceptions=re.findall(r'^([A-Za-z_][A-Za-z0-9_.]*):[ \t]*(.*)$',proc.stderr,re.MULTILINE)
        kind,detail=exceptions[-1] if exceptions else ('UpstreamError','')
        if not re.fullmatch(r'RAGFlow (?:rejected [A-Z]+ /[a-zA-Z0-9/_-]+ \(code [0-9]+\)|HTTP [0-9]{3} [A-Z]+ /[a-zA-Z0-9/_-]+|document parsing failed|ingestion timed out)',detail):detail=''
        print(json.dumps({'passed':False,'reason':'RAGFlow live protocol acceptance failed','process_exit':proc.returncode,'exception_type':kind,'failed_source_line':int(lines[-1]) if lines else None,'public_detail':detail}));return 1
    receipt=json.loads(proc.stdout);assert receipt['passed'];print(json.dumps(receipt));return 0
if __name__=='__main__':sys.exit(main())
