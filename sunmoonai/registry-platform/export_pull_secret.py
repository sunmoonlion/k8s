#!/usr/bin/env python3
"""Export a pull Secret into ~/private only. No cluster or network access."""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import stat

from credentials import REGISTRY, docker_config, load_credentials
from pull_secret import SecretError, dns_name


def private_parent(output):
    root = Path.home() / 'private'
    if not output.is_absolute() or '..' in output.parts or not output.is_relative_to(root):
        raise ValueError('Output must be an absolute path under ~/private')
    relative = output.relative_to(root)
    if not relative.parts:
        raise ValueError('Output filename required')
    descriptor = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for index in range(len(relative.parts)):
            info = os.fstat(descriptor)
            if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) & 0o077:
                raise ValueError('Private output directories must be caller-owned and owner-only')
            try:
                os.stat('.git', dir_fd=descriptor, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise ValueError('Refusing output inside a Git checkout')
            if index < len(relative.parts) - 1:
                child = os.open(relative.parts[index], os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                dir_fd=descriptor)
                os.close(descriptor)
                descriptor = child
        return descriptor, relative.name
    except BaseException:
        os.close(descriptor)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--namespace', required=True)
    parser.add_argument('--name', default='harbor-registry-secret')
    parser.add_argument('--credentials-file', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    dns_name(args.namespace)
    dns_name(args.name, subdomain=True)
    mode = os.environ.get('SUNMOON_DEPLOY_DRY_RUN', 'false')
    if mode not in ('true', 'false') or (args.apply and (args.dry_run or mode == 'true')):
        parser.error('Invalid or conflicting execution mode')
    if not args.apply:
        print(f'Plan: export {args.namespace}/{args.name}, registry={REGISTRY}; '
              'requires a new output file under ~/private; no credentials read')
        return
    descriptor, filename = private_parent(args.output)
    temporary = '.pull-secret-' + secrets.token_hex(16)
    created = False
    try:
        path = args.credentials_file or os.environ.get('REGISTRY_CREDENTIALS_FILE')
        if not path:
            raise ValueError('Explicit private credentials file required')
        data = base64.b64encode(docker_config(load_credentials(path)).encode()).decode()
        payload = {'apiVersion': 'v1', 'kind': 'Secret',
                   'metadata': {'name': args.name, 'namespace': args.namespace},
                   'type': 'kubernetes.io/dockerconfigjson', 'data': {'.dockerconfigjson': data}}
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=descriptor)
        created = True
        with os.fdopen(fd, 'w') as handle:
            json.dump(payload, handle, ensure_ascii=True, indent=2)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        # Atomic publication without replacing any existing file, link or backup.
        os.link(temporary, filename, src_dir_fd=descriptor, dst_dir_fd=descriptor,
                follow_symlinks=False)
        os.fsync(descriptor)
    finally:
        try:
            if created:
                os.unlink(temporary, dir_fd=descriptor)
        finally:
            os.close(descriptor)
    print('Private pull Secret exported (0600); no API calls or login validation performed')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, SecretError):
        raise SystemExit('Export failed: check private credentials, output directory ownership/permissions '
                         'and that output does not exist. Private details suppressed.') from None
