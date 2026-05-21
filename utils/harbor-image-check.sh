#!/bin/bash

# Check whether an image tag exists in Harbor before applying the workload.
# The check uses the namespace imagePullSecret, so it follows the same registry
# credentials that Kubernetes will use to pull the image.

urlencode_harbor_repo() {
    python3 - "$1" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
}

extract_harbor_auth_from_secret() {
    local namespace="$1"
    local secret_name="$2"
    local registry="$3"

    local dockerconfig
    if ! dockerconfig="$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 -d 2>/dev/null)"; then
        return 1
    fi

    DOCKERCONFIG="$dockerconfig" python3 - "$registry" <<'PY'
import base64
import json
import os
import sys

registry = sys.argv[1]
config = json.loads(os.environ.get("DOCKERCONFIG", "{}"))
auths = config.get("auths", {})
entry = auths.get(registry) or auths.get("https://" + registry) or auths.get("http://" + registry) or {}

auth = entry.get("auth")
if auth:
    print(base64.b64decode(auth).decode())
elif entry.get("username") and entry.get("password"):
    print(f"{entry['username']}:{entry['password']}")
PY
}

check_harbor_image_exists() {
    local image="$1"
    local namespace="$2"
    local secret_name="${3:-harbor-registry-secret}"

    if [[ -z "$image" || -z "$namespace" ]]; then
        log_error "镜像检查参数缺失: image=$image namespace=$namespace"
        return 1
    fi

    local image_without_tag="$image"
    local tag="latest"
    if [[ "$image" == *":"* && "${image##*:}" != *"/"* ]]; then
        tag="${image##*:}"
        image_without_tag="${image%:*}"
    fi

    local registry="${image_without_tag%%/*}"
    local remainder="${image_without_tag#*/}"
    local project="${remainder%%/*}"
    local repo="${remainder#*/}"

    if [[ -z "$registry" || -z "$project" || -z "$repo" || "$repo" == "$remainder" ]]; then
        log_error "无法解析 Harbor 镜像地址: $image"
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl 不存在，无法检查 Harbor 镜像: $image"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 不存在，无法解析 harbor-registry-secret: $secret_name"
        return 1
    fi

    local repo_encoded
    repo_encoded="$(urlencode_harbor_repo "$repo")"

    local auth=""
    auth="$(extract_harbor_auth_from_secret "$namespace" "$secret_name" "$registry" || true)"

    local url="https://${registry}/api/v2.0/projects/${project}/repositories/${repo_encoded}/artifacts/${tag}"
    local http_code
    if [[ -n "$auth" ]]; then
        http_code="$(curl -sk -o /dev/null -w "%{http_code}" -u "$auth" "$url")"
    else
        http_code="$(curl -sk -o /dev/null -w "%{http_code}" "$url")"
    fi

    case "$http_code" in
        200)
            log_success "✅ Harbor 镜像已存在: $image"
            return 0
            ;;
        404)
            log_error "❌ Harbor 镜像不存在: $image"
            log_error "请先把构建好的镜像推送到对应集群 Harbor，再重新部署"
            return 1
            ;;
        401|403)
            log_error "❌ Harbor 镜像检查鉴权失败: $image (HTTP $http_code, secret=$namespace/$secret_name)"
            return 1
            ;;
        *)
            log_error "❌ Harbor 镜像检查失败: $image (HTTP $http_code)"
            return 1
            ;;
    esac
}
