#!/usr/bin/env python3
"""Read the selected kubeconfig mapping as data, without shell evaluation."""
import os
from pathlib import Path
import re
import sys


def selected_path(filename, cluster):
    cluster = cluster.upper()
    if not re.fullmatch(r'KIND|C[1-9][0-9]*', cluster):
        raise ValueError('Explicit KIND or C<number> cluster required')
    sections = {'KIND'} if cluster == 'KIND' else {cluster + '_DIRECT', cluster + '_BASTION'}
    current = None
    values = {}
    seen_sections = set()
    for line in Path(filename).read_text().splitlines():
        text = line.strip()
        if not text or text.startswith(('#', ';')):
            continue
        if text.startswith('[') and text.endswith(']'):
            current = text[1:-1]
            if current in sections:
                if current in seen_sections:
                    raise ValueError('Duplicate selected configuration section')
                seen_sections.add(current)
            continue
        key, separator, value = text.partition('=')
        if current not in sections or not separator or key.strip() != 'kubeconfig':
            continue
        if current in values:
            raise ValueError('Duplicate selected kubeconfig setting')
        value = value.strip()
        if value[:1] in ('"', "'") and value[-1:] == value[:1]:
            value = value[1:-1]
        value = re.sub(r'\$\{HOME\}|\$HOME(?![A-Za-z0-9_])', lambda _: os.environ['HOME'], value)
        if value.startswith('~/'):
            value = os.environ['HOME'] + value[1:]
        if not value or any(c in value for c in '$`\r\n\x00:') or not Path(value).is_absolute():
            raise ValueError('Kubeconfig must be one absolute path; only HOME expansion is supported')
        values[current] = str(Path(value).resolve())
    paths = set(values.values())
    if len(paths) != 1:
        raise ValueError('Missing or ambiguous cluster kubeconfig mapping')
    return paths.pop()


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('Expected configuration file and cluster')
        print(selected_path(*sys.argv[1:]))
    except (ValueError, OSError, KeyError) as exc:
        # Do not include configuration content or credentials in diagnostics.
        print('Kubeconfig mapping rejected: ' + (str(exc) if isinstance(exc, ValueError)
                                                else 'configuration could not be read'), file=sys.stderr)
        sys.exit(1)
