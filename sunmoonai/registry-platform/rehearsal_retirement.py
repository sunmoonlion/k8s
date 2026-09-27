"""Refuse startup after an explicitly retired rehearsal loses its registry copy."""
from pathlib import Path


MARKER = 'retired-registry-copy.json'


def assert_active(root):
    marker = Path(root) / MARKER
    # A malformed marker or broken symlink must also fail closed. Do not remove
    # the marker automatically; recovery uses a fresh directory and identity.
    if marker.exists() or marker.is_symlink():
        raise ValueError('Historical rehearsal retired; restore to a new instance before use: ' + str(root))
