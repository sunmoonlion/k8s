#!/usr/bin/env python3
"""Read-only HTTP verification for the private local recovery candidate.

Only candidate :18443 receives credentials. The advertised production token realm
is validated, then explicitly routed to the candidate without changing DNS/TLS.
"""
import hashlib
import json
import re
import time
import urllib.error
import urllib.parse as url
import urllib.request as http

BASE='https://harbor.sunmoonai.com:18443'
ACCEPT=', '.join(['application/vnd.oci.image.manifest.v1+json','application/vnd.docker.distribution.manifest.v2+json',
                 'application/vnd.oci.image.index.v1+json','application/vnd.docker.distribution.manifest.list.v2+json'])


def _verify_registry(client,catalog,deadline):
    checked=0; layers={}; tokens={}
    def budget():
        if time.monotonic()>deadline: raise RuntimeError('Registry HTTP verification deadline exceeded')
    for project in catalog['projects']:
        for repo in project['repositories']:
            name=repo['name']; encoded=url.quote(name,safe='/')
            for artifact in repo['artifacts']:
                budget(); digest=artifact['digest']
                endpoint=BASE+'/v2/'+encoded+'/manifests/'+url.quote(digest,safe=':')
                if name not in tokens:
                    try:
                        with client.client.open(http.Request(endpoint,headers={'Accept':ACCEPT}),timeout=20):
                            raise RuntimeError('Private manifest unexpectedly accessible anonymously')
                    except urllib.error.HTTPError as exc:
                        if exc.code!=401: raise RuntimeError('Unexpected anonymous registry response') from None
                        challenge=dict(re.findall(r'(\w+)="([^"]+)"',exc.headers.get('WWW-Authenticate','')))
                    realm=url.urlsplit(challenge.get('realm',''))
                    if (realm.scheme,realm.hostname,realm.port,realm.path)!=('https','harbor.sunmoonai.com',30443,'/service/token'):
                        raise RuntimeError('Unexpected advertised token realm')
                    token_url=BASE+'/service/token?'+url.urlencode({'service':challenge['service'],'scope':'repository:'+name+':pull'})
                    with client.client.open(http.Request(token_url,headers={'Authorization':'Basic '+client.auth}),timeout=20) as response:
                        tokens[name]=json.load(response)['token']
                request=http.Request(endpoint,headers={'Accept':ACCEPT,'Authorization':'Bearer '+tokens[name]})
                with client.client.open(request,timeout=20) as response:
                    raw=response.read(32*1024**2+1); reported=response.headers.get('Docker-Content-Digest')
                if len(raw)>32*1024**2 or 'sha256:'+hashlib.sha256(raw).hexdigest()!=digest or reported!=digest:
                    raise RuntimeError('Manifest bytes or reported digest mismatch')
                manifest=json.loads(raw)
                for layer in manifest.get('layers',[]):
                    if 0<layer.get('size',0)<=128*1024**2:
                        layers.setdefault(layer['digest'],{'repo':name,'size':layer['size']})
                checked+=1
    if not layers: raise RuntimeError('No bounded image layer available for stream verification')
    # Verify one actual layer, using the largest eligible sample for meaningful I/O.
    digest,item=max(layers.items(),key=lambda pair:pair[1]['size']); budget()
    request=http.Request(BASE+'/v2/'+url.quote(item['repo'],safe='/')+'/blobs/'+digest,
                         headers={'Authorization':'Bearer '+tokens[item['repo']]})
    h=hashlib.sha256(); size=0
    with client.client.open(request,timeout=30) as response:
        for block in iter(lambda:response.read(1024**2),b''):
            budget(); size+=len(block)
            if size>item['size']: raise RuntimeError('Layer exceeds declared size')
            h.update(block)
    if size!=item['size'] or 'sha256:'+h.hexdigest()!=digest:
        raise RuntimeError('Streamed layer digest mismatch')
    return {'manifest_count':checked,'all_manifest_bytes_verified':True,'anonymous_manifest_denied':True,
            'sample_layer':{'digest':digest,'bytes':size},'tls_verified':True,'production_token_realm_preserved':True,
            'credentials_sent_only_to_candidate':True}


def verify_registry(client,catalog,deadline):
    try:
        return _verify_registry(client,catalog,deadline)
    except urllib.error.HTTPError as exc:
        # URL query and all authentication headers are deliberately excluded.
        raise RuntimeError('Registry HTTP '+str(exc.code)+' at '+url.urlsplit(exc.url).path) from None
