#!/usr/bin/env bash

# Deploy and validate the real Knowledge Architecture v2 R4 candidates in a
# fully isolated namespace. The accepted pre-v2 Knowledge topology in
# app-platform-dev is read-only throughout this gate.

set -euo pipefail
umask 077

ROOT="/home/zymun"
SCRIPT_ROOT="${ROOT}/k8s/sunmoonai/docs/architecture-v2/scripts"

export R3_APP="knowledge"
export R3_NAMESPACE="${R4_KNOWLEDGE_NAMESPACE:-knowledge-architecture-v2-r4}"
export R3_RELEASE_ID="r4-knowledge-002"
export R3_ADMIN_ORIGIN="https://knowledge-admin-r4.sunmoonai.com:30443"
export R3_WEB_ORIGIN="https://knowledge-web-r4.sunmoonai.com:30443"
export R3_CASDOOR_ORIGIN="https://casdoor.sunmoonai.com:30443"
export R3_PROVIDER_NAMESPACE="app-platform-dev"
export R3_INGRESS_NAMESPACE="ingress-platform-dev"
export R3_IDENTITY_SECRET="sunmoonai-architecture-v2-r4-knowledge-identity"
export R3_ADMIN_APPLICATION="sunmoonai-knowledge-architecture-v2-r4-admin"
export R3_WEB_APPLICATION="sunmoonai-knowledge-architecture-v2-r4-web"
export R3_ADMIN_DISPLAY_NAME="Knowledge Architecture v2 R4 Admin"
export R3_WEB_DISPLAY_NAME="Knowledge Architecture v2 R4 Web"
export R3_TASK_LABEL="architecture-v2-r4-knowledge"
export R3_IDENTITY_JOB_PREFIX="architecture-v2-r4-knowledge-identity"
export R3_RESULT_TASK="architecture-v2-r4-knowledge"
export R3_TARGET_TLS_SECRET="knowledge-r4-tls"
export R3_POLICY_CLUSTER_NAME="knowledge-r4-policy"
export R3_EVIDENCE_DIR="${ROOT}/k8s/sunmoonai/docs/architecture-v2/evidence/R4-knowledge-gate"

export BACKEND_IMAGE="harbor.sunmoonai.com:30443/app-images/knowledge-backend@sha256:a5db9fab89bd131992c205d61294c27d2511be14bf6d50cfb9cb5bce75e8367a"
export ADMIN_IMAGE="harbor.sunmoonai.com:30443/app-images/knowledge-admin-frontend@sha256:07130d859a89b18842ce043178b5477bbb67a3ab183aadfe18baed039bd0b9c2"
export WEB_IMAGE="harbor.sunmoonai.com:30443/app-images/knowledge-web-frontend@sha256:7bdd329bf24e479d1c8f859ef6ed909958bc1479b7296b3b212c2293c7601148"

# The accepted pre-v2 Knowledge Web image implements the same standalone
# runtime contract and is used only to prove native Deployment rollback. It is
# never promoted as an Architecture v2 candidate.
export WEB_R2_IMAGE="harbor.sunmoonai.com:30443/app-images/knowledge-web-frontend@sha256:597193f3d16334e2d81b24c6cd00b54e361fa810f284ba7c11db72f5f34a7cd4"
export R3_R2_BACKEND_ENV_NAME="WEB_BACKEND_INTERNAL_URL"

exec "${SCRIPT_ROOT}/run_r3_template_gate.sh"
