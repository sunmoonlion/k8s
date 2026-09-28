#!/usr/bin/env python3
"""Read-only capacity monitoring and exact, approval-bound cleanup plans.

Cloud 未经实机验证. No container/volume/system prune and no node image cleanup.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
DEFAULT_POLICY = HERE / 'policy.json'
STATE = Path('/var/lib/sunmoon/space')
GIB = 1024 ** 3


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def read_json(path):
    raw = Path(path).read_bytes()
    if len(raw) > 16 * 1024**2:
        raise ValueError('JSON input exceeds limit')
    return json.loads(raw)


def save_new(path, value):
    path = Path(path)
    if path.resolve() != path.absolute():
        raise ValueError('Non-symlink output required')
    with path.open('x') as stream:
        os.chmod(path, 0o600)
        json.dump(value, stream, indent=2, ensure_ascii=False); stream.write('\n')
        stream.flush(); os.fsync(stream.fileno())


def run(args, timeout=30):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise ValueError('Command failed; raw diagnostics withheld: ' + args[0])
    return result.stdout


class Docker(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout); self.sock.connect('/var/run/docker.sock')


def docker_get(path):
    if path not in ('/system/df', '/containers/json?all=1', '/volumes'):
        raise ValueError('Unsupported read-only Docker endpoint')
    c = Docker('localhost', timeout=240 if path=='/system/df' else 45)
    try:
        c.request('GET', path); r = c.getresponse(); raw = r.read(32 * 1024**2 + 1)
        if r.status != 200 or len(raw) > 32 * 1024**2:
            raise ValueError('Docker inventory incomplete')
        return json.loads(raw)
    finally:
        c.close()


def filesystem(path):
    s = os.statvfs(path)
    if not s.f_blocks:
        raise ValueError('Filesystem size unavailable')
    return {'path': str(path), 'total_bytes': s.f_blocks*s.f_frsize,
            'used_bytes': (s.f_blocks-s.f_bfree)*s.f_frsize, 'available_bytes': s.f_bavail*s.f_frsize,
            'percent_used': round(100*(s.f_blocks-s.f_bfree)/s.f_blocks,2),
            'inodes_available': s.f_favail if s.f_favail<=s.f_files else None,
            'inodes_total': s.f_files if s.f_favail<=s.f_files else None}


def mounts(policy):
    rows = {}
    for key in ('data','harbor','clusters'):
        path = policy['paths'][key]
        doc = json.loads(run(['findmnt','-J','-M',path,'-o','TARGET,SOURCE,FSTYPE,UUID,OPTIONS,FSROOT']))
        values = doc.get('filesystems') or []
        if len(values) != 1:
            raise ValueError('Required exact storage mount absent')
        row = values[0]; opts = row['options'].split(',')
        if row['uuid'] != policy['storage_uuid'] or row['fstype'] != 'ext4' or 'rw' not in opts:
            raise ValueError('Storage UUID/type/writable state differs')
        expected = {'data':'/','harbor':'/harbor','clusters':'/kind-clusters'}[key]
        if row['fsroot'] != expected:
            raise ValueError('Wrong bind root')
        rows[key] = row
    return rows


def status(policy, deep=False):
    report = {'schema':1,'at':now(),'read_only':True,'policy_sha256':digest(policy),
              'filesystems':{},'vhdx':{},'alerts':[], 'external_notification':'not configured',
              'automatic_deletion':False}
    def alert(level, message):report['alerts'].append({'level':level,'message':message})
    for key,path in [('system','/'),('windows',policy['paths']['windows']),('data',policy['paths']['data'])]:
        try:
            row = filesystem(path); report['filesystems'][key] = row
            pct = row['percent_used']; limits=policy['monitor']
            level = ('critical' if pct>=limits['critical_percent'] else 'block' if pct>=limits['block_percent']
                     else 'warning' if pct>=limits['warning_percent'] else None)
            if level:alert(level,f'{key}: {pct}% used')
            if row['inodes_total'] and row['inodes_available']/row['inodes_total'] < .05:
                alert('block',f'{key}: less than 5% inodes available')
        except Exception:alert('unknown',key+': filesystem metric unavailable')
    try:report['mounts']=mounts(policy)
    except Exception:alert('block','Required data UUID/bind/writable check failed; do not start writes')
    for key in ('wsl_vhdx','data_vhdx'):
        try:
            path=Path(policy['paths'][key]);s=path.stat()
            if not stat.S_ISREG(s.st_mode) or path.is_symlink():raise ValueError()
            report['vhdx'][key]={'path':str(path),'file_length_bytes':s.st_size,
                               'linux_reported_allocated_bytes':s.st_blocks*512,
                               'physical_allocation_verified':False}
        except Exception:alert('unknown',key+': file size unavailable')
    cap=policy['capacity'];peak=cap['operation_peak_gib']*GIB
    # Use lower of file length and reported allocation, so sparse-file holes do
    # not make future growth look smaller. Windows physical allocation is still
    # required for a final maintenance admission; this monitor is conservative.
    if 'windows' in report['filesystems'] and 'data_vhdx' in report['vhdx']:
        d=report['vhdx']['data_vhdx'];allocated=min(d['file_length_bytes'],d['linux_reported_allocated_bytes'])
        growth=max(0,cap['data_maximum_gib']*GIB-allocated)
        free=report['filesystems']['windows']['available_bytes']
        report['growth_budget']={'remaining_maximum_growth_bytes':growth,'operation_peak_bytes':peak,
          'projected_windows_free_bytes':free-growth-peak,'minimum_bytes':cap['windows_reserve_gib']*GIB,
          'estimate_only':True}
        if free-growth-peak < cap['windows_reserve_gib']*GIB:
            alert('block','Projected C: reserve below 50 GiB after data growth and operation peak')
    if 'data' in report['filesystems'] and report['filesystems']['data']['available_bytes'] < cap['data_reserve_gib']*GIB+peak:
        alert('block','Data reserve below configured 20 GiB plus operation peak')
    try:
        containers=docker_get('/containers/json?all=1');volumes=docker_get('/volumes').get('Volumes') or []
        report['protected_runtime']={'containers':len(containers),'volumes':len(volumes),
            'container_ids_sha256':digest(sorted(c['Id'] for c in containers)),
            'volume_names_sha256':digest(sorted(v['Name'] for v in volumes))}
    except Exception:alert('unknown','Docker protected runtime inventory unavailable')
    if deep:
        report['directory_usage']={}
        # Exactly one root per tree: binds are not summed again.
        for path in ['/data/harbor','/data/kind-clusters','/var/backups/sunmoon-harbor','/var/lib/docker','/var/lib/containerd','/var/log']:
            try:
                raw=run(['du','-sx','-B1','--',path],timeout=180)
                report['directory_usage'][path]=int(raw.split()[0])
            except Exception:report['directory_usage'][path]=None;alert('unknown','Deep inventory failed: '+path)
    report['large_operations_allowed']=not any(x['level'] in ('critical','block','unknown') for x in report['alerts'])
    report['health']='attention' if report['alerts'] else 'ok'
    report['stop_and_recovery_allowed']=True
    return report


def cache_candidates(policy):
    rows=docker_get('/system/df')['BuildCache']
    cutoff=dt.datetime.now(dt.timezone.utc)-dt.timedelta(days=policy['proposed_retention']['cache']['unused_days'])
    out=[]
    for r in rows:
        last=r.get('LastUsedAt')
        if not last or r.get('InUse') or r.get('Shared'):continue
        try:age=dt.datetime.fromisoformat(last.replace('Z','+00:00'))
        except ValueError:raise ValueError('Unrecognized cache timestamp') from None
        if age > cutoff:continue
        if not re.fullmatch(r'[a-z0-9]+',r['ID']):raise ValueError('Unrecognized cache ID')
        out.append({k:r.get(k) for k in ('ID','Size','LastUsedAt','InUse','Shared','Parents')})
    # Docker /system/df omits Parents on this engine; use the actual builder
    # graph. An old parent alone cannot be reclaimed while a child is retained.
    template='{"ID":{{json .ID}},"Parents":{{json .Parents}}}'
    topology=[json.loads(line) for line in run(['docker','buildx','du','--builder','default','--format',template],240).splitlines()]
    children={}
    for row in topology:
        for parent in row.get('Parents') or []:
            children.setdefault(parent,set()).add(row['ID'])
    eligible={r['ID'] for r in out}
    while True:
        excluded={i for i in eligible if children.get(i,set())-eligible}
        if not excluded:break
        eligible-=excluded
    return sorted([r for r in out if r['ID'] in eligible],key=lambda x:x['ID'])


def fingerprint(path):
    path=Path(path)
    if not path.is_absolute() or path.resolve()!=path:raise ValueError('Non-symlink absolute file required')
    with path.open('rb') as f:
        s=os.fstat(f.fileno())
        if not stat.S_ISREG(s.st_mode) or s.st_nlink!=1:raise ValueError('Only singly linked regular files admitted')
        h=hashlib.file_digest(f,'sha256').hexdigest()
    return {'path':str(path),'device':s.st_dev,'inode':s.st_ino,'size':s.st_size,
            'mtime_ns':s.st_mtime_ns,'allocated_bytes':s.st_blocks*512,'sha256':h}


def file_candidates(policy,scope):
    rows=[]
    for item in policy['file_scopes'][scope]:
        # A retained byte-identical copy is mandatory in this first executor.
        # Log/backup age alone is not a deletion authorization.
        path=Path(item['path']);retained=Path(item['retained_copy'])
        forbidden=('/data/kind-local-storage','/data/kind-clusters','/home/zymun/private','/var/lib/docker','/var/lib/containerd')
        if any(path==Path(v) or path.is_relative_to(v) for v in forbidden) or path.is_relative_to('/data/harbor'):
            raise ValueError('Protected data root cannot be a file cleanup target')
        a,b=fingerprint(path),fingerprint(retained)
        if a['sha256']!=b['sha256'] or a['size']!=b['size'] or (a['device'],a['inode'])==(b['device'],b['inode']):
            raise ValueError('Retained copy verification failed')
        rows.append({'file':a,'retained':b,'reason':item['reason']})
    return rows


def preview(policy,scope):
    value={'schema':1,'created_at':now(),'scope':scope,'policy_sha256':digest(policy),
      'automatic':False,'candidates':[],'blockers':[],'estimated_release_bytes':{'conservative':0,'api_candidate_bytes':0,'physical_upper_bound':None},
      'protected':policy['protected']}
    if scope=='cache':
        value['candidates']=cache_candidates(policy)
        value['estimated_release_bytes']['api_candidate_bytes']=sum(x['Size'] for x in value['candidates'])
        value['estimate_note']='API display size is not a physical bound; snapshot/content GC and concurrent writes can change actual release. No image sizes added.'
        value['blockers'].append('Each candidate needs explicit recoverable-input confirmation in approval')
    elif scope in ('logs','backups','temporary'):
        value['candidates']=file_candidates(policy,scope)
        value['estimated_release_bytes']['api_candidate_bytes']=sum(x['file']['allocated_bytes'] for x in value['candidates'])
        if not value['candidates']:value['blockers'].append('No exact files registered; no age/glob deletion')
    else:
        value['blockers'] += ['Harbor formal source not admitted yet; retention/GC execution disabled',
          'Live workload, rollback, offline material and referrer protection closure required',
          'Owner must approve proposed retention before native dry-run creates jobs']
    if not policy['deletion_policy_approved']:value['blockers'].append('Deletion policy awaits owner approval')
    value['plan_sha256']=digest(value)
    return value


def apply_plan(policy,plan_path,approval_path):
    plan=read_json(plan_path);approval=read_json(approval_path)
    if Path(approval_path).is_symlink() or Path(approval_path).stat().st_mode & 0o077:
        raise ValueError('Approval record must be owner-only and not a symlink')
    supplied=plan.pop('plan_sha256')
    if digest(plan)!=supplied or approval.get('plan_sha256')!=supplied:raise ValueError('Approved plan digest differs')
    if not policy['deletion_policy_approved'] or plan['policy_sha256']!=digest(policy):raise ValueError('Policy not approved or changed')
    if approval.get('approved_by')!='owner' or approval.get('decision')!='execute-exact-plan':raise ValueError('Explicit owner approval record required')
    age=(dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(plan['created_at'])).total_seconds()
    if not 0<=age<=3600:raise ValueError('Plan expired; refresh candidates and approval')
    if not plan['candidates']:raise ValueError('No admitted candidates')
    if plan['scope'] not in ('cache','logs','backups','temporary'):raise ValueError('Scope executor not admitted')
    fresh=preview(policy,plan['scope'])
    if fresh['candidates']!=plan['candidates']:raise ValueError('Candidates/references changed since approval')
    before=status(policy)
    if 'protected_runtime' not in before:raise ValueError('Runtime protection inventory unavailable')
    receipt={'schema':1,'plan_sha256':supplied,'at':now(),'before':before,'executed':[],'completed':False}
    dest=Path(str(plan_path)+'.receipt.json')
    save_new(dest.with_suffix('.intent.json'),receipt)
    if plan['scope']=='cache':
        ids=[c['ID'] for c in plan['candidates']]
        if sorted(approval.get('recoverable_cache_ids',[]))!=sorted(ids):raise ValueError('Recoverable input confirmation missing')
        filters=['id~=^('+'|'.join(ids)+')$','until=168h','private=""']
        cmd=['docker','buildx','du','--builder','default','--format','{{.ID}}']
        for f in filters:cmd+=['--filter',f]
        actual=set(run(cmd,240).split())
        if actual!=set(ids):raise ValueError('Builder preview differs from approved IDs')
        cmd=['docker','buildx','prune','--builder','default','--force']
        for f in filters:cmd+=['--filter',f]
        run(cmd,1200);receipt['executed']=ids
        remaining=set(run(['docker','buildx','du','--builder','default','--format','{{.ID}}','--filter',filters[0]],240).split())
        if not remaining<=set(ids):raise ValueError('Post-cleanup selection differs')
        receipt['removed_count']=len(set(ids)-remaining)
        receipt['retained_ids']=sorted(remaining)
    else:
        for row in plan['candidates']:
            if fingerprint(row['file']['path'])!=row['file'] or fingerprint(row['retained']['path'])!=row['retained']:
                raise ValueError('File or retained copy changed')
            journal=Path(str(plan_path)+'.journal.jsonl')
            with journal.open('a') as stream:
                stream.write(json.dumps({'intent':row['file']})+'\n');stream.flush();os.fsync(stream.fileno())
                Path(row['file']['path']).unlink();receipt['executed'].append(row['file']['path'])
                stream.write(json.dumps({'deleted':row['file']['path']})+'\n');stream.flush();os.fsync(stream.fileno())
    receipt['after']=status(policy)
    receipt['protected_unchanged']=receipt['before'].get('protected_runtime')==receipt['after'].get('protected_runtime')
    receipt['completed']=receipt['protected_unchanged'] and (plan['scope']!='cache' or receipt['removed_count']>0)
    receipt['logical_freed_bytes']={k:receipt['after']['filesystems'][k]['available_bytes']-v['available_bytes']
      for k,v in before['filesystems'].items() if k in receipt['after']['filesystems']}
    receipt['note']='Concurrent writes affect deltas; VHDX compaction is a separate owner maintenance step'
    save_new(dest,receipt)
    if not receipt['completed']:raise ValueError('No cache reclaimed or runtime inventory changed; inspect receipt')
    return receipt


def monitor_sample(policy):
    STATE.mkdir(mode=0o700,parents=True,exist_ok=True)
    if STATE.resolve()!=STATE or STATE.stat().st_uid!=os.geteuid():raise ValueError('Unsafe monitor state directory')
    current=status(policy)
    previous_path=STATE/'latest.json'
    if previous_path.exists():
        previous=read_json(previous_path)
        hours=(dt.datetime.fromisoformat(current['at'])-dt.datetime.fromisoformat(previous['at'])).total_seconds()/3600
        current['trend']={}
        for key,row in current['filesystems'].items():
            prior=previous.get('filesystems',{}).get(key)
            if prior and hours>0:
                rate=(row['used_bytes']-prior['used_bytes'])/hours
                current['trend'][key]={'growth_bytes_per_hour':rate,'hours_until_full':row['available_bytes']/rate if rate>0 else None,
                                       'two_sample_estimate':True}
    fd,temp=tempfile.mkstemp(prefix='.sample-',dir=STATE)
    with os.fdopen(fd,'w') as f:json.dump(current,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
    os.replace(temp,previous_path)
    return current


def monitor_install(policy_path,apply):
    # Publish immutable root-owned copies; service never executes the mutable checkout.
    payload=Path(__file__).read_bytes();conf=Path(policy_path).read_bytes()
    version=hashlib.sha256(payload+conf).hexdigest()[:16]
    root=Path('/opt/sunmoon/admin/space')/version
    unit=('[Unit]\nDescription=SunMoon read-only capacity monitor\nAfter=local-fs.target docker.service\n'
      '[Service]\nType=oneshot\nExecStart=/usr/bin/python3 -B '+str(root/'space.py')+' --policy '+str(root/'policy.json')+' monitor sample\n'
      'NoNewPrivileges=yes\nProtectSystem=full\nProtectHome=read-only\nPrivateTmp=yes\n'
      'ReadWritePaths=/var/lib/sunmoon/space\nTimeoutStartSec=180\n')
    timer='[Unit]\nDescription=SunMoon hourly read-only capacity check\n[Timer]\nOnBootSec=3min\nOnUnitActiveSec=1h\nAccuracySec=1min\n[Install]\nWantedBy=timers.target\n'
    if not apply:return {'dry_run':True,'immutable_install_root':str(root),'service':unit,'timer':timer,'delete_permission':False}
    if os.geteuid()!=0:raise ValueError('Monitor install requires root')
    STATE.mkdir(mode=0o700,parents=True,exist_ok=True);root.mkdir(mode=0o755,parents=True,exist_ok=True)
    for name,data in [('space.py',payload),('policy.json',conf)]:
        path=root/name
        if path.exists() and path.read_bytes()!=data:raise ValueError('Published version differs')
        if not path.exists():
            with path.open('xb') as f:f.write(data)
        os.chmod(path,0o644)
    for name,data in [('sunmoon-space-monitor.service',unit),('sunmoon-space-monitor.timer',timer)]:
        path=Path('/etc/systemd/system')/name
        if path.is_symlink():raise ValueError('Unit symlink refused')
        if path.exists() and path.read_text()!=data:
            previous=path.read_text()
            match=re.search(r'ExecStart=/usr/bin/python3 -B (/opt/sunmoon/admin/space/[0-9a-f]{16})/space.py',previous)
            if name!='sunmoon-space-monitor.service' or not match:
                raise ValueError('Existing unit is not a recognized managed version')
            old_root=Path(match.group(1))
            for old_file in (old_root/'space.py',old_root/'policy.json'):
                if old_file.resolve()!=old_file or old_file.stat().st_uid!=0 or old_file.stat().st_mode&0o022:
                    raise ValueError('Unsafe previous published version')
            old_hash=hashlib.sha256((old_root/'space.py').read_bytes()+(old_root/'policy.json').read_bytes()).hexdigest()[:16]
            if old_root.name!=old_hash or previous.replace(str(old_root),str(root))!=data:
                raise ValueError('Managed unit has changes beyond the version path')
            backup=root/'previous-monitor.service'
            if not backup.exists():backup.write_text(previous)
        path.write_text(data)
    run(['systemctl','daemon-reload']);run(['systemctl','enable','--now','sunmoon-space-monitor.timer'])
    run(['systemctl','start','sunmoon-space-monitor.service'],180)
    return {'installed':True,'published':str(root),'automatic':'read-only hourly; no deletion','external_notification':None}


def main():
    os.umask(0o077)
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--policy',type=Path,default=DEFAULT_POLICY)
    sub=p.add_subparsers(dest='action',required=True)
    q=sub.add_parser('status');q.add_argument('--deep',action='store_true');q.add_argument('--output',type=Path)
    q=sub.add_parser('policy');q.add_argument('operation',choices=['show'])
    q=sub.add_parser('preview');q.add_argument('--scope',required=True,choices=['harbor','gc','cache','logs','backups','temporary']);q.add_argument('--output',type=Path,required=True)
    q=sub.add_parser('apply');q.add_argument('--plan',type=Path,required=True);q.add_argument('--approval',type=Path,required=True)
    q=sub.add_parser('monitor');q.add_argument('operation',choices=['status','install','disable','sample']);q.add_argument('--apply',action='store_true')
    a=p.parse_args();policy=read_json(a.policy)
    if policy['schema']!=1 or policy['automatic_deletion']:raise ValueError('Unsupported or automatic deletion policy')
    if policy['proposed_retention']['cache']['builder']!='default' or policy['proposed_retention']['cache']['unused_days']!=7:
        raise ValueError('This cache executor only admits default builder and 7 days')
    if a.action=='status':
        result=status(policy,a.deep)
        if a.output:save_new(a.output,result)
    elif a.action=='policy':result=policy
    elif a.action=='preview':result=preview(policy,a.scope);save_new(a.output,result)
    elif a.action=='apply':
        # Process lock protects only this CLI; Docker/Kubernetes are rechecked separately.
        if os.geteuid()!=0:raise ValueError('Cleanup requires root and explicit approved plan')
        STATE.mkdir(mode=0o700,parents=True,exist_ok=True)
        with (STATE/'cleanup.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            result=apply_plan(policy,a.plan,a.approval)
    elif a.operation=='install':result=monitor_install(a.policy,a.apply)
    elif a.operation=='sample':result=monitor_sample(policy)
    elif a.operation=='disable':
        if not a.apply:result={'dry_run':True,'action':'disable monitor timer only'}
        else:run(['systemctl','disable','--now','sunmoon-space-monitor.timer']);result={'disabled':True}
    else:
        try:
            result=read_json(STATE/'latest.json')
            age=(dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(result['at'])).total_seconds()
            result['stale']=age>policy['monitor']['stale_minutes']*60
            if result['stale']:result['health']='unknown';result['large_operations_allowed']=False
        except OSError:result={'health':'unknown','reason':'No successful monitor sample','stale':True}
        try:result['timer']={};result['timer']['properties']=run(['systemctl','show','sunmoon-space-monitor.timer','-p','ActiveState','-p','NextElapseUSecMonotonic','-p','UnitFileState']).splitlines()
        except Exception:result['timer']={'state':'unknown'}
        try:
            service=run(['systemctl','show','sunmoon-space-monitor.service','-p','Result','-p','ExecMainStatus','-p','ActiveState']).splitlines()
            result['service']=service
            if 'ActiveState=failed' in service or any(v.startswith('Result=') and v!='Result=success' for v in service):
                result['health']='unknown';result['large_operations_allowed']=False
        except Exception:
            result['service']=['state=unknown'];result['health']='unknown'

    print(json.dumps(result,indent=2,ensure_ascii=False))


if __name__=='__main__':
    try:main()
    except Exception as e:
        # Paths/credentials from subprocess output are not printed.
        print('Space operation failed: '+(str(e) if isinstance(e,ValueError) else type(e).__name__),file=sys.stderr)
        raise SystemExit(1) from None
