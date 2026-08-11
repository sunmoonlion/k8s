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
DEFINITIONS_FILE="$SCRIPT_DIR/../../../messaging-platform/rabbitmq/resources/custom-values/app-definitions-development.yaml"
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
k patch secret rabbitmq-app-definitions -n "$RABBIT_NAMESPACE" --type=merge \
  -p "{\"data\":{\"load_definition.json\":\"$definition_b64\"}}" >/dev/null
expected_hash="$(printf '%s' "$definition_json" | sha256sum | awk '{print $1}')"
for _ in $(seq 1 30); do
  observed_hash="$(k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- sha256sum /app/load_definition.json 2>/dev/null | awk '{print $1}' || true)"
  [[ "$observed_hash" == "$expected_hash" ]] && break
  sleep 2
done
[[ "$observed_hash" == "$expected_hash" ]] || { echo "RabbitMQ definition volume did not converge" >&2; exit 1; }
k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- rabbitmqctl import_definitions /app/load_definition.json >/dev/null

password="investment-backend-worker-dev"
url="amqp://${USER_NAME}:${password}@rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local:5672/${VHOST}"
k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- rabbitmqctl authenticate_user "$USER_NAME" "$password" >/dev/null
permissions="$(k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- rabbitmqctl list_user_permissions "$USER_NAME" -q)"
queues="$(k exec --quiet -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- rabbitmqctl list_queues -p "$VHOST" name -q)"
grep -Fq "$VHOST" <<<"$permissions"
grep -Fxq 'investment.default' <<<"$queues"
k create secret generic "$SECRET" -n "$APP_NAMESPACE" --from-literal=CELERY_BROKER_URL="$url" --dry-run=client -o yaml | k apply -f - >/dev/null
k label secret "$SECRET" -n "$APP_NAMESPACE" sunmoonai.com/architecture=v2 sunmoonai.com/app=investment-r5 --overwrite >/dev/null
unset password url definition_json definition_b64 expected_hash observed_hash permissions queues
if [[ "$RESTART" == true ]] && k get deployment investment-r5-backend-api -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  k rollout restart deployment/investment-r5-backend-api deployment/investment-r5-backend-worker deployment/investment-r5-backend-scheduler -n "$APP_NAMESPACE" >/dev/null
fi
printf '{"task":"R5-V2-investment-broker","result":"passed","source_of_truth":"rabbitmq-app-definitions","user":"investment-backend-worker","vhost":"investment-development","queue":"investment.default","credentials_printed":false}\n'
