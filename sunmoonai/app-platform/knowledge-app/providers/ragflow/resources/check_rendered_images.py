#!/usr/bin/env python3
"""Check the exact Helm-rendered image references; read manifests from stdin.

Rendered Secrets stay in memory and are never printed or written. No publication.
"""
from pathlib import Path
import sys

try:
    import yaml
except ImportError:
    raise SystemExit('Provisioned PyYAML dependency required') from None

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'registry-platform'))
from images import REGISTRY, Registry, split_reference  # noqa: E402
from client import config  # noqa: E402


def references(value):
    result = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ('containers', 'initContainers', 'ephemeralContainers'):
                for container in item:
                    image = container['image']
                    if not isinstance(image, str) or not image.startswith(REGISTRY + '/'):
                        raise ValueError('Workload image must be in the approved registry')
                    split_reference(image)
                    result.add(image)
            else:
                result.update(references(item))
    elif isinstance(value, list):
        for item in value:
            result.update(references(item))
    return result


def main():
    raw = sys.stdin.read(32 * 1024 * 1024 + 1)
    if len(raw) > 32 * 1024 * 1024:
        raise ValueError('Rendered chart too large')
    images = set()
    for document in yaml.safe_load_all(raw):
        images.update(references(document))
    if not images:
        raise ValueError('No workload images rendered')
    registry = Registry(config(None), None)
    for image in sorted(images):
        result = registry.inspect(image)
        if result['state'] != 'exists':
            raise ValueError('Required rendered image missing')
    print(f'Checked {len(images)} rendered manifest references; layers/rollout not verified')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Rendered-image check failed: verify chart references, private registry configuration, '
                         'CA and image availability. Private diagnostics suppressed.') from None
