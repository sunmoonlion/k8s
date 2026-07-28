#!/usr/bin/env bash

# Independently roll the backend and frontend of one accepted Web tuple back to
# its prior immutable image and forward to the candidate again. Real Casdoor
# and strict-TLS verification runs at every stable point.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
PROFILE=""
OLD_BACKEND=""
NEW_BACKEND=""
OLD_FRONTEND=""
NEW_FRONTEND=""
CA_CERT="${HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt"

usage() {
  cat <<'EOF'
Usage: verify_b6_web_pair_rollbacks.sh --profile fastapi|nest \
  --old-backend IMAGE@sha256:DIGEST --new-backend IMAGE@sha256:DIGEST \
  --old-frontend IMAGE@sha256:DIGEST --new-frontend IMAGE@sha256:DIGEST
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --old-backend) OLD_BACKEND="$2"; shift 2 ;;
    --new-backend) NEW_BACKEND="$2"; shift 2 ;;
    --old-frontend) OLD_FRONTEND="$2"; shift 2 ;;
    --new-frontend) NEW_FRONTEND="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --ca-cert) CA_CERT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

for image in "$OLD_BACKEND" "$NEW_BACKEND" "$OLD_FRONTEND" "$NEW_FRONTEND"; do
  [[ "$image" =~ @sha256:[a-f0-9]{64}$ ]] || {
    printf 'all images must be immutable digest references\n' >&2
    exit 1
  }
done
[[ "$OLD_BACKEND" != "$NEW_BACKEND" ]] || {
  printf 'old and new backend digests must differ\n' >&2
  exit 1
}
[[ "$OLD_FRONTEND" != "$NEW_FRONTEND" ]] || {
  printf 'old and new frontend digests must differ\n' >&2
  exit 1
}
[[ -f "$CA_CERT" ]] || {
  printf 'strict TLS CA certificate is absent\n' >&2
  exit 1
}

case "$PROFILE" in
  fastapi)
    BACKEND_DEPLOYMENT="tpl-web-backend-p0-008b-b63f"
    FRONTEND_DEPLOYMENT="tpl-web-frontend-p0-008b-b63f"
    ORIGIN="https://tpl-web-p0-008b-b63f.sunmoonai.com:30443"
    VERIFIER="/home/zymun/k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_b6_web_fastapi_pair.mjs"
    TASK="V5-P0-008B-B6.3F-rollback"
    ;;
  nest)
    BACKEND_DEPLOYMENT="tpl-web-backend-b4"
    FRONTEND_DEPLOYMENT="tpl-web-frontend-b4"
    ORIGIN="https://tpl-web-b4.sunmoonai.com:30443"
    VERIFIER="/home/zymun/k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b4.mjs"
    TASK="V5-P0-008B-B6.3N-rollback"
    ;;
  *)
    printf 'profile must be fastapi or nest\n' >&2
    exit 2
    ;;
esac

k() {
  env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"
}

deployment_image() {
  k get "deployment/$1" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}'
}

business_snapshot() {
  k get deployments -n "$NAMESPACE" -o json \
    | jq -S --arg backend "$BACKEND_DEPLOYMENT" --arg frontend "$FRONTEND_DEPLOYMENT" '
        [.items[]
          | select(.metadata.name != $backend and .metadata.name != $frontend)
          | {
              name: .metadata.name,
              generation: .metadata.generation,
              image: .spec.template.spec.containers[0].image
            }
        ]
      '
}

run_verifier() {
  if [[ "$PROFILE" == fastapi ]]; then
    B63F_NAMESPACE="$NAMESPACE" \
    B63F_ORIGIN="$ORIGIN" \
    B63F_CA_CERT="$CA_CERT" \
    KUBECONFIG="$KUBECONFIG_PATH" \
      node "$VERIFIER"
  else
    B4_NAMESPACE="$NAMESPACE" \
    B4_ORIGIN="$ORIGIN" \
    B4_CA_CERT="$CA_CERT" \
    KUBECONFIG="$KUBECONFIG_PATH" \
      node "$VERIFIER"
  fi
}

patch_component() {
  local deployment="$1" image="$2" deployment_id="$3"
  local patch
  patch="$(
    jq -nc \
      --arg image "$image" \
      --arg deployment_id "$deployment_id" \
      '{
        spec: {
          template: {
            metadata: {
              annotations: {
                "sunmoonai.com/deployment-id": $deployment_id
              }
            },
            spec: {
              containers: [{
                name: (if $ARGS.named.deployment_id | contains("frontend")
                  then "frontend" else "backend" end),
                image: $image,
                env: [{name: "DEPLOYMENT_ID", value: $deployment_id}]
              }]
            }
          }
        }
      }'
  )"
  k patch "deployment/$deployment" -n "$NAMESPACE" \
    --type=strategic -p "$patch" >/dev/null
}

