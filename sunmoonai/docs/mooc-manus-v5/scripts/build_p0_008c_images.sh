#!/usr/bin/env bash

# Build the three immutable P0-008C candidate images from the exact Research
# repositories. This script does not deploy or mutate stable tags.

set -euo pipefail

ROOT="${ROOT:-/home/zymun}"
REGISTRY="${REGISTRY:-harbor.sunmoonai.com:30443/app-images}"
DATE_TAG="${DATE_TAG:-$(date +%Y%m%d)}"
PYPI_INDEX_URL="${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
NPM_CONFIG_REGISTRY="${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}"
MODE="build"

RUNTIME_REPO="$ROOT/research-app/research-admin-backend"
WEB_BFF_REPO="$ROOT/research-app/research-web-backend"
NEXT_REPO="$ROOT/research-app/research-web-frontend"

RUNTIME_TAG="${RUNTIME_TAG:-p0-008c-runtime-${DATE_TAG}}"
WEB_BFF_TAG="${WEB_BFF_TAG:-p0-008c-bff-${DATE_TAG}}"
NEXT_TAG="${NEXT_TAG:-p0-008c-next-${DATE_TAG}}"

usage() {
  cat <<'EOF'
Usage: build_p0_008c_images.sh [--build|--push|--all]

  --build  Build and inspect all candidate images (default)
  --push   Push already-built images and print immutable digest references
  --all    Build, inspect, push, and print immutable digest references

Optional environment:
  ROOT, REGISTRY, DATE_TAG, PYPI_INDEX_URL, NPM_CONFIG_REGISTRY
  HTTP_PROXY, HTTPS_PROXY, NO_PROXY
  RUNTIME_TAG, WEB_BFF_TAG, NEXT_TAG
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) MODE="build"; shift ;;
    --push) MODE="push"; shift ;;
    --all) MODE="all"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

runtime_image="${REGISTRY}/research-admin-backend:${RUNTIME_TAG}"
web_bff_image="${REGISTRY}/research-web-backend:${WEB_BFF_TAG}"
next_image="${REGISTRY}/research-web-frontend:${NEXT_TAG}"

require_clean_commit() {
  local repo="$1" label="$2" branch
  git -C "$repo" rev-parse --verify HEAD >/dev/null
  branch="$(git -C "$repo" branch --show-current)"
  [[ "$branch" == "codex-1" ]] || {
    printf '%s must be built from codex-1, got %s\n' "$label" "$branch" >&2
    exit 1
  }
  [[ -z "$(git -C "$repo" status --porcelain)" ]] || {
    printf '%s worktree is dirty; commit before building\n' "$label" >&2
    exit 1
  }
}

inspect_image() {
  local image="$1" expected_cmd="$2"
  docker image inspect "$image" >/dev/null
  if docker history --no-trunc "$image" \
    | grep -Eiq '(AGENT_PILOT_LLM_API_KEY|DOWNSTREAM_CLIENT_SECRET|CASDOOR_CLIENT_SECRET)=[^[:space:]]+'; then
    printf 'candidate image history appears to contain a runtime secret: %s\n' \
      "$image" >&2
    exit 1
  fi
  actual_cmd="$(
    docker image inspect "$image" \
      --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'
  )"
  [[ "$actual_cmd" == *"$expected_cmd"* ]] || {
    printf 'candidate image command mismatch: %s command=%s\n' \
      "$image" "$actual_cmd" >&2
    exit 1
  }
}

build_images() {
  require_clean_commit "$RUNTIME_REPO" "Research Runtime"
  require_clean_commit "$WEB_BFF_REPO" "Research Web BFF"
  require_clean_commit "$NEXT_REPO" "Research Next"

  docker build \
    --progress=plain \
    --build-arg "PYPI_INDEX_URL=${PYPI_INDEX_URL}" \
    --label "sunmoonai.com/task=v5-p0-008c" \
    --label "org.opencontainers.image.revision=$(git -C "$RUNTIME_REPO" rev-parse HEAD)" \
    -t "$runtime_image" \
    "$RUNTIME_REPO/app"

  docker build \
    --progress=plain \
    --build-arg "PYPI_INDEX_URL=${PYPI_INDEX_URL}" \
    --label "sunmoonai.com/task=v5-p0-008c" \
    --label "org.opencontainers.image.revision=$(git -C "$WEB_BFF_REPO" rev-parse HEAD)" \
    -t "$web_bff_image" \
    "$WEB_BFF_REPO/app"

  docker build \
    --progress=plain \
    --build-arg "NPM_CONFIG_REGISTRY=${NPM_CONFIG_REGISTRY}" \
    --build-arg "HTTP_PROXY=${HTTP_PROXY:-}" \
    --build-arg "HTTPS_PROXY=${HTTPS_PROXY:-}" \
    --build-arg "NO_PROXY=${NO_PROXY:-}" \
    --build-arg "NEXT_PUBLIC_API_URL=/api" \
    --build-arg "NEXT_PUBLIC_APP_NAME=research" \
    --build-arg "APP_ORIGIN=https://research-web-p0-008c.sunmoonai.com:30443" \
    --build-arg "WEB_BACKEND_INTERNAL_URL=http://research-web-backend-p0-008c:8000" \
    --build-arg "DEPLOYMENT_ID=p0-008c-candidate" \
    --label "sunmoonai.com/task=v5-p0-008c" \
    --label "org.opencontainers.image.revision=$(git -C "$NEXT_REPO" rev-parse HEAD)" \
    --target run-minimal \
    -f "$NEXT_REPO/mybuild/Dockerfile" \
    -t "$next_image" \
    "$NEXT_REPO"

  inspect_image "$runtime_image" "uvicorn"
  inspect_image "$web_bff_image" "uvicorn"
  inspect_image "$next_image" "server.js"
  printf 'P0-008C candidate image build passed\n'
}

push_image() {
  local image="$1" repository digest
  docker push "$image"
  repository="${image%:*}"
  digest="$(
    docker image inspect "$image" \
      --format '{{range .RepoDigests}}{{println .}}{{end}}' \
      | awk -v prefix="${repository}@" 'index($0, prefix) == 1 {print; exit}'
  )"
  [[ "$digest" =~ @sha256:[a-f0-9]{64}$ ]] || {
    printf 'no immutable digest found after push: %s\n' "$image" >&2
    exit 1
  }
  printf '%s\n' "$digest"
}

push_images() {
  inspect_image "$runtime_image" "uvicorn"
  inspect_image "$web_bff_image" "uvicorn"
  inspect_image "$next_image" "server.js"
  printf 'P0_008C_RUNTIME_IMAGE=%s\n' "$(push_image "$runtime_image")"
  printf 'P0_008C_WEB_BFF_IMAGE=%s\n' "$(push_image "$web_bff_image")"
  printf 'P0_008C_NEXT_IMAGE=%s\n' "$(push_image "$next_image")"
}

case "$MODE" in
  build) build_images ;;
  push) push_images ;;
  all) build_images; push_images ;;
esac
