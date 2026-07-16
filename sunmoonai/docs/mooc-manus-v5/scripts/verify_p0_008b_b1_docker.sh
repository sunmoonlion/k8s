#!/usr/bin/env bash
set -euo pipefail

FRONTEND_REPO="${HOME}/tpl-app/tpl-web-frontend"
BACKEND_REPO="${HOME}/tpl-app/tpl-web-backend"
FRONTEND_IMAGE="tpl-web-frontend:p0-008b-b1-candidate-20260716"
BACKEND_IMAGE="tpl-web-backend:p0-008b-b1-candidate-20260716"
FRONTEND_CONTAINER="p0-008b-b1-web-frontend"
FRONTEND_PORT="${P0_008B_FRONTEND_PORT:-18094}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

cleanup() {
  docker rm -f "${FRONTEND_CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

proxy_args=()
if [[ -n "${P0_HTTP_PROXY:-}" ]]; then
  proxy_args=(
    --build-arg "HTTP_PROXY=${P0_HTTP_PROXY}"
    --build-arg "HTTPS_PROXY=${P0_HTTP_PROXY}"
    --build-arg "NO_PROXY=localhost,127.0.0.1,harbor.sunmoonai.com"
  )
fi

docker build \
  --progress=plain \
  -f "${FRONTEND_REPO}/mybuild/Dockerfile" \
  -t "${FRONTEND_IMAGE}" \
  --build-arg "NPM_CONFIG_REGISTRY=${NPM_REGISTRY}" \
  --build-arg NEXT_PUBLIC_API_URL=/api \
  --build-arg NEXT_PUBLIC_APP_NAME=tpl \
  --build-arg APP_ORIGIN=http://localhost:3000 \
  --build-arg WEB_BACKEND_INTERNAL_URL=http://tpl-web-backend:8000 \
  --build-arg DEPLOYMENT_ID=p0-008b-b1-candidate \
  "${proxy_args[@]}" \
  "${FRONTEND_REPO}"

docker build \
  --progress=plain \
  -f "${BACKEND_REPO}/mybuild/Dockerfile" \
  -t "${BACKEND_IMAGE}" \
  --build-arg "NPM_REGISTRY=${NPM_REGISTRY}" \
  "${proxy_args[@]}" \
  "${BACKEND_REPO}"

frontend_user="$(
  docker image inspect "${FRONTEND_IMAGE}" --format '{{.Config.User}}'
)"
backend_user="$(
  docker image inspect "${BACKEND_IMAGE}" --format '{{.Config.User}}'
)"
[[ "${frontend_user}" == "nextjs" ]]
[[ "${backend_user}" == "appuser" ]]

docker run --rm \
  --entrypoint sh \
  "${BACKEND_IMAGE}" \
  -lc 'test ! -e /app/.env && test ! -e /app/.env.k8s && test ! -e /app/.env.example'

docker run --rm \
  --entrypoint node \
  "${BACKEND_IMAGE}" \
  -e '
const { validateEnvironment } = require("./dist/common/config/environment.js");
validateEnvironment({
  NODE_ENV: "production",
  NODE_TLS_REJECT_UNAUTHORIZED: "1",
  APP_ORIGIN: "https://tpl.sunmoonai.com",
  FRONTEND_URL: "https://tpl.sunmoonai.com",
  DATABASE_URL: "postgresql://user:password@postgresql:5432/tpl_web",
  REDIS_HOST: "redis.default.svc.cluster.local",
  REDIS_USER: "web-backend",
  REDIS_PASSWORD: "redis-password",
  CASDOOR_ENDPOINT: "https://casdoor.sunmoonai.com",
  CASDOOR_CLIENT_ID: "web-client",
  CASDOOR_CLIENT_SECRET: "client-secret",
  CASDOOR_REDIRECT_URI: "https://tpl.sunmoonai.com/api/auth/callback",
  CASDOOR_ORGANIZATION: "built-in",
  CASDOOR_APPLICATION: "app-tpl-web"
});
console.log("backend_environment=passed");
'

docker run -d \
  --name "${FRONTEND_CONTAINER}" \
  -p "${FRONTEND_PORT}:3000" \
  -e APP_ORIGIN="http://127.0.0.1:${FRONTEND_PORT}" \
  -e WEB_BACKEND_INTERNAL_URL=http://tpl-web-backend:8000 \
  -e DEPLOYMENT_ID=p0-008b-b1-candidate \
  "${FRONTEND_IMAGE}" >/dev/null

ready=0
for _ in $(seq 1 45); do
  if curl --fail --silent --show-error \
    --connect-timeout 2 \
    --max-time 5 \
    "http://127.0.0.1:${FRONTEND_PORT}/en" \
    >/tmp/p0-008b-b1-frontend.html; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "${ready}" != "1" ]]; then
  docker logs "${FRONTEND_CONTAINER}"
  exit 1
fi

grep -q 'data-route-class="public-content"' /tmp/p0-008b-b1-frontend.html
test "$(
  curl --silent --show-error \
    -o /tmp/p0-008b-b1-not-found.html \
    -w '%{http_code}' \
    "http://127.0.0.1:${FRONTEND_PORT}/en/not-found-b1"
)" = "404"
[[ "$(docker exec "${FRONTEND_CONTAINER}" id -u)" = "1001" ]]

(
  cd "${FRONTEND_REPO}/app"
  PLAYWRIGHT_BASE_URL="http://127.0.0.1:${FRONTEND_PORT}" \
    corepack pnpm test:e2e
)

frontend_id="$(docker image inspect "${FRONTEND_IMAGE}" --format '{{.Id}}')"
backend_id="$(docker image inspect "${BACKEND_IMAGE}" --format '{{.Id}}')"

printf '{"task":"V5-P0-008B-B1-docker","result":"passed","frontend_image_id":"%s","backend_image_id":"%s","frontend_user":"%s","backend_user":"%s","secrets_printed":false}\n' \
  "${frontend_id}" \
  "${backend_id}" \
  "${frontend_user}" \
  "${backend_user}"
