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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACL_VALUES="$SCRIPT_DIR/../../data-platform/redis/resources/custom-values/dev-values-kind.yaml"

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
[[ "$APP_NAMESPACE" == app-platform-dev && "$DATA_NAMESPACE" == data-platform-dev ]] || {
  echo "Investment Redis reconciliation is KIND development only" >&2; exit 2;
}
k get nodes -o json | jq -e '.items | length > 0 and all(.[]; .spec.providerID | startswith("kind://"))' >/dev/null

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

# Keep the stable mirror for Helm startup configuration, not only the live ACL.
# The same credential-free values declaration drives Helm and this reconcile.
k get configmap redis-sunmoonai-configuration -n "$DATA_NAMESPACE" -o json >"$tmpdir/config.json"
python3 - "$tmpdir" "$ACL_VALUES" "$DATA_NAMESPACE" "$USER_NAME" <<'PY'
import base64,hashlib,json,pathlib,sys,yaml
root=pathlib.Path(sys.argv[1])
users=yaml.safe_load(pathlib.Path(sys.argv[2]).read_text())["auth"]["acl"]["users"]
matches=[u for u in users if u["username"]==sys.argv[4]]
if len(matches)!=1: raise SystemExit("expected one governed Investment ACL declaration")
user=matches[0]
if user["existingSecret"]!="investment-redis-credential" or user["keys"]!="~investment:*" or user["channels"]!="resetchannels &investment:*":
    raise SystemExit("Investment ACL identity or isolation drift")
target=json.loads((root/"target.json").read_text())
password=base64.b64decode(target["data"]["REDIS_PASSWORD"])
if not password: raise SystemExit("empty Investment credential")
rule=" ".join(["user",user["username"],user["enabled"],"#"+hashlib.sha256(password).hexdigest(),user["keys"],user["commands"],user["channels"]])
mirror={"apiVersion":"v1","kind":"Secret","metadata":{"name":user["existingSecret"],"namespace":sys.argv[3],"labels":{"sunmoonai.com/app":"investment","sunmoonai.com/managed-by":"app-platform-v2"}},"type":"Opaque","data":{"REDIS_PASSWORD":target["data"]["REDIS_PASSWORD"],"ACL_RULE":base64.b64encode(rule.encode()).decode()}}
(root/"data.json").write_text(json.dumps(mirror))
config=json.loads((root/"config.json").read_text())
lines=config["data"]["users.acl"].splitlines()
lines=[line for line in lines if line.split()[:2]!=["user",user["username"]]]
config["data"]["users.acl"]="\n".join(lines+[rule])+"\n"
(root/"config-updated.json").write_text(json.dumps(config))
PY
chmod 600 "$tmpdir/data.json" "$tmpdir/config.json" "$tmpdir/config-updated.json"
k apply -f "$tmpdir/data.json" >/dev/null
# resourceVersion makes concurrent ConfigMap updates fail rather than overwrite.
k replace -f "$tmpdir/config-updated.json" >/dev/null

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
        - name: APP_ACL_RULE
          valueFrom: {secretKeyRef: {name: investment-redis-credential, key: ACL_RULE}}
        volumeMounts:
        - {name: startup-acl, mountPath: /startup-acl, readOnly: true}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          export REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD"
          read -r -a acl_rule <<<"\$APP_ACL_RULE"
          redis-cli -e -h '${REDIS_HOST}' --user default ACL SETUSER "\$APP_REDIS_USER" reset "\${acl_rule[@]:2}" >/dev/null
          redis-cli -e -h '${REDIS_HOST}' --user default ACL SAVE >/dev/null
          export REDISCLI_AUTH="\$APP_REDIS_PASSWORD"
          test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" PING)" = PONG
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" SET 'investment:app-platform-v2:acl-test' ok EX 30 >/dev/null
          test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" GET 'investment:app-platform-v2:acl-test')" = ok
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" DEL 'investment:app-platform-v2:acl-test' >/dev/null
          if redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" SET 'research:app-platform-v2:forbidden' denied EX 30 >/dev/null 2>&1; then exit 1; fi
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" PUBLISH 'investment:app-platform-v2:acl-test' ok >/dev/null
          if redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" PUBLISH 'knowledge:forbidden' denied >/dev/null 2>&1; then exit 1; fi
          redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" SUBSCRIBE 'investment:app-platform-v2:acl-test' > /tmp/subscribe-result &
          subscriber=\$!
          for attempt in {1..20}; do
            grep -qx subscribe /tmp/subscribe-result 2>/dev/null && break
            sleep 0.1
          done
          kill "\$subscriber" 2>/dev/null || true
          grep -qx subscribe /tmp/subscribe-result
          # A fresh isolated Redis process must load the same persisted startup
          # ACL, without restarting the shared Redis used by the other Apps.
          redis-server --port 0 --unixsocket /tmp/acl-restart.sock --aclfile /startup-acl/users.acl --save '' --appendonly no --daemonize yes --logfile /tmp/acl-restart.log
          for attempt in {1..30}; do
            test -S /tmp/acl-restart.sock && break
            sleep 0.1
          done
          if ! test -S /tmp/acl-restart.sock; then
            sed -E 's/#[0-9a-f]{64}/[redacted]/g' /tmp/acl-restart.log >&2
            exit 1
          fi
          test "\$(redis-cli -e -s /tmp/acl-restart.sock --user "\$APP_REDIS_USER" PING)" = PONG
          redis-cli -e -s /tmp/acl-restart.sock --user "\$APP_REDIS_USER" PUBLISH 'investment:app-platform-v2:acl-test' ok >/dev/null
          if redis-cli -e -s /tmp/acl-restart.sock --user "\$APP_REDIS_USER" GET 'info:forbidden' >/dev/null 2>&1; then exit 1; fi
          printf 'investment_redis_acl=passed positive=passed negative=passed pubsub=passed startup_reload=passed credentials_printed=false\n'
      volumes:
      - name: startup-acl
        configMap:
          name: redis-sunmoonai-configuration
          items: [{key: users.acl, path: users.acl}]
EOF

if ! k wait --for=condition=complete "job/$job" -n "$DATA_NAMESPACE" --timeout=120s; then
  k logs "job/$job" -n "$DATA_NAMESPACE" --tail=80 >&2 || true; exit 1
fi
k logs "job/$job" -n "$DATA_NAMESPACE" --tail=20
k delete job "$job" -n "$DATA_NAMESPACE" --wait=true >/dev/null
# investment-redis-credential remains the startup ACL credential reference.
if [[ "$RESTART" == true ]] && k get deployment investment-backend-api -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  k rollout restart deployment/investment-backend-api deployment/investment-backend-worker deployment/investment-backend-scheduler -n "$APP_NAMESPACE" >/dev/null
  k rollout status deployment/investment-backend-api -n "$APP_NAMESPACE" --timeout=300s >/dev/null
fi
printf '{"task":"R5-V2-investment-redis-acl","result":"passed","principal":"investment_backend","keyspace":"investment:*","credential_source":"%s","credentials_printed":false}\n' "$credential_source"
