# APP 组件开发文档

> 本文档以 `incubator-app-bff` 为例，说明 APP 组件的目录结构、配置管理、部署流程和开发指南。

## 一、设计原则

### 1.1 统一性原则
- **app 组件**：只有一个，不需要分类层，直接为 `app/deploy-app/`（两级结构）
- **其他组件**：可能有多个，统一使用三层结构 `{type}/{component-name}/deploy-{component-name}/`
- **目的**：即使某个类型只有一个组件，也保持统一的三层结构，确保整个组织结构的一致性

### 1.2 职责分离原则
- **生成（generate）**：负责生成 Kubernetes YAML 文件，配置在 `generate-*.conf` 中
- **部署（deploy）**：负责部署到 Kubernetes 集群，配置在 `deploy-*.conf` 中
- **关键**：生成脚本不读取部署配置，部署脚本不包含生成数据，完全分离

### 1.3 配置管理原则
- **所有默认值在 conf 文件中**：脚本中不设置硬编码默认值
- **用户明确知道配置位置**：所有配置都在 conf 文件中，便于查找和修改
- **配置优先级**：环境变量 > 主配置（deploy-*.conf）> generate-*.conf 默认值

### 1.4 动态发现原则
- 主部署脚本通过 `scan_and_deploy_components()` 函数自动扫描组件
- 无需手动维护组件列表
- 新增组件只需创建目录结构，无需修改主脚本

## 二、目录结构规范

### 2.1 顶层结构

```
incubator-app-bff/
├── deploy-incubator-bff/          # 部署相关脚本和配置
│   ├── app/                       # 主应用（两级结构）
│   ├── namespace/                 # Namespace 资源
│   ├── secret/                    # Secret 资源
│   ├── configMap/                 # ConfigMap 资源
│   ├── middleware/                # 中间件（如限流）
│   ├── ingress/                   # Ingress 路由
│   └── pvc/                       # 持久化存储
└── resources/                     # 资源模板和生成文件
    └── k8s-resource/
        ├── templates/             # YAML 模板文件
        └── custom-values/          # 生成脚本和配置
```

### 2.2 deploy-incubator-bff/ 下的组件分类

按 Kubernetes 资源类型分类：

```
deploy-incubator-bff/
├── app/                           # 主应用（单一组件，两级结构）
├── namespace/                     # Namespace 资源（多组件类型）
├── secret/                        # Secret 资源（多组件类型）
├── configMap/                     # ConfigMap 资源（多组件类型）
├── middleware/                    # 中间件（多组件类型）
├── ingress/                       # Ingress 路由（多组件类型）
└── pvc/                           # 持久化存储（多组件类型）
```

### 2.3 组件目录结构

#### 2.3.1 app 组件（单一组件，两级结构）

```
app/
└── deploy-app/
    ├── deploy-incubator-bff.sh      # 主部署脚本
    └── deploy-incubator-bff.conf    # 主配置文件（只包含部署控制参数）
```

**说明**：
- `app` 组件只有一个，不需要分类层
- 直接使用 `app/deploy-app/` 结构
- 脚本和配置文件使用应用名称：`deploy-incubator-bff.*`

#### 2.3.2 其他组件（多组件类型，三层结构）

```
{component-type}/
├── {component-name-1}/
│   └── deploy-{component-name-1}/
│       ├── deploy-{component-name-1}.sh
│       └── deploy-{component-name-1}.conf
└── {component-name-2}/
    └── deploy-{component-name-2}/
        ├── deploy-{component-name-2}.sh
        └── deploy-{component-name-2}.conf
```

**实际示例（incubator-app-bff）**：

```
namespace/
└── incubator-bff-namespace/
    └── deploy-incubator-bff-namespace/
        ├── deploy-incubator-bff-namespace.sh
        └── deploy-incubator-bff-namespace.conf

secret/
├── harbor-registry-secret/
│   └── deploy-harbor-registry-secret/
│       ├── deploy-harbor-registry-secret.sh
│       └── deploy-harbor-registry-secret.conf
└── incubator-bff-secret/
    └── deploy-incubator-bff-secret/
        ├── deploy-incubator-bff-secret.sh
        └── deploy-incubator-bff-secret.conf

configMap/
└── incubator-bff-config/
    └── deploy-incubator-bff-config/
        ├── deploy-incubator-bff-config.sh
        └── deploy-incubator-bff-config.conf

middleware/
└── incubator-bff-rate-limit/
    └── deploy-incubator-bff-rate-limit/
        ├── deploy-incubator-bff-rate-limit.sh
        └── deploy-incubator-bff-rate-limit.conf

ingress/
└── incubator-bff-ingress/
    └── deploy-ingress/
        └── deploy-ingress.sh

pvc/
└── incubator-bff-pvc/
    └── deploy-incubator-bff-pvc/
        └── deploy-incubator-bff-pvc.conf
```

