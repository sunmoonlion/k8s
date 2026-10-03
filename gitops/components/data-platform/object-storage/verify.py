#!/usr/bin/env python3
"""Actual TLS/versioned S3 acceptance. Only this run's randomly named bucket is removed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for field in ('kubectl', 'kubeconfig', 'namespace', 'mc', 'ca'):
        ap.add_argument('--' + field, required=True)
    ap.add_argument('--application')
    ap.add_argument('--app-namespace')
    ap.add_argument('--bucket')
    ap.add_argument('--runtime-check')
    args = ap.parse_args()
    require(os.geteuid() == 0, 'Private root input requires root')
    secret = json.load(sys.stdin)
    env = dict(os.environ)
    for key in ('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'):
        env.pop(key, None)
    env['NO_PROXY'] = '*'
    env['HOME'] = '/nonexistent'
    host = 'object-storage.' + args.namespace + '.svc.cluster.local'
    prefix = [args.kubectl, '--kubeconfig=' + args.kubeconfig, '--context=kind-sunmoon-kind', '-n', args.namespace]
    tunnel = subprocess.Popen(prefix + ['port-forward','--address=127.0.0.1','service/object-storage','0:9000'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(tunnel.stdout, selectors.EVENT_READ)
            port = None
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and tunnel.poll() is None:
                if selector.select(timeout=0.5):
                    match = re.search(r'Forwarding from 127\.0\.0\.1:(\d+)', tunnel.stdout.readline())
                    if match:
                        port = int(match.group(1))
                        break
        require(port is not None, 'Object storage tunnel did not become ready')
        with tempfile.TemporaryDirectory(prefix='sunmoon-s3-check-') as folder:
            root = Path(folder)
            ca = root / 'certs' / 'CAs'
            ca.mkdir(parents=True, mode=0o700)
            shutil.copyfile(args.ca, ca / 'platform.crt')
            config = {'version':'10','aliases':{'owned':{'url':f'https://{host}:{port}','accessKey':secret['root_user'],'secretKey':secret['root_password'],'api':'S3v4','path':'on'}}}
            config_path = root / 'config.json'
            config_path.write_text(json.dumps(config))
            config_path.chmod(0o600)
            command = [args.mc, '--config-dir', folder, '--resolve', f'{host}:{port}=127.0.0.1', '--json']
            def mc(*argv):
                out = subprocess.run(command + list(argv), capture_output=True, env=env, timeout=45)
                require(out.returncode == 0, 'S3 operation failed: ' + argv[0])
                return out.stdout
            if args.application:
                require(re.fullmatch(r'(info|knowledge|investment)', args.application), 'Unsupported storage application')
                require(args.bucket == args.application + '-originals', 'Unexpected domain bucket')
                runtime = subprocess.run([args.kubectl, '--kubeconfig=' + args.kubeconfig, '--context=kind-sunmoon-kind', '-n', args.app_namespace, 'exec', '-i', 'deployment/' + args.application + '-api', '--', 'python', '-'], input=Path(args.runtime_check).read_text(), text=True, capture_output=True, env=env, timeout=90)
                result = json.loads(runtime.stdout)
                try:
                    require(runtime.returncode == 0 and result.get('passed') is True, 'Actual application S3 acceptance failed')
                    print(json.dumps({'application':args.application, 'bucket':args.bucket, 'checks':result['checks']}))
                finally:
                    # Only this API probe's two UUID-keyed versions are removed by root.
                    for record in result['created_records']:
                        require(record['bucket'] == args.bucket and re.fullmatch(r'sunmoon-acceptance/[a-f0-9]{32}', record['key']), 'Refuse foreign acceptance object cleanup')
                        require(isinstance(record['version_id'],str) and 0 < len(record['version_id']) < 256, 'Unexpected acceptance version')
                        mc('rm','--version-id',record['version_id'],'owned/' + args.bucket + '/' + record['key'])
                return
            bucket = 'sunmoon-acceptance-' + uuid.uuid4().hex
            target = 'owned/' + bucket
            created = False
            try:
                mc('mb', target)
                created = True
                mc('version','enable', target)
                content = b'SunMoonAI licensed TLS versioned object acceptance\n'
                file = root / 'payload'
                file.write_bytes(content)
                mc('cp', str(file), target + '/payload')
                stat = json.loads(mc('stat', target + '/payload'))
                require(stat.get('versionID') not in (None, '', 'null'), 'S3 version ID was not returned')
                returned = mc('cat', target + '/payload')
                require(returned == content, 'S3 returned different bytes')
                print(json.dumps({'tls_ca_verified':True,'licensed_s3_write_read':True,'object_version_id':True,'sha256':hashlib.sha256(returned).hexdigest(),'scope':'Current server S3 protocol, not restart/rebuild persistence'}))
            finally:
                if created:
                    require(re.fullmatch(r'sunmoon-acceptance-[0-9a-f]{32}', bucket), 'Refuse foreign bucket cleanup')
                    mc('rm','--recursive','--force','--versions',target)
                    mc('rb',target)
    finally:
        tunnel.terminate()
        try:
            tunnel.wait(timeout=5)
        except subprocess.TimeoutExpired:
            tunnel.kill()
            tunnel.wait()

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never emit remote errors: they can contain licensing/account details.
        public = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print(json.dumps({'passed':False,'error':public}))
        sys.exit(1)
