#!/bin/bash

# Casdoor 首次部署后初始化脚本
#
# 功能：
#   1. 验证 Helm 声明式挂载的 /conf/app.conf 和本地化静态资源
#   2. 幂等创建 Casdoor Organizations
#   3. 幂等创建 Casdoor Applications（本地配置可声明 authorization_code/client_credentials）
#   4. 按 ORG_* 在各业务组织下幂等创建用户 admin（密码同 ADMIN_PASSWORD）
#
# 用法：
#   bash post-deploy-setup.sh [namespace] [--cluster C1|C2]
#
# 依赖：kubectl；若本机没有 psql，K8s 场景会自动使用临时 PostgreSQL client Pod

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POST_DEPLOY_SCRIPT_DIR="$SCRIPT_DIR"
SETUP_CONF="$SCRIPT_DIR/post-deploy-setup.conf"
LOCAL_SETUP_CONF="$SCRIPT_DIR/post-deploy-setup.local.conf"

find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-config-mapping.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}
K8S_ROOT_DIR="$(find_k8s_root_dir "$SCRIPT_DIR" || true)"
if [[ -n "${K8S_ROOT_DIR:-}" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    export DISABLE_AUTO_CLEANUP="${DISABLE_AUTO_CLEANUP:-true}"
    source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"
    SCRIPT_DIR="$POST_DEPLOY_SCRIPT_DIR"
fi

# ─────────────────────────── 日志 ───────────────────────────
log_info()    { echo "[INFO]  $*"; }
log_ok()      { echo "[OK]    $*"; }
log_warn()    { echo "[WARN]  $*"; }
log_error()   { echo "[ERROR] $*" >&2; }

wait_for_deployment_ready() {
    local deployment="$1" namespace="$2" timeout="${3:-300}"
    # availableReplicas may still belong to the old ReplicaSet. Require the
    # Kubernetes rollout controller to report the new template complete.
    if ! kubectl rollout status "deployment/$deployment" -n "$namespace" \
        --timeout="${timeout}s"; then
        kubectl describe deployment "$deployment" -n "$namespace" || true
        kubectl get pods -n "$namespace" -l "app.kubernetes.io/instance=${deployment}" -o wide || true
        return 1
    fi
    log_ok "Deployment 新 ReplicaSet 已完成 rollout: $namespace/$deployment"
    return 0
}

# ─────────────────────────── 参数解析 ───────────────────────────
NAMESPACE="app-platform-dev"
for arg in "$@"; do
    case "$arg" in
        --cluster) shift ;;  # 兼容统一模板，忽略集群参数（由调用方的 kubeconfig 处理）
        app-platform-*) NAMESPACE="$arg" ;;
        *) [ -n "$arg" ] && NAMESPACE="$arg" ;;
    esac
done

RELEASE="casdoor-sunmoonai"
PG_CLIENT_POD_NAME=""

cleanup_k8s_sql_client() {
    if [[ -n "$PG_CLIENT_POD_NAME" ]]; then
        kubectl delete pod "$PG_CLIENT_POD_NAME" -n "$(k8s_client_namespace)" \
            --ignore-not-found --wait=false >/dev/null 2>&1 || true
        PG_CLIENT_POD_NAME=""
    fi
}
trap cleanup_k8s_sql_client EXIT
CLUSTER_LOWER="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"
if [[ "$CLUSTER_LOWER" == "kind" || "$CLUSTER_LOWER" =~ ^c[0-9]+$ ]]; then
    DB_ACCESS_CONFIG="$SCRIPT_DIR/../db-access-bootstrap/config/postgresql.k8s.env"
else
    DB_ACCESS_CONFIG="$SCRIPT_DIR/../db-access-bootstrap/config/postgresql.external.env"
fi

# ─────────────────────────── 加载配置 ───────────────────────────

# 1. 从 db-access-bootstrap 读取 DB 连接基础值
if [[ -f "$DB_ACCESS_CONFIG" ]]; then
    source "$DB_ACCESS_CONFIG"
    DB_HOST="${DB_HOST:-$DB_HOST}"
    DB_PORT="${DB_PORT:-$DB_PORT}"
    DB_USER="${APP_DB_USER:-casdoor}"
    DB_PASSWORD="${APP_DB_PASSWORD:-}"
    DB_NAME="${APP_DB_NAME:-casdoor}"
