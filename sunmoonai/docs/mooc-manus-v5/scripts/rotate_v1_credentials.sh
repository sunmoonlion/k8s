#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
DATA_NAMESPACE="${DATA_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
REDIS_POD="${REDIS_POD:-redis-sunmoonai-master-0}"

kctl() {
  kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

secret_value() {
  local secret_name="$1"
  local key="$2"
  kctl get secret "$secret_name" -n "$APP_NAMESPACE" \
    -o "jsonpath={.data.${key}}" | base64 --decode
}

patch_secret_values() {
  local secret_name="$1"
  shift
  local patch='{"stringData":{'
  local separator=''
  local pair key value
  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    patch+="${separator}\"${key}\":$(jq -Rn --arg value "$value" '$value')"
    separator=','
  done
  patch+='}}'
  kctl patch secret "$secret_name" -n "$APP_NAMESPACE" \
    --type merge --patch "$patch" >/dev/null
}

replace_url_password() {
  URI="$1" NEW_PASSWORD="$2" python3 -c '
import os
from urllib.parse import quote, urlsplit, urlunsplit

parts = urlsplit(os.environ["URI"])
username = quote(parts.username or "", safe="")
password = quote(os.environ["NEW_PASSWORD"], safe="")
host = parts.hostname or ""
if ":" in host and not host.startswith("["):
    host = f"[{host}]"
port = f":{parts.port}" if parts.port is not None else ""
print(urlunsplit((parts.scheme, f"{username}:{password}@{host}{port}", parts.path, parts.query, parts.fragment)))
'
}

rotate_postgres_app() {
  local app="$1"
  local secret="${app}-admin-backend-postgresql-conn"
  local user database old_password new_password old_uri new_uri
  user="$(secret_value "$secret" APP_DB_USER)"
  database="$(secret_value "$secret" APP_DB_NAME)"
  old_password="$(secret_value "$secret" APP_DB_PASSWORD)"
  old_uri="$(secret_value "$secret" APP_DB_URI)"
  new_password="$(openssl rand -hex 24)"
  new_uri="$(replace_url_password "$old_uri" "$new_password")"

  local escaped_user escaped_password
  escaped_user="${user//\"/\"\"}"
  escaped_password="${new_password//\'/\'\'}"
  kctl exec -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- sh -lc \
    'PGPASSWORD="$(cat /opt/bitnami/postgresql/secrets/admin_password)" exec /opt/bitnami/postgresql/bin/psql -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1' \
    <<<"ALTER ROLE \"${escaped_user}\" WITH PASSWORD '${escaped_password}';" >/dev/null

  patch_secret_values "$secret" \
    "APP_DB_PASSWORD=$new_password" \
    "APP_DB_URI=$new_uri" \
    "DATABASE_URL=$new_uri"

  if kctl exec -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- env PGPASSWORD="$old_password" \
    /opt/bitnami/postgresql/bin/psql -h 127.0.0.1 -U "$user" -d "$database" -c 'select 1' \
    >/dev/null 2>&1; then
    echo "ERROR: old PostgreSQL password still works for ${app}" >&2
    return 1
  fi
  kctl exec -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- env PGPASSWORD="$new_password" \
    /opt/bitnami/postgresql/bin/psql -h 127.0.0.1 -U "$user" -d "$database" -c 'select 1' \
    >/dev/null
  echo "ROTATED postgres ${app}"
}

rotate_redis_app() {
  local app="$1"
  local secret="${app}-admin-backend-redis-conn"
  local user old_password new_password old_uri new_uri admin_password
  user="$(secret_value "$secret" REDIS_USER)"
  old_password="$(secret_value "$secret" REDIS_PASSWORD)"
  old_uri="$(secret_value "$secret" REDIS_URI)"
  new_password="$(openssl rand -hex 24)"
  new_uri="$(replace_url_password "$old_uri" "$new_password")"
  admin_password="$(kctl get secret redis-auth-secret -n "$DATA_NAMESPACE" \
    -o jsonpath='{.data.redis-password}' | base64 --decode)"

  kctl exec -i -n "$DATA_NAMESPACE" "$REDIS_POD" -- \
    redis-cli --no-auth-warning -a "$admin_password" \
    ACL SETUSER "$user" resetpass ">$new_password" >/dev/null

  patch_secret_values "$secret" \
    "REDIS_PASSWORD=$new_password" \
    "REDIS_URI=$new_uri"

  if kctl exec -i -n "$DATA_NAMESPACE" "$REDIS_POD" -- \
    redis-cli --no-auth-warning --user "$user" -a "$old_password" PING \
    2>/dev/null | grep -qx PONG; then
    echo "ERROR: old Redis password still works for ${app}" >&2
    return 1
  fi
  test "$(kctl exec -i -n "$DATA_NAMESPACE" "$REDIS_POD" -- \
    redis-cli --no-auth-warning --user "$user" -a "$new_password" PING \
    2>/dev/null | tr -d '\r')" = PONG
  echo "ROTATED redis ${app}"
}

restart_app() {
  local app="$1"
  local api="${app}-admin-backend"
  local worker="celeryworker-${app}-admin-backend"
  kctl rollout restart deployment "$api" "$worker" -n "$APP_NAMESPACE" >/dev/null
  kctl rollout status deployment "$api" -n "$APP_NAMESPACE" --timeout=300s
  kctl rollout status deployment "$worker" -n "$APP_NAMESPACE" --timeout=300s
  echo "READY ${app}"
}

for app in info knowledge research; do
  rotate_postgres_app "$app"
done

for app in info knowledge; do
  rotate_redis_app "$app"
done

for app in info knowledge research; do
  restart_app "$app"
done

echo "V1 credential rotation passed"
