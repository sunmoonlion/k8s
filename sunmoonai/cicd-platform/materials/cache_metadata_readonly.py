#!/usr/bin/env python3
"""Read selected non-secret BuildKit metadata fields; never opens the DB writable.

Version-specific inventory aid, not a cleanup API. Reject a changing DB.
Only cache relationships/digests/sizes are returned; descriptions are excluded.
"""
import json
import mmap
import os
import struct


def read_metadata():
    path = '/var/lib/docker/buildkit/containerd-overlayfs/metadata_v2.db'
    fields = {'cache.blob', 'cache.blobChainID', 'cache.chainID', 'cache.diffID',
              'cache.snapshot', 'cache.parent', 'cache.equalMutable',
              'cache.mergeParents', 'cache.lowerDiffParent', 'cache.upperDiffParent',
              'cache.blobsize', 'snapshot.size'}
    with open(path, 'rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        before = os.fstat(stream.fileno())
        if struct.unpack_from('<I', data, 16)[0] != 0xED0CDAED:
            raise RuntimeError('Unexpected Bolt header')
        page_size = struct.unpack_from('<I', data, 24)[0]
        def meta():
            return max((struct.unpack_from('<Q', data, i*page_size+64)[0], i*page_size) for i in [0, 1])
        tx, offset = meta()
        root = struct.unpack_from('<Q', data, offset+32)[0]
        def walk(buf, off):
            flags, count = struct.unpack_from('<HH', buf, off+8)
            if flags & 1:
                for n in range(count):
                    _, _, page = struct.unpack_from('<IIQ', buf, off+16+16*n)
                    yield from walk(data, page*page_size)
            elif flags & 2:
                for n in range(count):
                    entry = off+16+16*n
                    flag, pos, kl, vl = struct.unpack_from('<IIII', buf, entry)
                    yield buf[entry+pos:entry+pos+kl], buf[entry+pos+kl:entry+pos+kl+vl], flag
            else:
                raise RuntimeError('Unexpected page type')
        def bucket(value):
            page = struct.unpack_from('<Q', value)[0]
            return walk(data, page*page_size) if page else walk(value, 16)
        result = {}
        for key, value, flag in walk(data, root*page_size):
            if key != b'_main':
                continue
            if flag != 1:
                raise RuntimeError('Expected main bucket')
            for ident, record, recflag in bucket(value):
                if recflag != 1:
                    raise RuntimeError('Expected record bucket')
                selected = {}
                for name, raw, _ in bucket(record):
                    name = name.decode()
                    if name in fields and raw:
                        selected[name] = json.loads(raw)['value']
                result[ident.decode()] = selected
        after = os.fstat(stream.fileno())
        if meta()[0] != tx or before.st_mtime_ns != after.st_mtime_ns or before.st_size != after.st_size:
            raise RuntimeError('Metadata changed during read; retry inventory')
        return {'transaction_id': tx, 'records': result}


if __name__ == '__main__':
    print(json.dumps(read_metadata(), indent=2))
