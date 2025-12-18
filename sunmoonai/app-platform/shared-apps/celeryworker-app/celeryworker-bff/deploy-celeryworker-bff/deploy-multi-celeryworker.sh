#!/bin/bash

# Celery Worker 多后端部署脚本
# 用法: ./deploy-multi-celeryworker.sh <action> [project_id] [namespace] [environment]
# 注意: 镜像构建请使用 build/build-image.sh 脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 保存 Celery Worker 脚本的目录路径（统一部署模板会重新定义 SCRIPT_DIR）
CELERY_WORKER_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
# 注意：从 celeryworker-bff 到 k8s 需要 5 级（celeryworker-bff -> celeryworker-app -> shared-apps -> app-platform -> sunmoonai -> k8s）
source "$PROJECT_ROOT/../../../../../utils/unified-deployment-template.sh"

# 恢复 Celery Worker 脚本的目录路径
SCRIPT_DIR="$CELERY_WORKER_SCRIPT_DIR"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载部署配置文件
CELERY_WORKER_CONFIG_FILE="$SCRIPT_DIR/deploy-multi-celeryworker.conf"
if [[ -f "$CELERY_WORKER_CONFIG_FILE" ]]; then
    source "$CELERY_WORKER_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/../../../../../utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Celery Worker 多后端配置文件: $CELERY_WORKER_CONFIG_FILE"
else
    log_warn "未找到 Celery Worker 多后端配置文件: $CELERY_WORKER_CONFIG_FILE，使用默认配置"
fi

# 默认配置（对齐 PostgreSQL 部署脚本，使用硬编码默认值）
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 递归部署子组件
deploy_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Celery Worker 子组件..."
    
    # 定义子组件部署顺序（按优先级排序）
    # Secrets 现在由组件自己的 secrets/deploy-secrets-all 管理
    local sub_components=(
        "celeryworker_secrets:${secrets_enabled:-true}:${secrets_priority:-2000}:Celery Worker Secrets:$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
        "celeryworker_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Celery Worker 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "celeryworker_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Celery Worker API 接口路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )
    
    # 按优先级排序
    IFS=$'\n' sub_components=($(sort -t: -k3 -nr <<<"${sub_components[*]}"))
    unset IFS
    
    # 部署子组件
    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ "$enabled" == "true" ]]; then
            log_info "部署 $description (优先级: $priority)..."
            
            if [[ -f "$script_path" ]]; then
                # Ingress 脚本不接受 dry_run 参数，只传递 deploy/project_id/namespace/environment
                if [[ "$name" == "celeryworker_ingress" ]]; then
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                else
                    # 其他子组件可以传递 dry_run 参数
                    if bash "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                        log_success "✅ $description 部署成功"
                    else
                        log_error "❌ $description 部署失败"
                        return 1
                    fi
                fi
            else
                log_error "❌ $description 脚本不存在: $script_path"
                return 1
            fi
        else
            log_info "跳过 $description (已禁用)"
        fi
    done
    
    log_success "✅ Celery Worker 子组件部署完成"
    return 0
}

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE:-celeryworker}"
CELERY_WORKER_TAG="${CELERY_WORKER_TAG:-1.0.0}"

# 资源文件路径（对齐项目结构，统一使用 multi-celeryworker.yaml）
RESOURCES_DIR="../resources"
CELERYWORKER_YAML="${RESOURCES_DIR}/multi-celeryworker.yaml"
# 生成的 YAML 文件路径（可选，用于调试和审计）
# 通过环境变量 SAVE_GENERATED_YAML=true 启用保存
GENERATED_YAML="${RESOURCES_DIR}/multi-celeryworker-generated.yaml"

# Secrets 和 ConfigMap 统一部署脚本（按照 PostgreSQL 模式）
SECRETS_DIR="${SCRIPT_DIR}/secrets"
DEPLOY_SECRETS_ALL_SCRIPT="${SECRETS_DIR}/deploy-secrets-all/deploy-secrets-all.sh"

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
}

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 检查是否已有可用的Kubernetes连接
    if ! kubectl get nodes >/dev/null 2>&1; then
        # 确保 Kubernetes 连接已建立
        if ! setup_kubectl_environment; then
            log_error "❌ 无法建立 Kubernetes 连接"
            echo ""
            log_info "如果已手动设置 KUBECONFIG，请检查："
            echo "  export KUBECONFIG=/path/to/your/kubeconfig"
            echo "  kubectl get nodes"
            echo ""
            log_info "如果需要自动连接，请检查："
            echo "  1. SSH 连接配置是否正确"
            echo "  2. 端口是否被占用（当前错误显示端口 6442 已被占用）"
            echo "  3. 远程服务器上的 kubeconfig 文件权限"
            echo ""
            return 1
        fi
    fi
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先使用 namespace-platform 部署所需的命名空间："
        echo "  cd ../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

