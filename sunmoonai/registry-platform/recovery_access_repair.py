#!/usr/bin/env python3
"""Fix stopped candidate authentication and loopback publishing; never start services."""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
from urllib.parse import urlsplit,urlunsplit,quote,unquote
import yaml
from harbor_inputs import sha,write_new
from official_prepare import replace_env
from recovery_candidate import RUN,ROOT,PROJECT,BACKUP,bind
from recovery_repair import REDIS
from recovery_run import cmd,persist,STATE


def main():
    os.umask(0o077)
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--apply',action='store_true');a=p.parse_args()
    if not a.apply:
        print(json.dumps({'dry_run':True,'redis':'8.2.1 with authentication','proxy_network':'dedicated bridge without masquerade','services_started':False}));return
    if os.geteuid()!=0 or RUN.resolve()!=RUN:raise RuntimeError('Root and exact path required')
    state=json.loads(STATE.read_text())
    if state.get('completed') or state.get('stop_errors'):raise RuntimeError('Unexpected recovery state')
    for identity in state['created'].values():
        if json.loads(cmd(['docker','inspect',identity]))[0]['State']['Running']:raise RuntimeError('Stop candidate first')
    record=RUN/'repair-auth-and-publishing.json'
    if record.exists():raise RuntimeError('Repair already attempted')
    data=json.loads((BACKUP/'resources-private.json').read_text());items=data['items'] if isinstance(data,dict) else data
    original=next(i for i in items if i.get('kind')=='Secret' and i['metadata']['name']=='sunmoonai-harbor-registry')
    password=base64.b64decode(original['data'].get('REGISTRY_REDIS_PASSWORD','')).decode()
    reused=bool(password)
    if not password:password=secrets.token_urlsafe(32)
    if any(c in password for c in '\r\n\x00'):raise RuntimeError('Redis credential contains unsafe characters')
    frontend=PROJECT+'-frontend';name=PROJECT+'-redis-821-auth'
    if frontend in cmd(['docker','network','ls','--format','{{.Name}}']).splitlines() or name in cmd(['docker','ps','-a','--format','{{.Names}}']).splitlines():raise RuntimeError('Repair resource collision')
    files=['config/core/env','config/registry/config.yml','compose.yaml','preparation.json','run-state.json']
    for f in files:write_new(RUN/'before-access-repair'/f,(RUN/f).read_bytes())
    write_new(record,(json.dumps({'complete':False,'credential_reused':reused})+'\n').encode())
    cfgpath=RUN/'redis-auth.conf'
    write_new(cfgpath,('bind 0.0.0.0\nprotected-mode yes\ndir /data\nsave ""\nappendonly no\nrequirepass '+json.dumps(password)+'\n').encode())
    os.chown(cfgpath,1001,1001);os.chmod(cfgpath,0o400)
    core=RUN/'config/core/env';fields=dict(line.split('=',1) for line in core.read_text().splitlines() if '=' in line)
    replacements={}
    for key in ['_REDIS_URL_CORE','_REDIS_URL_REG']:
        u=urlsplit(fields[key])
        if u.scheme!='redis' or u.hostname!='redis':raise RuntimeError('Unexpected candidate Redis URL')
        replacements[key]=urlunsplit((u.scheme,':'+quote(password,safe='')+'@redis:'+str(u.port or 6379),u.path,u.query,u.fragment))
    replace_env(core,replacements)
    reg=RUN/'config/registry/config.yml';config=yaml.safe_load(reg.read_text())
    if config['redis']['addr']!='redis:6379':raise RuntimeError('Unexpected registry Redis address')
    config['redis']['password']=password;reg.write_text(yaml.safe_dump(config,sort_keys=False))
    compose=yaml.safe_load((RUN/'compose.yaml').read_text())
    service=compose['services']['redis'];service['container_name']=name;service['command']=['/etc/redis-recovery.conf']
    service['volumes'].append(bind(cfgpath,'/etc/redis-recovery.conf'))
    compose['networks']['frontend']={'name':frontend,'driver':'bridge','driver_opts':{'com.docker.network.bridge.enable_ip_masquerade':'false'}}
    compose['services']['proxy']['networks']=['harbor','frontend']
    (RUN/'compose.yaml').write_text(yaml.safe_dump(compose,sort_keys=False))
    state['intended'].append(name);persist(state)
    image=json.loads(cmd(['docker','image','inspect',REDIS]))[0]
    if REDIS not in image.get('RepoDigests',[]):raise RuntimeError('Redis identity changed')
    identity=cmd(['docker','create','--name',name,'--label','com.docker.compose.project='+PROJECT,'--label','com.docker.compose.service=redis',
                  '--network',PROJECT,'--network-alias','redis','--restart=no','--pull=never','--user','1001:1001','--read-only','--cap-drop=ALL',
                  '--security-opt=no-new-privileges','--memory=512m','--cpus=1','--pids-limit=128',
                  '--tmpfs','/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777','--log-driver=local','--log-opt','max-size=10m','--log-opt','max-file=2',
                  '--mount','type=bind,src='+str(RUN/'redis-821')+',dst=/data',
                  '--mount','type=bind,src='+str(cfgpath)+',dst=/etc/redis-recovery.conf,readonly',
                  '--entrypoint','/opt/bitnami/redis/bin/redis-server',image['Id'],'/etc/redis-recovery.conf']).strip()
    state['retained_redis_without_auth']=state['created']['redis'];state['created']['redis']=identity;persist(state)
    cmd(['docker','network','create','--driver','bridge','--opt','com.docker.network.bridge.enable_ip_masquerade=false','--label','sunmoonai.registry.recovery='+PROJECT,frontend])
    cmd(['docker','network','connect',frontend,state['created']['proxy']])
    # Verify environment values are not expanded by Compose; private output stays in memory.
    resolved=json.loads(cmd(['docker','compose','-f',str(RUN/'compose.yaml'),'config','--format','json']))
    if any(resolved['services']['core']['environment'].get(k)!=v for k,v in replacements.items()):raise RuntimeError('Redis URL interpolation changed')
    prep=json.loads((RUN/'preparation.json').read_text())
    for f in ['config/core/env','config/registry/config.yml','compose.yaml','redis-auth.conf']:prep['immutable_files'][f]=sha(RUN/f)
    prep['configuration']['proxy_frontend_network']=frontend;prep['configuration']['backend_internal_network']=True
    (RUN/'preparation.json').write_text(json.dumps(prep,indent=2)+'\n')
    record.write_text(json.dumps({'complete':True,'source_redis_credential_reused':reused,'redis_version':'8.2.1','frontend':frontend,'old_containers_retained':True,'services_started':False},indent=2)+'\n')
    print(record.read_text())


if __name__=='__main__':
    try:main()
    except Exception as exc:raise SystemExit('[recovery-access-repair] '+(str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__+'; details withheld')) from None