roll_with_continuity() {
  local deployment="$1" image="$2" deployment_id="$3"
  local host port monitor_dir monitor_pid
  host="${ORIGIN#https://}"
  host="${host%%:*}"
  port="${ORIGIN##*:}"
  monitor_dir="$(mktemp -d "/tmp/b63-${PROFILE}-monitor.XXXXXX")"

  (
    set +e
    count=0
    while :; do
      if ! curl --fail --silent --show-error \
        --connect-timeout 2 --max-time 10 \
        --cacert "$CA_CERT" \
        --resolve "${host}:${port}:127.0.0.1" \
        "${ORIGIN}/zh-CN" >/dev/null; then
        printf 'failed\n' >"${monitor_dir}/failure"
        exit 1
      fi
      count=$((count + 1))
      printf '%s\n' "$count" >"${monitor_dir}/count"
      sleep 0.2
    done
  ) &
  monitor_pid=$!

  sleep 1
  patch_component "$deployment" "$image" "$deployment_id"
  if ! k rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout=300s; then
    kill "$monitor_pid" >/dev/null 2>&1 || true
    wait "$monitor_pid" >/dev/null 2>&1 || true
    rm -rf "$monitor_dir"
    return 1
  fi
  sleep 1
  kill "$monitor_pid" >/dev/null 2>&1 || true
  wait "$monitor_pid" >/dev/null 2>&1 || true

  [[ ! -e "${monitor_dir}/failure" ]] || {
    printf 'strict TLS continuity probe failed during %s rollout\n' "$deployment" >&2
    rm -rf "$monitor_dir"
    return 1
  }
  [[ -s "${monitor_dir}/count" ]] || {
    printf 'strict TLS continuity probe made no successful request\n' >&2
    rm -rf "$monitor_dir"
    return 1
  }
  [[ "$(deployment_image "$deployment")" == "$image" ]] || {
    printf 'deployment did not stabilize at the requested digest\n' >&2
    rm -rf "$monitor_dir"
    return 1
  }
  cat "${monitor_dir}/count"
  rm -rf "$monitor_dir"
}

BUSINESS_BEFORE="$(business_snapshot)"
[[ "$(deployment_image "$BACKEND_DEPLOYMENT")" == "$NEW_BACKEND" ]]
[[ "$(deployment_image "$FRONTEND_DEPLOYMENT")" == "$NEW_FRONTEND" ]]

printf '%s_STAGE=stable_candidate\n' "$TASK"
run_verifier

printf '%s_STAGE=backend_rollback\n' "$TASK"
BACKEND_ROLLBACK_PROBES="$(
  roll_with_continuity "$BACKEND_DEPLOYMENT" "$OLD_BACKEND" \
    "b63-${PROFILE}-backend-rollback"
)"
run_verifier

printf '%s_STAGE=backend_recovery\n' "$TASK"
BACKEND_RECOVERY_PROBES="$(
  roll_with_continuity "$BACKEND_DEPLOYMENT" "$NEW_BACKEND" \
    "b63-${PROFILE}-backend-current"
)"
run_verifier

printf '%s_STAGE=frontend_rollback\n' "$TASK"
FRONTEND_ROLLBACK_PROBES="$(
  roll_with_continuity "$FRONTEND_DEPLOYMENT" "$OLD_FRONTEND" \
    "b63-${PROFILE}-frontend-rollback"
)"
run_verifier

printf '%s_STAGE=frontend_recovery\n' "$TASK"
FRONTEND_RECOVERY_PROBES="$(
  roll_with_continuity "$FRONTEND_DEPLOYMENT" "$NEW_FRONTEND" \
    "b63-${PROFILE}-frontend-current"
)"
run_verifier

[[ "$BUSINESS_BEFORE" == "$(business_snapshot)" ]] || {
  printf 'a non-B6.3 business Deployment changed\n' >&2
  exit 1
}

jq -nc \
  --arg task "$TASK" \
  --arg profile "$PROFILE" \
  --arg old_backend "$OLD_BACKEND" \
  --arg new_backend "$NEW_BACKEND" \
  --arg old_frontend "$OLD_FRONTEND" \
  --arg new_frontend "$NEW_FRONTEND" \
  --argjson backend_rollback_probes "$BACKEND_ROLLBACK_PROBES" \
  --argjson backend_recovery_probes "$BACKEND_RECOVERY_PROBES" \
  --argjson frontend_rollback_probes "$FRONTEND_ROLLBACK_PROBES" \
  --argjson frontend_recovery_probes "$FRONTEND_RECOVERY_PROBES" \
  '{
    task: $task,
    result: "passed",
    profile: $profile,
    path: "candidate -> backend-old -> backend-current -> frontend-old -> frontend-current",
    old_backend: $old_backend,
    new_backend: $new_backend,
    old_frontend: $old_frontend,
    new_frontend: $new_frontend,
    continuity_probes: {
      backend_rollback: $backend_rollback_probes,
      backend_recovery: $backend_recovery_probes,
      frontend_rollback: $frontend_rollback_probes,
      frontend_recovery: $frontend_recovery_probes
    },
    full_verifications: 5,
    final_state: "current",
    strict_tls: true,
    real_casdoor: true,
    business_deployments_unchanged: true,
    credentials_printed: false,
    tokens_printed: false
  }'
