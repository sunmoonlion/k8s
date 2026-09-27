#!/usr/bin/env python3
"""Read-only R2 estimate from Harbor digests, OCI content and cache dependencies.

No delete/GC calls. Run after R1/R4. Output contains no image configs or credentials.
Estimates exclude retained image/cache references; they are not a deletion permit.
"""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from space_reclaim_20260927 import get, now, RESULTS


def main():
    inventory = json.loads((RESULTS / 'luna-reclaim-after.20260927.json').read_text())
    catalog = json.loads((RESULTS / 'luna-r2-harbor-catalog.20260927.json').read_text())
    meta = json.loads((RESULTS / 'luna-r2-cache-metadata.20260927.json').read_text())['records']
    known = defaultdict(list)
    for project in catalog['projects']:
        for repo in project['repositories']:
            for artifact in repo['artifacts']:
                known[artifact['digest']].append(repo['name'] + '@' + artifact['digest'])
    content_root = Path('/var/lib/containerd/io.containerd.content.v1.content/blobs/sha256')
    content_sizes, objects, missing = {}, {}, set()

    def content(digest, parse=False):
        if not digest.startswith('sha256:') or len(digest) != 71:
            raise RuntimeError('Unexpected content digest')
        path = content_root / digest[7:]
        if not path.exists():
            missing.add(digest)
            return None
        st = path.stat()
        content_sizes[digest] = {'length': st.st_size, 'allocated': st.st_blocks*512}
        if parse and digest not in objects:
            raw = path.read_bytes()
            if 'sha256:' + hashlib.sha256(raw).hexdigest() != digest:
                raise RuntimeError('Local OCI descriptor digest mismatch')
            objects[digest] = json.loads(raw)
        return objects.get(digest)

    def graph(digest, seen):
        if digest in seen:
            return
        obj = content(digest, True)
        if obj is None:
            return
        seen.add(digest)
        if 'manifests' in obj:
            for desc in obj['manifests']:
                graph(desc['digest'], seen)
        elif 'layers' in obj and 'config' in obj:
            for desc in obj['layers'] + [obj['config']]:
                content(desc['digest'])
                if desc['digest'] in content_sizes:
                    seen.add(desc['digest'])

    def chains(layers):
        out, parent = set(), None
        for diff in layers:
            parent = diff if parent is None else 'sha256:' + hashlib.sha256((parent+' '+diff).encode()).hexdigest()
            out.add(parent)
        return out

    images, image_blobs, image_chains = {}, {}, {}
    app_ids, rest_ids, protected_ids = set(), set(), set()
    for image in inventory['images']:
        ident = image['Id']
        detail = get('/images/' + ident + '/json')
        root = (detail.get('Descriptor') or {}).get('digest', ident)
        local = content(root, True)
        matches = known.get(root, []) if local and ('manifests' in local or 'layers' in local) else []
        image_blobs[ident] = set()
        graph(root, image_blobs[ident])
        image_chains[ident] = chains(detail.get('RootFS', {}).get('Layers') or [])
        images[ident] = {**image, 'descriptor_digest': root, 'harbor_exact_matches': matches,
                         'source_status': 'Harbor exact manifest/index digest' if matches else 'no verified local recovery source; keep'}
        if image['Containers']:
            protected_ids.add(ident)
        elif any(m.startswith('app-images/') for m in matches):
            app_ids.add(ident)
        else:
            rest_ids.add(ident)
    caches = {c['ID']: c for c in inventory['build_cache']}
    parent_rows = json.loads((RESULTS / 'luna-r2-cache-parents.20260927.json').read_text())
    if {r['ID'] for r in parent_rows} != set(caches):
        raise RuntimeError('Cache inventory drift; refresh snapshots')
    def canonical(ident):
        if ident in caches:
            return ident
        alias = meta.get(ident, {}).get('cache.equalMutable')
        return alias if alias in caches else ident
    parents = {r['ID']: {canonical(p) for p in r.get('Parents') or []} for r in parent_rows}
    children = defaultdict(set)
    for ident, ps in parents.items():
        for p in ps:
            children[p].add(ident)

    def union(groups, ids):
        return set().union(*(groups[i] for i in ids)) if ids else set()

    app_chains = union(image_chains, app_ids)
    other_chains = union(image_chains, rest_ids | protected_ids)
    exclusive_chains = app_chains - other_chains
    seed = {k for k in caches if meta.get(k, {}).get('cache.chainID') in exclusive_chains and not caches[k]['InUse']}
    candidate_cache = set(seed)
    todo = list(seed)
    while todo:
        for p in parents.get(todo.pop(), set()):
            if p in caches and p not in candidate_cache and not caches[p]['InUse']:
                # Never include a cache record directly shared with a retained image chain.
                if meta.get(p, {}).get('cache.chainID') not in other_chains:
                    candidate_cache.add(p)
                    todo.append(p)
    while True:
        remove = {k for k in candidate_cache if children[k] - candidate_cache}
        if not remove:
            break
        candidate_cache -= remove
    retained_cache = set(caches) - candidate_cache
    # Retained cache ancestors conservatively protect content even for missing DU records.
    retained_meta = set(retained_cache)
    todo = list(retained_meta)
    while todo:
        m = meta.get(todo.pop(), {})
        for p in [m.get('cache.parent'), m.get('cache.equalMutable')]:
            if p and p not in retained_meta:
                retained_meta.add(p)
                todo.append(p)
    cache_blobs = {m['cache.blob'] for k, m in meta.items() if k in retained_meta and m.get('cache.blob')}
    candidate_blobs = union(image_blobs, app_ids) | {meta[k]['cache.blob'] for k in candidate_cache if meta.get(k, {}).get('cache.blob')}
    protected_blobs = union(image_blobs, rest_ids | protected_ids) | cache_blobs
    exclusive_blobs = candidate_blobs - protected_blobs
    for blob in exclusive_blobs:
        content(blob)

    snap_text = subprocess.run(['ctr', '--namespace', 'moby', 'snapshots', 'list'], capture_output=True, text=True, check=True).stdout
    snaps = {}
    for line in snap_text.splitlines()[1:]:
        cells = line.split()
        if cells:
            snaps[cells[0]] = cells[1] if len(cells) == 3 else None
    selected_snaps = app_chains | {meta[k]['cache.snapshot'] for k in candidate_cache if meta.get(k, {}).get('cache.snapshot')}
    selected_snaps &= set(snaps)
    retained_snaps = other_chains | {meta[k]['cache.snapshot'] for k in retained_meta if meta.get(k, {}).get('cache.snapshot')}
    # All other live snapshots are roots to preserve, including container writable layers.
    retained_snaps |= set(snaps) - selected_snaps
    todo = list(retained_snaps)
    while todo:
        parent = snaps.get(todo.pop())
        if parent and parent not in retained_snaps:
            retained_snaps.add(parent)
            todo.append(parent)
    exclusive_snaps = selected_snaps - retained_snaps
    usage = {}
    for ident in sorted(exclusive_snaps):
        output = subprocess.run(['ctr', '--namespace', 'moby', 'snapshots', 'usage', '-b', ident],
                                capture_output=True, text=True, check=True).stdout
        cells = output.splitlines()[-1].split()
        if cells[0] != ident:
            raise RuntimeError('Snapshot usage format changed')
        usage[ident] = int(cells[1])
    def group(ids):
        return {'count': len(ids), 'api_unique_layer_bytes_sum': sum(images[i]['Size']-images[i]['SharedSize'] for i in ids),
                'images': [images[i] for i in sorted(ids)]}
    result = {'at': now(), 'read_only': True, 'r2_execution_gate': 'host Harbor restored AND complete catalog digest comparison passed; currently false',
              'a': group(app_ids), 'b': group(rest_ids), 'container_protected': group(protected_ids),
              'a_cache': {'ids': sorted(candidate_cache), 'count': len(candidate_cache),
                          'api_bytes_sum_not_additive': sum(caches[k]['Size'] for k in candidate_cache),
                          'chain_seed_count': len(seed), 'selection': 'exclusive app chain seeds and ancestors; remove any record with retained descendants'},
              'a_estimate': {'exclusive_content_allocated_bytes': sum(content_sizes[b]['allocated'] for b in exclusive_blobs if b in content_sizes),
                             'exclusive_content_length_bytes': sum(content_sizes[b]['length'] for b in exclusive_blobs if b in content_sizes),
                             'exclusive_snapshot_usage_bytes': sum(usage.values()),
                             'exclusive_snapshot_count': len(usage), 'exclusive_content_count': len(exclusive_blobs),
                             'snapshots': usage, 'content_digests': sorted(exclusive_blobs),
                             'limitations': 'Planning estimate only. Unknown leases, alternate content variants and runtime GC may retain more. Missing lazy multiarch blobs are not local disk usage. Image and cache API sizes are not added.'},
              'b_harbor_exact_count': sum(bool(images[i]['harbor_exact_matches']) for i in rest_ids),
              'b_unverified_source_count': sum(not images[i]['harbor_exact_matches'] for i in rest_ids),
              'missing_local_descriptor_count': len(missing)}
    result['a_estimate']['combined_bytes'] = result['a_estimate']['exclusive_content_allocated_bytes'] + sum(usage.values())
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
