#!/usr/bin/env bash

# Fail-fast validation for the per-application browser OIDC Secret. Values are
# decoded only in-process and are never printed.

require_browser_oidc_secret() {
    local namespace="$1"
    local app_name="$2"
    local secret_name="$3"
    local expected_application="$4"
    local key encoded decoded
    local required_keys=(
        CASDOOR_ENDPOINT
        CASDOOR_BACKCHANNEL_ENDPOINT
        CASDOOR_CLIENT_ID
        CASDOOR_CLIENT_SECRET
        CASDOOR_REDIRECT_URI
        CASDOOR_APPLICATION
        FRONTEND_BASE_URL
        FRONTEND_ALLOWED_ORIGINS
        SESSION_COOKIE_SECURE
    )

    if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        log_error "浏览器 OIDC Secret 不存在: $namespace/$secret_name"
        log_error "拒绝部署 $app_name；请先运行 V5-P0-005 browser identity provisioner"
        return 1
    fi

    for key in "${required_keys[@]}"; do
        encoded="$(kubectl get secret "$secret_name" -n "$namespace" \
            -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
        if [[ -z "$encoded" ]]; then
            log_error "浏览器 OIDC Secret 缺少非空键: $namespace/$secret_name key=$key"
            return 1
        fi
    done

    decoded="$(kubectl get secret "$secret_name" -n "$namespace" \
        -o jsonpath='{.data.CASDOOR_APPLICATION}' | base64 --decode)"
    if [[ "$decoded" != "$expected_application" ]]; then
        unset decoded
        log_error "浏览器 OIDC Secret application 与部署不匹配: app=$app_name"
        return 1
    fi
    unset decoded encoded key

    log_success "浏览器 OIDC 配置门禁通过: $namespace/$secret_name"
}
