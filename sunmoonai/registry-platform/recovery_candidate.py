#!/usr/bin/env python3
"""Prepare this local Harbor cold-backup recovery candidate; never starts services.

Default prints a plan. --apply imports six pinned offline images, copies a registry
archive to new storage, and writes a private Compose candidate. No deletion or
cloud transport; cloud 未经实机验证. This is a migration tool, not production deployment.
"""
import argparse
import copy
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile

import yaml
from harbor_inputs import EXPECTED_ROOT as ROOT, HERE, sha, write_new
from official_prepare import nested, command, replace_env

RUN = ROOT/'recovery'
PROJECT = 'sunmoon-harbor-recovery-20260927'
BACKUP = Path('/home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926/backup-20260926T145600Z')
PG_RUN = Path('/data/harbor/rehearsals/pg17-20260927T040000Z')
INSTALLER = Path('/home/zymun/packages-to-be-installed/releases/registry-platform-2.13.2-linux-amd64/harbor-offline-installer-v2.13.2.tgz')
PG_IMAGE = 'bitnami/postgresql@sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b'
PG = '/opt/bitnami/postgresql/bin/'
REGISTRY_SHA = '94aad564812c2af543d1e7bd5f76fcf0f564205a2f0b101b628702a84cf6fb16'
# Historical first preparation imported redis-photon; execution now requires source Redis 8.2.1.
SERVICES = {'registry':'registry-photon','registryctl':'harbor-registryctl','core':'harbor-core',
            'portal':'harbor-portal','redis':'redis-photon','proxy':'nginx-photon'}


def guard():
    command(['bash','/opt/sunmoon/admin/storage/storage-20260928-v3/check-storage-mounts.sh',
             '--layout','sunmoon-data','--expected-uuid','a28de356-4ba1-4a21-93f5-744b9b9d8be0',
             '--min-free-gib','40','--require-service-visibility'])
    if os.geteuid() != 0 or ROOT.resolve() != ROOT:
        raise RuntimeError('Root and exact mounted candidate path required')
    state = json.loads((ROOT/'generator-state.json').read_text())
    if state.get('completed') is not True:
        raise RuntimeError('Official configuration preparation incomplete')
    receipt = json.loads((ROOT/'inputs-receipt.json').read_text())
    for name, info in receipt['private_files'].items():
        if sha(ROOT/name) != info['sha256']:
            raise RuntimeError('Original preserved input changed')
    for name, digest in [('registry.dump','8690de0139c8e97d6f885b46023ea834c26b246b6f3d27077d7932d2ec8535a4'),
                         ('globals.sql','db88e2684931daccddc3f5a252b14cdb1d6d5c5ca8ba33eec1608a9bff8d34e1')]:
        if sha(PG_RUN/name) != digest:
            raise RuntimeError('Logical export changed')
    if not json.loads((PG_RUN/'state.json').read_text()).get('completed'):
        raise RuntimeError('Logical database rehearsal incomplete')


def images():
    lock = json.loads((HERE/'artifacts.lock.json').read_text())['artifacts'][0]
    if INSTALLER.stat().st_size != lock['bytes'] or sha(INSTALLER) != lock['sha256']:
        raise RuntimeError('Installer changed')
    outer, inner = nested(INSTALLER)
    with outer, inner:
        for member in inner:
            if member.name == 'manifest.json':
                manifest = json.load(inner.extractfile(member)); break
        else:
            raise RuntimeError('Missing image manifest')
    selected, configs, wanted = [], {}, set()
    for name in SERVICES.values():
        matching = [m for m in manifest if m.get('RepoTags') == ['goharbor/'+name+':v2.13.2']]
        if len(matching) != 1:
            raise RuntimeError('Missing or ambiguous official runtime image')
        item = copy.deepcopy(matching[0])
        item['RepoTags'] = ['sunmoon-offline/'+name+':2.13.2-recovery-20260927']
        if command(['docker','image','ls','--format','{{.Repository}}:{{.Tag}}',item['RepoTags'][0]]).strip():
            raise RuntimeError('Recovery image alias exists; preserve previous attempt')
        selected.append(item); wanted.update([item['Config'], *item['Layers']])
    found = set()
    outer, inner = nested(INSTALLER)
    with outer, inner, tarfile.open(RUN/'runtime-images.tar','x') as target:
        for member in inner:
            if member.name not in wanted: continue
            name = PurePosixPath(member.name)
            if name.is_absolute() or '..' in name.parts or not member.isfile() or member.name in found:
                raise RuntimeError('Unsafe image archive entry')
            found.add(member.name)
            stream = inner.extractfile(member)
            if member.name.endswith('.json'):
                data = stream.read()
                if hashlib.sha256(data).hexdigest()+'.json' != member.name:
                    raise RuntimeError('Image configuration hash mismatch')
                configs[member.name] = json.loads(data); stream = io.BytesIO(data)
            target.addfile(member, stream)
        if found != wanted: raise RuntimeError('Incomplete runtime images')
        raw = json.dumps(selected).encode(); member = tarfile.TarInfo('manifest.json'); member.size = len(raw)
        target.addfile(member, io.BytesIO(raw))
    command(['docker','load','-i',str(RUN/'runtime-images.tar')],timeout=240,output=RUN/'image-load.log')
    result = {}
    for item in selected:
        actual = json.loads(command(['docker','image','inspect',item['RepoTags'][0]]))[0]
        original = configs[item['Config']]
        if actual['RootFS']['Layers'] != original['rootfs']['diff_ids'] or original['architecture'] != 'amd64' or original['os'] != 'linux':
            raise RuntimeError('Runtime image layers/platform mismatch')
        for key in ['Env','Entrypoint','Cmd','User','WorkingDir','Volumes']:
            a,b=actual['Config'].get(key),original['config'].get(key)
            if key == 'User': a,b=a or '',b or ''
            if a != b: raise RuntimeError('Runtime image config mismatch: '+key)
        official = next(n for n in SERVICES.values() if item['RepoTags'][0] == 'sunmoon-offline/'+n+':2.13.2-recovery-20260927')
        result[official] = {'id':actual['Id'],'volumes':list((actual['Config'].get('Volumes') or {}).keys()),
                            'source_config_sha256':item['Config'].removesuffix('.json')}
    return result


