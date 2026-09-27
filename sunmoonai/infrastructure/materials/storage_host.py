"""Cloud data mount preflight and first-time directory preparation.

未经实机验证. Mounting/formatting/fstab/cleanup are outside this adapter.
Only called after node installation and cluster ownership checks.
"""
import json
from pathlib import Path
import re
import subprocess

from os_install import safe_directory, exact_file
from image_import import inspect_archive, import_items
from bundle import below
from storage_resources import images, validate


def mount_view(path, exact=False):
    result = subprocess.run(['findmnt', '--json', '--mountpoint' if exact else '--target', str(path),
                             '--output', 'TARGET,SOURCE,FSTYPE,UUID,OPTIONS,FSROOT'],
                            capture_output=True, check=True, text=True, timeout=15)
    views = json.loads(result.stdout)['filesystems']
    if len(views) != 1:
        raise ValueError('Ambiguous storage mount')
    return views[0]


def execute(root, manifest, data, work, spec, node_name, uid, apply=False):
    validate(spec)
    node = spec['paths'][node_name]
    if not node['enabled']:
        return {'storage_host_skipped': True, 'node': node_name}
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', node['uuid']):
        raise ValueError('Pre-recorded data filesystem UUID required')
    path, mount = Path(node['path']), Path(node['mountpoint'])
    for candidate in (mount, path, *path.parents):
        if candidate.resolve() != candidate or (candidate.exists() and (
                not candidate.is_dir() or candidate.stat().st_uid != 0 or candidate.stat().st_mode & 0o022)):
            raise ValueError('Storage parents must be real root-owned non-writable-by-others directories')
    view = mount_view(mount, exact=True)
    system = mount_view(Path('/'), exact=True)
    if (view.get('uuid') != node['uuid'] or view['fstype'] not in ('ext4', 'xfs')
            or view['target'] != str(mount) or view.get('fsroot') != '/'
            or 'rw' not in view['options'].split(',') or system.get('uuid') == view['uuid']):
        raise ValueError('Expected independent writable data filesystem not mounted; no fallback to system disk')
    # No nested filesystem may redirect a child directory to another disk.
    existing = path
    while not existing.exists():
        existing = existing.parent
    if mount_view(existing)['target'] != str(mount):
        raise ValueError('Unexpected nested mount under storage root')
    receipt = work / 'storage-host.json'
    identity = {'uid': uid, 'node': node_name, 'path': str(path), 'mountpoint': str(mount), 'uuid': node['uuid']}
    if receipt.exists():
        if receipt.resolve() != receipt or receipt.stat().st_uid != 0 or receipt.stat().st_mode & 0o077 or json.loads(receipt.read_text()) != identity:
            raise ValueError('Storage ownership receipt differs')
    elif path.exists() and any(path.iterdir()):
        raise ValueError('Unowned storage directory has data; no adoption or cleanup')
    records = images(manifest, data)
    for item in records:
        inspect_archive(below(root, item['material_path']), item)
    if apply:
        safe_directory(path)
        # Record ownership before importing, allowing safe resume after a
        # transport/import failure; this is not a completion/IO receipt.
        exact_file(receipt, (json.dumps(identity, sort_keys=True, indent=2) + '\n').encode(), 0o600)
        import_items(root, records, work)
    return {'storage_host_ready': apply, 'preflight_passed': True, **identity, 'io_validated': False}
