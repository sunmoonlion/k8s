"""Read-only peak-space estimate from the exact already verified upstream archive."""
import argparse,gzip,hashlib,json,tarfile,sys
p=argparse.ArgumentParser();p.add_argument('archive');p.add_argument('digest');p.add_argument('--node-cache',action='store_true');p.add_argument('--base-cached',action='store_true');a=p.parse_args()
cached=set(sys.stdin.read().split()) if a.node_cache else set()
with tarfile.open(a.archive) as archive:
 raw=archive.extractfile('blobs/sha256/'+a.digest.removeprefix('sha256:')).read()
 assert 'sha256:'+hashlib.sha256(raw).hexdigest()==a.digest
 manifest=json.loads(raw);unpacked=0;compressed=0
 for layer in manifest['layers']:
  if layer['digest'] in cached:continue
  stream=archive.extractfile('blobs/sha256/'+layer['digest'].removeprefix('sha256:'))
  compressed+=layer['size']
  if layer['mediaType'].endswith('+gzip') or layer['mediaType'].endswith('.gzip'):
   stream=gzip.GzipFile(fileobj=stream)
  while chunk:=stream.read(4*1024*1024):unpacked+=len(chunk)
# Host base content+snapshot, converter spool, compressed layout+final archive,
# and 1GiB allowance for the bounded permission and small source adaptation.
print(json.dumps({'uncompressed_bytes':unpacked,'compressed_bytes':compressed,'planned_bytes':2*unpacked+compressed+67108864 if a.node_cache else (unpacked if a.base_cached else 2*unpacked)+(2*compressed if a.base_cached else 3*compressed)+1073741824}))
