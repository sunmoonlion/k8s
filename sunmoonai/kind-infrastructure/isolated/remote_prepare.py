#!/usr/bin/env python3
"""Download/export public artifacts on a helper host; never create a cluster."""
import argparse
import fcntl
from pathlib import Path
import shutil

from cluster import Cluster, HERE


class DownloadHost(Cluster):
    def run(self, args, **kwargs):
        # Headroom covers compressed layers, unpacked Docker layers and exported tars.
        # This is a per-operation guard, not a filesystem quota.
        available = shutil.disk_usage(self.root).free
        minimum = 8 if str(args[0]) == 'docker' and args[1] == 'pull' else 6
        if available < minimum * 1024**3:
            raise RuntimeError(f'Remote staging stopped: less than {minimum} GiB free; existing services were not cleaned')
        return super().run(args, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', required=True)
    args = parser.parse_args()
    root = Path(args.artifacts).expanduser().resolve()
    expected = Path.home() / '.cache/sunmoon-artifacts'
    if not root.is_relative_to(expected) or root == expected:
        raise ValueError('Remote downloads must stay under ~/.cache/sunmoon-artifacts')
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    c = DownloadHost(HERE / 'profile.json', str(root))
    with open(root / '.operation.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        c.prepare()


if __name__ == '__main__':
    main()
