#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"

kubectl_cmd() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

echo "section=deployments"
kubectl_cmd get deployment -n "$APP_NAMESPACE" -o json | jq -c '
  [
    .items[]
    | select(
        .metadata.name
        | test("^(info-|celeryworker-info-|nodebullworker-info-)")
      )
    | {
        name: .metadata.name,
        replicas: (.spec.replicas // 0),
        ready_replicas: (.status.readyReplicas // 0),
        service_account: (.spec.template.spec.serviceAccountName // "default"),
        containers: [
          .spec.template.spec.containers[]
          | {
              name,
              image,
              command: (.command // []),
              args: (.args // []),
              config_maps: [(.envFrom // [])[]?.configMapRef.name | select(. != null)],
              secrets: [(.envFrom // [])[]?.secretRef.name | select(. != null)],
              secret_key_refs: [
                (.env // [])[]?
                | select(.valueFrom.secretKeyRef != null)
                | {
                    env: .name,
                    secret: .valueFrom.secretKeyRef.name,
                    key: .valueFrom.secretKeyRef.key
                  }
              ]
            }
        ]
      }
  ]
  | sort_by(.name)
'

echo "section=cronjobs"
kubectl_cmd get cronjob -n "$APP_NAMESPACE" -o json | jq -c '
  [
    .items[]
    | select(.metadata.name | test("^info-"))
    | {
        name: .metadata.name,
        suspend: (.spec.suspend // false),
        schedule: .spec.schedule,
        service_account: (.spec.jobTemplate.spec.template.spec.serviceAccountName // "default"),
        images: [.spec.jobTemplate.spec.template.spec.containers[].image]
      }
  ]
  | sort_by(.name)
'

echo "section=services"
kubectl_cmd get service -n "$APP_NAMESPACE" -o json | jq -c '
  [
    .items[]
    | select(.metadata.name | test("^info-"))
    | {
        name: .metadata.name,
        type: .spec.type,
        selector: (.spec.selector // {}),
        ports: [.spec.ports[] | {name, port, targetPort}]
      }
  ]
  | sort_by(.name)
'

echo "section=ingress_routes"
if kubectl_cmd api-resources --api-group=traefik.io -o name | grep -Eq '^ingressroutes(\.|$)'; then
  kubectl_cmd get ingressroute -n "$APP_NAMESPACE" -o json | jq -c '
    [
      .items[]
      | select(.metadata.name | test("^info-"))
      | {
          name: .metadata.name,
          entry_points: (.spec.entryPoints // []),
          routes: [
            (.spec.routes // [])[]
            | {
                match,
                services: [(.services // [])[] | {name, port}]
              }
          ],
          tls_configured: (.spec.tls != null)
        }
    ]
    | sort_by(.name)
  '
else
  echo '[]'
fi

echo "section=persistent_volume_claims"
kubectl_cmd get pvc -n "$APP_NAMESPACE" -o json | jq -c '
  [
    .items[]
    | select(
        .metadata.name
        | test("^(info-|celeryworker-info-|nodebullworker-info-)")
      )
    | {
        name: .metadata.name,
        phase: .status.phase,
        storage_class: .spec.storageClassName,
        requested_storage: .spec.resources.requests.storage
      }
  ]
  | sort_by(.name)
'

echo "section=secret_keys"
for name in $(
  kubectl_cmd get secret -n "$APP_NAMESPACE" -o name \
    | sed 's#secret/##' \
    | grep -E '^(info-|celeryworker-info-|nodebullworker-info-)' \
    | sort
); do
  keys="$(
    kubectl_cmd get secret "$name" -n "$APP_NAMESPACE" -o json \
      | jq -c '(.data // {}) | keys | sort'
  )"
  jq -cn --arg name "$name" --argjson keys "$keys" '{name: $name, keys: $keys}'
done

echo "section=database_connections"
kubectl_cmd exec \
  --quiet \
  -n "$POSTGRES_NAMESPACE" \
  "$POSTGRES_POD" \
  -- sh -lc '
    psql_bin=/opt/bitnami/postgresql/bin/psql
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec "$psql_bin" \
      -U postgres \
      -d postgres \
      -X \
      -v ON_ERROR_STOP=1 \
      -At \
      -c "
        SELECT COALESCE(
          jsonb_agg(
            jsonb_build_object(
              '\''database'\'', datname,
              '\''role'\'', usename,
              '\''application_name'\'', application_name,
              '\''state'\'', state,
              '\''connection_count'\'', connection_count
            )
            ORDER BY datname, usename, application_name, state
          ),
          '\''[]'\''::jsonb
        )
        FROM (
          SELECT
            datname,
            usename,
            application_name,
            state,
            count(*) AS connection_count
          FROM pg_stat_activity
          WHERE datname IN ('\''info_admin'\'', '\''info_web'\'')
          GROUP BY datname, usename, application_name, state
        ) AS connections;
      "
  '
