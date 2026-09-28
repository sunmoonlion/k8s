#!/usr/bin/env bash
# Business Secret deployment; sourced functions only. Cloud: 未经实机验证.
# Call only after the component's deploy-plan boundary.
opaque_secret_entry() (
    set -euo pipefail
    set +x
    local root="$1" config="$2" profile="$3" default_namespace="$4"
    shift 4
    source "$root/utils/cluster-arg-parser.sh"
    unified_parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    local action=deploy positional_namespace=''
    case "$profile" in
        redis-secrets|elasticsearch-secrets)
            [[ $# -le 3 && "${3:-false}" == false ]] || { echo 'Expected action namespace false' >&2; return 2; }
            action="${1:-deploy}"; positional_namespace="${2:-}"
            # Elasticsearch previously accepted delete as an uninstall alias.
            [[ "$profile:$action" != elasticsearch-secrets:delete ]] || action=uninstall
            case "$action" in deploy|status|uninstall) ;; *) echo 'Unsupported Secret action' >&2; return 2 ;; esac ;;
        *)
            [[ $# -le 4 && "${4:-false}" == false ]] || {
                echo 'Business Secret expects project namespace environment false; use the entry for dry-run' >&2; return 2;
            }
            positional_namespace="${2:-}" ;;
    esac
    [[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || {
        echo 'Explicit CLUSTER required' >&2; return 1;
    }
    local selected_cluster="$CLUSTER" namespace="$positional_namespace"
    [[ -f "$config" && ! -L "$config" ]] || { echo 'Secret configuration missing' >&2; return 1; }
    source "$config" >/dev/null 2>&1 || { echo 'Secret configuration failed' >&2; return 1; }
    [[ "$CLUSTER" == "$selected_cluster" ]] || { echo 'Configuration changed selected cluster' >&2; return 1; }
    source "$root/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping >/dev/null 2>&1 || { echo 'Secret cluster mapping failed' >&2; return 1; }
    [[ "$CLUSTER" == "$selected_cluster" ]] || { echo 'Mapping changed selected cluster' >&2; return 1; }
    case "$profile" in
        elasticsearch-secrets)
            SECRET_NAME="${ELASTICSEARCH_SECRET_NAME:?Secret name required}"
            namespace="${namespace:-${ELASTICSEARCH_NAMESPACE:-$default_namespace}}" ;;
        redis-secrets)
            SECRET_NAME="${REDIS_SECRET_NAME:?Secret name required}"
            namespace="${namespace:-${REDIS_NAMESPACE:-$default_namespace}}" ;;
        *) namespace="${namespace:-${NAMESPACE:-${SECRET_NAMESPACE:-$default_namespace}}}" ;;
    esac
    [[ "${SECRET_TYPE:-Opaque}" == Opaque ]] || { echo 'Business Secret type must be Opaque' >&2; return 1; }
    source "$root/utils/deploy-target.sh"
    if [[ "$action" != deploy ]]; then
        sunmoon_deploy_target_init "$root" || return 1
        python3 -B "$root/utils/secret-management/lib/opaque_secret.py" --action "$action" \
            --namespace "$namespace" --name "$SECRET_NAME" --apply
        return $?
    fi

    # key:variable mappings preserve the component's actual historical keys.
    local -a fields=() required=() payload=() restart_args=()
    local restart_mode=always
    case "$profile" in
        elasticsearch-secrets)
            fields=("${ELASTICSEARCH_AUTH_SECRET_PASSWORD_KEY:?Secret password key required}:ELASTICSEARCH_PASSWORD"
                    elasticsearch-username:ELASTICSEARCH_USERNAME kibana-password:KIBANA_SYSTEM_PASSWORD)
            required=(ELASTICSEARCH_PASSWORD ELASTICSEARCH_USERNAME KIBANA_SYSTEM_PASSWORD)
            restart_mode=none ;;
        redis-secrets)
            fields=("${REDIS_PASSWORD_KEY:?Secret password key required}:REDIS_PASSWORD"
                    "${REDIS_MASTER_PASSWORD_KEY:?Secret master key required}:REDIS_MASTER_PASSWORD"
                    "${REDIS_DATABASE_KEY:?Secret database key required}:REDIS_DATABASE")
            REDIS_DATABASE="${REDIS_DATABASE:-redis}"
            required=(REDIS_PASSWORD REDIS_MASTER_PASSWORD)
            restart_mode=none ;;
        postgresql-auth-secret) fields=(admin_password:admin_password dev_password:dev_password) ;;
        postgresql-authservice-db-secret|postgresql-llmopsservice-db-secret)
            fields=(DB_HOST:DB_HOST DB_PORT:DB_PORT DB_NAME:DB_NAME DB_USER:DB_USER DB_PASSWORD:DB_PASSWORD DB_SSLMODE:DB_SSLMODE) ;;
        mongodb-auth-secret)
            fields=(mongodb-root-password:mongodb_root_password mongodb-passwords:mongodb_passwords mongodb-metrics-password:mongodb_metrics_password mongodb-replica-set-key:mongodb_replica_set_key) ;;
        mongodb-llmopsservice-db-secret)
            fields=(DB_HOST:DB_HOST DB_PORT:DB_PORT DB_NAME:DB_NAME DB_USER:DB_USER DB_SSLMODE:DB_SSLMODE) ;;
        redis-auth-secret) fields=(redis-password:redis_password) ;;
        redis-myapp-secret|redis-llmopsservice-secret)
            fields=(REDIS_HOST:REDIS_HOST REDIS_PORT:REDIS_PORT REDIS_PASSWORD:REDIS_PASSWORD REDIS_SSL:REDIS_SSL)
            [[ "$profile" != redis-llmopsservice-secret ]] || fields+=(REDIS_DB:REDIS_DB)
            restart_mode=none ;;
        elasticsearch-myapp-secret|kibana-elasticsearch-secret|logstash-elasticsearch-secret)
            fields=(ES_HOST:ES_HOST ES_PORT:ES_PORT ES_USERNAME:ES_USERNAME ES_PASSWORD:ES_PASSWORD ES_TLS:ES_TLS)
            restart_mode=none ;;
        neo4j-secrets) fields=(password:neo4j_password) ;;
        rabbitmq-auth-secret)
            fields=(rabbitmq-username:rabbitmq_username rabbitmq-password:rabbitmq_password rabbitmq-erlang-cookie:rabbitmq_erlang_cookie)
            restart_mode=existing-changed ;;
        pgadmin-auth-secret)
            fields=("${PGADMIN_AUTH_SECRET_PASSWORD_KEY:-pgadmin-password}:pgadmin_password")
            required=(pgadmin_password) ;;
        flower-secrets)
            fields=("${FLOWER_AUTH_SECRET_PASSWORD_KEY:?Secret password key required}:flower_password"
                    "${FLOWER_ADMIN_USER_KEY:?Secret username key required}:flower_admin_user"
                    broker-url:broker_url broker-api-url:broker_api_url)
            required=(flower_password) ;;
        mongo-express-secrets)
            fields=("${MONGO_EXPRESS_AUTH_SECRET_PASSWORD_KEY:-mongo-express-password}:mongo_express_password"
                    "${MONGO_EXPRESS_ADMIN_USER_KEY:-mongo-express-admin-user}:mongo_express_admin_user"
                    "${MONGO_EXPRESS_MONGODB_AUTH_PASSWORD_KEY:-mongodb-auth-password}:mongodb_auth_password"
                    "${MONGO_EXPRESS_SITE_COOKIE_SECRET_KEY:-site-cookie-secret}:site_cookie_secret"
                    "${MONGO_EXPRESS_SITE_SESSION_SECRET_KEY:-site-session-secret}:site_session_secret"
                    "${MONGO_EXPRESS_BASIC_AUTH_PASSWORD_KEY:-basic-auth-password}:basic_auth_password")
            mongo_express_admin_user="${mongo_express_admin_user:-admin}"
            required=(mongo_express_password mongodb_auth_password site_cookie_secret site_session_secret basic_auth_password) ;;
        *) echo 'Unknown business Secret profile' >&2; return 2 ;;
    esac
    local variable item key value component
    for variable in "${required[@]}"; do
        [[ -n "${!variable:-}" ]] || {
            printf 'Explicit configuration required: %s; no credential generated or rotated\n' "$variable" >&2; return 1;
        }
    done
    for item in "${fields[@]}"; do
        key="${item%%:*}"; variable="${item#*:}"
        [[ "$variable" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && "$key" =~ ^[a-zA-Z0-9._-]+$ && ${#key} -le 253 ]] || {
            echo 'Invalid Secret key mapping' >&2; return 1;
        }
        value="${!variable:-}"
        [[ -z "$value" ]] || payload+=("$key" "$value")
    done
    [[ ${#payload[@]} -gt 0 ]] || { echo 'No business Secret data configured' >&2; return 1; }
    [[ "${RESTART_COMPONENTS:-false}" == true || "${RESTART_COMPONENTS:-false}" == false ]] || {
        echo 'RESTART_COMPONENTS must be true or false' >&2; return 1;
    }
    if [[ "$restart_mode" != none && "${RESTART_COMPONENTS:-false}" == true ]]; then
        local -a components=()
        IFS=',' read -r -a components <<< "${RESTART_COMPONENTS_LIST:-}"
        for component in "${components[@]}"; do
            component="${component#"${component%%[![:space:]]*}"}"
            component="${component%"${component##*[![:space:]]}"}"
            [[ -z "$component" ]] || restart_args+=(--restart "$component")
        done
    fi
    sunmoon_deploy_target_init "$root" || return 1
    # Shell builtin -> pipe. Values never become an external process argument or file.
    builtin printf '%s\0' "${payload[@]}" | python3 -B "$root/utils/secret-management/lib/opaque_secret.py" \
        --namespace "$namespace" --name "${SECRET_NAME:-$profile}" \
        --restart-mode "$restart_mode" "${restart_args[@]}" --apply
)
