# 递归式部署架构设计文档

## 📋 文档信息

- **版本**: v1.0
- **创建日期**: 2024-10-23
- **作者**: SunMoonAI Platform Team
- **适用范围**: Harbor 及所有子级组件部署

## 🎯 架构概述

### 设计理念

递归式部署架构是一种**配置驱动**的模块化部署方案，通过配置文件控制子级组件的启用状态，实现**一级一级**的递归部署。每一级都有：

1. **配置文件** (`xxx.conf`) - 定义子级是否启用
2. **部署脚本** (`xxx.sh`) - 执行本级和子级部署
3. **子目录** - 包含具体的部署组件

### 核心优势

- **模块化**: 每个组件独立管理，职责清晰
- **可配置**: 通过配置文件控制启用/禁用，支持环境差异化
- **递归性**: 支持多级嵌套部署，符合复杂系统结构
- **容错性**: 子级失败不影响本级，支持部分部署成功
- **可扩展**: 易于添加新的子级组件

## 🏗️ 架构设计


### 架构命名规则规范

#### 核心命名原则

递归式部署架构遵循严格的命名规则，确保目录结构和文件命名的一致性和可预测性：

##### 1. 没有子目录的情况
```
目录名/
├── deploy-目录名/
│   ├── deploy-目录名.conf
│   └── deploy-目录名.sh
└── 目录名.yaml    子目录的yaml文件
```

**示例**：
```
middleware/
├── deploy-middleware/
│   ├── deploy-middleware.conf
│   └── deploy-middleware.sh
└── middleware.yaml
```

##### 2. 有子目录的情况
```
父级目录名/
├── deploy-目录名-all/
│   ├── deploy-目录名-all.conf        父级目录的配置，包括：核心服务即父级本身的配置和子服务的部署控制配置  
│   ├── deploy-目录名-all.sh          父级目录的部署脚本，包括：核心服务即父级本身的服务的部署脚本，子组件的部署目录
│   └── 子目录名1/ 
        ___子级目录的yaml文件                    放置子级的部署目录和子级的yaml文件
│       └── deploy-子目录名1/
│           ├── deploy-子目录名1.conf
│           └── deploy-子目录名1.sh
            
└── 父级目录名.yaml     比如chart的yaml就放在这里
```
把握两点：
第一，每一个资源目录或资源文件，自成一个子目录，多个资源形成多个目录，不能多个资源共享一个目录。这种子目录因而其部署目录中只包含部署的配置文件和部署脚本。
第二，父目录只能是包含子目录的目录，父目录里只有部署目录和子目录，不能包含资源目录或文件，而其部署目录包含部署脚本和部署配置文件，因为是父目录，所有部署目录和其里面的部署脚本都有-all后缀

要注意的两点：
    1、子目录的部署脚本仅仅部署自己的yaml文件，其部署脚本因而不带-all后缀
    2、如果部署目录里含有子目录，那么，它的部署脚本，也会控制其所含有的子目录的部署，但是它的部署脚本却不带有-all后缀，因为它本质上是对它的yaml文件所作的部署，它的部署目录里的子目录只是对其部署所属yaml文件必须的准备和前置工作，   
    
    这时，该部署目录往往表现为：不仅包含部署脚本和部署配置文件，还包括子目录（与此对照的是：对于带有后缀的父目录的部署目录，则仅仅含有部署配置文件和部署脚本）

#

#### 实际示例：Harbor部署架构

以下是Harbor项目的实际目录结构，展示了递归部署架构的具体应用：

