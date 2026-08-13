#!/usr/bin/env bash

# Create a dedicated Investment Redis principal and prove its key isolation.
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
DATA_NAMESPACE="data-platform-dev"
TARGET_SECRET="investment-backend-redis-conn"
USER_NAME="investment_backend"
REDIS_HOST="redis-sunmoonai-master.data-platform-dev.svc.cluster.local"
REDIS_PORT="6379"
REDIS_DB="0"
REDIS_IMAGE="harbor.sunmoonai.com:30443/k8s-images/redis:8.2.1-debian-12-r0"
MODE=plan
RESTART=true

[[ "${1:-}" != --apply ]] || { MODE=apply; shift; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --app-namespace) APP_NAMESPACE="$2"; shift 2 ;;
    --data-namespace) DATA_NAMESPACE="$2"; shift 2 ;;
    --no-restart) RESTART=false; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
k() { env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"; }

printf 'PLAN target=%s/%s redis_user=%s keyspace=investment:*\n' "$APP_NAMESPACE" "$TARGET_SECRET" "$USER_NAME"
printf 'PLAN source_values=host,port,db only credentials_generated=true credentials_printed=false\n'
[[ "$MODE" == apply ]] || exit 0

tmpdir="$(mktemp -d)"; chmod 700 "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
if k get secret "$TARGET_SECRET" -n "$APP_NAMESPACE" -o json >"$tmpdir/target.json" 2>/dev/null; then
  # The existing Secret is the stable credential source. Reconcile Redis from
  # it instead of rotating the password on every declarative apply.
  chmod 600 "$tmpdir/target.json"
  python3 - "$tmpdir/target.json" "$USER_NAME" <<'PY'
import base64,json,sys
payload=json.load(open(sys.argv[1])); data=payload.get("data",{})
required={"REDIS_HOST","REDIS_PORT","REDIS_DB","REDIS_USER","REDIS_PASSWORD"}
if not required.issubset(data): raise SystemExit("existing Investment Redis Secret is incomplete")
if base64.b64decode(data["REDIS_USER"]).decode()!=sys.argv[2]: raise SystemExit("Investment Redis principal drift")
PY
  credential_source=existing-secret
else
  password="$(openssl rand -hex 32)"
  # Build a new Investment-owned connection Secret from governed, non-secret
  # topology values.  No retired Research Secret is a bootstrap dependency.
  python3 - "$APP_NAMESPACE" "$TARGET_SECRET" "$USER_NAME" "$password" "$REDIS_HOST" "$REDIS_PORT" "$REDIS_DB" <<'PY' >"$tmpdir/target.json"
import base64,json,sys
namespace,name,user,password,host,port,db=sys.argv[1:]
data={
    "REDIS_HOST":base64.b64encode(host.encode()).decode(),
    "REDIS_PORT":base64.b64encode(port.encode()).decode(),
    "REDIS_DB":base64.b64encode(db.encode()).decode(),
}
data["REDIS_USER"]=base64.b64encode(user.encode()).decode()
data["REDIS_PASSWORD"]=base64.b64encode(password.encode()).decode()
print(json.dumps({"apiVersion":"v1","kind":"Secret","metadata":{"name":name,"namespace":namespace,"labels":{"sunmoonai.com/architecture":"v2","sunmoonai.com/app":"investment"}},"type":"Opaque","data":data},separators=(",",":")))
PY
  k apply -f "$tmpdir/target.json" >/dev/null
  unset password
  credential_source=generated-once
fi

job=app-platform-v2-investment-redis-acl
k delete job "$job" -n "$DATA_NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${DATA_NAMESPACE}
  labels: {sunmoonai.com/architecture: v2, sunmoonai.com/app: investment}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 120
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels: {sunmoonai.com/architecture: v2, sunmoonai.com/app: investment}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      containers:
      - name: reconcile
        image: ${REDIS_IMAGE}
        securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
        env:
        - name: REDIS_ADMIN_PASSWORD
          valueFrom: {secretKeyRef: {name: redis-auth-secret, key: redis-password}}
        - name: APP_REDIS_USER
          value: ${USER_NAME}
        - name: APP_REDIS_PASSWORD
          valueFrom: {secretKeyRef: {name: investment-redis-credential, key: REDIS_PASSWORD}}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          export REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD"
          redis-cli -e -h '${REDIS_HOST}' --user default ACL SETUSER "\$APP_REDIS_USER" reset on ">\$APP_REDIS_PASSWORD" '~investment:*' resetchannels -@all +@read +@write +@connection +@hash +@string +@list +@set +@sortedset -@dangerous >/dev/null
          redis-cli -e -h '${REDIS_HOST}' --user default ACL SAVE >/dev/null
          export REDISCLI_AUTH="\$APP_REDIS_PASSWORD"
          test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" PING)" = PONG
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" SET 'investment:app-platform-v2:acl-test' ok EX 30 >/dev/null
          test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" GET 'investment:app-platform-v2:acl-test')" = ok
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" DEL 'investment:app-platform-v2:acl-test' >/dev/null
          if redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" SET 'research:app-platform-v2:forbidden' denied EX 30 >/dev/null 2>&1; then exit 1; fi
          printf 'investment_redis_acl=passed positive=passed negative=passed credentials_printed=false\n'
EOF

# Transfer only the new password into the data namespace for the short-lived Job.
k get secret "$TARGET_SECRET" -n "$APP_NAMESPACE" -o json >"$tmpdir/live.json"
python3 - "$tmpdir/live.json" "$DATA_NAMESPACE" <<'PY' >"$tmpdir/data.json"
import json,sys
v=json.load(open(sys.argv[1])); v["metadata"]={"name":"investment-redis-credential","namespace":sys.argv[2]}; v["data"]={"REDIS_PASSWORD":v["data"]["REDIS_PASSWORD"]}; v.pop("status",None); print(json.dumps(v,separators=(",",":")))
PY
k apply -f "$tmpdir/data.json" >/dev/null
if ! k wait --for=condition=complete "job/$job" -n "$DATA_NAMESPACE" --timeout=120s; then
  k logs "job/$job" -n "$DATA_NAMESPACE" --tail=80 >&2 || true; exit 1
fi
k logs "job/$job" -n "$DATA_NAMESPACE" --tail=20
k delete job "$job" -n "$DATA_NAMESPACE" --wait=true >/dev/null
k delete secret investment-redis-credential -n "$DATA_NAMESPACE" >/dev/null
if [[ "$RESTART" == true ]] && k get deployment investment-backend-api -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  k rollout restart deployment/investment-backend-api deployment/investment-backend-worker deployment/investment-backend-scheduler -n "$APP_NAMESPACE" >/dev/null
  k rollout status deployment/investment-backend-api -n "$APP_NAMESPACE" --timeout=300s >/dev/null
fi
printf '{"task":"R5-V2-investment-redis-acl","result":"passed","principal":"investment_backend","keyspace":"investment:*","credential_source":"%s","credentials_printed":false}\n' "$credential_source"