**说明**：
- 即使某个类型只有一个组件，也保持三层结构
- 例如：`configMap/incubator-bff-config/deploy-incubator-bff-config/`
- 这样整个组织结构统一，便于扩展

## 三、命名规范

### 3.1 组件目录命名

- **去掉 "-app" 后缀**：`incubator-app-bff-secret` → `incubator-bff-secret`
- **使用小写字母和连字符**：`harbor-registry-secret`
- **语义清晰**：名称应能清楚表达组件的用途

### 3.2 部署目录命名

- **格式**：`deploy-{component-name}`
- **示例**：
  - `deploy-incubator-bff-namespace`
  - `deploy-harbor-registry-secret`
  - `deploy-incubator-bff-secret`
  - `deploy-incubator-bff-config`
  - `deploy-incubator-bff-rate-limit`

### 3.3 脚本和配置文件命名

- **部署脚本**：`deploy-{component-name}.sh`
- **部署配置**：`deploy-{component-name}.conf`
- **生成脚本**：`generate-{component-name}.sh`
- **生成配置**：`generate-{component-name}.conf`

## 四、配置管理策略

### 4.1 职责分离原则

#### 4.1.1 部署配置（deploy-*.conf）

**职责**：只包含部署控制参数，不包含用于生成 YAML 的数据内容

**位置**：`deploy-incubator-bff/{type}/{component-name}/deploy-{component-name}/deploy-{component-name}.conf`

**内容**：
- 基础配置（默认值，可通过命令行参数覆盖）
  - `PROJECT_ID`、`NAMESPACE`、`ENVIRONMENT`
- 组件部署控制（用于主脚本动态扫描）
  - `{component}_enabled`：控制是否部署此组件
  - `{component}_priority`：部署优先级（数值越大越先部署）
  - `{component}_description`：组件描述（用于日志输出）

**示例（deploy-incubator-bff-config.conf）**：
```bash
# ============================================================================
# Incubator App BFF ConfigMap 部署配置
# 职责：只包含部署控制参数，不包含用于生成 YAML 的数据内容
# 注意：ConfigMap 的数据内容在 generate-incubator-bff-config.conf 中
# ============================================================================

# 基础配置（默认值，可通过主配置或命令行参数覆盖）
PROJECT_ID="${PROJECT_ID:-sunmoonai}"
NAMESPACE="${NAMESPACE:-app-platform-dev}"
ENVIRONMENT="${ENVIRONMENT:-development}"

# 组件部署控制（用于主脚本动态扫描）
incubator_bff_config_enabled="${incubator_bff_config_enabled:-true}"
incubator_bff_config_priority="${incubator_bff_config_priority:-500}"
incubator_bff_config_description="${incubator_bff_config_description:-Incubator App BFF ConfigMap}"
```

#### 4.1.2 生成配置（generate-*.conf）

**职责**：配置 YAML 生成相关的参数和数据内容

**位置**：`resources/k8s-resource/custom-values/{type}/{component-name}/generate-{component-name}/generate-{component-name}.conf`

**内容**：
- 生成参数
  - `TEMPLATE_FILE`：模板文件路径
  - `OUTPUT_FILE`：输出文件名
  - `ENABLED`：是否启用生成
  - `RESOURCE_TYPE`：资源类型
- 基础配置（用于生成 YAML）
  - `NAMESPACE`、`ENVIRONMENT`、`ENV`
- 资源数据内容（用于生成 YAML）
  - 所有用于填充 YAML 模板的数据

**示例（generate-incubator-bff-config.conf）**：
```bash
# ============================================================================
# Incubator App BFF ConfigMap YAML 生成配置
# 职责：配置 YAML 生成相关的参数和数据内容
# ============================================================================

# 模板文件路径（相对于 resources/k8s-resource/）
TEMPLATE_FILE="../../templates/configmap/incubator-app-bff-config.yaml"

# 输出文件名（生成在当前目录）
OUTPUT_FILE="incubator-app-bff-config-generated.yaml"

# 是否启用生成
ENABLED="true"

# 资源类型
RESOURCE_TYPE="configmap"

# 基础配置（用于生成 YAML）
# 注意：这些配置的优先级（从高到低）：
#   1. 环境变量（如果已设置）
#   2. 主应用的 deploy-incubator-bff.conf（如果存在，由生成脚本自动读取）
#   3. 本文件中的默认值（作为后备）
NAMESPACE="${NAMESPACE:-app-platform-dev}"
ENVIRONMENT="${ENVIRONMENT:-development}"
ENV="${ENV:-dev}"

# ConfigMap 数据内容（用于生成 YAML）
PROJECT_NAME="${PROJECT_NAME:-Incubator App BFF}"
SERVER_NAME="${SERVER_NAME:-incubator.sunmoonai.com}"
# ... 其他数据内容
```

#### 4.1.3 主配置（app/deploy-app/deploy-incubator-bff.conf）

