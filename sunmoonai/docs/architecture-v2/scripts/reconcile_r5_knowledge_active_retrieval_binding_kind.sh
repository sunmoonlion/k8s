#!/usr/bin/env bash

# Reconcile the single active Knowledge retrieval binding from one of the
# provider-managed caller bindings. Secret values never leave the cluster or
# appear in command output. R7.1 has retired the Research rollback runtime, so
# Investment is now the only accepted active caller.
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE=app-platform-dev
CALLER=investment
RESTART=true
TARGET_SECRET=knowledge-active-retrieval-service-binding

usage() {
  echo "usage: $0 [--caller investment] [--no-restart] [--kubeconfig PATH] [--namespace NAME]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --caller) CALLER="$2"; shift 2 ;;
    --no-restart) RESTART=false; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

case "$CALLER" in
  investment) SOURCE_SECRET=knowledge-investment-retrieval-service-binding ;;
  *)
    echo "caller '$CALLER' is retired; only investment is accepted after R7.1" >&2
    usage
    exit 2
    ;;
esac

[[ "$NAMESPACE" == app-platform-dev ]] || {
  echo "active retrieval binding is restricted to app-platform-dev" >&2
  exit 2
}

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=30s "$@"
}

source_json="$(k get secret "$SOURCE_SECRET" -n "$NAMESPACE" -o json)"
changed=false
for key in \
  RETRIEVAL_AUTH_CASDOOR_APPLICATION \
  RETRIEVAL_AUTH_DISCOVERY_URL \
  RETRIEVAL_AUTH_BACKCHANNEL_ENDPOINT \
  RETRIEVAL_AUTH_AUDIENCE \
  RETRIEVAL_AUTH_SUBJECT_ALLOWLIST \
  RETRIEVAL_AUTH_REQUIRED_SCOPE
do
  jq -e --arg key "$key" '.data[$key] | type == "string" and length > 0' \
    <<<"$source_json" >/dev/null
done

existing_json="$(k get secret "$TARGET_SECRET" -n "$NAMESPACE" -o json 2>/dev/null || true)"
if [[ -z "$existing_json" ]] \
  || [[ "$(jq -cS '.data' <<<"$existing_json")" != "$(jq -cS '.data' <<<"$source_json")" ]] \
  || [[ "$(jq -r '.metadata.labels["sunmoonai.com/active-caller"] // ""' <<<"$existing_json")" != "$CALLER" ]] \
  || [[ "$(jq -r '.metadata.annotations["architecture.sunmoonai.com/source-secret"] // ""' <<<"$existing_json")" != "$SOURCE_SECRET" ]]
then
  changed=true
fi

jq \
  --arg namespace "$NAMESPACE" \
  --arg target "$TARGET_SECRET" \
  --arg caller "$CALLER" \
  '{
    apiVersion:"v1",
    kind:"Secret",
    metadata:{
      name:$target,
      namespace:$namespace,
      labels:{
        "sunmoonai.com/managed-by":"architecture-v2",
        "sunmoonai.com/relation":"knowledge-retrieval-active",
        "sunmoonai.com/active-caller":$caller
      },
      annotations:{
        "architecture.sunmoonai.com/source-secret":.metadata.name
      }
    },
    type:"Opaque",
    data:.data
  }' <<<"$source_json" | k apply -f - >/dev/null

DEPLOYMENT=knowledge-r5-backend-api
deployment_json="$(k get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o json)"
container_name="$(jq -er '.spec.template.spec.containers[0].name' <<<"$deployment_json")"
current_env_from="$(jq -c '.spec.template.spec.containers[0].envFrom' <<<"$deployment_json")"
env_from="$(
  jq -c '
    .spec.template.spec.containers[0].envFrom
    | map(
        if .secretRef.name == "knowledge-research-retrieval-service-binding"
           or .secretRef.name == "knowledge-investment-retrieval-service-binding"
        then {secretRef:{name:"knowledge-active-retrieval-service-binding"}}
        else .
        end
      )
    | reduce .[] as $item (
        [];
        ($item.configMapRef.name // $item.secretRef.name) as $key
        | if any(.[]; (.configMapRef.name // .secretRef.name) == $key)
          then .
          else . + [$item]
          end
      )
  ' <<<"$deployment_json"
)"
if [[ "$current_env_from" != "$env_from" ]]; then
  jq -n \
    --arg name "$container_name" \
    --argjson envFrom "$env_from" \
    '{spec:{template:{spec:{containers:[{name:$name,envFrom:$envFrom}]}}}}' \
    | k patch deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        --type=strategic --patch-file=/dev/stdin >/dev/null
  changed=true
fi

if [[ "$RESTART" == true && "$changed" == true ]]; then
  k rollout restart "deployment/$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
  k rollout status "deployment/$DEPLOYMENT" -n "$NAMESPACE" --timeout=300s >/dev/null
fi

active="$(k get secret "$TARGET_SECRET" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.sunmoonai\.com/active-caller}')"
[[ "$active" == "$CALLER" ]]

printf '{"task":"R5-Knowledge-active-retrieval-binding","result":"passed","active_caller":"%s","target_secret":"%s","changed":%s,"credentials_printed":false}\n' \
  "$CALLER" "$TARGET_SECRET" "$changed"