```
harbor/                                    # 父级目录
├── deploy-harbor/                         # 父级部署目录
│   ├── deploy-harbor.conf                 # 父级配置文件
│   ├── deploy-harbor.sh                   # 父级部署脚本
│   ├── ingress/                           # 子目录：Ingress配置
│   │   └── deploy-ingress/
│   │       ├── deploy-ingress.conf
│   │       └── deploy-ingress.sh
│   ├── middleware/                        # 子目录：中间件配置
│   │   └── deploy-middleware/
│   │       ├── deploy-middleware.conf
│   │       └── deploy-middleware.sh
│   └── secrets/                           # 子目录：Secret管理
│       ├── deploy-secrets-all/            # Secret统一部署
│       │   ├── deploy-secrets-all.conf
│       │   └── deploy-secrets-all.sh
│       ├── harbor-secrets/                # Harbor认证Secret
│       │   ├── deploy-harbor-secrets/     # Harbor Secret部署
│       │   │   ├── deploy-harbor-secrest.conf
│       │   │   └── deploy-harbor-secrets.sh
│       │   └── harbor-secrets.yaml        # Harbor Secret配置
│       └── harbor.sunmoonai.local-tls/    # Harbor TLS Secret
│           └── harbor.sunmoonai.local-tls.yaml
├── resources/                             # 资源目录
│   ├── custom-values/                     # 自定义配置
│   ├── harbor/                            # Harbor Chart
│   └── harbor-bitnami-native/             # Bitnami原生配置
└── Harbor完整部署文档.md                  # 部署文档
```

**架构特点分析：**

1. **父级控制**: `deploy-harbor.sh` 控制所有子组件的部署
2. **子级独立**: 每个Secret都有独立的部署脚本和配置
3. **层次清晰**: 按功能模块组织，如ingress、middleware、secrets
4. **资源分离**: resources目录存放Chart和配置文件
5. **文档完整**: 包含完整的部署文档

**部署流程：**
1. 父级脚本 `deploy-harbor.sh` 启动
2. 按优先级部署子组件：secrets → middleware → ingress
3. 每个子组件独立部署，互不干扰
4. 最终形成完整的Harbor服务栈

##### 优先级控制规则
- **优先级范围**: 建议使用 1-1000 的数值范围
- **优先级含义**: 数值越大优先级越高，越先部署
- **默认优先级**: 如果未设置优先级，使用默认值
- **依赖关系**: 通过优先级数值体现组件间的依赖关系

#### 实际应用示例

##### Harbor 项目完整结构
```

### 配置文件规范

#### 主配置文件格式 (`xxx.conf`)

```bash
# ============================================================================
# 基础配置
# ============================================================================
PROJECT_ID="sunmoonai"
NAMESPACE="cicd-platform-dev"
ENVIRONMENT="development"

# ============================================================================
# 子级部署控制标志
# ============================================================================
# 控制是否部署各个子级组件
middleware_enabled="true"      # 是否部署 Traefik 中间件
ingress_enabled="true"         # 是否部署 Ingress 配置
secrets_enabled="false"        # 是否部署密钥管理

# ============================================================================
# 子子级部署控制标志（如果存在）
# ============================================================================
# 在子级配置文件中定义
web_routes_enabled="true"      # 是否部署 Web 路由
tcp_routes_enabled="false"     # 是否部署 TCP 路由
```

#### 子级配置文件格式

每个子级目录可以有自己的配置文件，格式与主配置文件相同：

```bash
# middleware/middleware.conf
middleware_timeout_enabled="true"
middleware_buffering_enabled="true"

# ingress/ingress.conf  
web_routes_enabled="true"
tcp_routes_enabled="false"
```

### 部署脚本规范

#### 两级部署逻辑原则

所有级别的带有 `-all` 的部署脚本，部署逻辑都分为两大块：

1. **第一级：子级组件部署**
   - 根据优先级部署子目录下的 `-all.sh` 或 `.sh` 脚本
   - 如果子目录没有孙目录，就没有 `-all.sh` 脚本，只有 `.sh` 脚本
   - 按优先级顺序执行，确保依赖关系正确

2. **第二级：本级专属部署**
   - 部署本级别专属的部署逻辑
   - 例如：Harbor 核心服务、配置、监控等
   - 在子级组件部署完成后执行

#### 部署逻辑结构
```bash
deploy_xxx() {
    # 阶段1：部署子级组件（按优先级）
    log_info "🚀 阶段1：部署子级组件（按优先级）..."
    deploy_sub_components_by_priority
    
    # 阶段2：部署本级专属组件
    log_info "🚀 阶段2：部署本级专属组件..."
    deploy_current_level_components
}
```

#### 主部署脚本结构 (`xxx.sh`)

```bash
#!/bin/bash

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置文件
source "$SCRIPT_DIR/xxx.conf"

