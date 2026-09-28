#!/usr/bin/env bash
# Historical image helper disabled before loading configuration or contacting nodes.
printf '%s\n' 'Archived: see legacy/cloud/README.md. Global cleanup is disabled; use reviewed registry/operations flows.' >&2
return 2 2>/dev/null || exit 2
