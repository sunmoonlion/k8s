#!/usr/bin/env python3
"""Shared registry manifest check. Default is a local plan; --apply performs GETs.

No Docker load/login/push, SSH, cleanup, cluster access or insecure fallback.
Cloud execution remains 未经实机验证. A manifest check is not a full layer pull.
"""
import argparse
import base64
import hashlib
import http.client
import json
import re
import ssl
import subprocess
from pathlib import Path
from urllib.parse import quote, urlencode

from client import config, checked_ca
from credentials import load_credentials

REGISTRY = 'harbor.sunmoonai.com:30443'
ACCEPT = ', '.join(('application/vnd.oci.image.index.v1+json',
                    'application/vnd.oci.image.manifest.v1+json',
                    'application/vnd.docker.distribution.manifest.list.v2+json',
                    'application/vnd.docker.distribution.manifest.v2+json'))
REPOSITORY = re.compile(r'[a-z0-9]+(?:(?:[._]|__|-+)[a-z0-9]+)*(?:/[a-z0-9]+(?:(?:[._]|__|-+)[a-z0-9]+)*)*')
DIGEST = re.compile(r'sha256:[a-f0-9]{64}')


class ImageCheckError(RuntimeError):
    """Safe diagnostic built from local constants, never from response bodies."""


def split_reference(reference):
    if '@' in reference:
        repository, selector = reference.rsplit('@', 1)
        if not DIGEST.fullmatch(selector):
            raise ImageCheckError('Invalid SHA256 image digest')
        separator = '@'
    else:
        repository, colon, selector = reference.rpartition(':')
        if not colon or '/' in selector or not re.fullmatch(r'[\w][\w.-]{0,127}', selector, re.ASCII):
            raise ImageCheckError('An explicit image tag or SHA256 digest is required')
        separator = ':'
    return repository, separator, selector


def target_reference(source, project):
    repository, separator, selector = split_reference(source)
    if repository.startswith(REGISTRY + '/'):
        target = repository[len(REGISTRY) + 1:]
    else:
        first = repository.split('/')[0]
        if '/' in repository and ('.' in first or ':' in first or first == 'localhost'):
            repository = repository.split('/', 1)[1]
        if not REPOSITORY.fullmatch(repository):
            raise ImageCheckError('Invalid source repository')
        # Preserve the existing component-list mapping, including AIStor nesting.
        name = repository if repository.startswith('minio/aistor/') else repository.rsplit('/', 1)[-1]
        target = project + '/' + name
    if '/' not in target or not REPOSITORY.fullmatch(target):
        raise ImageCheckError('Invalid destination project/repository')
    return REGISTRY + '/' + target + separator + selector