# 本级部署函数
deploy_current_level() {
    # 执行本级特殊逻辑
    log_info "开始部署本级组件..."
    # ... 本级部署逻辑
}

# 递归部署子级组件
deploy_sub_components() {
    log_info "开始递归部署子级组件..."
    
    # 部署子级组件
    if [[ "${middleware_enabled:-false}" == "true" ]]; then
        deploy_component "middleware" "Traefik 中间件"
    fi
    
    if [[ "${ingress_enabled:-false}" == "true" ]]; then
        deploy_component "ingress" "Ingress 配置"
    fi
    
    if [[ "${secrets_enabled:-false}" == "true" ]]; then
        deploy_component "secrets" "密钥管理"
    fi
}

# 通用组件部署函数
deploy_component() {
    local component="$1"
    local description="$2"
    
    log_info "🚀 部署 $description..."
    
    # 确定脚本路径
    local script_path=""
    case "$component" in
        "middleware")
            script_path="$SCRIPT_DIR/middleware/deploy-middleware-all/deploy-middleware-all.sh"
            ;;
        "ingress")
            script_path="$SCRIPT_DIR/ingress/deploy-ingress-all/deploy-ingress-all.sh"
            ;;
        "secrets")
            script_path="$SCRIPT_DIR/secrets/deploy-secrets-all/deploy-secrets-all.sh"
            ;;
    esac
    
    # 检查脚本是否存在
    if [[ -f "$script_path" ]]; then
        # 切换到脚本目录
        local original_dir="$(pwd)"
        cd "$(dirname "$script_path")"
        
        # 执行部署脚本
        if ./"$(basename "$script_path")" "$@"; then
            log_success "✅ $description 部署成功"
        else
            log_error "❌ $description 部署失败"
            cd "$original_dir"
            return 1
        fi
        
        # 恢复原目录
        cd "$original_dir"
    else
        log_warn "⚠️  $description 部署脚本不存在: $script_path"
    fi
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-$PROJECT_ID}"
    local namespace="${3:-$NAMESPACE}"
    local environment="${4:-$ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    case "$action" in
        "deploy")
            # 执行本级部署
            deploy_current_level "$project_id" "$namespace" "$environment" "$dry_run"
            
            # 递归部署子级组件
            deploy_sub_components "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        "uninstall")
            # 卸载逻辑
            uninstall_current_level "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        *)
            show_help
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## 🔧 实现细节

### 配置加载机制

1. **主配置文件加载**:
   ```bash
   source "$SCRIPT_DIR/deploy-harbor.conf"
   ```

2. **子级配置文件加载**:
   ```bash
   # 在子级脚本中
   source "$SCRIPT_DIR/deploy-middleware-all.conf"
   ```

3. **环境变量覆盖**:
   ```bash
   # 支持环境变量覆盖配置文件
   middleware_enabled="${MIDDLEWARE_ENABLED:-${middleware_enabled:-false}}"
   ```

### 错误处理机制

1. **本级错误处理**:
   ```bash
   if ! deploy_current_level; then
       log_error "本级部署失败"
       exit 1
   fi
   ```

2. **子级错误处理**:
   ```bash
   if ! deploy_component "middleware" "Traefik 中间件"; then
       log_error "中间件部署失败，但继续部署其他组件"
       # 可以选择继续或停止
   fi
   ```

3. **回滚机制**:
   ```bash
   rollback_failed_components() {
       # 实现回滚逻辑
   }
   ```

### 日志记录规范

