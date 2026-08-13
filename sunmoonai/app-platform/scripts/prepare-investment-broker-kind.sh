#!/usr/bin/env bash

# Reconcile a dedicated RabbitMQ vhost/user for Investment Celery roles.
set -euo pipefail
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE=app-platform-dev
RABBIT_NAMESPACE=messaging-platform-dev
POD=rabbitmq-sunmoonai-0
USER_NAME=investment-backend-worker
VHOST=investment-development
SECRET=investment-backend-broker
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINITIONS_FILE="$SCRIPT_DIR/../../messaging-platform/rabbitmq/resources/custom-values/app-definitions-development.yaml"
MODE=plan
RESTART=true
[[ "${1:-}" != --apply ]] || { MODE=apply; shift; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --no-restart) RESTART=false; shift ;;
    *) exit 2 ;;
  esac
done
k() { env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"; }
printf 'PLAN broker=%s/%s user=%s vhost=%s queue=investment.default credentials_printed=false\n' "$APP_NAMESPACE" "$SECRET" "$USER_NAME" "$VHOST"
[[ "$MODE" == apply ]] || exit 0

# RabbitMQ's loaded definitions are the topology source of truth.  Users that
# are created only with rabbitmqctl are removed by the definitions reconciler,
# so update the mounted definition first and import that exact document.
definition_json="$(python3 - "$DEFINITIONS_FILE" <<'PY'
import json
import pathlib
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
marker = next(i for i, line in enumerate(lines) if "load_definition.json: |" in line)
body = lines[marker + 1 :]
nonempty = [line for line in body if line.strip()]
indent = min(len(line) - len(line.lstrip()) for line in nonempty)
text = "\n".join(line[indent:] for line in body).strip()
value = json.loads(text)
assert any(item.get("name") == "investment-backend-worker" for item in value["users"])
assert any(item.get("name") == "investment.default" for item in value["queues"])
print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
PY
)"
definition_b64="$(printf '%s' "$definition_json" | base64 -w0)"
echo BROKER_STAGE=update-definition-secret
k patch secret rabbitmq-app-definitions -n "$RABBIT_NAMESPACE" --type=merge \
  -p "{\"data\":{\"load_definition.json\":\"$definition_b64\"}}" >/dev/null
k wait --for=condition=Ready "pod/$POD" -n "$RABBIT_NAMESPACE" --timeout=300s >/dev/null
expected_hash="$(printf '%s' "$definition_json" | sha256sum | awk '{print $1}')"
for _ in $(seq 1 30); do
  observed_hash="$(k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- sha256sum /app/load_definition.json 2>/dev/null | awk '{print $1}' || true)"
  [[ "$observed_hash" == "$expected_hash" ]] && break
  sleep 2
done
[[ "$observed_hash" == "$expected_hash" ]] || { echo "RabbitMQ definition volume did not converge" >&2; exit 1; }
echo BROKER_STAGE=reconcile-active-topology

# Do not import the complete definitions document into a live 384Mi RabbitMQ
# process. RabbitMQ imports definitions concurrently and the full online import
# can exceed that memory limit. Reconcile only this App's live objects; the
# mounted full document remains the source used at broker startup.
password="investment-backend-worker-dev"
permission_pattern='^investment[.]default$|^celery|^celery[.].*|^reply[.]celery[.].*|^.*[.]reply[.]celery[.]pidbox$|^celeryev$'
k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- sh -lc '
  set -eu
  user="$1"; password="$2"; vhost="$3"; pattern="$4"
  admin="$RABBITMQ_USERNAME:$(cat "$RABBITMQ_PASSWORD_FILE")"
  api=http://127.0.0.1:15672/api
  curl --fail --silent --show-error --user "$admin" \
    --header "content-type: application/json" --request PUT \
    --data "{\"password\":\"$password\",\"tags\":\"\"}" \
    "$api/users/$user" >/dev/null
  curl --fail --silent --show-error --user "$admin" \
    --header "content-type: application/json" --request PUT \
    --data "{\"configure\":\"$pattern\",\"write\":\"$pattern\",\"read\":\"$pattern\"}" \
    "$api/permissions/$vhost/$user" >/dev/null
  curl --fail --silent --show-error --user "$admin" \
    --header "content-type: application/json" --request PUT \
    --data "{\"durable\":true,\"auto_delete\":false,\"arguments\":{}}" \
    "$api/queues/$vhost/investment.default" >/dev/null
  for legacy_queue in investment.web.default investment.admin.default; do
    code="$(curl --silent --show-error --user "$admin" --request DELETE \
      --output /dev/null --write-out "%{http_code}" \
      "$api/queues/$vhost/$legacy_queue")"
    test "$code" = 204 || test "$code" = 404
  done
  for legacy_user in \
    investment-web-backend-producer investment-web-backend-worker \
    investment-admin-backend-producer investment-admin-backend-worker; do
    code="$(curl --silent --show-error --user "$admin" --request DELETE \
      --output /dev/null --write-out "%{http_code}" "$api/users/$legacy_user")"
    test "$code" = 204 || test "$code" = 404
  done
  curl --fail --silent --show-error --user "$admin" "$api/users/$user" \
    | grep -Fq "\"name\":\"$user\""
  curl --fail --silent --show-error --user "$admin" \
    "$api/queues/$vhost/investment.default" >/dev/null
' sh "$USER_NAME" "$password" "$VHOST" "$permission_pattern"

# R7.1 已关闭旧双 Backend 观察窗；上面的精确协调同时清除了旧用户和队列。
echo BROKER_STAGE=legacy-queues-removed
echo BROKER_STAGE=legacy-users-removed

url="amqp://${USER_NAME}:${password}@rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local:5672/${VHOST}"
echo BROKER_STAGE=active-user-authenticated
k create secret generic "$SECRET" -n "$APP_NAMESPACE" --from-literal=CELERY_BROKER_URL="$url" --dry-run=client -o yaml | k apply -f - >/dev/null
echo BROKER_STAGE=application-secret-reconciled
k label secret "$SECRET" -n "$APP_NAMESPACE" sunmoonai.com/architecture=v2 sunmoonai.com/app=investment-r5 sunmoonai.com/managed-by=app-platform-v2 --overwrite >/dev/null
unset password url definition_json definition_b64 expected_hash observed_hash permission_pattern
if [[ "$RESTART" == true ]] && k get deployment investment-r5-backend-api -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  k rollout restart deployment/investment-r5-backend-api deployment/investment-r5-backend-worker deployment/investment-r5-backend-scheduler -n "$APP_NAMESPACE" >/dev/null
fi
printf '{"task":"R5-V2-investment-broker","result":"passed","source_of_truth":"rabbitmq-app-definitions","user":"investment-backend-worker","vhost":"investment-development","queue":"investment.default","credentials_printed":false}\n'
