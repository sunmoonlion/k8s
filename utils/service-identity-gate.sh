#!/usr/bin/env bash

# Fail-fast validation for one service-to-service identity relationship.
# Secret values are decoded only for comparisons and are never printed.

require_service_identity_relation() {
    local namespace="$1"
    local caller="$2"
    local client_secret_name="$3"
    local binding_secret_name="$4"
    local expected_application="$5"
    local expected_scope="$6"
    local key encoded client_id audience application scope discovery backchannel subjects
    local caller_discovery caller_backchannel
    local client_keys=(
        KNOWLEDGE_APP_SERVICE_CLIENT_ID
        KNOWLEDGE_APP_SERVICE_CLIENT_SECRET
        KNOWLEDGE_APP_SERVICE_DISCOVERY_URL
        KNOWLEDGE_APP_SERVICE_BACKCHANNEL_ENDPOINT
    )
    local binding_keys=(
        INTERNAL_AUTH_CASDOOR_APPLICATION
        INTERNAL_AUTH_DISCOVERY_URL
        INTERNAL_AUTH_BACKCHANNEL_ENDPOINT
        INTERNAL_AUTH_AUDIENCE
        INTERNAL_AUTH_SUBJECT_ALLOWLIST
        INTERNAL_AUTH_REQUIRED_SCOPE
    )

    for secret_name in "$client_secret_name" "$binding_secret_name"; do
        if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
            log_error "服务身份 Secret 不存在: $namespace/$secret_name"
            log_error "拒绝部署 $caller；请先运行 V5-P0-005 service identity provisioner"
            return 1
        fi
    done

    for key in "${client_keys[@]}"; do
        encoded="$(kubectl get secret "$client_secret_name" -n "$namespace" \
            -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
        if [[ -z "$encoded" ]]; then
            log_error "服务调用 Secret 缺少非空键: $namespace/$client_secret_name key=$key"
            return 1
        fi
    done
    for key in "${binding_keys[@]}"; do
        encoded="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
            -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
        if [[ -z "$encoded" ]]; then
            log_error "服务资源绑定 Secret 缺少非空键: $namespace/$binding_secret_name key=$key"
            return 1
        fi
    done

    client_id="$(kubectl get secret "$client_secret_name" -n "$namespace" \
        -o jsonpath='{.data.KNOWLEDGE_APP_SERVICE_CLIENT_ID}' | base64 --decode)"
    audience="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_AUDIENCE}' | base64 --decode)"
    application="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_CASDOOR_APPLICATION}' | base64 --decode)"
    scope="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_REQUIRED_SCOPE}' | base64 --decode)"
    discovery="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_DISCOVERY_URL}' | base64 --decode)"
    backchannel="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_BACKCHANNEL_ENDPOINT}' | base64 --decode)"
    subjects="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o jsonpath='{.data.INTERNAL_AUTH_SUBJECT_ALLOWLIST}' | base64 --decode)"
    caller_discovery="$(kubectl get secret "$client_secret_name" -n "$namespace" \
        -o jsonpath='{.data.KNOWLEDGE_APP_SERVICE_DISCOVERY_URL}' | base64 --decode)"
    caller_backchannel="$(kubectl get secret "$client_secret_name" -n "$namespace" \
        -o jsonpath='{.data.KNOWLEDGE_APP_SERVICE_BACKCHANNEL_ENDPOINT}' | base64 --decode)"

    if [[ "$client_id" != "$audience" ]]; then
        log_error "服务调用 client 与资源 audience 不一致: caller=$caller"
        return 1
    fi
    if [[ "$caller_discovery" != "$discovery" || "$caller_backchannel" != "$backchannel" ]]; then
        log_error "服务调用方与资源方的 Discovery/backchannel 不一致: caller=$caller"
        return 1
    fi
    if [[ "$application" != "$expected_application" || "$scope" != "$expected_scope" ]]; then
        log_error "服务身份 application/scope 与部署契约不一致: caller=$caller"
        return 1
    fi
    if [[ ! "$discovery" =~ ^https://[A-Za-z0-9._-]+(:[0-9]+)?/\.well-known/openid-configuration$ ]]; then
        log_error "服务 Discovery URL 必须是显式 HTTPS 标准 Discovery: caller=$caller"
        return 1
    fi
    if [[ ! "$backchannel" =~ ^https?://[A-Za-z0-9._-]+(:[0-9]+)?$ ]]; then
        log_error "服务 backchannel endpoint 格式无效: caller=$caller"
        return 1
    fi
    if [[ -z "$subjects" || "$subjects" == *[[:space:]]* ]]; then
        log_error "服务 subject binding 为空或格式无效: caller=$caller"
        return 1
    fi

    unset encoded client_id audience application scope discovery backchannel subjects key
    unset caller_discovery caller_backchannel
    log_success "服务身份关系门禁通过: caller=$caller relation=$expected_application"
}