**职责**：控制整个应用的部署流程

**内容**：
- 基础配置（默认值，可通过命令行参数覆盖）
  - `INCUBATOR_BFF_PROJECT_ID`、`INCUBATOR_BFF_NAMESPACE`、`ENVIRONMENT`
- 组件开关（控制是否部署整个类型）
  - `namespace_enabled`、`secrets_enabled`、`configmap_enabled`、`middleware_enabled`、`ingress_enabled`
- 部署优先级控制（数值越大越先部署）
  - `namespace_priority=3000`（最高）
  - `secrets_priority=2000`
  - `configmap_priority=1900`
  - `middleware_priority=1000`
  - `ingress_priority=100`（最低）

**示例**：
```bash
# ============================================================================
# Incubator App BFF 部署配置
# 职责：只包含部署控制参数，不包含用于生成 YAML 的数据内容
# 注意：用于生成 YAML 的数据内容在 generate-app.conf 中
# ============================================================================

# 基础配置（默认值，可通过命令行参数覆盖）
INCUBATOR_BFF_PROJECT_ID="${INCUBATOR_BFF_PROJECT_ID:-sunmoonai}"
INCUBATOR_BFF_NAMESPACE="${INCUBATOR_BFF_NAMESPACE:-app-platform-dev}"
ENVIRONMENT="${ENVIRONMENT:-development}"

# 组件开关（控制是否部署）
namespace_enabled="true"      # Namespace（应在所有资源之前创建）
secrets_enabled="true"        # Secrets（已与 ConfigMaps 分离）
configmap_enabled="true"      # ConfigMaps（已与 Secrets 分离）
middleware_enabled="false"    # Middleware（限流中间件）
ingress_enabled="true"        # Ingress（HTTP 路由）

# 部署优先级控制（数值越大越先部署）
namespace_priority=3000       # Namespace 优先级（最高）
secrets_priority=2000         # Secrets 优先级
configmap_priority=1900       # ConfigMaps 优先级
middleware_priority=1000      # Middleware 优先级
ingress_priority=100          # Ingress 优先级（最低）
```

### 4.2 配置优先级

#### 4.2.1 生成脚本配置优先级

生成脚本的配置优先级（从高到低）：
1. **环境变量**（如果已设置）
2. **主应用的 deploy-incubator-bff.conf**（如果存在，由生成脚本自动读取）
3. **generate-*.conf 中的默认值**（作为后备）

**工作流程**：
1. 生成脚本先尝试读取主应用的 `deploy-incubator-bff.conf`（如果存在）
2. 从主配置获取基础配置的默认值（`NAMESPACE`、`ENVIRONMENT`）
3. 如果读取不到，或变量不存在，则使用 `generate-*.conf` 中的默认值

#### 4.2.2 部署脚本配置优先级

部署脚本的配置优先级（从高到低）：
1. **命令行参数**
2. **deploy-*.conf 中的配置**
3. **空值**（由调用者确保提供）

### 4.3 配置分离的优势

- **职责清晰**：生成和部署完全独立，互不干扰
- **易于维护**：所有配置都在 conf 文件中，用户明确知道配置位置
- **灵活性**：生成脚本可以独立运行（使用默认值），也可以从主配置继承
- **一致性**：通过主配置统一管理基础配置，避免重复维护

## 五、resources/k8s-resource/ 目录结构

### 5.1 目录结构

```
resources/
└── k8s-resource/                  # Kubernetes 部署资源
    ├── templates/                 # YAML 模板文件（按资源类型分类）
    │   ├── app/
    │   │   └── incubator-app-bff.yaml
    │   ├── namespace/
    │   │   └── incubator-app-bff-namespace.yaml
    │   ├── secret/
    │   │   ├── harbor-registry-secret.yaml
    │   │   └── incubator-app-bff-secret.yaml
    │   ├── configmap/
    │   │   └── incubator-app-bff-config.yaml
    │   ├── middleware/
    │   │   └── incubator-app-bff-rate-limit.yaml
    │   ├── ingress/
    │   │   └── ingress.yaml
    │   └── pvc/
    │       └── incubator-app-bff-pvc.yaml
    └── custom-values/             # 生成脚本和配置（与 deploy-* 目录结构对应）
        ├── app/
        │   └── generate-app/
        │       ├── generate-app.conf
        │       ├── generate-app.sh
        │       └── incubator-app-bff-generated.yaml  # 生成的 YAML
        ├── namespace/
        │   └── incubator-bff-namespace/
        │       └── generate-incubator-bff-namespace/
        │           ├── generate-incubator-bff-namespace.conf
        │           ├── generate-incubator-bff-namespace.sh
        │           └── incubator-app-bff-namespace-generated.yaml
        ├── secret/
        │   ├── harbor-registry-secret/
        │   │   └── generate-harbor-registry-secret/
        │   │       ├── generate-harbor-registry-secret.conf
        │   │       ├── generate-harbor-registry-secret.sh
        │   │       └── harbor-registry-secret-generated.yaml
        │   └── incubator-bff-secret/
        │       └── generate-incubator-bff-secret/
        │           ├── generate-incubator-bff-secret.conf
        │           ├── generate-incubator-bff-secret.sh
        │           └── incubator-app-bff-secret-generated.yaml
        ├── configMap/
        │   └── incubator-bff-config/
        │       └── generate-incubator-bff-config/
        │           ├── generate-incubator-bff-config.conf
        │           ├── generate-incubator-bff-config.sh
        │           └── incubator-app-bff-config-generated.yaml
        ├── middleware/
        │   └── incubator-bff-rate-limit/
        │       └── generate-incubator-bff-rate-limit/
        │           ├── generate-incubator-bff-rate-limit.conf
        │           ├── generate-incubator-bff-rate-limit.sh
        │           └── incubator-app-bff-rate-limit-generated.yaml
        ├── ingress/
        │   └── incubator-bff-ingress/
        │       └── generate-ingress/
        │           ├── generate-ingress.conf
        │           ├── generate-ingress.sh
        │           └── incubator-app-bff-ingress-generated.yaml
        └── pvc/
            └── incubator-bff-pvc/
                └── generate-incubator-bff-pvc/
                    ├── generate-incubator-bff-pvc.conf
                    ├── generate-incubator-bff-pvc.sh
                    └── incubator-app-bff-pvc-generated.yaml
```