else
    log_warn "db-access-bootstrap 配置不存在: $DB_ACCESS_CONFIG，使用内置默认值"
    DB_HOST="www.sunmoonai.com"
    DB_PORT="30444"
    DB_USER="casdoor"
    DB_PASSWORD=""
    DB_NAME="casdoor"
fi

# 2. 加载 post-deploy-setup.conf（可覆盖 DB 连接，定义 Org/App）
if [[ -f "$SETUP_CONF" ]]; then
    source "$SETUP_CONF"
    log_info "已加载配置: $SETUP_CONF"
else
    log_warn "未找到 $SETUP_CONF，跳过 Organizations/Applications 初始化"
fi
if [[ "${CASDOOR_ENABLE_LEGACY_IDENTITY_SETUP:-false}" == "true" && -f "$LOCAL_SETUP_CONF" ]]; then
    # 兼容旧的 operator-only 配置，但默认关闭；P0-005 provision Job 是
    # 业务 identity 的唯一正常入口，避免与本脚本形成第二套漂移真相源。
    source "$LOCAL_SETUP_CONF"
    log_warn "已显式启用 legacy Casdoor identity setup；迁移完成后应关闭 CASDOOR_ENABLE_LEGACY_IDENTITY_SETUP"
elif [[ -f "$LOCAL_SETUP_CONF" ]]; then
    log_info "检测到 operator-only identity 配置，但默认跳过（由 P0-005 provision Job 负责）"
else
    log_info "未找到本地敏感配置，跳过额外 Organizations/Applications"
fi

# ─────────────────────────── 第一步：app.conf ───────────────────────────

