#!/usr/bin/env python3
"""Create a stopped core replacement so repaired env-file values take effect.

Docker stores environment at create time; restarting does not reread env_file.
Only this candidate is admitted; previous container remains stopped and retained.
"""
import argparse,json,os
from harbor_inputs import write_new
from recovery_candidate import RUN,PROJECT
from recovery_run import cmd,persist,STATE


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--apply',action='store_true');a=p.parse_args()
 if not a.apply:print('Plan: create one stopped core replacement using repaired private env file; no deletion');return
 if os.geteuid()!=0:raise RuntimeError('Root required')
 state=json.loads(STATE.read_text());record=RUN/'repair-core-environment.json';name=PROJECT+'-core-auth'
 if record.exists() or name in cmd(['docker','ps','-a','--format','{{.Names}}']).splitlines():raise RuntimeError('Replacement already exists')
 for identity in state['created'].values():
  if json.loads(cmd(['docker','inspect',identity]))[0]['State']['Running']:raise RuntimeError('Stop candidate first')
 cfg=json.loads(cmd(['docker','compose','-f',str(RUN/'compose.yaml'),'config','--format','json']))['services']['core']
 write_new(record,b'{"complete":false}\n');state['intended'].append(name);persist(state)
 argv=['docker','create','--name',name,'--label','com.docker.compose.project='+PROJECT,'--label','com.docker.compose.service=core',
       '--network',PROJECT,'--network-alias','core','--restart=no','--pull=never','--cap-drop=ALL','--security-opt=no-new-privileges',
       '--memory=1g','--cpus=2','--pids-limit=256','--log-driver=local','--log-opt','max-size=10m','--log-opt','max-file=2',
       '--env-file',str(RUN/'config/core/env')]
 for cap in cfg.get('cap_add',[]):argv+=['--cap-add',cap]
 for m in cfg['volumes']:argv+=['--mount','type=bind,src='+m['source']+',dst='+m['target']+(',readonly' if m.get('read_only') else '')]
 argv+=[cfg['image']];identity=cmd(argv).strip()
 state['retained_core_before_auth']=state['created']['core'];state['created']['core']=identity;persist(state)
 actual=json.loads(cmd(['docker','inspect',identity]))[0]
 env=dict(x.split('=',1) for x in actual['Config']['Env'])
 if any(env.get(k)!=v for k,v in cfg['environment'].items()):raise RuntimeError('Created core environment mismatch')
 if any(m['Type']=='volume' for m in actual['Mounts']) or actual['State']['Running']:raise RuntimeError('Unexpected core state/volume')
 record.write_text(json.dumps({'complete':True,'environment_matches':True,'original_retained':True,'services_started':False},indent=2)+'\n');print(record.read_text())


if __name__=='__main__':
 try:main()
 except Exception as exc:raise SystemExit('[recovery-core-refresh] '+(str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__+'; details withheld')) from None
