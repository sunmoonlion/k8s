#!/usr/bin/env python3
"""Actual graph transaction and verified TLS acceptance; never deploys components."""
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
import struct
import subprocess
import sys
import time
import uuid

def require(condition, reason):
    if not condition: raise RuntimeError(reason)

@contextlib.contextmanager
def forward(kube, remote, env):
    proc=subprocess.Popen(kube+['port-forward','--address=127.0.0.1','service/neo4j','0:'+str(remote)],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,env=env)
    try:
        port=None
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout,selectors.EVENT_READ)
            deadline=time.monotonic()+20
            while time.monotonic()<deadline and proc.poll() is None:
                if selector.select(0.5):
                    match=re.search(r'Forwarding from 127\.0\.0\.1:(\d+)',proc.stdout.readline())
                    if match:port=int(match.group(1));break
        require(port is not None,'Graph management tunnel unavailable')
        yield port
    finally:
        proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()

class TrustedTunnel(http.client.HTTPSConnection):
    def connect(self):
        raw=socket.create_connection(('127.0.0.1',self.port),timeout=self.timeout)
        self.sock=self._context.wrap_socket(raw,server_hostname=self.host)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('kubectl','kubeconfig','namespace','ca','version'):parser.add_argument('--'+key,required=True)
    args=parser.parse_args();secret=json.load(sys.stdin)
    env=dict(os.environ)
    for key in ('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'):env.pop(key,None)
    env['NO_PROXY']='*'
    kube=[args.kubectl,'--kubeconfig='+args.kubeconfig,'--context=kind-sunmoon-kind','--request-timeout=20s','-n',args.namespace]
    ctx=ssl.create_default_context(cafile=args.ca)
    require(ctx.check_hostname and ctx.verify_mode==ssl.CERT_REQUIRED,'Graph TLS verification required')
    host='neo4j.'+args.namespace+'.svc.cluster.local'
    with forward(kube,7473,env) as https_port,forward(kube,7687,env) as bolt_port:
        def request(method,path,body=None,auth=True,expect=202):
            client=TrustedTunnel(host,https_port,context=ctx,timeout=30)
            headers={'Content-Type':'application/json','Accept':'application/json'}
            if auth:headers['Authorization']='Basic '+base64.b64encode((secret['username']+':'+secret['password']).encode()).decode()
            try:
                client.request(method,path,body=None if body is None else json.dumps(body).encode(),headers=headers)
                response=client.getresponse();raw=response.read()
                require(response.status==expect,'Graph query HTTP status '+str(response.status))
                payload=json.loads(raw) if raw else {}
                if expect==202:require(not payload.get('errors'),'Graph query returned semantic errors')
                return payload
            finally:client.close()
        query_path='/db/neo4j/query/v2'
        def query(statement,parameters=None):return request('POST',query_path,{'statement':statement,'parameters':parameters or {}})['data']['values']
        request('POST',query_path,{'statement':'RETURN 1'},auth=False,expect=401)
        component=query('CALL dbms.components() YIELD versions, edition RETURN versions[0], edition')
        require(component==[[args.version,'community']],'Running graph edition/version differs from lock')
        nonce=uuid.uuid4().hex
        transaction=None
        try:
            rows=query("CREATE (a:SunmoonAcceptance {run:$run,value:'源'}), (b:SunmoonAcceptance {run:$run,value:'目标'}), (a)-[:SUNMOON_ACCEPTANCE]->(b) RETURN a.value,b.value",{'run':nonce})
            require(rows==[['源','目标']],'Graph relationship write differs')
            rows=query('MATCH (a:SunmoonAcceptance {run:$run})-[:SUNMOON_ACCEPTANCE]->(b:SunmoonAcceptance {run:$run}) RETURN a.value,b.value',{'run':nonce})
            require(rows==[['源','目标']],'Committed graph relationship not readable')
            pending=request('POST',query_path+'/tx',{'statement':'CREATE (n:SunmoonAcceptance {run:$run,uncommitted:true}) RETURN n.uncommitted','parameters':{'run':nonce}})
            transaction=pending['transaction']['id']
            require(re.fullmatch('[a-zA-Z0-9_-]+',transaction) is not None,'Graph transaction identifier invalid')
            require(pending['data']['values']==[[True]],'Open graph transaction differs')
            request('DELETE',query_path+'/tx/'+transaction)
            transaction=None
            require(query('MATCH (n:SunmoonAcceptance {run:$run,uncommitted:true}) RETURN count(n)',{'run':nonce})==[[0]],'Graph transaction rollback did not restore prior state')
            with socket.create_connection(('127.0.0.1',bolt_port),timeout=10) as raw:
                with ctx.wrap_socket(raw,server_hostname=host) as tls:
                    offered=(0x00000006,0x00000805,0x00000405,0x00000404)
                    tls.sendall(struct.pack('!5I',0x6060B017,*offered))
                    selected=b''
                    while len(selected)<4:
                        part=tls.recv(4-len(selected));require(bool(part),'Bolt protocol negotiation closed');selected+=part
                    require(struct.unpack('!I',selected)[0] in offered,'Bolt protocol version unsupported')
        finally:
            if transaction:request('DELETE',query_path+'/tx/'+transaction)
            query('MATCH (n:SunmoonAcceptance {run:$run}) DETACH DELETE n RETURN count(n)',{'run':nonce})
        print(json.dumps({'passed':True,'version':args.version,'edition':'community','tls_chain_and_hostname':True,'unauthenticated_query_denied':True,'committed_relationship_write_read':True,'explicit_transaction_rollback':True,'bolt_tls_negotiation':True,'scope':'Internal HTTPS graph transactions and Bolt TLS negotiation; not business graph, fine-grained RBAC, Bolt driver session, restart or backup recovery'}))

if __name__=='__main__':
    try:main()
    except Exception as error:
        print(json.dumps({'passed':False,'error':str(error) if isinstance(error,RuntimeError) else type(error).__name__}))
        raise SystemExit(1)