### 5.2 与部署脚本目录的对应关系

**重要设计原则**：`resources/k8s-resource/` 下的目录结构与 `deploy-incubator-bff/` 下的组件分类一一对应。

```
deploy-incubator-bff/              resources/k8s-resource/
├── app/                          ├── templates/app/              ← 对应
│   └── deploy-app/               └── custom-values/app/          ← 对应
├── namespace/                    ├── templates/namespace/         ← 对应
│   └── ...                       └── custom-values/namespace/    ← 对应
├── secret/                       ├── templates/secret/            ← 对应
│   └── ...                       └── custom-values/secret/        ← 对应
├── configMap/                    ├── templates/configmap/         ← 对应
│   └── ...                       └── custom-values/configMap/    ← 对应
├── middleware/                   ├── templates/middleware/       ← 对应
│   └── ...                       └── custom-values/middleware/   ← 对应
├── ingress/                      ├── templates/ingress/           ← 对应
│   └── ...                       └── custom-values/ingress/       ← 对应
└── pvc/                          ├── templates/pvc/              ← 对应
    └── ...                       └── custom-values/pvc/           ← 对应
```

**设计原理**：
1. **模板目录（templates/）**：存放 YAML 模板文件，包含变量占位符（如 `${NAMESPACE}`, `${IMAGE_NAME}`）
2. **生成目录（custom-values/）**：存放生成脚本和配置，用于从模板生成最终的 YAML 文件
3. **部署脚本目录（deploy-incubator-bff/）**：存放部署脚本，用于执行 `kubectl apply/delete` 操作
4. **对应关系**：每个资源类型在模板目录、生成目录和部署脚本目录中都有对应目录，便于管理和理解

### 5.3 工作流程

```
源码构建镜像
  ↓
镜像信息（名称、标签、仓库等）
  ↓
填充 templates/ 中的 YAML 模板（通过 generate-*.sh）
  ↓
生成最终的 YAML 文件（*-generated.yaml，在各组件的 generate-* 目录下）
  ↓
部署脚本读取生成的 YAML
  ↓
执行 kubectl apply/delete
```

**关键点**：
- 通过 app 源码构建的镜像信息来填充 YAML 模板中的变量
- 生成的 YAML 文件被部署脚本使用
- 模板、生成脚本和部署脚本的目录结构一一对应，确保结构清晰、易于维护

## 六、动态发现机制

### 6.1 scan_and_deploy_components() 函数

主部署脚本通过 `scan_and_deploy_components()` 函数自动发现和部署组件：

```bash
scan_and_deploy_components() {
    local component_type="$1"  # secret, configMap, middleware, namespace 等
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    local base_dir="$PROJECT_ROOT/$component_type"
    
    # 扫描所有子目录
    for subdir in "$base_dir"/*/; do
        local dirname=$(basename "$subdir")
        
        # 跳过 deploy-*-all 目录（已废弃）
        [[ "$dirname" =~ ^deploy-.*-all$ ]] && continue
        
        # 查找 deploy-* 目录
        local deploy_dir="$subdir/deploy-${dirname}"
        local script_file="$deploy_dir/deploy-${dirname}.sh"
        local conf_file="$deploy_dir/deploy-${dirname}.conf"
        
        # 读取组件配置（优先级、启用状态等）
        # 按优先级排序并部署
    done
}
```

### 6.2 变量名转换规则

从目录名转换为配置变量名：

