#!/usr/bin/env python3
"""Owner-only external connection output, without shell interpolation."""
import os
from pathlib import Path
import shlex
import stat
import sys
import tempfile


def main():
    action, name = sys.argv[1:]
    path = Path(name)
    if not path.is_absolute() or path.resolve() != path:
        raise ValueError('Absolute non-symlink output required')
    parent = path.parent.stat()
    if parent.st_uid != os.geteuid() or stat.S_IMODE(parent.st_mode) & 0o077:
        raise ValueError('Output parent must already be owner-only and owned by caller')
    if path.exists():
        old = path.stat()
        if not stat.S_ISREG(old.st_mode) or old.st_uid != os.geteuid() or old.st_mode & 0o077 or old.st_nlink != 1:
            raise ValueError('Unsafe existing output')
    if action == 'deprovision':
        path.unlink(missing_ok=True)
        return
    raw = sys.stdin.buffer.read(1048577)
    if len(raw) > 1048576:
        raise ValueError('Output exceeds limit')
    cells = raw.decode().split('\0')
    if cells.pop() or len(cells) % 2:
        raise ValueError('Invalid output frame')
    content = ''.join(k+'='+shlex.quote(v)+'\n' for k,v in zip(cells[::2],cells[1::2]))
    fd, temp = tempfile.mkstemp(prefix='.dbctl-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as stream:
            stream.write(content);stream.flush();os.fsync(stream.fileno())
        os.replace(temp,path)
    finally:
        if os.path.exists(temp):os.unlink(temp)
    print('Private connection output written; values withheld')


if __name__ == '__main__':
    try:main()
    except Exception:raise SystemExit('Private output failed; check explicit path, owner and permissions') from None
