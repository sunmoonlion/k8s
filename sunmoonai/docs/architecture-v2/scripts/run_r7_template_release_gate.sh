#!/usr/bin/env bash

# Run the complete template release gate against the exact frozen R7 images.

set -euo pipefail

ROOT="/home/zymun"
K8S_ROOT="${ROOT}/k8s"
export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/kind-config}"
export R3_NAMESPACE="tpl-architecture-v2-r7"
export R3_RELEASE_ID="r7-template-001"
export R3_IDENTITY_SECRET="sunmoonai-architecture-v2-r7-identity"
export R3_ADMIN_APPLICATION="sunmoonai-tpl-architecture-v2-r7-admin"
export R3_WEB_APPLICATION="sunmoonai-tpl-architecture-v2-r7-web"
export R3_ADMIN_DISPLAY_NAME="Template Architecture v2 R7 Admin"
export R3_WEB_DISPLAY_NAME="Template Architecture v2 R7 Web"
export R3_TASK_LABEL="architecture-v2-r7-template"
export R3_IDENTITY_JOB_PREFIX="architecture-v2-r7-template-identity"
export R3_RESULT_TASK="architecture-v2-r7-template"
export R3_POLICY_CLUSTER_NAME="tpl-r7-policy"
export R3_TARGET_TLS_SECRET="tpl-r7-tls"
export R3_EVIDENCE_DIR="${K8S_ROOT}/sunmoonai/docs/architecture-v2/evidence/R7-release/template"
export BACKEND_IMAGE="harbor.sunmoonai.com:30443/app-images/tpl-backend@sha256:8b504098427ab5349a04e933e1fdf71e3a8fc11ce0f5b36fff703ad356bad348"
export ADMIN_IMAGE="harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend@sha256:cd2b91f54d71586b69c7f3d558066fb8afecf8a701911951076aa3ea5b30ea6b"
export WEB_IMAGE="harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:a835b1d4dcb8b405233fc901c11452f26f971b9d21c679e3cdee6c0d9bfbf729"

cd "$K8S_ROOT"
exec bash sunmoonai/docs/architecture-v2/scripts/run_r3_template_gate.sh