```bash
# 目录名：incubator-bff-secret
# 转换：将 - 替换为 _
var_base=$(echo "$dirname" | tr '-' '_')
# 结果：incubator_bff_secret

# 特殊处理：incubator-app-bff-* -> incubator_bff_*
var_base=$(echo "$var_base" | sed 's/^incubator_app_bff_/incubator_bff_/')

# 变量名：
enabled_var="${var_base}_enabled"      # incubator_bff_secret_enabled
priority_var="${var_base}_priority"    # incubator_bff_secret_priority
description_var="${var_base}_description"  # incubator_bff_secret_description
```

### 6.3 部署顺序

主部署脚本按以下顺序部署组件：

1. **Namespace** (优先级 3000) - 最高优先级，最先部署
2. **Secrets** (优先级 2000)
3. **ConfigMaps** (优先级 1900)
4. **Middleware** (优先级 1000)
5. **Ingress** (优先级 100) - 最低优先级
6. **App** (主应用，最后部署)

## 七、完整示例（incubator-app-bff）

### 7.1 目录结构示例

```
incubator-app-bff/
├── deploy-incubator-bff/
│   ├── app/
│   │   └── deploy-app/
│   │       ├── deploy-incubator-bff.sh
│   │       └── deploy-incubator-bff.conf
│   ├── namespace/
│   │   └── incubator-bff-namespace/
│   │       └── deploy-incubator-bff-namespace/
│   │           ├── deploy-incubator-bff-namespace.sh
│   │           └── deploy-incubator-bff-namespace.conf
│   ├── secret/
│   │   ├── harbor-registry-secret/
│   │   │   └── deploy-harbor-registry-secret/
│   │   │       ├── deploy-harbor-registry-secret.sh
│   │   │       └── deploy-harbor-registry-secret.conf
│   │   └── incubator-bff-secret/
│   │       └── deploy-incubator-bff-secret/
│   │           ├── deploy-incubator-bff-secret.sh
│   │           └── deploy-incubator-bff-secret.conf
│   ├── configMap/
│   │   └── incubator-bff-config/
│   │       └── deploy-incubator-bff-config/
│   │           ├── deploy-incubator-bff-config.sh
│   │           └── deploy-incubator-bff-config.conf
│   ├── middleware/
│   │   └── incubator-bff-rate-limit/
│   │       └── deploy-incubator-bff-rate-limit/
│   │           ├── deploy-incubator-bff-rate-limit.sh
│   │           └── deploy-incubator-bff-rate-limit.conf
│   ├── ingress/
│   │   └── incubator-bff-ingress/
│   │       └── deploy-ingress/
│   │           └── deploy-ingress.sh
│   └── pvc/
│       └── incubator-bff-pvc/
│           └── deploy-incubator-bff-pvc/
│               └── deploy-incubator-bff-pvc.conf
└── resources/
    └── k8s-resource/
        ├── templates/             # YAML 模板文件
        │   ├── app/
        │   ├── namespace/
        │   ├── secret/
        │   ├── configmap/
        │   ├── middleware/
        │   ├── ingress/
        │   └── pvc/
        └── custom-values/          # 生成脚本和配置
            ├── app/
            │   └── generate-app/
            │       ├── generate-app.conf
            │       ├── generate-app.sh
            │       └── incubator-app-bff-generated.yaml
            ├── namespace/
            │   └── incubator-bff-namespace/
            │       └── generate-incubator-bff-namespace/
            │           ├── generate-incubator-bff-namespace.conf
            │           ├── generate-incubator-bff-namespace.sh
            │           └── incubator-app-bff-namespace-generated.yaml
            ├── secret/
            │   ├── harbor-registry-secret/
            │   │   └── generate-harbor-registry-secret/
            │   │       ├── generate-harbor-registry-secret.conf
            │   │       ├── generate-harbor-registry-secret.sh
            │   │       └── harbor-registry-secret-generated.yaml
            │   └── incubator-bff-secret/
            │       └── generate-incubator-bff-secret/
            │           ├── generate-incubator-bff-secret.conf
            │           ├── generate-incubator-bff-secret.sh
            │           └── incubator-app-bff-secret-generated.yaml
            ├── configMap/
            │   └── incubator-bff-config/
            │       └── generate-incubator-bff-config/
            │           ├── generate-incubator-bff-config.conf
            │           ├── generate-incubator-bff-config.sh
            │           └── incubator-app-bff-config-generated.yaml
            ├── middleware/
            │   └── incubator-bff-rate-limit/
            │       └── generate-incubator-bff-rate-limit/
            │           ├── generate-incubator-bff-rate-limit.conf
            │           ├── generate-incubator-bff-rate-limit.sh
            │           └── incubator-app-bff-rate-limit-generated.yaml
            ├── ingress/
            │   └── incubator-bff-ingress/
            │       └── generate-ingress/
            │           ├── generate-ingress.conf
            │           ├── generate-ingress.sh
            │           └── incubator-app-bff-ingress-generated.yaml
            └── pvc/
                └── incubator-bff-pvc/
                    └── generate-incubator-bff-pvc/
                        ├── generate-incubator-bff-pvc.conf
                        ├── generate-incubator-bff-pvc.sh
                        └── incubator-app-bff-pvc-generated.yaml
```

