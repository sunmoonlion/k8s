#!/usr/bin/env python3
"""Bounded actual ELK acceptance. No deployment, password printing or business deletion."""
import argparse
import base64
import contextlib
import http.client
import json
import os
import re
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
    args=parser.parse_args()
    secret=json.load(sys.stdin)
    env=dict(os.environ)
    for key in ('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'): env.pop(key,None)
    env['NO_PROXY']='*'
    kube=[args.kubectl,'--kubeconfig='+args.kubeconfig,'--context=kind-sunmoon-kind','--request-timeout=20s','-n',args.namespace]
    ctx=ssl.create_default_context(cafile=args.ca)
    require(ctx.check_hostname and ctx.verify_mode==ssl.CERT_REQUIRED,'TLS verification required')
    with contextlib.ExitStack() as stack:
        ports={name:stack.enter_context(forward(kube,name,port,env)) for name,port in (('elasticsearch',9200),('logstash',8080),('kibana',5601))}
        def request(service, method, path, auth=None, payload=None, expect=200):
            client=TrustedTunnel(service+'.'+args.namespace+'.svc.cluster.local',ports[service],context=ctx,timeout=30)
            headers={'Content-Type':'application/json','kbn-xsrf':'sunmoon-acceptance'}
            if auth:
                headers['Authorization']='Basic '+base64.b64encode((auth[0]+':'+auth[1]).encode()).decode()
            try:
                client.request(method,path,body=None if payload is None else json.dumps(payload).encode(),headers=headers)
                response=client.getresponse();body=response.read()
                require(response.status==expect,service+' '+method+' '+path.split('?')[0]+' status '+str(response.status))
                if not body: return {}
                try: return json.loads(body)
                except ValueError: return {}
            finally: client.close()
        admin=('elastic',secret['elastic_password'])
        writer=(args.writer,secret['logstash_password'])
        reader=(args.reader,secret['reader_password'])
        request('elasticsearch','GET','/',expect=401)
        require(request('elasticsearch','GET','/',admin)['version']['number']==args.version,'Elasticsearch version differs from selected lock')
        health=request('elasticsearch','GET','/_cluster/health',admin)
        require(health['number_of_nodes']==1 and health['status'] in ('yellow','green'),'Single node search health not ready')
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
            # Detailed status requires operator privileges; keep the runtime reader role unchanged.
            status=request('kibana','GET','/api/status',admin)
            require(status['status']['overall']['level']=='available','Kibana overall status is not available')
            require(status['version']['number']==args.version,'Kibana version differs from selected lock')
            request('kibana','GET','/api/saved_objects/_find?type=index-pattern&per_page=1',reader)
        finally:
            if own_doc:
                require(own_doc['_index'].startswith(args.index_prefix+'-') and own_doc['_source']['sunmoon_acceptance_id']==nonce,'Refuse removing foreign data')
                request('elasticsearch','DELETE','/'+own_doc['_index']+'/_doc/'+own_doc['_id']+'?refresh=true',admin)
        print(json.dumps({'passed':True,'version':args.version,'tls_chain_and_hostname':True,'unauthenticated_rejected':True,'logstash_to_elasticsearch':True,'independent_log_read':True,'writer_read_and_admin_denied':True,'foreign_index_denied':True,'reader_write_denied':True,'kibana_authenticated_api':True,'scope':'Actual internal ELK protocol and permissions; not all application logs, public ingress, restart or disaster recovery'}))

if __name__=='__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'passed':False,'error':str(error) if isinstance(error,RuntimeError) else type(error).__name__}))
        raise SystemExit(1)
