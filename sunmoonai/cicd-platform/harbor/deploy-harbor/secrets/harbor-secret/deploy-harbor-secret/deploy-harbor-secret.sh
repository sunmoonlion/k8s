#!/usr/bin/env bash
# Historical in-cluster Harbor; retained in legacy/cloud pending real cloud validation.
printf '%s\n' 'Harbor installation moved to registry-platform; old implementation archived in legacy/cloud.' >&2
return 2 2>/dev/null || exit 2