```bash
# 日志级别
log_info "ℹ️  信息: 开始部署组件"
log_success "✅ 成功: 组件部署完成"
log_warn "⚠️  警告: 组件配置异常"
log_error "❌ 错误: 组件部署失败"

# 日志格式
log_info "🚀 部署 $description..."
log_success "✅ $description 部署成功"
log_error "❌ $description 部署失败"
```

## 📋 开发规范

### 新增子级组件

1. **创建目录结构**:
   ```bash
   mkdir -p deploy-harbor/new-component/deploy-new-component
   ```

2. **添加配置文件**:
   ```bash
   # deploy-harbor.conf 中添加
   new_component_enabled="true"
   ```

3. **创建部署脚本**:
   ```bash
   # deploy-harbor/new-component/deploy-new-component/deploy-new-component.sh
   # 实现 new-component 的部署逻辑
   ```

4. **更新主脚本**:
   ```bash
   # 在 deploy_sub_components() 中添加
   if [[ "${new_component_enabled:-false}" == "true" ]]; then
       deploy_component "new-component" "新组件"
   fi
   ```

### 脚本命名规范

- **主脚本**: `deploy-xxx-all.sh`
- **子级脚本**: `deploy-xxx-all.sh`
- **配置文件**: `deploy-xxx-all.conf`
- **部署目录**: `deploy-xxx-all/`

### 参数传递规范

```bash
# 主脚本调用子脚本
./sub-script.sh "$project_id" "$namespace" "$environment" "$dry_run"

# 子脚本接收参数
main() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    # ... 处理逻辑
}
```

## 🚀 使用示例

### 基本部署

```bash
# 部署 Harbor 及所有启用的子级组件
cd /path/to/harbor/deploy-harbor
./deploy-harbor.sh deploy sunmoonai cicd-platform-dev development false
```

### 配置控制

```bash
# 修改配置文件
vim deploy-harbor.conf

# 只部署 Harbor 和中间件，跳过 Ingress
middleware_enabled="true"
ingress_enabled="false"
secrets_enabled="false"
```

### 环境差异化

```bash
# 开发环境
ENVIRONMENT="development"
middleware_enabled="true"
ingress_enabled="true"

# 生产环境
ENVIRONMENT="production"
middleware_enabled="true"
ingress_enabled="true"
secrets_enabled="true"
```

## 🔍 测试验证

### 单元测试

```bash
# 测试配置文件加载
source deploy-harbor.conf
echo "middleware_enabled: $middleware_enabled"

# 测试脚本存在性
test -f middleware/deploy-middleware-all/deploy-middleware-all.sh && echo "脚本存在" || echo "脚本不存在"
```

### 集成测试

```bash
# 干运行测试
./deploy-harbor.sh deploy sunmoonai cicd-platform-dev development true

# 实际部署测试
./deploy-harbor.sh deploy sunmoonai cicd-platform-dev development false
```

## 📚 最佳实践

### 1. 配置管理

- 使用版本控制管理配置文件
- 为不同环境创建不同的配置文件
- 使用环境变量覆盖敏感配置

### 2. 错误处理

- 实现完整的错误处理机制
- 提供详细的错误信息
- 支持部分部署成功

### 3. 日志记录

- 使用统一的日志格式
- 记录关键操作和错误
- 支持日志级别控制

### 4. 扩展性

- 遵循统一的命名规范
- 保持接口的一致性
- 支持向后兼容

## 🎯 总结

递归式部署架构是一个**配置驱动**的模块化部署方案，具有以下特点：

1. **模块化**: 每个组件独立管理
2. **可配置**: 通过配置文件控制行为
3. **递归性**: 支持多级嵌套部署
4. **容错性**: 子级失败不影响本级
5. **可扩展**: 易于添加新组件

这个架构特别适合：
- 复杂的微服务部署
- 多组件协同的系统
- 需要灵活配置的环境
- 企业级生产环境

通过遵循本文档的规范和最佳实践，可以构建出稳定、可维护、可扩展的部署系统。
