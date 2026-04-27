#!/bin/bash

# Casdoor 首次部署后初始化脚本
#
# 功能：
#   1. 写入 /conf/app.conf（beego 配置，含 copyrequestbody=true）
#   2. 幂等创建 Casdoor Organizations
#   3. 幂等创建 Casdoor Applications
#
# 用法：
#   bash post-deploy-setup.sh [namespace] [--cluster C1|C2]
#
# 依赖：kubectl、psql（postgresql-client）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_ACCESS_CONFIG="$SCRIPT_DIR/../db-access-bootstrap/config/postgresql.external.env"
SETUP_CONF="$SCRIPT_DIR/post-deploy-setup.conf"

# ─────────────────────────── 日志 ───────────────────────────
log_info()    { echo "[INFO]  $*"; }
log_ok()      { echo "[OK]    $*"; }
log_warn()    { echo "[WARN]  $*"; }
log_error()   { echo "[ERROR] $*" >&2; }

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

# ─────────────────────────── 第一步：app.conf ───────────────────────────

setup_app_conf() {
    local pod
    pod=$(kubectl get pods -n "$NAMESPACE" \
        -l "app.kubernetes.io/instance=$RELEASE" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$pod" ]]; then
        log_error "未找到 Casdoor pod (release=$RELEASE, namespace=$NAMESPACE)"
        return 1
    fi
    log_info "目标 Pod: $pod"

    if kubectl exec -n "$NAMESPACE" "$pod" -- \
        sh -c 'test -f /conf/app.conf && grep -q copyrequestbody /conf/app.conf' 2>/dev/null; then
        log_info "/conf/app.conf 已存在，跳过写入"
    else
        log_info "写入 /conf/app.conf ..."
        kubectl exec -n "$NAMESPACE" "$pod" -- sh -c 'cat > /conf/app.conf << '"'"'EOF'"'"'
appname = casdoor
httpport = 8000
runmode = dev
SessionOn = true
copyrequestbody = true
logPostOnly = true
EOF'
        log_info "重启 Casdoor deployment ..."
        kubectl rollout restart deployment/"$RELEASE" -n "$NAMESPACE"
        kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=120s
        log_ok "app.conf 写入并重启完成"
    fi
}

# ─────────────────────────── psql 工具函数 ───────────────────────────

run_sql() {
    local sql="$1"
    PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" -p "$DB_PORT" \
        -U "$DB_USER" -d "$DB_NAME" \
        -q -c "$sql"
}

check_psql() {
    if ! command -v psql &>/dev/null; then
        log_error "psql 未安装，无法初始化 Organizations/Applications"
        log_error "请安装：apt install postgresql-client"
        return 1
    fi
    # 测试连接
    if ! PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" -p "$DB_PORT" \
        -U "$DB_USER" -d "$DB_NAME" \
        -q -c "SELECT 1" &>/dev/null; then
        log_error "无法连接 PostgreSQL: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
        return 1
    fi
    log_info "PostgreSQL 连接正常"
}

# ─────────────────────────── 第二步：Organizations ───────────────────────────

create_org() {
    local entry="$1"
    local name display_name default_app
    IFS='|' read -r name display_name default_app <<< "$entry"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local sql
    sql="INSERT INTO organization (
        owner, name, created_time, updated_time,
        display_name, default_application,
        password_type, phone_prefix, country_codes, init_score, is_profile_public
    ) VALUES (
        'admin', '$name', '$now', '$now',
        '$display_name', '$default_app',
        'plain', '86', '{\"CN\"}', 2000, false
    ) ON CONFLICT (owner, name) DO NOTHING;"

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
        ((i++))
    done
}

# ─────────────────────────── 第三步：Applications ───────────────────────────

create_app() {
    local entry="$1"
    local name display_name client_id client_secret org redirect_uris enable_signup
    IFS='|' read -r name display_name client_id client_secret org redirect_uris enable_signup <<< "$entry"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # redirect_uris 中的单引号转义
    local safe_uris
    safe_uris="${redirect_uris//\'/\'\'}"

    local sql
    sql="INSERT INTO application (
        owner, name, created_time, updated_time,
        display_name, client_id, client_secret,
        redirect_uris, cert, grant_types,
        organization, enable_sign_up,
        token_format, expire_in_hours, refresh_expire_in_hours
    ) VALUES (
        'admin', '$name', '$now', '$now',
        '$display_name', '$client_id', '$client_secret',
        '$safe_uris', 'cert-built-in', 'code',
        '$org', $enable_signup,
        'JWT', 168, 336
    ) ON CONFLICT (owner, name) DO NOTHING;"

    if run_sql "$sql"; then
        log_ok "Application 就绪: $name (client_id=$client_id)"
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
        ((i++))
    done
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

    # Step 2 & 3: Organizations + Applications（需要 psql）
    if check_psql; then
        setup_organizations
        setup_applications
    else
        log_warn "跳过 Organizations/Applications 初始化（psql 不可用或连接失败）"
    fi

    echo ""
    echo "═══════════ Casdoor 访问信息 ═══════════"
    echo "地址：https://casdoor.sunmoonai.com:30443"
    echo "账号：admin / 123（建议立即修改密码）"
    echo "════════════════════════════════════════"
    echo ""
}

main "$@"
