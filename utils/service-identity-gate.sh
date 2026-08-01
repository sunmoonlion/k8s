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
    local relation_kind="${7:-ingest}"
    local key encoded client_id audience application scope discovery backchannel subjects
    local caller_discovery caller_backchannel
    local client_id_key client_secret_key caller_discovery_key caller_backchannel_key
    local application_key discovery_key backchannel_key audience_key subjects_key scope_key
    if [[ "$relation_kind" == "retrieve" ]]; then
        client_id_key="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID"
        client_secret_key="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET"
        caller_discovery_key="KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL"
        caller_backchannel_key="KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT"
        application_key="RETRIEVAL_AUTH_CASDOOR_APPLICATION"
        discovery_key="RETRIEVAL_AUTH_DISCOVERY_URL"
        backchannel_key="RETRIEVAL_AUTH_BACKCHANNEL_ENDPOINT"
        audience_key="RETRIEVAL_AUTH_AUDIENCE"
        subjects_key="RETRIEVAL_AUTH_SUBJECT_ALLOWLIST"
        scope_key="RETRIEVAL_AUTH_REQUIRED_SCOPE"
    elif [[ "$relation_kind" == "ingest" ]]; then
        client_id_key="KNOWLEDGE_APP_SERVICE_CLIENT_ID"
        client_secret_key="KNOWLEDGE_APP_SERVICE_CLIENT_SECRET"
        caller_discovery_key="KNOWLEDGE_APP_SERVICE_DISCOVERY_URL"
        caller_backchannel_key="KNOWLEDGE_APP_SERVICE_BACKCHANNEL_ENDPOINT"
        application_key="INTERNAL_AUTH_CASDOOR_APPLICATION"
        discovery_key="INTERNAL_AUTH_DISCOVERY_URL"
        backchannel_key="INTERNAL_AUTH_BACKCHANNEL_ENDPOINT"
        audience_key="INTERNAL_AUTH_AUDIENCE"
        subjects_key="INTERNAL_AUTH_SUBJECT_ALLOWLIST"
        scope_key="INTERNAL_AUTH_REQUIRED_SCOPE"
    else
        log_error "未知服务身份关系类型: $relation_kind"
        return 1
    fi
    local client_keys=(
        "$client_id_key"
        "$client_secret_key"
        "$caller_discovery_key"
        "$caller_backchannel_key"
    )
    local binding_keys=(
        "$application_key"
        "$discovery_key"
        "$backchannel_key"
        "$audience_key"
        "$subjects_key"
        "$scope_key"
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
        -o "jsonpath={.data.${client_id_key}}" | base64 --decode)"
    audience="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${audience_key}}" | base64 --decode)"
    application="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${application_key}}" | base64 --decode)"
    scope="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${scope_key}}" | base64 --decode)"
    discovery="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${discovery_key}}" | base64 --decode)"
    backchannel="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${backchannel_key}}" | base64 --decode)"
    subjects="$(kubectl get secret "$binding_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${subjects_key}}" | base64 --decode)"
    caller_discovery="$(kubectl get secret "$client_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${caller_discovery_key}}" | base64 --decode)"
    caller_backchannel="$(kubectl get secret "$client_secret_name" -n "$namespace" \
        -o "jsonpath={.data.${caller_backchannel_key}}" | base64 --decode)"

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
