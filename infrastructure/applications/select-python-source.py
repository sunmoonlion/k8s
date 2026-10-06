#!/usr/bin/env python3
"""Select a mirror in an exported build context, preserving locked identities."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tomllib


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--context', required=True, type=Path)
    modes = json.loads(Path(__file__).with_name('download-modes.json').read_text())
    parser.add_argument('--mode', required=True, choices=modes)
    args = parser.parse_args()
    context = args.context
    if (context.is_symlink() or context.resolve() != context.absolute()
            or context.name != 'context'
            or not context.parent.name.startswith('sunmoon-tpl-build-')
            or context.parent.parent != Path('/tmp')):
        raise ValueError('Only an exported /tmp/sunmoon-tpl-build-*/context is writable')
    profile = modes[args.mode]
    indexes = {m['python_index'] for m in modes.values()}
    prefixes = {m['python_packages'] for m in modes.values()}

    def map_url(url):
        if url in indexes:
            return profile['python_index']
        for prefix in prefixes:
            if url.startswith(prefix):
                suffix = url[len(prefix):]
                if not re.fullmatch(r'[a-zA-Z0-9_./+%-]+', suffix) or '..' in suffix.split('/'):
                    raise ValueError('Unsupported artifact URL path')
                return profile['python_packages'] + suffix
        return url

    def canonical(value):
        if isinstance(value, dict):
            return {k: canonical(v) for k, v in value.items()}
        if isinstance(value, list):
            return [canonical(v) for v in value]
        return map_url(value) if isinstance(value, str) else value

    files = {}
    for name in ('pyproject.toml', 'uv.lock'):
        path = context / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Expected regular input file: ' + name)
        before = path.read_bytes()
        text = before.decode('utf-8')
        parsed = tomllib.loads(text)
        after = re.sub(r'"(https://[^"\s]+)"',
                       lambda m: json.dumps(map_url(m[1])), text).encode('utf-8')
        if canonical(parsed) != tomllib.loads(after.decode('utf-8')):
            raise ValueError('Projection changed values other than approved source URLs')
        files[name] = (path, before, after, parsed)

    uv = files['pyproject.toml'][3].get('tool', {}).get('uv', {})
    configured = uv.get('index', [])
    if (len(configured) != 1 or configured[0].get('url') not in indexes
            or not configured[0].get('default') or uv.get('sources')):
        raise ValueError('Expected one approved default index without source overrides')
    lock = files['uv.lock'][3]
    if lock.get('version') != 1 or not lock.get('package'):
        raise ValueError('Unsupported or empty uv lock')
    artifacts = 0
    for package in lock['package']:
        source = package.get('source', {})
        if source in ({'editable': '.'}, {'virtual': '.'}):
            continue
        if set(source) != {'registry'} or source['registry'] not in indexes:
            raise ValueError('Unsupported locked package source')
        for artifact in ([package['sdist']] if 'sdist' in package else []) + package.get('wheels', []):
            url = artifact.get('url', '')
            if (not any(url.startswith(p) for p in prefixes)
                    or not re.fullmatch(r'sha256:[a-f0-9]{64}', artifact.get('hash', ''))
                    or ('size' in artifact and (not isinstance(artifact['size'], int) or artifact['size'] <= 0))):
                raise ValueError('Artifact must have an approved URL, SHA256 and valid size when present')
            map_url(url)
            artifacts += 1
    if not artifacts:
        raise ValueError('No locked artifacts')
    # Validate both documents fully before writing either disposable input.
    for path, before, after, _ in files.values():
        if before != after:
            path.write_bytes(after)
    print(json.dumps({
        'mode': args.mode,
        'changed': any(before != after for _, before, after, _ in files.values()),
        'packages': len(lock['package']), 'artifacts': artifacts,
        'locked_identities_preserved': True,
        'files': {name: {'source_sha256': sha(before), 'build_sha256': sha(after)}
                  for name, (_, before, after, _) in files.items()},
    }))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit(str(exc)) from exc