def registry_copy():
    archive = BACKUP/'volumes/registry.tar'
    if archive.stat().st_size != 17868021760 or sha(archive) != REGISTRY_SHA:
        raise RuntimeError('Registry archive checksum mismatch')
    destination = RUN/'registry'; destination.mkdir(mode=0o755)
    files, names, total = {}, set(), 0
    with tarfile.open(archive) as tar:
        for item in tar:
            path = PurePosixPath(item.name)
            if path.is_absolute() or '..' in path.parts or not (item.isfile() or item.isdir()) or str(path) in names:
                raise RuntimeError('Unsafe/duplicate registry member')
            names.add(str(path)); out=destination/path
            if item.isdir():
                out.mkdir(parents=True,exist_ok=True,mode=0o755); continue
            out.parent.mkdir(parents=True,exist_ok=True,mode=0o755)
            digest=hashlib.sha256()
            with tar.extractfile(item) as src, out.open('xb') as dst:
                for block in iter(lambda: src.read(1024**2), b''):
                    dst.write(block); digest.update(block)
            os.chmod(out,0o644); files[str(path)]={'bytes':item.size,'sha256':digest.hexdigest()}; total+=item.size
    # Independent reread of every copied file, not just a successful extraction.
    for name, expected in files.items():
        if (destination/name).stat().st_size != expected['bytes'] or sha(destination/name) != expected['sha256']:
            raise RuntimeError('Copied registry file mismatch')
        parts=PurePosixPath(name).parts
        if 'blobs' in parts and parts[-1]=='data' and parts[-2]!=expected['sha256']:
            raise RuntimeError('Registry blob content differs from digest path')
    registry_permissions(destination)
    write_new(RUN/'registry-files.json',(json.dumps(files,sort_keys=True)+'\n').encode())
    return {'files':len(files),'bytes':total,'all_copied_file_sha256_match':True}


def registry_permissions(destination):
    if destination != RUN/'registry' or destination.resolve()!=destination:
        raise RuntimeError('Unexpected registry permission target')
    count=0
    for path in [destination,*destination.rglob('*')]:
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise RuntimeError('Unexpected registry inode type')
        os.chown(path,10000,10000)
        os.chmod(path,0o750 if path.is_dir() else 0o640)
        count+=1
    return count


def bind(source,target,readonly=True):
    return {'type':'bind','source':str(source),'target':target,'read_only':readonly,'bind':{'create_host_path':False}}


