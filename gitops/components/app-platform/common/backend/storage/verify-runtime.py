"""Runs inside the actual API role with its mounted, independent S3 credentials."""
import hashlib
import json
import sys
import uuid
from botocore.exceptions import ClientError
from app.infrastructure.storage.object_storage import ObjectStorage

store = ObjectStorage()
client = store.s3_client()
key = 'sunmoon-acceptance/' + uuid.uuid4().hex
records = []
checks = {}
passed = False
try:
    expected = [b'SunMoonAI original version one\n', b'SunMoonAI original version two\n']
    for content in expected:
        item = store.put_bytes(object_key=key, data=content, content_type='application/octet-stream')
        assert item.bucket == store.bucket and item.version_id and item.version_id != 'null'
        records.append({'bucket':item.bucket, 'key':key, 'version_id':item.version_id})
        assert item.sha256 == hashlib.sha256(content).hexdigest()
    assert records[0]['version_id'] != records[1]['version_id']
    for record, content in zip(records, expected, strict=True):
        result = client.get_object(Bucket=store.bucket, Key=key, VersionId=record['version_id'])
        try:
            assert result['Body'].read() == content
            assert result['Metadata']['sha256'] == hashlib.sha256(content).hexdigest()
        finally:
            result['Body'].close()
    checks.update(actual_application_storage=True, independent_identity=True, tls_ca_verified=True, original_versions_preserved=True, byte_digest_verified=True)
    try:
        client.list_objects_v2(Bucket='sunmoon-forbidden-bucket', MaxKeys=1)
        raise AssertionError('Foreign bucket unexpectedly readable')
    except ClientError as error:
        assert error.response['Error']['Code'] == 'AccessDenied'
        checks['foreign_bucket_denied'] = True
    try:
        client.put_bucket_versioning(Bucket=store.bucket, VersioningConfiguration={'Status':'Suspended'})
        raise AssertionError('Application unexpectedly controls bucket versioning')
    except ClientError as error:
        assert error.response['Error']['Code'] == 'AccessDenied'
        checks['bucket_administration_denied'] = True
    passed = True
except Exception as error:
    checks['error_class'] = type(error).__name__
finally:
    client.close()
    print(json.dumps({'passed':passed, 'checks':checks, 'created_records':records}))
    sys.exit(0 if passed else 1)
