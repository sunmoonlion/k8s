#!/usr/bin/env bash

# Verify the formal Investment Celery queue without printing credentials.
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
RABBIT_NAMESPACE=messaging-platform-dev
POD=rabbitmq-sunmoonai-0
VHOST=investment-development
QUEUE=investment.default

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

row="$(
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" exec --quiet \
    -n "$RABBIT_NAMESPACE" "$POD" -c rabbitmq -- \
    rabbitmqctl list_queues -p "$VHOST" name consumers messages_ready messages_unacknowledged -q \
    | awk -v queue="$QUEUE" '$1 == queue {print $0}'
)"
[[ -n "$row" ]] || { echo "formal Investment queue is absent" >&2; exit 1; }
read -r name consumers ready unacknowledged <<<"$row"
[[ "$name" == "$QUEUE" && "$consumers" == 1 && "$ready" == 0 && "$unacknowledged" == 0 ]] || {
  echo "formal Investment queue is not drained or has the wrong consumer count" >&2
  exit 1
}

printf '{"task":"R5-V4-investment-broker","result":"passed","vhost":"%s","queue":"%s","consumers":%d,"messages_ready":%d,"messages_unacknowledged":%d,"credentials_printed":false}\n' \
  "$VHOST" "$QUEUE" "$consumers" "$ready" "$unacknowledged"
