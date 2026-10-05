#!/usr/bin/env python3
"""Show locked material ownership and local presence without downloading or publishing."""
import argparse
import json
from pathlib import Path
import re
import sys

import yaml

INFRA = Path(__file__).resolve().parents[1]
LOCKS = INFRA / 'artifacts'
OWNER = re.compile(r'^(cluster|host|registry|shared|components)/[a-z0-9-]+(/[a-z0-9-]+)*$')


def image_path(image):
    owner = image['material_owner']
    if not OWNER.fullmatch(owner) or not re.fullmatch(r'sha256:[a-f0-9]{64}', image['manifest_digest']):
        raise ValueError('Invalid material owner or digest: ' + image['id'])
    return owner + '/images/' + image['id'] + '-' + image['manifest_digest'][7:] + '.tar'


def code_path(owner):
    """Resolve responsibility, not another copy of component parameters or versions."""
    if owner == 'components/foundations/storage':
        return 'gitops/components/foundations/storage.yaml.j2'
    if owner.startswith('components/'):
        path = INFRA.parent / 'gitops' / owner
        if (path/'config.yaml').is_file():
            return 'gitops/' + owner + '/config.yaml'
        return 'gitops/' + owner if path.is_dir() else '未接入组件声明'
    if owner.startswith('cluster/'):
        return 'infrastructure/cluster'
    if owner.startswith('registry/'):
        return 'infrastructure/registry'
    return {
        'host/docker': 'infrastructure/host',
        'host/entry': 'infrastructure/entry',
        'shared/tools': 'infrastructure/tools',
        'shared/flux': 'infrastructure/flux',
        'shared/build-base-images': 'infrastructure/applications/config.yaml',
    }[owner]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', default='environments/kind/site.yaml')
    parser.add_argument('--owner', default='all', help='Exact ownership directory or parent, e.g. components/data-platform')
    args = parser.parse_args()
    site = Path(args.site)
    if not site.is_absolute():
        site = INFRA / site
    config = yaml.safe_load(site.read_text())
    cache = Path(config['artifact_cache_root'])
    if not cache.is_absolute() or cache == Path('/') or cache.is_symlink():
        raise ValueError('Invalid material cache root')
    if args.owner != 'all' and not re.fullmatch(r'[a-z0-9-]+(/[a-z0-9-]+)*', args.owner):
        raise ValueError('Invalid owner filter')
    rows = []
    tracked = set()

    def local(relative):
        p = cache / relative
        if p.is_symlink() or any(x.is_symlink() for x in p.parents if x != cache.parent):
            raise ValueError('Redirected material path: ' + str(p))
        return '存在（未校验）' if p.is_file() else '缺失'

    def record(owner, kind, identifier, relative, target):
        if not OWNER.fullmatch(owner):
            raise ValueError('Invalid owner: ' + owner)
        status = local(relative) if relative else '无需独立归档'
        rows.append([owner, kind, identifier, relative or '—', status, target])
        if relative:
            tracked.update([relative, relative + '.json', relative + '.part'])

    files = json.loads((LOCKS/'files.lock.json').read_text())['files']
    for f in files:
        p = Path(f['path'])
        if p.is_absolute() or '..' in p.parts:
            raise ValueError('Invalid file path: ' + f['path'])
        owner = p.parent.parent.as_posix()
        record(owner, f['kind'], f['id'], f['path'], '本地引导/安装/复制；不发布为镜像')
    upstream = json.loads((LOCKS/'upstream-images.lock.json').read_text())['images']
    node = json.loads((LOCKS/'node-image.lock.json').read_text())['images']
    derived = json.loads((INFRA.parent/'gitops/components/data-platform/ragflow/image.lock.json').read_text())['images']
    bootstrap = {f['id'] for f in json.loads((LOCKS/'bootstrap-archives.lock.json').read_text())['files']}
    host = {f['id'] for f in json.loads((LOCKS/'host-archives.lock.json').read_text())['files']}
    for image in upstream + node + derived:
        owner = image['material_owner']
        relative = image_path(image)
        if image.get('group') == 'registry':
            relative = ''
            target = 'Harbor 官方离线包内启动镜像；宿主 Docker'
        elif image.get('group') == 'cluster-build':
            relative = ''
            target = '节点构建输入；嵌入 KIND 节点，不要求独立归档'
        elif image['id'] in bootstrap | host:
            target = 'Docker/节点离线导入'
        else:
            target = config['registry_address'] + '/platform/' + image['id'] + '@' + image['manifest_digest']
        record(owner, 'image', image['id'], relative, target)
    for lock in sorted((INFRA.parent/'gitops/components/app-platform').glob('*-app/*/image.lock.yaml')):
        image = yaml.safe_load(lock.read_text())
        owner = lock.parent.relative_to(INFRA.parent/'gitops').as_posix()
        record(owner, 'application-image', image['repository'], '', config['registry_address'] + '/platform/' + image['repository'] + '@' + image['digest'])
    # Match nested bundles to their existing component owner, not to their inner type directory.
    known_owners = sorted({row[0] for row in rows}, key=len, reverse=True)
    # Older versions and partial files are visible, never silently classified as deletable.
    for p in sorted(cache.rglob('*')):
        if p.is_symlink():
            raise ValueError('Redirected cache entry: ' + str(p))
        if p.is_file() and p.relative_to(cache).as_posix() not in tracked:
            relative = p.relative_to(cache).as_posix()
            owner = next((owned for owned in known_owners if relative.startswith(owned + '/')),
                         p.parent.parent.relative_to(cache).as_posix())
            rows.append([owner, '未被当前锁引用', p.name, relative, '存在（未校验）', '保留；需另行核对清理'])
    selected = [r for r in rows if args.owner == 'all' or r[0] == args.owner or r[0].startswith(args.owner + '/')]
    if not selected:
        raise ValueError('No materials for owner: ' + args.owner)
    print('物料根：' + str(cache))
    print('存在仅指文件可见；未校验内容，也未查询 Harbor。')
    print('归属\t类型\t物料 ID\t批次内路径\t本地状态\t使用方式/Harbor 目标\t配置/部署代码')
    for row in sorted(selected):
        print('\t'.join(row + [code_path(row[0])]))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
