#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-config}"
export KUBECONFIG

SOURCE_DIR="${QUESTION_DATA_SOURCE_DIR:-/home/zymun/AI-Application-Development-Lessons/lessons/25_实战——综合智能体集成/integrated_agent_service}"
ENV_FILE="${DEEPSEEK_ENV_FILE:-/home/zymun/AI-Application-Development-Lessons/lessons/23_Trace与可观测性——从问数Demo到运行事实/.env}"
IMAGE="${QUESTION_DATA_IMAGE:-question-data:demo}"
KIND_CLUSTER="${KIND_CLUSTER:-kind}"
NAMESPACE="${QUESTION_DATA_NAMESPACE:-app-platform-dev}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "找不到问数源码目录：$SOURCE_DIR" >&2
  exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "找不到 DeepSeek 配置：$ENV_FILE" >&2
  echo "请设置 DEEPSEEK_ENV_FILE，或先准备含 DEEPSEEK_API_KEY 的 .env" >&2
  exit 1
fi

read_env() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]+=/, "")
      gsub(/\r/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "$ENV_FILE"
}

API_KEY="$(read_env DEEPSEEK_API_KEY)"
BASE_URL="$(read_env DEEPSEEK_BASE_URL)"
MODEL="$(read_env DEEPSEEK_DEFAULT_MODEL)"

if [[ -z "$API_KEY" ]]; then
  echo "DEEPSEEK_API_KEY 为空，无法启动问数服务" >&2
  exit 1
fi

echo "构建镜像 $IMAGE"
docker build -t "$IMAGE" "$SOURCE_DIR"

echo "导入 Kind 集群 $KIND_CLUSTER"
kind load docker-image "$IMAGE" --name "$KIND_CLUSTER"

echo "写入 Secret"
kubectl -n "$NAMESPACE" create secret generic question-data-secret \
  --from-literal="DEEPSEEK_API_KEY=${API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "应用运行时与路由"
kubectl apply -f "$ROOT/k8s/20-runtime.yaml"
kubectl apply -f "$ROOT/k8s/30-ingress.yaml"

CM_ARGS=(
  --from-literal=APP_HOST=0.0.0.0
  --from-literal=APP_PORT=8000
  --from-literal="DEEPSEEK_BASE_URL=${BASE_URL:-https://api.deepseek.com}"
  --from-literal="DEEPSEEK_DEFAULT_MODEL=${MODEL:-deepseek-v4-flash}"
)
kubectl -n "$NAMESPACE" create configmap question-data-config \
  "${CM_ARGS[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "等待 Deployment 就绪"
kubectl -n "$NAMESPACE" rollout status deploy/question-data --timeout=180s

echo
echo "问数展示服务已就绪："
echo "  https://127.0.0.1:30443/"
echo "  https://question.sunmoonai.com:30443/"
echo
echo "健康检查："
echo "  curl -k https://127.0.0.1:30443/health"
echo "  curl -k https://127.0.0.1:30443/ready"
