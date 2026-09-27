#!/usr/bin/env python3
"""Read-only R2-B archive verification; hashes required amd64 OCI blobs, no load."""
import hashlib
import json
from pathlib import Path
import tarfile

from space_reclaim_20260927 import RESULTS, now


def main():
    batch = json.loads((RESULTS / 'luna-r2-classification.20260927.json').read_text())
    images = batch['b']['images']
    root = Path('/home/zymun/packages-to-be-installed')
    archives = sorted((root / 'images').glob('*.tar'))
    for folder in ['releases/kind-1.36.4-calico-3.32.2-linux-amd64/images',
                   'releases/build-template-20260926-linux-amd64/images',
                   'releases/harbor-preserve-20260926/preparation/images']:
        archives += sorted((root / folder).glob('*.tar'))
    matches, examined = {}, []
    for archive in archives:
        with tarfile.open(archive, 'r:') as tar:
            members = {m.name.removeprefix('./'): m for m in tar.getmembers() if m.isfile()}
            hits = [i for i in images if 'blobs/sha256/'+i['descriptor_digest'][7:] in members]
            examined.append({'archive': str(archive), 'matching_image_count': len(hits)})
            if not hits:
                continue
            checked = set()
            def read(digest, parse=False):
                name = 'blobs/sha256/' + digest[7:]
                if name not in members:
                    raise RuntimeError('Required archive blob missing: ' + digest)
                with tar.extractfile(members[name]) as stream:
                    if parse:
                        raw = stream.read()
                        actual = hashlib.sha256(raw).hexdigest()
                    else:
                        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
                if 'sha256:' + actual != digest:
                    raise RuntimeError('Archive digest mismatch: ' + digest)
                checked.add(digest)
                return json.loads(raw) if parse else None
            def walk(digest):
                if digest in checked:
                    return
                obj = read(digest, True)
                if 'manifests' in obj:
                    selected = [d for d in obj['manifests'] if (d.get('platform') or {}).get('architecture') == 'amd64'
                                and (d.get('platform') or {}).get('os') == 'linux']
                    if not selected:
                        raise RuntimeError('No linux/amd64 descriptor')
                    for d in selected:
                        walk(d['digest'])
                elif 'layers' in obj and 'config' in obj:
                    for desc in obj['layers'] + [obj['config']]:
                        if desc['digest'] not in checked:
                            read(desc['digest'])
                else:
                    raise RuntimeError('Expected OCI index/manifest')
            for image in hits:
                walk(image['descriptor_digest'])
                matches.setdefault(image['Id'], []).append({'archive': str(archive),
                    'verified_descriptor': image['descriptor_digest'], 'platform': 'linux/amd64',
                    'method': 'SHA256 of exact OCI descriptor and all required platform config/layer blobs; no load'})
        print('Checked archive:', archive.name, 'matching images:', len(hits), flush=True)
    result = {'at': now(), 'read_only': True, 'archives_examined': examined,
              'images': [{**i, 'verified_archive_sources': matches.get(i['Id'], [])} for i in images]}
    result['summary'] = {'count': len(images), 'harbor_exact': sum(bool(i['harbor_exact_matches']) for i in images),
                         'archive_exact': len(matches),
                         'at_least_one_verified_source': sum(bool(i['harbor_exact_matches'] or matches.get(i['Id'])) for i in images),
                         'no_verified_source': sum(not (i['harbor_exact_matches'] or matches.get(i['Id'])) for i in images)}
    output = RESULTS / 'luna-r2-archive-sources.20260927.json'
    with output.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps(result['summary']))


if __name__ == '__main__':
    main()