### 7.2 部署流程

1. **主脚本启动**：`app/deploy-app/deploy-incubator-bff.sh`
2. **加载主配置**：`deploy-incubator-bff.conf`
3. **动态扫描组件**：
   - 扫描 `namespace/` 目录下的所有组件（优先级 3000）
   - 扫描 `secret/` 目录下的所有组件（优先级 2000）
   - 扫描 `configMap/` 目录下的所有组件（优先级 1900）
   - 扫描 `middleware/` 目录下的所有组件（优先级 1000）
   - 扫描 `ingress/` 目录下的所有组件（优先级 100）
4. **读取组件配置**：从每个组件的 `deploy-*.conf` 读取优先级和启用状态
5. **按优先级排序**：数值越大优先级越高
6. **逐个部署**：总开关 && 组件开关 = 最终是否部署
7. **部署主应用**：最后部署主应用（Deployment 和 Service）

### 7.3 生成流程

1. **部署脚本调用生成脚本**：在部署前自动调用 `generate-*.sh`
2. **生成脚本读取配置**：
   - 先尝试读取主应用的 `deploy-incubator-bff.conf`（如果存在）
   - 然后读取 `generate-*.conf` 获取所有数据内容
3. **导出环境变量**：供 `envsubst` 使用
4. **处理模板**：使用 `envsubst` 替换模板中的变量
5. **生成 YAML**：输出到 `generate-*` 目录下的 `*-generated.yaml`

## 八、配置管理最佳实践

### 8.1 默认值管理

- **所有默认值都在 conf 文件中**：脚本中不设置硬编码默认值
- **用户明确知道配置位置**：所有配置都在 conf 文件中，便于查找和修改
- **配置优先级明确**：环境变量 > 主配置 > generate-*.conf 默认值

### 8.2 配置分离

- **生成配置（generate-*.conf）**：包含所有用于生成 YAML 的数据内容
- **部署配置（deploy-*.conf）**：只包含部署控制参数（enabled、priority、description）
- **主配置（deploy-incubator-bff.conf）**：控制整个应用的部署流程

### 8.3 配置继承

- **生成脚本可选读取主配置**：作为基础配置的默认值源
- **保持独立性**：如果主配置不存在，使用 generate-*.conf 中的默认值
- **灵活性**：生成脚本可以独立运行，也可以从主配置继承

## 九、设计优势

### 9.1 统一性
- 所有组件类型（除 app 外）都使用统一的三层结构
- 即使只有一个组件，也保持结构一致
- 便于理解和维护

### 9.2 职责分离
- 生成和部署完全独立，互不干扰
- 配置分离，职责清晰
- 易于维护和扩展

### 9.3 可扩展性
- 新增组件只需创建目录结构，无需修改主脚本
- 动态发现机制自动识别新组件
- 配置分散在各组件中，互不干扰

### 9.4 可维护性
- 目录结构清晰，一目了然
- 命名规范统一，便于查找
- 所有配置都在 conf 文件中，用户明确知道配置位置
- 路径管理集中，易于修改

### 9.5 灵活性
- 生成脚本可以独立运行（使用默认值）
- 也可以从主配置继承（保证一致性）
- 部署脚本可以通过命令行参数覆盖配置

## 十、开发流程

### 10.1 统一的开发流程

所有 APP 平台组件遵循统一的开发流程：

1. **源代码开发**（在源代码项目中）
   - 开发应用代码（如 `app.py`、`requirements.txt`）
   - 编写 Dockerfile
   - 源代码和 Dockerfile 在源代码项目中管理

2. **构建镜像**（在源代码项目中）
   - 使用源代码项目中的 Dockerfile 构建 Docker 镜像
   - 推送到镜像仓库（如 Harbor）
   - **注意**：镜像构建不在 k8s 配置目录中执行

3. **创建 Kubernetes 模板**（`resources/k8s-resource/templates/`）
   - 创建主应用模板（Deployment、Service）：`templates/app/应用名.yaml`
   - 创建 ConfigMap 模板：`templates/configmap/资源名.yaml`
   - 创建 Secret 模板：`templates/secret/资源名.yaml`
   - 创建 Ingress 模板：`templates/ingress/ingress.yaml`
   - 创建 Middleware 模板：`templates/middleware/资源名.yaml`
   - 创建 Namespace 模板：`templates/namespace/应用名-namespace.yaml`
   - 创建 PVC 模板：`templates/pvc/应用名-pvc.yaml`
   - 模板文件使用占位符（如 `${VAR}`、`${VAR:-default}`）

