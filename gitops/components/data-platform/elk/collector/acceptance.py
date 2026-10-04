"""Actual node-log to Elasticsearch evidence; no arbitrary log or secret output."""
import hashlib
import json
import subprocess
import time


def verify_application_logs(request, kube, env, args, reader, require):
    base = kube[:-2]
    def get(namespace, resource, *extra):
        return json.loads(subprocess.check_output(base + ['-n', namespace, 'get', resource, *extra, '-o', 'json'], env=env, timeout=30))
    ds = get(args.collector_namespace, 'daemonset/log-collector')
    require(ds['status'].get('observedGeneration') == ds['metadata']['generation'], 'Collector generation is stale')
    require(ds['status'].get('desiredNumberScheduled') == 3 and ds['status'].get('numberReady') == 3, 'Collector must be ready on all three nodes')
    agents = get(args.collector_namespace, 'pods', '-l', 'app.kubernetes.io/name=fluent-bit')['items']
    require(len(agents) == 3 and len({p['spec']['nodeName'] for p in agents}) == 3, 'Collector node coverage differs')
    for pod in agents:
        spec = pod['spec'];container = spec['containers'][0]
        require(spec.get('automountServiceAccountToken') is False, 'Collector API token mounted')
        require(spec['securityContext']['runAsUser'] == 1000 and spec['securityContext']['runAsGroup'] == 0, 'Collector read-only node log identity differs')
        require(container['securityContext']['capabilities']['drop'] == ['ALL'] and container['securityContext']['readOnlyRootFilesystem'] and not container['securityContext']['allowPrivilegeEscalation'], 'Collector security boundary differs')
        require(container['image'].endswith('@'+args.collector_digest) and pod['status']['containerStatuses'][0]['imageID'].endswith('@'+args.collector_digest), 'Actual collector image differs from lock')
        require(any(v['name']=='logs' and v.get('readOnly') is True for v in container['volumeMounts']), 'Node logs must be read-only')
        require(not any('projected' in v or v.get('hostPath', {}).get('path') == '/var/run/docker.sock' for v in spec['volumes']), 'Unexpected credential/socket mount')
    apps = get(args.application_namespace, 'pods')['items']
    required = []
    for app in ('tpl','info','knowledge','investment'):
        for role in ('api','worker','scheduler','web','admin'):
            matches=[p for p in apps if p['metadata']['name'].startswith(app+'-'+role+'-') and p['status']['phase']=='Running']
            require(len(matches)==1, 'Actual application role absent: '+app+'/'+role)
            required.extend(matches)
    required.extend(p for p in apps if p['metadata']['name'].startswith('casdoor-') and p['status']['phase']=='Running')
    require(len(required)==21, 'Expected four applications and Casdoor')
    evidence=[]
    deadline=time.monotonic()+150
    pending={p['metadata']['name']:p for p in required}
    while pending and time.monotonic()<deadline:
        for name,pod in list(pending.items()):
            query={'size':30,'sort':[{'@timestamp':'desc'}], 'query':{'bool':{'filter':[{'term':{'kubernetes.pod_name.keyword':name}},{'term':{'kubernetes.namespace_name.keyword':args.application_namespace}},{'term':{'cluster.keyword':'sunmoon-kind'}}]}}}
            hits=request('elasticsearch','POST','/'+args.index_prefix+'-*/_search',reader,query)['hits']['hits']
            if not hits: continue
            raw=subprocess.check_output(base+['-n', args.application_namespace,'logs',name,'--all-containers=true','--tail=4000'],env=env,timeout=30).decode(errors='replace')
            candidates=[h for h in hits if isinstance(h['_source'].get('message'),str) and h['_source']['message'].strip() and h['_source']['message'].strip() in raw and h['_source'].get('node')==pod['spec']['nodeName']]
            if candidates:
                source=candidates[0]['_source']
                require(source.get('stream') in ('stdout','stderr') and source['kubernetes'].get('container_name') and source.get('log_file','').startswith('/var/log/containers/'), 'CRI metadata missing')
                evidence.append({'pod':name,'uid':pod['metadata']['uid'],'node':pod['spec']['nodeName'],'container':source['kubernetes']['container_name'],'stream':source['stream'],'message_sha256':hashlib.sha256(source['message'].encode()).hexdigest(),'timestamp':source['@timestamp']})
                del pending[name]
        if pending: time.sleep(3)
    require(not pending, 'No matching real container log for: '+','.join(sorted(pending)))
    outside={'query':{'bool':{'filter':[{'exists':{'field':'kubernetes.namespace_name'}},{'term':{'cluster.keyword':'sunmoon-kind'}}],'must_not':[{'term':{'kubernetes.namespace_name.keyword':args.application_namespace}}]}}}
    require(request('elasticsearch','POST','/'+args.index_prefix+'-*/_count',reader,outside)['count']==0, 'Collector sent logs outside application namespace')
    # Stable saved metadata, no log retention/deletion policy is created.
    views=request('kibana','GET','/api/data_views',reader)['data_view']
    matches=[v for v in views if v['id']==args.data_view_id]
    created=False
    if not matches:
        view=request('kibana','POST','/api/data_views/data_view',reader,{'data_view':{'id':args.data_view_id,'title':args.index_prefix+'-*','name':'SunMoon application logs','timeFieldName':'@timestamp'},'override':False})['data_view']
        require(view['id']==args.data_view_id, 'Kibana view identity differs')
        created=True
    view=request('kibana','GET','/api/data_views/data_view/'+args.data_view_id,reader)['data_view']
    require(view['title']==args.index_prefix+'-*' and view['timeFieldName']=='@timestamp','Refuse overwriting foreign Kibana view')
    return {'collector_nodes':3,'actual_application_pods':len(evidence),'real_logs_match_kubectl':True,'non_app_namespace_logs_absent':True,'kibana_data_view':args.data_view_id,'data_view_created':created,'log_evidence':evidence}
