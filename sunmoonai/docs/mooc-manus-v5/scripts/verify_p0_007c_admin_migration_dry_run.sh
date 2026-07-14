#!/usr/bin/env bash
set -euo pipefail

# Read-only verification of the P0-007C migration procedure. It never writes
# to an App repository, changes a gitlink, contacts a registry, or creates a
# remote repository.

WORKSPACE_ROOT="${V5_WORKSPACE_ROOT:-${HOME:?HOME is required}}"
TEMPLATE_ROOT="${V5_TEMPLATE_ROOT:-$WORKSPACE_ROOT/tpl-app/tpl-admin-frontend}"
TEMPLATE_COMMIT="${V5_TEMPLATE_COMMIT:-be4bf3d}"

if [[ ! -e "$TEMPLATE_ROOT/.git" ]]; then
  echo "template repository not found: $TEMPLATE_ROOT" >&2
  exit 1
fi

readonly -a REQUIRED_FILES=(
  app/root.tsx
  app/routes.ts
  app/components/app-shell.tsx
  app/lib/auth.ts
  app/lib/api.ts
  app/components/crud/contract-upload.tsx
  mybuild/Dockerfile
  mybuild/nginx.conf
  pnpm-lock.yaml
  docs/react-admin-v1-migration-checklist.md
)

declare -A APP_ROOTS=(
  [info]="$WORKSPACE_ROOT/info-app"
  [knowledge]="$WORKSPACE_ROOT/knowledge-app"
  [research]="$WORKSPACE_ROOT/research-app"
)
declare -A APP_AUDIENCES=(
  [info]="info:admin"
  [knowledge]="knowledge:admin"
  [research]="research:admin"
)
declare -A APP_COOKIES=(
  [info]="sunmoonai_info_admin_sid"
  [knowledge]="sunmoonai_knowledge_admin_sid"
  [research]="sunmoonai_research_admin_sid"
)

TEMPLATE_HEAD="$(git -C "$TEMPLATE_ROOT" rev-parse HEAD)"
git -C "$TEMPLATE_ROOT" cat-file -e "$TEMPLATE_COMMIT^{commit}"
EXPECTED_HEAD="$(git -C "$TEMPLATE_ROOT" rev-parse "$TEMPLATE_COMMIT")"
if [[ "$TEMPLATE_HEAD" != "$EXPECTED_HEAD" ]]; then
  echo "template HEAD is not the frozen commit: head=$TEMPLATE_HEAD expected=$EXPECTED_HEAD" >&2
  exit 1
fi

for file in "${REQUIRED_FILES[@]}"; do
  [[ -f "$TEMPLATE_ROOT/$file" ]] || { echo "template file missing: $file" >&2; exit 1; }
done

if [[ -e "$TEMPLATE_ROOT/app/routes/info-crawl.tsx" || -e "$TEMPLATE_ROOT/app/lib/info-api.ts" ]]; then
  echo "domain-specific Info files leaked into the template" >&2
  exit 1
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/p0-007c-admin-dry-run.XXXXXX")"
cleanup() { rm -rf "$tmp_root"; }
trap cleanup EXIT

printf '{\n'
printf '  "task": "V5-P0-007C-admin-migration-dry-run",\n'
printf '  "template_commit": "%s",\n' "$TEMPLATE_HEAD"
printf '  "template_head_matches_frozen": true,\n'
printf '  "network_access": false,\n'
printf '  "app_repositories_modified": false,\n'
printf '  "remote_repositories_created": false,\n'
printf '  "apps": [\n'

first=1
for app in info knowledge research; do
  app_root="${APP_ROOTS[$app]}"
  frontend_root="$app_root/${app}-admin-frontend"
  [[ -e "$app_root/.git" ]] || { echo "parent repository not found: $app_root" >&2; exit 1; }
  [[ -e "$frontend_root/.git" ]] || { echo "frontend repository not found: $frontend_root" >&2; exit 1; }
  [[ -z "$(git -C "$app_root" status --porcelain)" ]] || { echo "$app parent worktree is dirty" >&2; exit 1; }
  [[ -z "$(git -C "$frontend_root" status --porcelain)" ]] || { echo "$app frontend worktree is dirty" >&2; exit 1; }

  before_gitlink="$(git -C "$app_root" ls-tree HEAD "${app}-admin-frontend")"
  [[ -n "$before_gitlink" ]] || { echo "missing $app gitlink in parent HEAD" >&2; exit 1; }
  branch="$(git -C "$frontend_root" branch --show-current)"
  app_commit="$(git -C "$frontend_root" rev-parse HEAD)"

  clean_root="$tmp_root/$app"
  mkdir -p "$clean_root"
  git -C "$TEMPLATE_ROOT" archive "$TEMPLATE_HEAD" | tar -x -C "$clean_root"
  for file in "${REQUIRED_FILES[@]}"; do
    [[ -f "$clean_root/$file" ]] || { echo "$app clean-room missing: $file" >&2; exit 1; }
  done
  [[ ! -e "$clean_root/app/routes/info-crawl.tsx" ]] || { echo "Info route in $app clean-room template" >&2; exit 1; }

  [[ $first -eq 1 ]] || printf ',\n'
  first=0
  printf '    {"app": "%s", "branch": "%s", "current_frontend_commit": "%s", ' "$app" "$branch" "$app_commit"
  printf '"parent_gitlink_unchanged": true, "api_base": "/api", "audience": "%s", ' "${APP_AUDIENCES[$app]}"
  printf '"session_cookie": "%s", "clean_room_from_template": true, "writes_to_app": false}' "${APP_COOKIES[$app]}"

  after_gitlink="$(git -C "$app_root" ls-tree HEAD "${app}-admin-frontend")"
  [[ "$before_gitlink" == "$after_gitlink" ]] || { echo "$app gitlink changed during dry-run" >&2; exit 1; }
done

printf '\n  ]\n}\n'
echo "P0-007C admin migration dry-run passed (Info -> Knowledge -> Research; no App repository changed)"