# 生成模板 YAML 文件（如果不存在）
generate_template_yaml() {
    if [ -f "$CELERYWORKER_YAML" ]; then
        return 0  # 文件已存在，不需要生成
    fi
    
    log_info "模板文件不存在，自动生成: $CELERYWORKER_YAML"
    mkdir -p "$RESOURCES_DIR"
    
    cat > "$CELERYWORKER_YAML" <<'TEMPLATE_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: celeryworker-multi
  namespace: ${NAMESPACE:-app-platform-dev}
  labels:
    app: celeryworker-multi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: celeryworker-multi
  template:
    metadata:
      labels:
        app: celeryworker-multi
    spec:
      # 多个 Init Container: 从不同后端镜像提取任务定义代码
      # 注意：Init Container 由部署脚本动态生成，替换 {{INIT_CONTAINERS}} 占位符
      initContainers:
{{INIT_CONTAINERS}}
      
      # Init Container 3: 合并代码并创建统一入口
      # 注意：使用 python:alpine 镜像，因为需要 Python 来合并 celery_app.py 中的 task_routes
      - name: merge-code
        image: python:alpine
        volumeMounts:
        - name: worker-code
          mountPath: /shared
        command:
          - sh
          - -c
          - |
            echo "=========================================="
            echo "合并多个后端的代码"
            echo "=========================================="
            
            MERGED_DIR="/shared/app"
            mkdir -p "$MERGED_DIR"
            
            # 合并 worker 目录（任务定义）- 合并所有后端的任务
            # 注意：后端列表由部署脚本动态生成，替换 {{MERGE_BACKENDS}} 占位符
            # 重要：保留原始目录结构，不重命名，确保导入路径不变（例如：from .email.tasks import send_verify_email）
            # 策略：如果路径冲突，合并文件内容（追加），而不是覆盖，确保所有任务定义都保留
            echo ""
            echo "合并 worker 目录（任务定义）..."
            mkdir -p "$MERGED_DIR/worker"
            for backend in {{MERGE_BACKENDS}}; do
              if [ -d "/shared/app/$backend/worker" ]; then
                echo "  从 $backend/worker 合并任务..."
                # 遍历 worker 目录下的所有文件（保留子目录结构）
                find "/shared/app/$backend/worker" -type f | while read -r source_file; do
                  # 计算相对路径（相对于 worker 目录）
                  # 例如：/shared/app/incubator/worker/email/tasks.py -> email/tasks.py
                  relative_path="${source_file#/shared/app/$backend/worker/}"
                  
                  # 目标文件路径（保持原始路径，不重命名）
                  target_file="$MERGED_DIR/worker/$relative_path"
                  target_dir=$(dirname "$target_file")
                  
                  # 创建目标目录
                  mkdir -p "$target_dir"
                  
                  # 如果文件已存在，合并内容（追加），而不是覆盖
                  # 原因：任务名称已包含后端前缀（如 incubator.send_verify_email），所以即使文件合并，任务名称也不同，不会冲突
                  if [ -f "$target_file" ]; then
                    echo "    ⚠ 路径冲突: $relative_path (来自 $backend，将合并到现有文件)"
                    echo "" >> "$target_file"
                    echo "# ========================================" >> "$target_file"
                    echo "# 来自 $backend 后端的任务定义" >> "$target_file"
                    echo "# ========================================" >> "$target_file"
                    echo "" >> "$target_file"
                    cat "$source_file" >> "$target_file"
                  else
                    # 文件不存在，直接复制
                    cp "$source_file" "$target_file"
                  fi
                done
              fi
            done
            
            # 合并 worker/__init__.py（重要：确保所有后端的任务都被导入）
            # 注意：后端列表由部署脚本动态生成，替换 {{MERGE_BACKENDS}} 占位符
            echo ""
            echo "合并 worker/__init__.py..."
            worker_init_file="$MERGED_DIR/worker/__init__.py"
            mkdir -p "$(dirname "$worker_init_file")"
            
            # 创建统一的 __init__.py，导入所有后端的任务
            cat > "$worker_init_file" <<'INIT_EOF'
from app.core.celery_app import celery_app

# 自动导入所有后端的任务模块
# 注意：导入路径保持不变（例如：from .email.tasks import send_verify_email）
# 任务名称已包含后端前缀（如 incubator.send_verify_email），不会冲突
INIT_EOF
            
            # 合并所有后端的 worker/__init__.py 内容
            for backend in {{MERGE_BACKENDS}}; do
              backend_init_file="/shared/app/$backend/worker/__init__.py"
              if [ -f "$backend_init_file" ]; then
                echo "" >> "$worker_init_file"
                echo "# ========================================" >> "$worker_init_file"
                echo "# 来自 $backend 后端的任务导入" >> "$worker_init_file"
                echo "# ========================================" >> "$worker_init_file"
                # 复制导入语句（跳过注释和空行，只保留实际的导入语句）
                grep -E '^from |^import ' "$backend_init_file" >> "$worker_init_file" 2>/dev/null || true
                echo "  ✓ 合并 $backend/worker/__init__.py"
              fi
            done
            
            # 合并 core 目录（Celery配置）- 智能合并所有后端的配置
            # 注意：后端列表由部署脚本动态生成，替换 {{MERGE_BACKENDS}} 占位符
            # 重要：需要合并所有后端的 task_routes，因为每个后端有不同的任务路由配置
            # 策略：
            #   1. 复制第一个后端的 core 目录（作为基础配置）
            #   2. 使用 Python 脚本合并其他后端的 celery_app.py 中的 task_routes 配置
            echo ""
            echo "合并 core 目录（Celery配置）..."
            mkdir -p "$MERGED_DIR/core"
            
            # 第一步：复制第一个后端的 core 目录（作为基础配置）
            first_backend=""
            for backend in {{MERGE_BACKENDS}}; do
              if [ -d "/shared/app/$backend/core" ]; then
                echo "  使用 $backend/core 作为基础配置..."
                cp -r "/shared/app/$backend/core"/* "$MERGED_DIR/core/" 2>/dev/null || true
                first_backend="$backend"
                break
              fi
            done
            
            # 第二步：合并其他后端的 celery_app.py 中的 task_routes
            # 因为每个后端可能有不同的任务路由配置（如 llmops.* → llmops-queue, incubator.* → email-queue）
            if [ -n "$first_backend" ] && [ -f "$MERGED_DIR/core/celery_app.py" ]; then
              merged_celery_app="$MERGED_DIR/core/celery_app.py"
              echo "  合并所有后端的 task_routes 配置..."
              
              # 使用 Python 来合并 task_routes（python:alpine 镜像包含 Python）
              python3 <<PYTHON_EOF
import re
import sys

# 读取合并后的 celery_app.py（第一个后端的配置）
with open("$merged_celery_app", "r") as f:
    merged_content = f.read()

# 提取第一个后端的 task_routes（处理嵌套字典）
def extract_task_routes_dict(content):
    """提取 task_routes 字典内容，处理嵌套大括号"""
    match = re.search(r'task_routes\s*=\s*\{', content)
    if not match:
        return None
    start_pos = match.end() - 1  # 从 { 开始
    brace_count = 0
    end_pos = start_pos
    for i, char in enumerate(content[start_pos:], start_pos):
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
            if brace_count == 0:
                end_pos = i + 1
                break
    return content[start_pos:end_pos]

def parse_routes_dict(dict_str):
    """解析路由字典，提取所有路由配置"""
    routes = {}
    # 使用更精确的正则表达式匹配 "pattern": { ... }，处理嵌套字典
    pattern = r'["\']([^"\']+)["\']\s*:\s*\{'
    matches = list(re.finditer(pattern, dict_str))
    for i, match in enumerate(matches):
        pattern_name = match.group(1)
        start_pos = match.end() - 1  # 从 { 开始
        # 找到对应的结束 }
        brace_count = 0
        end_pos = start_pos
        for j, char in enumerate(dict_str[start_pos:], start_pos):
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end_pos = j + 1
                    break
        config = dict_str[start_pos:end_pos]
        routes[pattern_name] = config
    return routes

# 提取第一个后端的 task_routes
first_routes_dict = extract_task_routes_dict(merged_content)
if not first_routes_dict:
    print("未找到 task_routes 配置", file=sys.stderr)
    sys.exit(1)

# 解析第一个后端的路由配置
merged_routes = parse_routes_dict(first_routes_dict)

# 合并其他后端的 task_routes
backends = "{{MERGE_BACKENDS}}".split()
for backend in backends:
    if backend == "$first_backend":
        continue
    backend_file = "/shared/app/{}/core/celery_app.py".format(backend)
    try:
        with open(backend_file, "r") as f:
            backend_content = f.read()
        backend_routes_dict = extract_task_routes_dict(backend_content)
        if backend_routes_dict:
            backend_routes = parse_routes_dict(backend_routes_dict)
            for pattern_name, config in backend_routes.items():
                if pattern_name not in merged_routes:
                    merged_routes[pattern_name] = config
                    print("    添加 {} 的路由配置: {}".format(backend, pattern_name))
    except FileNotFoundError:
        pass

# 重新构建 task_routes 字符串
new_routes_str = "task_routes = {\n"
for pattern_name, config in merged_routes.items():
    new_routes_str += "    \"{}\": {}\n".format(pattern_name, config)
    # 确保每个路由配置后都有逗号（除了最后一个）
    if pattern_name != list(merged_routes.keys())[-1]:
        if not config.rstrip().endswith(','):
            new_routes_str = new_routes_str.rstrip() + ",\n"
new_routes_str += "}"

# 替换原文件中的 task_routes（使用精确匹配）
first_dict_match = re.search(r'task_routes\s*=\s*\{', merged_content)
if first_dict_match:
    start_pos = first_dict_match.start()
    # 找到对应的结束位置
    brace_count = 0
    end_pos = start_pos
    for i, char in enumerate(merged_content[start_pos:], start_pos):
        if char == '{':
            brace_count += 1
        elif char == '}':
            brace_count -= 1
            if brace_count == 0:
                end_pos = i + 1
                break
    new_content = merged_content[:start_pos] + new_routes_str + merged_content[end_pos:]
else:
    new_content = merged_content

# 写回文件
with open("$merged_celery_app", "w") as f:
    f.write(new_content)

print("  ✓ 已合并所有后端的 task_routes 配置")
PYTHON_EOF
            fi
            
            # 合并其他共享目录（按优先级：{{MERGE_BACKENDS}}）
            # 注意：后端列表由部署脚本动态生成，替换 {{MERGE_BACKENDS}} 占位符
            echo ""
            echo "合并其他共享目录..."
            for dir in services db models schemas crud; do
              for backend in {{MERGE_BACKENDS}}; do
                if [ -d "/shared/app/$backend/$dir" ]; then
                  echo "  复制 $backend/$dir..."
                  cp -r "/shared/app/$backend/$dir" "$MERGED_DIR/" 2>/dev/null || true
                  break  # 找到第一个就停止（按优先级）
                fi
              done
            done
            
            # 复制 __init__.py（按优先级：{{MERGE_BACKENDS}}）
            echo ""
            echo "复制 __init__.py..."
            for backend in {{MERGE_BACKENDS}}; do
              if [ -f "/shared/app/$backend/__init__.py" ]; then
                cp "/shared/app/$backend/__init__.py" "$MERGED_DIR/" 2>/dev/null || true
                echo "  ✓ 使用 $backend/__init__.py"
                break  # 找到第一个就停止（按优先级）
              fi
            done
            
            # 注意：celeryworker_pre_start.py 现在在 celeryworker 镜像中，不需要从后端镜像提取
            
            echo ""
            echo "=========================================="
            echo "代码合并完成，合并后目录内容:"
            echo "=========================================="
            ls -la "$MERGED_DIR" || true
            echo ""
            if [ -d "$MERGED_DIR/worker" ]; then
              echo "合并后的任务文件:"
              ls -la "$MERGED_DIR/worker" || true
            fi
            echo ""
      
      containers:
      - name: celeryworker
        image: ${CELERY_WORKER_IMAGE_REGISTRY}/${CELERY_WORKER_IMAGE_PROJECT}/${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}
        imagePullPolicy: ${IMAGE_PULL_POLICY:-IfNotPresent}
        volumeMounts:
        - name: worker-code
          mountPath: /app/app  # 挂载合并后的代码
        envFrom:
        # 从 ConfigMap 读取 Celery Worker 配置
        - configMapRef:
            name: celeryworker-config
        env:
        # 数据库连接（任务执行需要，从 Secret 读取）
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgresql-llmopsservice-db-secret
              key: DB_URL
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - celery
            - -A
            - app.worker
            - inspect
            - ping
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - celery
            - -A
            - app.worker
            - inspect
            - ping
          initialDelaySeconds: 5
          periodSeconds: 10
      
      volumes:
      - name: worker-code
        emptyDir: {}  # 临时存储，Pod 重启时清空并重新提取
---
apiVersion: v1
kind: Service
metadata:
  name: celeryworker-multi-service
  namespace: ${NAMESPACE:-app-platform-dev}
  labels:
    app: celeryworker-multi
spec:
  selector:
    app: celeryworker-multi
  ports:
  - port: 5555
    targetPort: 5555
    protocol: TCP
  type: ClusterIP
TEMPLATE_EOF
    
    log_success "✅ 模板文件已生成: $CELERYWORKER_YAML"
}

# 检查环境配置
check_env_config() {
    # 如果模板文件不存在，自动生成
    generate_template_yaml
    
    if [ ! -f "$CELERYWORKER_YAML" ]; then
        log_error "配置文件不存在: $CELERYWORKER_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/multi-celeryworker.yaml"
        exit 1
    fi
    
    # 检查 envsubst 是否可用
    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst 命令未找到，请安装 gettext 包"
        log_info "Ubuntu/Debian: sudo apt-get install gettext-base"
        log_info "CentOS/RHEL: sudo yum install gettext"
        exit 1
    fi
}

# ============================================================================
# 动态生成 Init Container 和后端列表
# ============================================================================

# 获取所有启用的后端列表（通过检查 BACKEND_*_IMAGE 变量）
get_enabled_backends() {
    local backends=()
    # 检查配置文件中定义的所有后端（通过 BACKEND_*_IMAGE 变量）
    # 使用 set 命令获取所有变量，然后过滤出 BACKEND_*_IMAGE 变量
    while IFS= read -r var_line; do
        # 提取变量名（例如：BACKEND_llmops_IMAGE="llmops-app-bff" -> BACKEND_llmops_IMAGE）
        local var_name=$(echo "$var_line" | cut -d'=' -f1)
        # 提取后端名称（例如：BACKEND_llmops_IMAGE -> llmops）
        local backend_name=$(echo "$var_name" | sed 's/^BACKEND_//' | sed 's/_IMAGE$//')
        
        # 跳过空的后端名称
        if [ -z "$backend_name" ]; then
            continue
        fi
        
        # 检查是否启用（可以通过 BACKEND_*_ENABLED 控制，默认启用）
        local enabled_var="BACKEND_${backend_name}_ENABLED"
        local enabled="${!enabled_var:-true}"
        if [ "$enabled" = "true" ]; then
            backends+=("$backend_name")
        fi
    done < <(set | grep -E '^BACKEND_[a-zA-Z0-9_]+_IMAGE=' || true)
    
    echo "${backends[@]}"
}

# 动态生成单个后端的 Init Container YAML
generate_init_container_yaml() {
    local backend_name="$1"
    local backend_upper=$(echo "$backend_name" | tr '[:lower:]' '[:upper:]')
    
    # 使用间接变量引用获取配置
    local image_registry_var="BACKEND_${backend_name}_IMAGE_REGISTRY"
    local image_project_var="BACKEND_${backend_name}_IMAGE_PROJECT"
    local image_var="BACKEND_${backend_name}_IMAGE"
    local tag_var="BACKEND_${backend_name}_TAG"
    local source_dir_var="BACKEND_${backend_name}_CODE_EXTRACT_SOURCE_DIR"
    local extract_dirs_var="BACKEND_${backend_name}_CODE_EXTRACT_DIRS"
    local extract_files_var="BACKEND_${backend_name}_CODE_EXTRACT_FILES"
    
    # 获取后端配置（使用默认值）
    local image_registry="${!image_registry_var:-${DEFAULT_BACKEND_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}"
    local image_project="${!image_project_var:-${DEFAULT_BACKEND_IMAGE_PROJECT:-k8s-images}}"
    local image="${!image_var}"
    local tag="${!tag_var:-1.0.0}"
    local source_dir="${!source_dir_var:-${DEFAULT_CODE_EXTRACT_SOURCE_DIR:-/app/app}}"
    local extract_dirs="${!extract_dirs_var:-${DEFAULT_CODE_EXTRACT_DIRS:-worker core services db models schemas crud}}"
    local extract_files="${!extract_files_var:-${DEFAULT_CODE_EXTRACT_FILES:-__init__.py}}"
    
    # 导出环境变量供 envsubst 使用（使用大写变量名，例如 LLMOPS_*, INCUBATOR_*）
    # 注意：这些变量会在部署函数中统一导出，这里不需要重复导出
    
    # 生成 Init Container YAML（使用模板）
    # 注意：变量名使用 ${backend_upper}_* 格式（例如 LLMOPS_*, INCUBATOR_*）
    # 这些变量在部署函数中已经导出
    cat <<EOF
      # Init Container: 从 ${backend_name} 提取代码
      - name: extract-${backend_name}-code
        image: \${${backend_upper}_IMAGE_REGISTRY}/\${${backend_upper}_IMAGE_PROJECT}/\${${backend_upper}_IMAGE}:\${${backend_upper}_TAG}
        imagePullPolicy: \${IMAGE_PULL_POLICY:-IfNotPresent}
        env:
        - name: CODE_EXTRACT_SOURCE_DIR
          value: "\${${backend_upper}_CODE_EXTRACT_SOURCE_DIR:-/app/app}"
        - name: CODE_EXTRACT_TARGET_DIR
          value: "/shared/app/${backend_name}"
        - name: CODE_EXTRACT_DIRS
          value: "\${${backend_upper}_CODE_EXTRACT_DIRS:-worker core services db models schemas crud}"
        - name: CODE_EXTRACT_FILES
          value: "\${${backend_upper}_CODE_EXTRACT_FILES:-__init__.py}"
        command:
          - sh
          - -c
          - |
            echo "=========================================="
            echo "从 \${${backend_upper}_IMAGE} 镜像提取任务定义代码"
            echo "=========================================="
            echo "源代码路径: \${CODE_EXTRACT_SOURCE_DIR}"
            echo "目标路径: \${CODE_EXTRACT_TARGET_DIR}"
            echo "提取目录: \${CODE_EXTRACT_DIRS}"
            echo "提取文件: \${CODE_EXTRACT_FILES}"
            echo "=========================================="
            
            SOURCE_DIR="\${CODE_EXTRACT_SOURCE_DIR}"
            TARGET_DIR="\${CODE_EXTRACT_TARGET_DIR}"
            
            mkdir -p "\$TARGET_DIR"
            
            # 复制目录（从环境变量读取目录列表）
            if [ -n "\${CODE_EXTRACT_DIRS}" ]; then
              echo ""
              echo "开始复制目录..."
              for dir in \${CODE_EXTRACT_DIRS}; do
                if [ -d "\$SOURCE_DIR/\$dir" ]; then
                  echo "  ✓ 复制 \$dir/..."
                  cp -r "\$SOURCE_DIR/\$dir" "\$TARGET_DIR/"
                else
                  echo "  ⚠ 跳过 \$dir/（目录不存在）"
                fi
              done
            fi
            
            # 复制文件（从环境变量读取文件列表）
            if [ -n "\${CODE_EXTRACT_FILES}" ]; then
              echo ""
              echo "开始复制文件..."
              for file in \${CODE_EXTRACT_FILES}; do
                if [ -f "\$SOURCE_DIR/\$file" ]; then
                  echo "  ✓ 复制 \$file"
                  cp "\$SOURCE_DIR/\$file" "\$TARGET_DIR/"
                else
                  echo "  ⚠ 跳过 \$file（文件不存在）"
                fi
              done
            fi
            
            echo ""
            echo "=========================================="
            echo "代码提取完成，目标目录内容:"
            echo "=========================================="
            ls -la "\$TARGET_DIR" || true
            echo ""
        volumeMounts:
        - name: worker-code
          mountPath: /shared
EOF
}

# 动态生成所有 Init Container YAML
generate_all_init_containers() {
    local backends=($(get_enabled_backends))
    local init_containers=""
    
    for backend in "${backends[@]}"; do
        init_containers+="$(generate_init_container_yaml "$backend")"$'\n'
    done
    
    echo "$init_containers"
}

# 生成后端列表字符串（用于合并逻辑）
generate_backend_list() {
    local backends=($(get_enabled_backends))
    echo "${backends[*]}"  # 用空格分隔
}

# 部署 Celery Worker
deploy_celeryworker() {
    log_info "开始部署 Celery Worker（多后端）..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../build && ./build-image.sh build-push
    CELERY_WORKER_FULL_IMAGE_NAME="${CELERY_WORKER_IMAGE_REGISTRY}/${CELERY_WORKER_IMAGE_PROJECT}/${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
    IMAGE_PULL_POLICY="IfNotPresent"  # 如果本地有则使用，否则从仓库拉取
    log_info "使用 Harbor 镜像部署: $CELERY_WORKER_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 准备环境变量
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    export CELERY_WORKER_IMAGE_REGISTRY="${CELERY_WORKER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export CELERY_WORKER_IMAGE_PROJECT="${CELERY_WORKER_IMAGE_PROJECT:-k8s-images}"
    export CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE}"
    export CELERY_WORKER_TAG="${CELERY_WORKER_TAG}"
    export CELERY_WORKER_FULL_IMAGE_NAME="$CELERY_WORKER_FULL_IMAGE_NAME"
    export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-IfNotPresent}"
    
    # 多后端配置（动态导出所有后端的环境变量，用于兼容性和 envsubst）
    # 动态导出所有启用的后端环境变量
    log_info "导出后端环境变量..."
    local backends=($(get_enabled_backends))
    for backend in "${backends[@]}"; do
        local backend_upper=$(echo "$backend" | tr '[:lower:]' '[:upper:]')
        
        # 使用间接变量引用获取配置
        local image_registry_var="BACKEND_${backend}_IMAGE_REGISTRY"
        local image_project_var="BACKEND_${backend}_IMAGE_PROJECT"
        local image_var="BACKEND_${backend}_IMAGE"
        local tag_var="BACKEND_${backend}_TAG"
        local source_dir_var="BACKEND_${backend}_CODE_EXTRACT_SOURCE_DIR"
        local extract_dirs_var="BACKEND_${backend}_CODE_EXTRACT_DIRS"
        local extract_files_var="BACKEND_${backend}_CODE_EXTRACT_FILES"
        
        # 导出环境变量（使用大写变量名，用于 YAML 中的 envsubst）
        eval "export ${backend_upper}_IMAGE_REGISTRY=\"\${${image_registry_var}:-${DEFAULT_BACKEND_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}\""
        eval "export ${backend_upper}_IMAGE_PROJECT=\"\${${image_project_var}:-${DEFAULT_BACKEND_IMAGE_PROJECT:-k8s-images}}\""
        eval "export ${backend_upper}_IMAGE=\"\${${image_var}}\""
        eval "export ${backend_upper}_TAG=\"\${${tag_var}:-1.0.0}\""
        eval "export ${backend_upper}_CODE_EXTRACT_SOURCE_DIR=\"\${${source_dir_var}:-${DEFAULT_CODE_EXTRACT_SOURCE_DIR:-/app/app}}\""
        eval "export ${backend_upper}_CODE_EXTRACT_DIRS=\"\${${extract_dirs_var}:-${DEFAULT_CODE_EXTRACT_DIRS:-worker core services db models schemas crud}}\""
        eval "export ${backend_upper}_CODE_EXTRACT_FILES=\"\${${extract_files_var}:-${DEFAULT_CODE_EXTRACT_FILES:-__init__.py}}\""
        
        log_info "  后端 $backend: ${!image_var}:${!tag_var:-1.0.0}"
    done
    
    # 从配置文件读取环境变量
    # RabbitMQ 和 Redis 配置（方案A：所有后端共享）
    # RabbitMQ: 单个实例 + 多个队列（llmops-queue, incubator-queue）
    # Redis: 单个实例 + 结果键前缀（自动区分 llmops 和 incubator）
    export CELERY_BROKER_URL="${CELERY_BROKER_URL:-amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//}"
    export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-redis://redis-service.data-platform:6379/0}"
    export CELERY_QUEUES="${CELERY_QUEUES:-llmops-queue,incubator-queue}"
    export CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-2}"
    export REDIS_URL="${REDIS_URL:-redis://redis-service.data-platform:6379}"
    
    # ============================================================
    # 阶段1：部署子级组件（按优先级，先部署依赖项）
    # ============================================================
    log_info "🚀 阶段1：部署 Celery Worker 子级组件..."
    if ! deploy_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_error "❌ Celery Worker 子级组件部署失败！"
        return 1
    fi
    log_success "✅ Celery Worker 子级组件部署完成"
    
    # ============================================================
    # 阶段2：部署本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段2：部署 Celery Worker 核心服务..."
    log_info "部署 Celery Worker（多后端）(环境: $ENVIRONMENT, 镜像: $CELERY_WORKER_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-IfNotPresent}, 命名空间: $NAMESPACE)..."
    
    # 动态生成 Init Container 和后端列表
    log_info "动态生成 Init Container 配置..."
    INIT_CONTAINERS_YAML=$(generate_all_init_containers)
    BACKEND_LIST=$(generate_backend_list)
    
    log_info "启用的后端: $BACKEND_LIST"
    
    # 创建临时文件并替换占位符和环境变量
    TEMP_YAML=$(mktemp)
    TEMP_INIT_CONTAINERS=$(mktemp)
    
    # 将 Init Container YAML 写入临时文件（用于多行替换）
    echo "$INIT_CONTAINERS_YAML" > "$TEMP_INIT_CONTAINERS"
    
    # 先替换后端列表占位符（单行，简单）
    sed "s|{{MERGE_BACKENDS}}|$BACKEND_LIST|g" "$CELERYWORKER_YAML" > "$TEMP_YAML"
    
    # 然后替换 Init Container 占位符（多行，使用 perl 或 awk）
    # 使用 perl 处理多行替换
    if command -v perl &> /dev/null; then
        perl -pe 'BEGIN { $init_containers = `cat '"$TEMP_INIT_CONTAINERS"'`; chomp $init_containers; } s/\{\{INIT_CONTAINERS\}\}/$init_containers/;' "$TEMP_YAML" > "${TEMP_YAML}.tmp"
        mv "${TEMP_YAML}.tmp" "$TEMP_YAML"
    else
        # 如果没有 perl，使用 awk（需要特殊处理多行）
        awk -v init_containers_file="$TEMP_INIT_CONTAINERS" '
            BEGIN {
                while ((getline line < init_containers_file) > 0) {
                    init_containers = init_containers line "\n"
                }
                close(init_containers_file)
            }
            /{{INIT_CONTAINERS}}/ {
                gsub(/{{INIT_CONTAINERS}}/, init_containers)
            }
            { print }
        ' "$TEMP_YAML" > "${TEMP_YAML}.tmp"
        mv "${TEMP_YAML}.tmp" "$TEMP_YAML"
    fi
    
    # 最后替换环境变量（envsubst）
    envsubst < "$TEMP_YAML" > "${TEMP_YAML}.final"
    mv "${TEMP_YAML}.final" "$TEMP_YAML"
    rm -f "$TEMP_INIT_CONTAINERS"
    
    # 可选：保存生成的 YAML 到 resources 目录（用于调试和审计）
    # 通过环境变量 SAVE_GENERATED_YAML=true 启用
    if [ "${SAVE_GENERATED_YAML:-false}" = "true" ]; then
        cp "$TEMP_YAML" "$GENERATED_YAML"
        log_info "💾 已保存生成的 YAML 到: $GENERATED_YAML"
    fi
    
    # 部署 Deployment 和 Service
    kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"
    rm -f "$TEMP_YAML"
    
    if [ $? -eq 0 ]; then
        log_success "Celery Worker（多后端）部署完成！"
        log_info "监听队列: ${CELERY_QUEUES}"
        echo ""
        log_info "检查部署状态:"
        echo "  kubectl get pods -n $NAMESPACE -l app=celeryworker-multi"
        echo "  kubectl get svc -n $NAMESPACE -l app=celeryworker-multi"
        echo ""
        log_info "查看 Pod 日志:"
        echo "  kubectl logs -n $NAMESPACE -l app=celeryworker-multi -f"
    else
        log_error "Celery Worker（多后端）部署失败"
        exit 1
    fi
}

# 卸载 Celery Worker
undeploy_celeryworker() {
    log_info "开始卸载 Celery Worker（多后端）..."
    log_info "环境: $ENVIRONMENT, 命名空间: $NAMESPACE"
    
    check_env_config
    
    # ============================================================
    # 阶段1：卸载本级核心服务（Deployment 和 Service）
    # ============================================================
    log_info "🚀 阶段1：卸载 Celery Worker 核心服务..."
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE="$NAMESPACE"
    export ENV="$ENV"  # 保留 ENV 用于兼容性（YAML 中可能使用）
    export ENVIRONMENT="$ENVIRONMENT"
    envsubst < "$CELERYWORKER_YAML" > "$TEMP_YAML"
    kubectl delete -f "$TEMP_YAML" -n "$NAMESPACE" --ignore-not-found=true
    rm -f "$TEMP_YAML"
    log_success "✅ Celery Worker 核心服务卸载完成"
    
    # ============================================================
    # 阶段2：卸载子级组件（按优先级，逆序卸载）
    # ============================================================
    log_info "🚀 阶段2：卸载 Celery Worker 子级组件..."
    if ! uninstall_sub_components "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false; then
        log_warn "⚠️ Celery Worker 子级组件卸载部分失败，继续..."
    fi
    log_success "✅ Celery Worker 子级组件卸载完成"
    
    log_success "Celery Worker（多后端）卸载完成！"
}

# 卸载子组件（按优先级，逆序）
uninstall_sub_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始卸载 Celery Worker 子组件..."
    
    # 定义子组件卸载顺序（按优先级排序，逆序卸载）
    local sub_components=(
        "celeryworker_middleware:${middleware_enabled:-false}:${middleware_priority:-1000}:Celery Worker 中间件:$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
        "celeryworker_ingress:${ingress_enabled:-false}:${ingress_priority:-100}:Celery Worker API 接口路由:$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
    )
    
    # 按优先级排序（卸载时反向顺序）
    IFS=$'\n' sub_components=($(sort -t: -k3 -n <<<"${sub_components[*]}"))
    unset IFS
    
    # 卸载子组件
    for component_info in "${sub_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ "$enabled" == "true" ]]; then
            log_info "卸载 $description (优先级: $priority)..."
            
            if [[ -f "$script_path" ]]; then
                # 禁用子脚本的自动清理，保持连接以便后续操作
                # Ingress 脚本使用 uninstall 命令
                if [[ "$name" == "celeryworker_ingress" ]]; then
                    if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 卸载成功"
                    else
                        log_error "❌ $description 卸载失败"
                    fi
                else
                    # 其他子组件可能使用不同的卸载方式
                    if DISABLE_AUTO_CLEANUP=true bash "$script_path" uninstall "$project_id" "$namespace" "$environment"; then
                        log_success "✅ $description 卸载成功"
                    else
                        log_error "❌ $description 卸载失败"
                    fi
                fi
            else
                log_warn "⚠️ $description 脚本不存在: $script_path"
            fi
        fi
    done
    
    log_success "✅ Celery Worker 子组件卸载完成"
    return 0
}

# 显示状态
show_status() {
    log_info "Celery Worker（多后端）状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 Deployments:"
    kubectl get deployment -n "$NAMESPACE" -l app=celeryworker-multi 2>/dev/null || echo "  无 Deployment"
    echo ""
    log_info "Init Container 日志（最近一个 Pod）:"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=celeryworker-multi -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        log_info "Pod: $POD_NAME"
        echo ""
        log_info "Init Container: extract-llmops-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c extract-llmops-code --tail=20 2>/dev/null || log_warn "无法获取日志"
        echo ""
        log_info "Init Container: extract-incubator-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c extract-incubator-code --tail=20 2>/dev/null || log_warn "无法获取日志"
        echo ""
        log_info "Init Container: merge-code"
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c merge-code --tail=20 2>/dev/null || log_warn "无法获取日志"
    else
        log_warn "未找到运行中的 Pod"
    fi
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    
    # 将 environment 转换为 ENV（用于兼容性）
    case "$environment" in
        "development"|"dev")
            ENV="dev"
            ;;
        "production"|"prod")
            ENV="prod"
            ;;
        *)
            ENV="dev"  # 默认值
            ;;
    esac
    
    # 更新全局变量
    ACTION="$action"
    PROJECT_ID="$project_id"
    NAMESPACE="$namespace"
    ENVIRONMENT="$environment"
    
    log_info "Celery Worker（多后端）部署脚本启动"
    log_info "操作: $ACTION, 项目: $PROJECT_ID, 命名空间: $NAMESPACE, 环境: $ENVIRONMENT"
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            log_info "开始部署 Celery Worker（多后端）..."
            
            # 读取 Kubernetes 配置文件
            if ! read_k8s_config; then
                log_error "无法读取 Kubernetes 配置文件"
                exit 1
            fi
            
            # 检查是否已有可用的Kubernetes连接
            if kubectl get nodes >/dev/null 2>&1; then
                log_info "使用现有 Kubernetes 连接"
            else
                # 设置 Kubernetes 环境（建立远程连接）
                if ! setup_kubectl_environment; then
                    log_error "无法建立 Kubernetes 连接"
                    exit 1
                fi
                
                # 验证连接是否可用
                if ! kubectl get nodes >/dev/null 2>&1; then
                    log_error "Kubernetes 连接不可用，请检查连接状态"
                    exit 1
                fi
            fi
            
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            deploy_celeryworker
            show_status
            ;;
        "undeploy")
            if ! check_namespace "$namespace"; then
                log_error "❌ 命名空间检查失败"
                exit 1
            fi
            undeploy_celeryworker
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "无效的操作: $ACTION"
            echo "用法: $0 <action> [project_id] [namespace] [environment]"
            echo ""
            echo "操作:"
            echo "  deploy     部署 Celery Worker（多后端）"
            echo "  undeploy   卸载 Celery Worker（多后端）"
            echo "  status     查看 Celery Worker（多后端）状态"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（默认: $DEFAULT_PROJECT_ID）"
            echo "  namespace    命名空间（默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（默认: $DEFAULT_ENVIRONMENT）"
            echo ""
            echo "操作说明:"
            echo "  deploy       - 部署到 Kubernetes（从 Harbor 拉取镜像）"
            echo "                注意: 部署前请确保镜像已构建并推送到 Harbor"
            echo "                构建镜像: cd ../build && ./build-image.sh build-push"
            echo "  undeploy     - 卸载 Celery Worker（多后端）"
            echo "  status       - 查看 Celery Worker（多后端）状态"
            echo ""
            echo "示例:"
            echo "  $0 deploy sunmoonai app-platform-dev development"
            echo "  $0 deploy sunmoonai app-platform-prod production"
            echo "  $0 deploy sunmoonai                              # 使用默认命名空间和环境"
            echo ""
            echo "环境:"
            echo "  development  开发环境"
            echo "  production   生产环境"
            echo ""
            echo "完整流程示例:"
            echo "  # 1. 构建并推送镜像"
            echo "  cd ../build"
            echo "  ./build-image.sh build-push"
            echo ""
            echo "  # 2. 部署服务"
            echo "  cd ../deploy-celeryworker-bff"
            echo "  ./deploy-multi-celeryworker.sh deploy sunmoonai app-platform-dev development"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