4. **配置 YAML 生成**（`resources/k8s-resource/custom-values/`）
   - 为每个组件创建 `generate-{component-name}/` 目录
   - 配置 `generate-{component-name}.conf`：定义模板路径、输出文件名和数据内容
   - 创建 `generate-{component-name}.sh`：生成脚本

5. **部署**（`deploy-incubator-bff/`）
   - 使用部署脚本应用生成的 YAML 文件
   - 部署脚本会自动检查并生成 YAML（如果缺失）
   - **重要**：所有组件（包括 Secrets、ConfigMaps、Ingress、Middleware、Namespace 等）都统一使用 `resources/k8s-resource/custom-values/` 下的生成 YAML

### 10.2 完整开发流程示例（incubator-app-bff）

#### 步骤 1：准备源代码

源代码在源代码项目中开发，镜像构建也在源代码项目中执行：

```bash
# 在源代码项目中
cd /path/to/source-project
# 开发应用代码
# 编写 Dockerfile
# 构建镜像
./build/build-image.sh build-push
```

#### 步骤 2：创建 Kubernetes 模板

在 k8s 配置目录中创建模板文件：

```bash
cd k8s/sunmoonai/incubator-app/incubator-app-bff

# 创建主应用模板
mkdir -p resources/k8s-resource/templates/app
# 编辑 resources/k8s-resource/templates/app/incubator-app-bff.yaml

# 创建其他资源模板
mkdir -p resources/k8s-resource/templates/{namespace,secret,configmap,middleware,ingress,pvc}
# 编辑相应的模板文件
```

#### 步骤 3：配置生成脚本

为每个组件创建生成配置和脚本：

```bash
# 创建生成目录结构
mkdir -p resources/k8s-resource/custom-values/app/generate-app
mkdir -p resources/k8s-resource/custom-values/namespace/incubator-bff-namespace/generate-incubator-bff-namespace
# ... 其他组件

# 创建生成配置
# 编辑 resources/k8s-resource/custom-values/app/generate-app/generate-app.conf
# 编辑 resources/k8s-resource/custom-values/namespace/incubator-bff-namespace/generate-incubator-bff-namespace/generate-incubator-bff-namespace.conf
# ... 其他组件

# 创建生成脚本
# 编辑 resources/k8s-resource/custom-values/app/generate-app/generate-app.sh
# ... 其他组件
```

#### 步骤 4：配置部署脚本

创建部署配置和脚本：

```bash
# 创建部署目录结构
mkdir -p deploy-incubator-bff/app/deploy-app
mkdir -p deploy-incubator-bff/namespace/incubator-bff-namespace/deploy-incubator-bff-namespace
# ... 其他组件

# 创建部署配置
# 编辑 deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.conf
# 编辑 deploy-incubator-bff/namespace/incubator-bff-namespace/deploy-incubator-bff-namespace/deploy-incubator-bff-namespace.conf
# ... 其他组件

# 创建部署脚本
# 编辑 deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh
# ... 其他组件
```

#### 步骤 5：生成 YAML 文件（可选，部署时会自动生成）

```bash
# 单独运行生成脚本
cd resources/k8s-resource/custom-values/app/generate-app
./generate-app.sh

# 或者部署时会自动生成
```

#### 步骤 6：部署服务

```bash
cd deploy-incubator-bff/app/deploy-app
./deploy-incubator-bff.sh deploy sunmoonai app-platform-dev development
```

### 10.3 常用操作

#### 查看状态

```bash
cd deploy-incubator-bff/app/deploy-app
./deploy-incubator-bff.sh status sunmoonai app-platform-dev development
```

#### 卸载服务

```bash
cd deploy-incubator-bff/app/deploy-app
./deploy-incubator-bff.sh uninstall sunmoonai app-platform-dev development
```

**注意**：卸载时 Namespace 不会自动卸载（需要手动执行，安全考虑）。

#### 更新代码并重新部署

```bash
# 1. 在源代码项目中更新代码并重新构建镜像
cd /path/to/source-project
./build/build-image.sh build-push

# 2. 更新模板文件（如果需要）
# 编辑 resources/k8s-resource/templates/ 下的模板文件

# 3. 重新生成 YAML（可选，部署时会自动生成）
cd resources/k8s-resource/custom-values/app/generate-app
./generate-app.sh

# 4. 重新部署
cd deploy-incubator-bff/app/deploy-app
./deploy-incubator-bff.sh deploy sunmoonai app-platform-dev development
```

### 10.4 配置修改指南

#### 修改镜像版本

编辑生成配置 `resources/k8s-resource/custom-values/app/generate-app/generate-app.conf`：

```bash
INCUBATOR_BFF_TAG="${INCUBATOR_BFF_TAG:-1.0.1}"
```

#### 修改 Harbor 配置