setup_app_conf() {
    local pod
    pod=$(kubectl get pods -n "$NAMESPACE" \
        -l "app.kubernetes.io/instance=$RELEASE" \
        -o jsonpath='{range .items[?(@.status.containerStatuses[0].ready==true)]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -n 1)

    if [[ -z "$pod" ]]; then
        log_error "未找到 Casdoor pod (release=$RELEASE, namespace=$NAMESPACE)"
        return 1
    fi
    log_info "目标 Pod: $pod"

    local expected_runmode="${CASDOOR_RUNMODE:-prod}"
    if ! kubectl exec -n "$NAMESPACE" "$pod" -- \
        sh -ec "test -f /conf/app.conf && grep -Eq '^[[:space:]]*copyrequestbody[[:space:]]*=[[:space:]]*true' /conf/app.conf && grep -Eq '^[[:space:]]*runmode[[:space:]]*=[[:space:]]*${expected_runmode}[[:space:]]*' /conf/app.conf && grep -Eq '^[[:space:]]*staticBaseUrl[[:space:]]*=[[:space:]]*\"\.\"[[:space:]]*' /conf/app.conf" 2>/dev/null; then
        log_error "/conf/app.conf 不符合 Helm 声明式配置（runmode=$expected_runmode/copyrequestbody=true/staticBaseUrl=local）；拒绝执行临时 kubectl exec 写入"
        return 1
    fi
    if kubectl exec -n "$NAMESPACE" "$pod" -- \
        sh -ec '
          set -eu
          test -f /web/build/index.html
          ! grep -qE "fonts\\.googleapis\\.com|cdn\\.casbin\\.org|cdn\\.casdoor\\.com" /web/build/index.html
          ! grep -Rql --include="*.css" "fonts\\.googleapis\\.com" /web/build/static/css 2>/dev/null
          test -z "$(find /web/build/static/js -type f -name '*.js' -exec grep -l "cdn\\.casdoor\\.com" {} + 2>/dev/null)"
          if command -v curl >/dev/null 2>&1; then
            ! curl -fsS -D - -o /dev/null http://127.0.0.1:8000/ | grep -qiE "fonts\\.googleapis\\.com|cdn\\.casbin\\.org|cdn\\.casdoor\\.com"
          fi
        '; then
        log_ok "Casdoor 配置与静态资源就绪（无外部字体/CDN 依赖）"
    else
        log_error "Casdoor 静态资源仍含外部网络依赖或资源不完整"
        return 1
    fi
}

# ─────────────────────────── psql 工具函数 ───────────────────────────

run_sql() {
    local sql="$1"

    if ! use_k8s_sql_client && command -v psql &>/dev/null; then
        PGPASSWORD="$DB_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" \
            -U "$DB_USER" -d "$DB_NAME" \
            -q -c "$sql"
    else
        run_sql_with_k8s_client "$sql"
    fi
}

# SQL 字符串中单引号转义为 ''
sql_escape_single() {
    printf '%s' "${1//\'/\'\'}"
}

check_psql() {
    if ! use_k8s_sql_client && command -v psql &>/dev/null; then
        if ! PGPASSWORD="$DB_PASSWORD" psql \
            -h "$DB_HOST" -p "$DB_PORT" \
            -U "$DB_USER" -d "$DB_NAME" \
            -q -c "SELECT 1" &>/dev/null; then
            log_error "无法连接 PostgreSQL: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
            return 1
        fi
    else
        if ! run_sql_with_k8s_client "SELECT 1" &>/dev/null; then
            log_error "无法通过临时 client Pod 连接 PostgreSQL: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
            return 1
        fi
    fi
    log_info "PostgreSQL 连接正常"
}

use_k8s_sql_client() {
    [[ "${FORCE_K8S_SQL_CLIENT:-false}" == "true" ]] && return 0
    [[ "$DB_HOST" =~ \.svc(\.|$) ]]
}

k8s_client_namespace() {
    if [[ -n "${PG_CLIENT_NAMESPACE:-}" ]]; then
        printf '%s\n' "$PG_CLIENT_NAMESPACE"
    elif [[ "$DB_HOST" =~ \.([a-z0-9-]+)\.svc(\.|$) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        printf '%s\n' "$NAMESPACE"
    fi
}

k8s_client_image() {
    local registry="harbor.sunmoonai.com"
    if declare -F get_cluster_harbor_registry >/dev/null; then
        registry="$(get_cluster_harbor_registry)"
    fi
    if [[ "$CLUSTER_LOWER" =~ ^c[0-9]+$ && "$registry" == "harbor.sunmoonai.com" ]]; then
        registry="harbor.sunmoonai.com:30443"
    fi
    printf '%s\n' "${PG_CLIENT_IMAGE:-${registry}/k8s-images/postgresql:17.6.0-debian-12-r4}"
}

run_sql_with_k8s_client() {
    local sql="$1"
    local client_ns client_image timeout pull_policy
    client_ns="$(k8s_client_namespace)"
    client_image="$(k8s_client_image)"
    timeout="${PG_CLIENT_POD_RUNNING_TIMEOUT:-5m0s}"
    pull_policy="${PG_CLIENT_IMAGE_PULL_POLICY:-IfNotPresent}"

    command -v kubectl >/dev/null 2>&1 || {
        log_error "kubectl 不可用，且本机未安装 psql"
        return 1
    }

    if [[ -z "$PG_CLIENT_POD_NAME" ]]; then
        PG_CLIENT_POD_NAME="casdoor-postdeploy-pg-$(date +%s%N | tail -c 8)"
        kubectl run "$PG_CLIENT_POD_NAME" --restart=Never -n "$client_ns" \
            --image="$client_image" \
            --image-pull-policy="$pull_policy" \
            --pod-running-timeout="$timeout" \
            --env="PGPASSWORD=$DB_PASSWORD" \
            --labels="app.kubernetes.io/component=casdoor-postdeploy-sql" \
            --command -- sleep 900 >/dev/null
        kubectl wait --for=condition=Ready "pod/$PG_CLIENT_POD_NAME" \
            -n "$client_ns" --timeout="$timeout" >/dev/null
    fi

    kubectl exec -n "$client_ns" "$PG_CLIENT_POD_NAME" -- \
        psql -h "$DB_HOST" -p "$DB_PORT" \
            -U "$DB_USER" -d "$DB_NAME" \
            -q -c "$sql"
}

# ─────────────────────────── 第二步：Organizations ───────────────────────────

create_org() {
    local entry="$1"
    local name display_name default_app
    IFS='|' read -r name display_name default_app <<< "$entry"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local sql
    # languages：Casdoor 登录页 Languages 区块会执行 languages.length；列为 NULL 时整页白板
    #（TypeError: Cannot read properties of null (reading 'length')）
    sql="INSERT INTO organization (
        owner, name, created_time,
        display_name, default_application,
        password_type, country_codes, init_score, is_profile_public,
        languages
    ) VALUES (
        'admin', '$name', '$now',
        '$display_name', '$default_app',
        'plain', '[\"CN\"]', 2000, false,
        '[\"en\",\"zh\"]'
    ) ON CONFLICT (owner, name) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        default_application = EXCLUDED.default_application,
        password_type = EXCLUDED.password_type,
        country_codes = EXCLUDED.country_codes,
        init_score = EXCLUDED.init_score,
        is_profile_public = EXCLUDED.is_profile_public,
        languages = EXCLUDED.languages;"

    if run_sql "$sql"; then
        log_ok "Organization 就绪: $name"
    else
        log_error "Organization 创建失败: $name"
        return 1
    fi
}

setup_organizations() {
    log_info "初始化 Organizations ..."
    local i=1
    while true; do
        local var="ORG_${i}"
        local val="${!var:-}"
        [[ -z "$val" ]] && break
        create_org "$val"
        i=$((i + 1))
    done
}

# 已用旧脚本写入的组织可能没有 languages，补上以免 OAuth 登录页崩溃
patch_organization_languages() {
    log_info "校验所有 Organization.languages，并建立数据库不变量（修复登录页白板根因）..."
    run_sql "UPDATE organization SET languages = '[\"en\",\"zh\"]' WHERE languages IS NULL OR btrim(languages) = '' OR lower(btrim(languages)) = 'null';" \
        || return 1
    run_sql "ALTER TABLE organization DROP CONSTRAINT IF EXISTS sunmoonai_org_languages_json_array;" \
        || return 1
    run_sql "ALTER TABLE organization ADD CONSTRAINT sunmoonai_org_languages_json_array CHECK (languages IS NOT NULL AND btrim(languages) <> '' AND jsonb_typeof(languages::jsonb) = 'array');" \
        && log_ok "Organization.languages 不变量已建立（所有组织均为非空 JSON array）"
}

# ─────────────────────────── 第三步：Applications ───────────────────────────

create_app() {
    local entry="$1"
    local name display_name client_id client_secret org redirect_uris enable_signup grant_types
    IFS='|' read -r name display_name client_id client_secret org redirect_uris enable_signup grant_types <<< "$entry"

    grant_types="${grant_types:-[\"authorization_code\"]}"
    if [[ -z "$name" || -z "$client_id" || -z "$client_secret" || -z "$org" ]]; then
        log_error "Application 配置缺少 name/client_id/client_secret/organization"
        return 1
    fi
    if [[ "$enable_signup" != "true" && "$enable_signup" != "false" ]]; then
        log_error "Application 配置 enable_sign_up 必须为 true/false: $name"
        return 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 所有来自本地配置的 SQL 字段均做单引号转义；grant_types/redirect_uris 仍由配置文件提供 JSON。
    local safe_name safe_display_name safe_client_id safe_client_secret safe_org safe_uris safe_grant_types
    safe_name="$(sql_escape_single "$name")"
    safe_display_name="$(sql_escape_single "$display_name")"
    safe_client_id="$(sql_escape_single "$client_id")"
    safe_client_secret="$(sql_escape_single "$client_secret")"
    safe_org="$(sql_escape_single "$org")"
    safe_uris="${redirect_uris//\'/\'\'}"
    safe_grant_types="${grant_types//\'/\'\'}"

    local sql
    sql="INSERT INTO application (
        owner, name, created_time,
        display_name, client_id, client_secret,
        redirect_uris, cert, grant_types,
        organization, enable_sign_up,
        token_format, expire_in_hours, refresh_expire_in_hours
    ) VALUES (
        'admin', '$safe_name', '$now',
        '$safe_display_name', '$safe_client_id', '$safe_client_secret',
        '$safe_uris', 'cert-built-in', '$safe_grant_types',
        '$safe_org', $enable_signup,
        'JWT', 168, 336
    ) ON CONFLICT (owner, name) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        client_id = EXCLUDED.client_id,
        client_secret = EXCLUDED.client_secret,
        redirect_uris = EXCLUDED.redirect_uris,
        cert = EXCLUDED.cert,
        grant_types = EXCLUDED.grant_types,
        organization = EXCLUDED.organization,
        enable_sign_up = EXCLUDED.enable_sign_up,
        token_format = EXCLUDED.token_format,
        expire_in_hours = EXCLUDED.expire_in_hours,
        refresh_expire_in_hours = EXCLUDED.refresh_expire_in_hours;"

    if run_sql "$sql"; then
        log_ok "Application 就绪: $name (grant_types=$grant_types)"
    else
        log_error "Application 创建失败: $name"
        return 1
    fi
}

setup_applications() {
    log_info "初始化 Applications ..."
    local i=1
    while true; do
        local var="APP_${i}"
        local val="${!var:-}"
        [[ -z "$val" ]] && break
        create_app "$val"
        i=$((i + 1))
    done
}

# ─────────────────────────── 第四步：各组织 admin 用户 ───────────────────────────

# 业务组织 OAuth 登录需要「该组织」下的用户；built-in/admin 无法替代。
# 对每个 ORG_<n>（name|display_name|default_application）：创建或更新 owner=<name>/admin。
ensure_org_admin_users() {
    local pwd="${ADMIN_PASSWORD:-}"
    if [[ -z "$pwd" ]]; then
        log_info "ADMIN_PASSWORD 未设置，跳过各组织 admin 用户"
        return 0
    fi

    local safe_pwd now
    safe_pwd="$(sql_escape_single "$pwd")"
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "幂等创建各业务组织下的 admin 用户（与 ADMIN_PASSWORD 一致）..."
    local i=1
    while true; do
        local var="ORG_${i}"
        local val="${!var:-}"
        [[ -z "$val" ]] && break

        local org_name display_name default_app
        IFS='|' read -r org_name display_name default_app <<< "$val"

        if [[ "$org_name" == "built-in" ]]; then
            log_info "跳过 built-in（使用全局 admin 流程）"
            i=$((i + 1))
            continue
        fi

        local org_safe app_safe email_safe sql
        org_safe="$(sql_escape_single "$org_name")"
        app_safe="$(sql_escape_single "$default_app")"
        email_safe="$(sql_escape_single "admin@${org_name}.local")"

        sql="INSERT INTO \"user\" (
            owner, name, created_time, updated_time,
            id, type, password, password_salt,
            display_name, avatar, email, phone,
            score, karma, ranking,
            is_default_avatar, is_online,
            is_admin, is_forbidden, is_deleted,
            signup_application, properties,
            address,
            created_ip,
            signin_wrong_times
        ) VALUES (
            '${org_safe}', 'admin', '${now}', '${now}',
            gen_random_uuid()::text, 'normal-user', '${safe_pwd}', '',
            'Admin', 'https://cdn.casbin.org/img/casbin.svg', '${email_safe}', '',
            2000, 0, 1,
            false, false,
            true, false, false,
            '${app_safe}', '{}',
            '[]',
            '127.0.0.1',
            0
        ) ON CONFLICT (owner, name) DO UPDATE SET
            password = EXCLUDED.password,
            updated_time = EXCLUDED.updated_time,
            signup_application = EXCLUDED.signup_application,
            is_admin = EXCLUDED.is_admin;"

        if run_sql "$sql"; then
            log_ok "组织用户就绪: ${org_name}/admin → signup_application=${default_app}"
        else
            log_error "组织用户创建失败: ${org_name}/admin"
            return 1
        fi

        i=$((i + 1))
    done
}

