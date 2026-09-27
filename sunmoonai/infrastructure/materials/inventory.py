#!/usr/bin/env python3
"""Read-only inventory for cluster material retirement; never moves/deletes files.

Candidate means review after migration, NOT permission to delete. Output contains
paths, sizes, hashes and code reference locations, never configuration contents.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess


def replacement(path):
    """Explicit historical cluster set; platform archives default to keep."""
    name = path.name
    if path.parent.name == 'images':
        if re.fullmatch(r'calico_[a-z0-9-]+_v3\.28\.2\.tar', name) or name == 'calico-v3.28.2.yaml':
            return 'Calico 3.32.2 manifest and its exact image set'
        if name == 'quay.io_tigera_operator_v1.3.5.tar':
            return 'Review retirement of old operator when shared Calico manifest adapter is complete'
        if re.fullmatch(r'registry\.k8s\.io_kube-(apiserver|controller-manager|scheduler|proxy)_v1\.30\.4\.tar', name):
            return 'kubeadm 1.36.4 required control-plane images'
        return {
            'registry.k8s.io_coredns_coredns_v1.11.1.tar': 'kubeadm 1.36.4: CoreDNS v1.14.2',
            'registry.k8s.io_pause_3.9.tar': 'kubeadm 1.36.4: pause 3.10.2',
            'registry.k8s.io_etcd_3.5.12-0.tar': 'kubeadm 1.36.4: etcd 3.6.8-0',
        }.get(name)
    if path.parent.name == 'debs':
        if re.fullmatch(r'(kubeadm|kubelet|kubectl)_1\.30\.4-1\.1_amd64\.deb', name):
            return 'Pinned 1.36.4 binary plus explicit systemd units and OS dependency closure'
        return {
            'cri-tools_1.30.1-1.1_amd64.deb': 'crictl v1.36.0',
            'kubernetes-cni_1.2.0-00_amd64.deb': 'Calico 3.32.2 CNI; bootstrap binaries/dependencies still need closure',
        }.get(name)
    return {
        'tars/nerdctl-full-2.1.3-linux-amd64.tar.gz': 'nerdctl 2.3.5 + containerd 2.3.4 + runc 1.4.3; CNI closure separately required',
        'tars/crictl-v1.30.0-linux-amd64.tar.gz': 'crictl v1.36.0',
        'charts/tigera-operator-v3.28.2.tgz': 'Shared Calico 3.32.2 adapter; old operator path must first be retired',
    }.get(path.as_posix())


def code_references(repo, names):
    result = subprocess.run(['rg', '--files', 'sunmoonai'], cwd=repo,
                            capture_output=True, text=True, check=True)
    references = {name: [] for name in names}
    broad = []
    for name in result.stdout.splitlines():
        p = Path(name)
        if p.suffix not in {'.sh', '.py', '.conf', '.ps1'} or 'results' in p.parts or 'docs' in p.parts:
            continue
        if '/materials/' in name:
            continue  # Evidence/download tooling is not a deployment consumer.
        target = repo / p
        if target.is_symlink() or target.stat().st_size > 2 * 1024**2:
            continue
        try:
            lines = target.read_text().splitlines()
        except UnicodeError:
            continue
        for number, line in enumerate(lines, 1):
            if line.lstrip().startswith('#'):
                continue
            location = f'{name}:{number}'
            for archive in names:
                if archive in line:
                    references[archive].append(location)
            if ('packages-to-be-installed' in line or
                re.search(r'nerdctl-full\*|kube\w*\*.*\.deb|images/\*|tars/\*', line)):
                broad.append(location)
    return references, sorted(set(broad))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    root = args.root.expanduser().resolve(strict=True)
    repo = args.repo.expanduser().resolve(strict=True)
    groups, seen, candidates, preserved, errors, skipped = {}, set(), [], [], [], []

    def error(exc):
        errors.append({'path': str(exc.filename), 'errno': exc.errno})

    for directory, dirs, files in os.walk(root, followlinks=False, onerror=error):
        dirs.sort()
        files.sort()
        for name in [*dirs, *files]:
            path = Path(directory) / name
            rel = path.relative_to(root)
            try:
                info = path.lstat()
            except OSError as exc:
                error(exc)
                continue
            if stat.S_ISLNK(info.st_mode):
                skipped.append(rel.as_posix())
                continue
            group = '/'.join(rel.parts[:2]) if rel.parts[0] == 'releases' else rel.parts[0]
            sums = groups.setdefault(group, {'files': 0, 'logical_bytes': 0, 'allocated_unique_bytes': 0})
            identity = (info.st_dev, info.st_ino)
            if identity not in seen:
                sums['allocated_unique_bytes'] += info.st_blocks * 512
                seen.add(identity)
            if not stat.S_ISREG(info.st_mode):
                continue
            sums['files'] += 1
            sums['logical_bytes'] += info.st_size
            next_version = replacement(rel) if len(rel.parts) == 2 else None
            superseded = rel.as_posix() == 'releases/kubeadm-1.36.4-linux-amd64/tars/nerdctl-full-2.3.5-linux-amd64.tar.gz'
            if next_version or superseded:
                with path.open('rb') as stream:
                    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
                after = path.stat()
                if (info.st_ino, info.st_size, info.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                    raise RuntimeError('Candidate changed during read-only inventory')
                candidates.append({
                    'path': rel.as_posix(), 'bytes': info.st_size,
                    'allocated_bytes': info.st_blocks * 512, 'sha256': digest,
                    'hardlinks': info.st_nlink,
                    'category': 'superseded_new_download' if superseded else 'old_cluster_material',
                    'replacement': next_version or 'Separately pinned containerd 2.3.4/runc 1.4.3; minimal nerdctl 2.3.5',
                    'delete_eligible_now': False,
                })
            elif len(rel.parts) == 2 and rel.parts[0] in {'images', 'debs', 'charts', 'tars'}:
                preserved.append({'path': rel.as_posix(), 'allocated_bytes': info.st_blocks * 512,
                                  'reason': 'Platform/app version unchanged or dependency not proven obsolete'})
    references, broad = code_references(repo, {Path(c['path']).name for c in candidates})
    for item in candidates:
        item['literal_code_references'] = references[Path(item['path']).name]
    lock = json.loads(Path(__file__).with_name('cluster-artifacts.lock.json').read_text())
    totals = {}
    for item in candidates:
        category = totals.setdefault(item['category'], {'files': 0, 'allocated_bytes_upper_bound': 0})
        category['files'] += 1
        category['allocated_bytes_upper_bound'] += item['allocated_bytes'] if item['hardlinks'] == 1 else 0
    print(json.dumps({
        'schema': 1, 'checked_at': datetime.now(timezone.utc).isoformat(), 'root': str(root),
        'readonly': True, 'deleted': False, 'released_bytes': 0,
        'complete_regular_file_inventory': not errors, 'errors': errors,
        'symlinks_not_followed': len(skipped), 'symlink_examples': skipped[:20],
        'allocation_scope': 'Unique regular files and directories; symlink allocations and filesystem metadata excluded',
        'groups': groups, 'allocated_unique_bytes': sum(g['allocated_unique_bytes'] for g in groups.values()),
        'candidate_totals': totals, 'candidates': candidates, 'preserved_top_level_materials': preserved,
        'broad_path_code_references': broad,
        'reference_limit': 'Literal locations and broad path indicators only; dynamic references require adapter review. Empty references do not authorize deletion.',
        'cluster_closure_complete': lock['closure_complete'], 'cluster_closure_pending': lock['pending'],
        'gates': ['finish migration acceptance and rollback observation',
                  'validate complete replacement materials and deployment adapters',
                  'check retained release/backup references and exact hashes before final cleanup',
                  'preserve Harbor cold backups, platform/app versions, old client and containers/volumes'],
        'physical_space_limit': 'File allocation estimates; C: space return requires owner-operated WSL shutdown/compaction.',
    }, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
