#!/usr/bin/env python3
"""Verify a pinned Windows bundle, conditionally upload, then independently read back.

Only curl (SigV4 + TLS) and kubectl are external dependencies. Secrets arrive on stdin,
stay in a private temporary curl config, and never appear in argv or command output.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import stat
import subprocess
import sys
import tempfile
import time
import zipfile

CHUNK = 1024 * 1024
BUCKET = 'agent-releases'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def hash_stream(stream):
    sha, size = hashlib.sha256(), 0
    while data := stream.read(CHUNK):
        sha.update(data)
        size += len(data)
    return sha.hexdigest(), size


def safe_path(name):
    require(isinstance(name, str) and len(name) <= 240, 'Invalid bundle path')
    require(all(re.fullmatch(r'[A-Za-z0-9_@.-]+', p) and p not in ('.', '..')
                and not p.endswith('.') and not re.match(r'(?i)^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)', p)
                for p in name.split('/')), 'Unsafe bundle path')
    return str(PurePosixPath(name))


def verify_zip(stream, release):
    require(re.fullmatch(r'windows-x64/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.zip', release['object_key'])
            and '..' not in release['object_key'], 'Unsafe release key')
    require(0 < release['size_bytes'] <= 1024**3, 'Unsupported ZIP size')
    for key in ('zip_sha256', 'manifest_sha256'):
        require(re.fullmatch('[a-f0-9]{64}', release[key]), 'Invalid configured checksum')
    digest, size = hash_stream(stream)
    require((digest, size) == (release['zip_sha256'], release['size_bytes']), 'ZIP SHA256/size mismatch')
    stream.seek(0)
    with zipfile.ZipFile(stream) as archive:
        members, names, total = {}, set(), 0
        for item in archive.infolist():
            require(not stat.S_ISLNK(item.external_attr >> 16) and not item.flag_bits & 1, 'Linked/encrypted ZIP refused')
            if item.is_dir():
                safe_path(item.filename.rstrip('/'))
                continue
            name = safe_path(item.filename)
            require(name.lower() not in names, 'Duplicate archive path')
            names.add(name.lower())
            members[name] = item
            total += item.file_size
        require(len(members) <= 10000 and total <= 2 * 1024**3, 'Oversized bundle')
        require('bundle-manifest.json' in members, 'Missing manifest')
        require(members['bundle-manifest.json'].file_size <= 4 * CHUNK, 'Oversized manifest')
        manifest_bytes = archive.read('bundle-manifest.json')
        require(hashlib.sha256(manifest_bytes).hexdigest() == release['manifest_sha256'], 'Manifest SHA256 mismatch')
        manifest = json.loads(manifest_bytes)
        require(manifest['schema'] == 1 and manifest['platform'] == 'win32' and manifest['architecture'] == 'x64'
                and manifest['relayProtocol'] == 1 and manifest['agentVersion'] == release['version']
                and manifest['codexVersion'] == release['codex_version']
                and manifest['sourceRevision'] == release['source_revision'], 'Bundle release identity mismatch')
        expected = manifest['files']
        require(len(expected) == len(members) - 1 and len({f['path'].lower() for f in expected}) == len(expected), 'Manifest inventory mismatch')
        for entry in expected:
            name = safe_path(entry['path'])
            require(name != 'bundle-manifest.json' and name in members, 'Missing bundle file')
            require(members[name].file_size == entry['size'], 'Bundle size mismatch')
            with archive.open(name) as body:
                require(hash_stream(body) == (entry['sha256'], entry['size']), 'Bundle file digest mismatch')
    stream.seek(0)
    return {'zip_sha256': digest, 'size_bytes': size, 'manifest_sha256': release['manifest_sha256'], 'files': len(members)}


@contextmanager
def tunnel(kubectl, kubeconfig, namespace):
    require(re.fullmatch('[a-z0-9-]+', namespace), 'Invalid namespace')
    argv = [kubectl, '--kubeconfig=' + kubeconfig, '--context=kind-sunmoon-kind', '-n', namespace,
            'port-forward', '--address=127.0.0.1', 'service/object-storage', '0:9000']
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            deadline, port = time.monotonic() + 20, None
            while time.monotonic() < deadline and process.poll() is None:
                if selector.select(timeout=0.5):
                    match = re.search(r'Forwarding from 127\.0\.0\.1:(\d+)', process.stdout.readline())
                    if match:
                        port = int(match[1])
                        break
        require(port is not None, 'Storage tunnel unavailable')
        yield port
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdout.close()


class S3Curl:
    def __init__(self, directory, host, port, ca, region, user, password):
        require(re.fullmatch('[A-Za-z0-9_-]+', user) and re.fullmatch('[A-Za-z0-9]{40}', password), 'Invalid credential input')
        require(re.fullmatch('[a-z0-9-]+', region), 'Invalid region')
        self.directory = directory
        self.config = directory / (user + '.curl')
        with self.config.open('x', encoding='utf-8') as f:
            os.chmod(self.config, 0o600)
            f.write('user = "' + user + ':' + password + '"\n')
        self.base = ['curl', '-q', '--config', str(self.config), '--silent', '--show-error',
                     '--noproxy', '*', '--proxy', '', '--proto', '=https',
                     '--connect-timeout', '5', '--max-time', '900',
                     '--cacert', ca, '--aws-sigv4', 'aws:amz:' + region + ':s3',
                     '--resolve', f'{host}:{port}:127.0.0.1']
        self.url = f'https://{host}:{port}/{BUCKET}/'

    def request(self, method, key, *, stream=None, digest=None, metadata=None, headers=()):
        require(re.fullmatch(r'[A-Za-z0-9/._-]+', key) and '..' not in key, 'Invalid object key')
        argv = self.base + ['--request', method, '--dump-header', str(self.directory / 'headers'), self.url + key]
        for header in headers:
            argv += ['--header', header]
        if stream is not None:
            # An inherited, already verified descriptor prevents a path replacement race.
            argv += ['--upload-file', '/proc/self/fd/' + str(stream.fileno()),
                     '--header', 'Content-Type: application/zip', '--header', 'If-None-Match: *',
                     '--header', 'x-amz-content-sha256: ' + digest,
                     '--header', 'x-amz-meta-sha256: ' + digest,
                     '--header', 'x-amz-meta-manifest-sha256: ' + metadata]
        with (self.directory / 'curl-error').open('wb') as errors:
            process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=errors,
                                       pass_fds=(stream.fileno(),) if stream else ())
            try:
                result = hash_stream(process.stdout)
                require(process.wait(timeout=10) == 0, 'Storage transfer failed (inspect endpoint/TLS/network)')
            finally:
                process.stdout.close()
                if process.poll() is None:
                    process.kill()
                    process.wait()
        raw = (self.directory / 'headers').read_text()
        blocks = [b for b in raw.split('\n\n') if b.startswith('HTTP/')]
        require(bool(blocks), 'Missing storage response')
        lines = blocks[-1].splitlines()
        status = int(lines[0].split()[1])
        fields = dict((k.lower(), v.strip()) for line in lines[1:] if ':' in line for k, v in [line.split(':', 1)])
        return status, fields, result


def publish(stream, release, writer, reader):
    key = release['object_key']
    status, _, _ = writer.request('PUT', key, stream=stream, digest=release['zip_sha256'], metadata=release['manifest_sha256'])
    # Never retry a conflict or replace an object. A repeated identical release can only be read/verified.
    require(status in (200, 412), 'Conditional upload refused; no automatic overwrite/retry')
    read_status, fields, content = reader.request('GET', key)
    require(read_status == 200, 'Independent readback failed')
    require(content == (release['zip_sha256'], release['size_bytes']), 'Readback digest/size mismatch')
    require(fields.get('x-amz-meta-sha256') == release['zip_sha256']
            and fields.get('x-amz-meta-manifest-sha256') == release['manifest_sha256'], 'Readback metadata mismatch')
    # Safe negative permission probes: no destructive actions, no foreign writes.
    denied_read, _, _ = writer.request('GET', key)
    require(denied_read == 403, 'Writer unexpectedly readable')
    denied_write, _, _ = reader.request('PUT', key, headers=('If-None-Match: *',))
    require(denied_write == 403, 'Reader unexpectedly writable')
    return {'uploaded': status == 200, 'existing_preserved': status == 412,
            'readback_verified': True, 'writer_read_denied': True, 'reader_write_denied': True}


def unchanged(stream, before):
    after = os.fstat(stream.fileno())
    return (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip', required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--kubectl')
    parser.add_argument('--kubeconfig')
    parser.add_argument('--namespace', default='data-platform-dev')
    parser.add_argument('--ca')
    args = parser.parse_args()
    inputs = json.load(sys.stdin)
    release = inputs['release']
    fd = os.open(args.zip, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode), 'ZIP must be a regular file')
        checked = verify_zip(stream, release)
        require(unchanged(stream, before), 'ZIP changed during validation')
        if not args.apply:
            print(json.dumps({'action': 'verified-local', **checked}))
            return
        require(args.kubectl and args.kubeconfig and args.ca and inputs['release']['bucket'] == BUCKET, 'Missing deployment input')
        with tunnel(args.kubectl, args.kubeconfig, args.namespace) as port, tempfile.TemporaryDirectory(prefix='sunmoon-release-') as folder:
            root = Path(folder)
            clients = {role: S3Curl(root, 'object-storage.' + args.namespace + '.svc.cluster.local', port, args.ca,
                                   inputs['region'], release[role], inputs['credentials'][role + '_secret'])
                       for role in ('reader', 'writer')}
            result = publish(stream, release, clients['writer'], clients['reader'])
        require(unchanged(stream, before), 'ZIP changed during upload')
        print(json.dumps({'action': 'uploaded-and-verified', 'bucket': BUCKET, 'key': release['object_key'], **checked, **result}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never print HTTP bodies or SDK errors containing credentials.
        print('Release operation stopped: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