# ─────────────────────────── 第五步：全局 Admin 密码 ───────────────────────────

setup_admin_password() {
    local pwd="${ADMIN_PASSWORD:-}"
    if [[ -z "$pwd" ]]; then
        log_info "ADMIN_PASSWORD 未设置，跳过 admin 密码更新"
        return 0
    fi

    local safe_pwd
    safe_pwd="$(sql_escape_single "$pwd")"
    local sql="UPDATE \"user\" SET password='${safe_pwd}', updated_time='$(date -u +"%Y-%m-%dT%H:%M:%SZ")' WHERE owner='built-in' AND name='admin';"
    if run_sql "$sql"; then
        log_ok "admin 密码已更新"
    else
        log_error "admin 密码更新失败"
        return 1
    fi
}

# ─────────────────────────── 主流程 ───────────────────────────

main() {
    echo ""
    echo "════════════════════════════════════════"
    echo " Casdoor Post-Deploy Setup"
    echo " Namespace: $NAMESPACE"
    echo "════════════════════════════════════════"
    echo ""

    # Step 1: app.conf
    setup_app_conf || exit 1

    # Step 2～5：Organizations / Applications / 组织 admin / 全局 admin（需要 psql）
    check_psql || {
        log_error "PostgreSQL 不可用；拒绝以未完成身份/数据不变量的状态报告部署成功"
        exit 1
    }
    setup_organizations
    patch_organization_languages
    setup_applications
    ensure_org_admin_users
    setup_admin_password

    echo ""
    echo "═══════════ Casdoor 访问信息 ═══════════"
    echo "地址：https://casdoor.sunmoonai.com:30443"
    echo "控制台：built-in 组织 admin（密码由受控配置注入，不在日志显示）"
    echo "业务应用登录：凭据由 Casdoor/受控配置管理，不在日志显示"
    echo "════════════════════════════════════════"
    echo ""
}

main "$@"