def configuration(image_map):
    shutil.copytree(ROOT/'generated-config',RUN/'config')
    for p in (RUN/'config').rglob('*'):
        os.chown(p,10000,10000); os.chmod(p,0o750 if p.is_dir() else 0o640)
    os.chown(RUN/'config',10000,10000); os.chmod(RUN/'config',0o750)
    for name in ['core-data','redis','database','pg-config','tls','signing','ca-download']:
        uid=1001 if name in ['database','pg-config'] else 999 if name=='redis' else 10000
        p=RUN/name; p.mkdir(mode=0o750); os.chown(p,uid,uid)
    for source,target in [('tls_cert','tls/server.crt'),('tls_key','tls/server.key'),('ca','ca-download/ca.crt'),
                          ('token_key','signing/private_key.pem'),('token_cert','signing/root.crt'),('core_key','signing/secretkey')]:
        write_new(RUN/target,(ROOT/'private'/source).read_bytes())
        os.chown(RUN/target,10000,10000); os.chmod(RUN/target,0o400)
    # Preserve exact nginx TLS filenames from official preparation, without exposing other secrets.
    for p in (ROOT/'data/secret/cert').iterdir():
        if not p.is_file() or p.is_symlink(): raise RuntimeError('Unexpected prepared TLS path')
        dest=RUN/'tls'/p.name
        if dest.exists():
            if dest.read_bytes()!=p.read_bytes(): raise RuntimeError('TLS filename collision')
        else: write_new(dest,p.read_bytes())
        os.chown(dest,10000,10000); os.chmod(dest,0o400)
    replace_env(RUN/'config/core/env',{'READ_ONLY':'true'})
    # No external jobs are started; data copy is additionally mounted read-only.
    upstream=yaml.safe_load((ROOT/'compose/docker-compose.yml').read_text())
    output={'name':PROJECT,'services':{},'networks':{'harbor':{'name':PROJECT,'internal':True}}}
    for role,image_name in SERVICES.items():
        service=copy.deepcopy(upstream['services'][role])
        service.update(image=image_map[image_name]['id'],container_name=PROJECT+'-'+role,restart='no',pull_policy='never',
                       logging={'driver':'local','options':{'max-size':'10m','max-file':'2'}},
                       networks=['harbor'],security_opt=['no-new-privileges:true'],mem_limit='1g',cpus=2,pids_limit=256)
        service.pop('ports',None); service.pop('depends_on',None)
        service.pop('env_file',None)
        if (RUN/'config'/role/'env').exists():
            # Compose raw env-file mode prevents interpolation of original secret bytes.
            service['env_file']=[{'path':str(RUN/'config'/role/'env'),'format':'raw'}]
        volumes=[]
        for item in upstream['services'][role].get('volumes',[]):
            if isinstance(item,str):
                parts=item.split(':'); source,target=parts[:2]
            else: source,target=item['source'],item['target']
            if source.startswith('./common/config/'):
                source=RUN/'config'/source.removeprefix('./common/config/')
            elif target=='/storage': source=RUN/'registry'
            elif target=='/data/': source=RUN/'core-data'
            elif target=='/etc/core/ca/': source=RUN/'ca-download'
            elif target=='/var/lib/redis': source=RUN/'redis'
            elif target=='/etc/core/private_key.pem': source=RUN/'signing/private_key.pem'
            elif target=='/etc/core/key': source=RUN/'signing/secretkey'
            elif target=='/etc/registry/root.crt': source=RUN/'signing/root.crt'
            elif target=='/etc/cert': source=RUN/'tls'
            else: raise RuntimeError('Unexpected upstream volume target: '+target)
            source=Path(source)
            if not source.exists() or not source.resolve().is_relative_to(RUN):
                raise RuntimeError('Runtime bind source missing/outside recovery directory')
            volumes.append(bind(source,target,readonly=target not in ['/data/','/var/lib/redis']))
        service['volumes']=volumes
        targets={v['target'].rstrip('/') for v in volumes}
        tmpfs_allowed={'portal':{'/run','/var/cache/nginx','/var/log/nginx'},
                       'proxy':{'/run','/var/cache/nginx','/var/log/nginx'},
                       'registryctl':{'/var/lib/registry'}}.get(role,set())
        extra={v.rstrip('/') for v in image_map[image_name]['volumes']}-targets
        if extra!=tmpfs_allowed:
            raise RuntimeError('Uncovered declared image volume: '+role)
        if extra:
            service['tmpfs']=[v+':rw,nosuid,nodev,size=32m,uid=10000,gid=10000,mode=0750' for v in sorted(extra)]
        if role=='proxy': service['ports']=['127.0.0.1:18443:8443']
        output['services'][role]=service
    pgcfg={'postgresql.conf':"listen_addresses = '*'\nunix_socket_directories = '/tmp'\nhba_file = '/rehearsal-config/pg_hba.conf'\nident_file = '/rehearsal-config/pg_ident.conf'\nshared_preload_libraries = 'pgaudit'\nlogging_collector = off\nmax_connections = 100\n",
           'pg_hba.conf':'local all postgres trust\nhost registry postgres 0.0.0.0/0 md5\n', 'pg_ident.conf':'',
           'passwd':'postgres:x:1001:1001:PostgreSQL:/tmp:/bin/false\n','group':'postgres:x:1001:\n'}
    for name,content in pgcfg.items():
        write_new(RUN/'pg-config'/name,content.encode()); os.chown(RUN/'pg-config'/name,1001,1001); os.chmod(RUN/'pg-config'/name,0o400)
    pgimage=json.loads(command(['docker','image','inspect',PG_IMAGE]))[0]
    if PG_IMAGE not in pgimage.get('RepoDigests',[]) or set(pgimage['Config'].get('Volumes',{}))!={'/bitnami/postgresql','/docker-entrypoint-initdb.d','/docker-entrypoint-preinitdb.d'}:
        raise RuntimeError('PostgreSQL image identity/volumes changed')
    output['services']['postgresql']={'image':pgimage['Id'],'container_name':PROJECT+'-postgresql',
        'user':'1001:1001','entrypoint':[PG+'postgres'],'command':['-D','/bitnami/postgresql/data','-c','config_file=/rehearsal-config/postgresql.conf'],
        'environment':{'LD_PRELOAD':'/opt/bitnami/common/lib/libnss_wrapper.so','NSS_WRAPPER_PASSWD':'/rehearsal-config/passwd','NSS_WRAPPER_GROUP':'/rehearsal-config/group'},
        'volumes':[bind(RUN/'database','/bitnami/postgresql',False),bind(RUN/'pg-config','/rehearsal-config'),
                   bind(RUN/'pg-config','/docker-entrypoint-initdb.d'),bind(RUN/'pg-config','/docker-entrypoint-preinitdb.d')],
        'tmpfs':['/tmp:rw,nosuid,nodev,noexec,size=128m,mode=1777'],'shm_size':'128m','read_only':True,
        'cap_drop':['ALL'],'security_opt':['no-new-privileges:true'],'restart':'no','pull_policy':'never',
        'networks':['harbor'],'mem_limit':'1g','cpus':2,'pids_limit':128,
        'logging':{'driver':'local','options':{'max-size':'10m','max-file':'2'}}}
    write_new(RUN/'compose.yaml',yaml.safe_dump(output,sort_keys=False).encode())
    # Parse effective Compose privately: it contains environment secrets.
    parsed=json.loads(command(['docker','compose','-f',str(RUN/'compose.yaml'),'config','--format','json']))
    if set(parsed['services'])!=set(SERVICES)|{'postgresql'} or not parsed['networks']['harbor']['internal']:
        raise RuntimeError('Compose service/network scope changed')
    for role,service in parsed['services'].items():
        if service.get('restart')!='no' or service.get('privileged') or service.get('network_mode'):
            raise RuntimeError('Unexpected Compose runtime privilege')
        for mount in service['volumes']:
            if mount['type']!='bind' or not Path(mount['source']).resolve().is_relative_to(RUN):
                raise RuntimeError('Unexpected Compose volume')
        ports=service.get('ports',[])
        if role=='proxy':
            if len(ports)!=1 or ports[0].get('host_ip')!='127.0.0.1' or str(ports[0]['published'])!='18443' or ports[0]['target']!=8443:
                raise RuntimeError('Unexpected published proxy port')
        elif ports: raise RuntimeError('Unexpected published service port')
    rawenv=dict(line.split('=',1) for line in (RUN/'config/core/env').read_text().splitlines() if '=' in line)
    if any(parsed['services']['core']['environment'].get(k)!=v for k,v in rawenv.items()):
        raise RuntimeError('Compose altered original environment values')
    return {'services':sorted(parsed['services']),'internal_network':True,'bind':'127.0.0.1:18443','secrets_preserved_after_compose_parse':True}


