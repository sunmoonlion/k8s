#!/usr/bin/env python3
"""Bounded actual ELK acceptance. No deployment, password printing or business deletion."""
import argparse
import base64
import contextlib
import http.client
import json
import os
import re
import random
import selectors
import socket
import ssl
import subprocess
import sys
import time
import uuid

def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)

@contextlib.contextmanager
def forward(kube, name, remote, env):
    proc = subprocess.Popen(kube + ['port-forward','--address=127.0.0.1','service/'+name,'0:'+str(remote)],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,env=env)
    try:
        port=None
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout,selectors.EVENT_READ)
            deadline=time.monotonic()+20
            while time.monotonic()<deadline and proc.poll() is None:
                if selector.select(0.5):
                    match=re.search(r'Forwarding from 127\.0\.0\.1:(\d+)',proc.stdout.readline())
                    if match:
                        port=int(match.group(1));break
        require(port is not None,name+' management tunnel unavailable')
        yield port
    finally:
        proc.terminate()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: proc.kill();proc.wait()

class TrustedTunnel(http.client.HTTPSConnection):
    def connect(self):
        raw=socket.create_connection(('127.0.0.1',self.port),timeout=self.timeout)
        self.sock=self._context.wrap_socket(raw,server_hostname=self.host)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('kubectl','kubeconfig','namespace','ca','version','writer','reader','ingest-user','index-prefix'):
        parser.add_argument('--'+key,required=True)
    for key in ('collector-namespace','application-namespace','collector-digest','data-view-id','collector-enabled'):
        parser.add_argument('--'+key)
    parser.add_argument("--components", default="all")
    args=parser.parse_args()
    chosen={"elasticsearch","elk-initialize","kibana","logstash","elk-collector","elk-data-view"} if args.components=="all" else set(args.components.split(","))
    require(bool(chosen) and chosen <= {"elasticsearch","elk-initialize","kibana","logstash","elk-collector","elk-data-view"},"Invalid ELK component scope")
    ingestion=bool(chosen & {"logstash","elk-collector"})
    browser=bool(chosen & {"kibana","elk-data-view"})
    secret=json.load(sys.stdin)
    env=dict(os.environ)
    for key in ('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'): env.pop(key,None)
    env['NO_PROXY']='*'
    kube=[args.kubectl,'--kubeconfig='+args.kubeconfig,'--context=kind-sunmoon-kind','--request-timeout=20s','-n',args.namespace]
    ctx=ssl.create_default_context(cafile=args.ca)
    require(ctx.check_hostname and ctx.verify_mode==ssl.CERT_REQUIRED,'TLS verification required')
    with contextlib.ExitStack() as stack:
        endpoints=[('elasticsearch',9200)]+([('logstash',8080)] if ingestion else [])+([('kibana',5601)] if browser else [])
        ports={name:stack.enter_context(forward(kube,name,port,env)) for name,port in endpoints}
        def request(service, method, path, auth=None, payload=None, expect=200):
            headers={'Content-Type':'application/json','kbn-xsrf':'sunmoon-acceptance'}
            if auth:
                headers['Authorization']='Basic '+base64.b64encode((auth[0]+':'+auth[1]).encode()).decode()
            deadline=time.monotonic()+180
            delay=1.0
            while True:
                client=TrustedTunnel(service+'.'+args.namespace+'.svc.cluster.local',ports[service],context=ctx,timeout=min(30,max(1,deadline-time.monotonic())))
                try:
                    client.request(method,path,body=None if payload is None else json.dumps(payload).encode(),headers=headers)
                    response=client.getresponse();body=response.read()
                    status=response.status
                finally: client.close()
                # Only an explicit 429 means retry; ambiguous timed-out writes are never replayed.
                if service=='logstash' and status==429 and time.monotonic()<deadline:
                    time.sleep(min(delay+random.uniform(0,0.5),max(0,deadline-time.monotonic())))
                    delay=min(10.0,delay*2)
                    continue
                require(status==expect,service+' '+method+' '+path.split('?')[0]+' status '+str(status))
                if not body: return {}
                try: return json.loads(body)
                except ValueError: return {}
        admin=('elastic',secret['elastic_password'])
        writer=(args.writer,secret['logstash_password'])
        reader=(args.reader,secret['reader_password'])
        request('elasticsearch','GET','/',expect=401)
        require(request('elasticsearch','GET','/',admin)['version']['number']==args.version,'Elasticsearch version differs from selected lock')
        health=request('elasticsearch','GET','/_cluster/health',admin)
        require(health['number_of_nodes']==1 and health['status'] in ('yellow','green'),'Single node search health not ready')
        if ingestion:
            request('logstash','POST','/',(args.ingest_user,'invalid-acceptance-password'),{'message':'rejected'},expect=401)
            nonce=uuid.uuid4().hex
            marker={'sunmoon_acceptance_id':nonce,'message':'中文日志链路验收','service':{'name':'sunmoon-platform-acceptance'}}
            own_doc=None
            try:
                request('logstash','POST','/',(args.ingest_user,secret['ingest_password']),marker)
                query={'query':{'term':{'sunmoon_acceptance_id.keyword':nonce}},'size':2}
                deadline=time.monotonic()+90
                while time.monotonic()<deadline:
                    search=request('elasticsearch','POST','/'+args.index_prefix+'-*/_search',admin,query)
                    hits=search['hits']['hits']
                    if hits:
                        require(len(hits)==1 and hits[0]['_source']['sunmoon_acceptance_id']==nonce,'Acceptance marker identity differs')
                        own_doc=hits[0];break
                    time.sleep(1)
                require(own_doc is not None,'Logstash event did not reach Elasticsearch')
                result=request('elasticsearch','POST','/'+args.index_prefix+'-*/_search',reader,query)
                require(len(result['hits']['hits'])==1,'Independent read identity could not retrieve the marker')
                request('elasticsearch','POST','/'+args.index_prefix+'-*/_search',writer,query,expect=403)
                request('elasticsearch','GET','/_security/user',writer,expect=403)
                request('elasticsearch','PUT','/foreign-acceptance/_doc/'+nonce,writer,marker,expect=403)
                request('elasticsearch','PUT','/'+own_doc['_index']+'/_doc/'+nonce,reader,marker,expect=403)
            finally:
                if own_doc:
                    require(own_doc['_index'].startswith(args.index_prefix+'-') and own_doc['_source']['sunmoon_acceptance_id']==nonce,'Refuse removing foreign data')
                    request('elasticsearch','DELETE','/'+own_doc['_index']+'/_doc/'+own_doc['_id']+'?refresh=true',admin)
        if browser:
            # Detailed status requires operator privileges; keep the runtime reader role unchanged.
            status=request('kibana','GET','/api/status',admin)
            require(status['status']['overall']['level']=='available','Kibana overall status is not available')
            require(status['version']['number']==args.version,'Kibana version differs from selected lock')
            request('kibana','GET','/api/saved_objects/_find?type=index-pattern&per_page=1',reader)
        collected={}
        if 'elk-collector' in chosen and str(args.collector_enabled).lower() == 'true':
            from collector.acceptance import verify_application_logs
            collected=verify_application_logs(request,kube,env,args,reader,require)
        print(json.dumps({'application_log_collection':collected,'passed':True,'version':args.version,'tls_chain_and_hostname':True,'unauthenticated_rejected':True,'selected_components':sorted(chosen),'logstash_to_elasticsearch':ingestion,'independent_log_read':ingestion,'writer_read_and_admin_denied':ingestion,'foreign_index_denied':ingestion,'reader_write_denied':ingestion,'kibana_authenticated_api':browser,'scope':'Actual internal ELK protocol, permissions and enabled node application logs/data view; public ingress, restart and disaster recovery require separate acceptance'}))

if __name__=='__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'passed':False,'error':str(error) if isinstance(error,RuntimeError) else type(error).__name__}))
        raise SystemExit(1)
