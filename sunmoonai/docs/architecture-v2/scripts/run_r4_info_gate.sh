#!/usr/bin/env bash

# Deploy and validate the real Info Architecture v2 R4 candidates in a fully
# isolated namespace. The accepted pre-v2 Info topology in app-platform-dev is
# read-only throughout this gate.

set -euo pipefail
umask 077

ROOT="/home/zymun"
SCRIPT_ROOT="${ROOT}/k8s/sunmoonai/docs/architecture-v2/scripts"

export R3_APP="info"
export R3_NAMESPACE="${R4_INFO_NAMESPACE:-info-architecture-v2-r4}"
export R3_RELEASE_ID="r4-info-001"
export R3_ADMIN_ORIGIN="https://info-admin-r4.sunmoonai.com:30443"
export R3_WEB_ORIGIN="https://info-web-r4.sunmoonai.com:30443"
export R3_CASDOOR_ORIGIN="https://casdoor.sunmoonai.com:30443"
export R3_PROVIDER_NAMESPACE="app-platform-dev"
export R3_INGRESS_NAMESPACE="ingress-platform-dev"
export R3_IDENTITY_SECRET="sunmoonai-architecture-v2-r4-info-identity"
export R3_ADMIN_APPLICATION="sunmoonai-info-architecture-v2-r4-admin"
export R3_WEB_APPLICATION="sunmoonai-info-architecture-v2-r4-web"
export R3_ADMIN_DISPLAY_NAME="Info Architecture v2 R4 Admin"
export R3_WEB_DISPLAY_NAME="Info Architecture v2 R4 Web"
export R3_TASK_LABEL="architecture-v2-r4-info"
export R3_IDENTITY_JOB_PREFIX="architecture-v2-r4-info-identity"
export R3_RESULT_TASK="architecture-v2-r4-info"
export R3_TARGET_TLS_SECRET="info-r4-tls"
export R3_POLICY_CLUSTER_NAME="info-r4-policy"
export R3_EVIDENCE_DIR="${ROOT}/k8s/sunmoonai/docs/architecture-v2/evidence/R4-info-gate"

export BACKEND_IMAGE="harbor.sunmoonai.com:30443/app-images/info-backend@sha256:bab29c3fc2795f41cd80a0a3da75df0e9761d9465360600a9810c679db50c19c"
export ADMIN_IMAGE="harbor.sunmoonai.com:30443/app-images/info-admin-frontend@sha256:defacc2f58584541561ada6ce13918efe4be41e9dd7ef21decd30299cd2f149d"
export WEB_IMAGE="harbor.sunmoonai.com:30443/app-images/info-web-frontend@sha256:60f3f70a67630997cc3d0fe9884c166fd5023dac9eed81a3a03b22c5e5c66c52"
export WEB_R2_IMAGE="harbor.sunmoonai.com:30443/app-images/info-web-frontend@sha256:c4b140ded816b495e07314b56c523973c4c1378661efb1a48fd4240e88578520"

exec "${SCRIPT_ROOT}/run_r3_template_gate.sh"