编辑生成配置 `resources/k8s-resource/custom-values/app/generate-app/generate-app.conf`：

```bash
INCUBATOR_BFF_IMAGE_REGISTRY="${INCUBATOR_BFF_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
INCUBATOR_BFF_IMAGE_PROJECT="${INCUBATOR_BFF_IMAGE_PROJECT:-k8s-images}"
```

#### 修改 Ingress 配置

编辑生成配置 `resources/k8s-resource/custom-values/ingress/incubator-bff-ingress/generate-ingress/generate-ingress.conf`：

```bash
UNIFIED_HOST="${UNIFIED_HOST:-incubator.sunmoonai.com}"
NODE_IP="${NODE_IP:-101.126.151.0}"
USE_STRIP_PREFIX="${USE_STRIP_PREFIX:-false}"  # 是否使用 stripprefix
USE_RATE_LIMIT="${USE_RATE_LIMIT:-true}"        # 是否使用限流中间件
```

#### 修改限流配置

编辑生成配置 `resources/k8s-resource/custom-values/middleware/incubator-bff-rate-limit/generate-incubator-bff-rate-limit/generate-incubator-bff-rate-limit.conf`：

```bash
RATE_LIMIT_AVERAGE="${RATE_LIMIT_AVERAGE:-100}"   # 平均每秒请求数
RATE_LIMIT_BURST="${RATE_LIMIT_BURST:-200}"       # 突发允许请求数
RATE_LIMIT_PERIOD="${RATE_LIMIT_PERIOD:-1}"       # 时间窗口（秒）
```

#### 修改模板文件

编辑 `resources/k8s-resource/templates/` 下的模板文件，然后重新生成 YAML：

```bash
# 修改模板文件
vim resources/k8s-resource/templates/app/incubator-app-bff.yaml

# 重新生成 YAML（可选，部署时会自动生成）
cd resources/k8s-resource/custom-values/app/generate-app
./generate-app.sh
```

**重要**：所有模板文件（包括 Secrets、ConfigMaps、Ingress、Middleware、Namespace、PVC 等）都统一在 `resources/k8s-resource/templates/` 目录下。

### 10.5 故障排查

#### 镜像拉取失败

- 检查 Harbor 配置是否正确（在 `generate-app.conf` 中）
- 确认已登录 Harbor：`docker login harbor.sunmoonai.com:30443`
- 检查镜像是否已推送到 Harbor
- 检查网络连接

#### Pod 无法启动

- 检查镜像是否已推送到 Harbor
- 检查生成的 YAML 文件是否存在：`ls resources/k8s-resource/custom-values/*/generate-*/*-generated.yaml`
- 检查 Secrets 和 ConfigMaps 是否已部署
- 查看 Pod 日志：`kubectl logs -n app-platform-dev -l app=incubator-app-bff`

#### YAML 生成失败

- 检查模板文件中的占位符是否正确
- 检查 `generate-*.conf` 中是否设置了相应的变量
- 检查 `generate-*.sh` 中是否导出了环境变量
- 查看生成脚本的错误输出
- 使用 `kubectl apply --dry-run=client` 验证生成的 YAML

#### Ingress 无法访问

- 检查 Ingress 是否已部署：`kubectl get ingressroute -n app-platform-dev`
- 检查 Traefik 是否正常运行
- 检查域名解析和防火墙规则
- 检查 Middleware 配置（如果使用限流中间件）

#### 命名空间不存在

- 如果启用了 `namespace_enabled`，Namespace 会在部署时自动创建
- 如果未启用，需要手动创建：`kubectl create namespace app-platform-dev`
- 检查部署脚本是否正确执行了 Namespace 创建

## 十一、总结

本设计通过统一的三层结构（除 app 外），实现了：

- **结构统一**：所有组件类型使用相同的目录结构模式
- **职责分离**：生成和部署完全独立，配置分离
- **自动发现**：主脚本自动扫描和部署所有组件
- **配置灵活**：混合配置方案，既有集中管理，又有细粒度控制
- **易于扩展**：新增组件只需创建目录结构，无需修改主脚本
- **便于维护**：清晰的目录结构和命名规范，便于理解和维护
- **用户友好**：所有配置都在 conf 文件中，用户明确知道配置位置

### 新架构优势

- **职责清晰**：模板文件只负责定义资源结构，生成脚本负责变量替换，部署脚本只负责部署
- **易于维护**：所有模板文件统一位置，便于查找和管理
- **自动化**：部署脚本自动检查并生成 YAML（如果缺失），无需手动操作
- **可扩展**：通过创建新的 `generate-*` 目录轻松添加新的资源类型
- **统一架构**：所有组件（主应用、Secrets、ConfigMaps、Ingress、Middleware、Namespace、PVC）都使用同一套 YAML 生成机制
- **配置分离**：生成配置和部署配置完全分离，职责清晰

这种设计确保了整个应用组件结构的一致性、可扩展性和可维护性。