def main():
    os.umask(0o077)
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--apply',action='store_true'); args=parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run':True,'root':str(RUN),'registry_bytes':17868021760,'image_count':6,'start_services':False,'delete':False,'entry_switch':False},indent=2)); return
    guard()
    if not RUN.exists():
        raise RuntimeError('Fresh preparation requires source Redis 8.2.1 renderer; use reviewed existing candidate only')
    if RUN.exists(): raise RuntimeError('Recovery preparation already exists; no overwrite/retry')
    RUN.mkdir(mode=0o700)
    image_map=images(); write_new(RUN/'images.json',(json.dumps(image_map,indent=2)+'\n').encode())
    print('Six offline image identities verified; copying registry archive',flush=True)
    registry=registry_copy(); print('All copied registry files verified',flush=True)
    config=configuration(image_map)
    files={str(p.relative_to(RUN)):sha(p) for p in RUN.rglob('*') if p.is_file() and p.parts[len(RUN.parts)] in ['config','pg-config','tls','signing','ca-download']}
    files['compose.yaml']=sha(RUN/'compose.yaml')
    result={'prepared':True,'registry':registry,'configuration':config,'immutable_files':files,'started_services':False}
    write_new(RUN/'preparation.json',(json.dumps(result,indent=2)+'\n').encode())
    print(json.dumps({k:v for k,v in result.items() if k!='immutable_files'},indent=2))


if __name__=='__main__':
    try: main()
    except Exception as exc:
        raise SystemExit('[recovery-candidate] FAIL: '+(str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__+'; private details withheld')) from None