class Registry:
    def __init__(self, profile, credentials_file):
        _, self.context = checked_ca(profile)
        self.credentials = load_credentials(credentials_file or profile['REGISTRY_CREDENTIALS_FILE'])
        self.timeout = int(profile['REGISTRY_REQUEST_TIMEOUT'])

    def get(self, path, headers=None, limit=4 * 1024**2):
        connection = http.client.HTTPSConnection('harbor.sunmoonai.com', 30443,
                                                 context=self.context, timeout=self.timeout)
        try:
            # Direct pinned host, no redirects or environment HTTP proxy handling.
            connection.request('GET', path, headers=headers or {})
            response = connection.getresponse()
            content = response.read(limit + 1)
            if len(content) > limit:
                raise ImageCheckError('Registry response exceeds the size limit')
            return response.status, dict((k.lower(), v) for k, v in response.getheaders()), content
        finally:
            connection.close()

    def inspect(self, reference):
        repository, separator, selector = split_reference(reference)
        repository = repository.removeprefix(REGISTRY + '/')
        path = '/v2/' + quote(repository, safe='/') + '/manifests/' + quote(selector, safe=':')
        headers = {'Accept': ACCEPT}
        status, reply, raw = self.get(path, headers)
        if status == 401:
            challenge = reply.get('www-authenticate', '')
            pairs = re.findall(r'(\w+)="([^"]+)"', challenge)
            values = dict(pairs)
            if (not challenge.lower().startswith('bearer ') or len(values) != len(pairs)
                    or values.get('realm') != 'https://' + REGISTRY + '/service/token'
                    or values.get('service') != 'harbor-registry'):
                raise ImageCheckError('Registry authentication challenge differs from the approved host')
            token_path = '/service/token?' + urlencode({'service': 'harbor-registry',
                                                        'scope': 'repository:' + repository + ':pull'})
            secret = self.credentials['username'] + ':' + self.credentials['password']
            token_status, _, token_raw = self.get(token_path,
                {'Authorization': 'Basic ' + base64.b64encode(secret.encode()).decode()}, limit=1024**2)
            if token_status != 200:
                raise ImageCheckError('Registry token request failed: HTTP ' + str(token_status))
            token_data = json.loads(token_raw)
            token = token_data.get('token') or token_data.get('access_token')
            if not isinstance(token, str) or not token or any(c in token for c in '\r\n\0'):
                raise ImageCheckError('Invalid registry token response')
            headers['Authorization'] = 'Bearer ' + token
            status, reply, raw = self.get(path, headers)
        if status == 404:
            # A generic ingress 404 must not be classified as a missing image.
            body = json.loads(raw)
            codes = {error.get('code') for error in body.get('errors', []) if isinstance(error, dict)}
            if not codes or not codes <= {'MANIFEST_UNKNOWN', 'NAME_UNKNOWN'}:
                raise ImageCheckError('Unrecognized registry 404 response')
            return {'reference': reference, 'state': 'missing'}
        if status != 200:
            raise ImageCheckError('Registry manifest request failed: HTTP ' + str(status))
        digest = 'sha256:' + hashlib.sha256(raw).hexdigest()
        if reply.get('docker-content-digest') != digest:
            raise ImageCheckError('Registry manifest bytes differ from the response digest')
        if separator == '@' and digest != selector:
            raise ImageCheckError('Registry manifest differs from the requested digest')
        body = json.loads(raw)
        if (not isinstance(body, dict) or body.get('schemaVersion') != 2
                or body.get('mediaType') not in ACCEPT.split(', ')):
            raise ImageCheckError('Unsupported manifest schema/media type')
        return {'reference': reference, 'state': 'exists', 'digest': digest,
                'digest_pinned': separator == '@', 'layers_verified': False,
                'media_type': body['mediaType']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('check',))
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--component')
    source.add_argument('--image')
    parser.add_argument('--project')
    parser.add_argument('--config', type=Path)
    parser.add_argument('--credentials-file', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    profile = config(args.config)
    project = args.project or profile['REGISTRY_IMAGE_PROJECT']
    if not re.fullmatch(r'[a-z0-9]+(?:[._-][a-z0-9]+)*', project):
        parser.error('Invalid project name')
    if args.image:
        sources = [args.image]
    else:
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', args.component):
            parser.error('Invalid component name')
        directory = Path(profile['REGISTRY_COMPONENT_LIST_DIR'])
        if not directory.is_absolute():
            parser.error('Component list directory must be absolute')
        path = directory / (args.component + '-images.txt')
        sources = [line.strip() for line in path.read_text().splitlines()
                   if line.strip() and not line.lstrip().startswith('#')]
    mapped = {}
    for ref in sources:
        target = target_reference(ref, project)
        if target in mapped and mapped[target] != ref:
            raise ImageCheckError('Different sources map to one destination; resolve the component list')
        mapped[target] = ref
    targets = list(mapped)
    if not targets:
        raise ImageCheckError('Empty required image set is not an acceptance result')
    if not args.apply:
        print(json.dumps({'apply': False, 'registry': REGISTRY, 'images': targets,
                          'operation': 'GET manifest; verify raw SHA256; no automatic publication',
                          'credentials_read': False}, indent=2))
        return
    registry = Registry(profile, args.credentials_file)
    results = [registry.inspect(target) for target in targets]
    print(json.dumps({'results': results, 'layers_verified': False}, indent=2))
    if any(item['state'] != 'exists' for item in results):
        raise SystemExit(2)


if __name__ == '__main__':
    try:
        main()
    except ImageCheckError as error:
        raise SystemExit('Registry image check failed: ' + str(error)) from None
    except ssl.SSLError:
        raise SystemExit('Registry image check failed: TLS verification/handshake; not a missing image') from None
    except (TimeoutError, subprocess.TimeoutExpired):
        raise SystemExit('Registry image check failed: timeout; not a missing image') from None
    except (OSError, ValueError, TypeError, AttributeError, http.client.HTTPException) as error:
        # Do not emit response bodies, credentials or token contents.
        raise SystemExit('Registry image check failed: ' + type(error).__name__ +
                         '; check config, CA, credentials, connectivity and manifest identity') from None
