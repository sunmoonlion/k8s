# App Platform 统一部署脚本

## 概述

`deploy-app-platform-all` 用于统一部署 App Platform 下的所有应用组件，包括：
- **共享应用** (shared-apps): celeryworker, document-converter, onlyoffice-docs
- **业务应用** (business-apps): incubator, llmops

## 文件结构

```
deploy-app-platform-all/
├── deploy-app-platform-all.sh      # 主部署脚本
├── deploy-app-platform-all.conf    # 配置文件
├── 开发方案.md                      # 开发方案文档
└── README.md                        # 使用说明（本文件）
```

## 使用方法

### 1. 部署所有组件

```bash
# 使用默认配置部署
bash deploy-app-platform-all.sh deploy

# 指定项目ID、命名空间和环境
bash deploy-app-platform-all.sh deploy sunmoonai app-platform-dev development
```

### 2. 卸载所有组件

```bash
bash deploy-app-platform-all.sh uninstall
```

### 3. 使用集群配置

```bash
# 使用 C1 集群配置
bash deploy-app-platform-all.sh deploy --cluster C1

# 使用 C2 集群配置
bash deploy-app-platform-all.sh deploy --cluster C2
```

## 配置说明

### 组件启用/禁用

在 `deploy-app-platform-all.conf` 中控制：

```bash
# 启用/禁用组件
celeryworker_bff_enabled="true"
incubator_bff_enabled="false"  # 禁用该组件
```

### 部署优先级

数值越大越先部署：

```bash
# 共享应用优先（基础设施）
celeryworker_bff_priority=1000
document_converter_bff_priority=900
onlyoffice_docs_bff_priority=800

# 业务应用
incubator_bff_priority=700
incubator_ssr_priority=600
llmops_bff_priority=500
llmops_ssr_priority=400
```

### 集群配置映射

支持通过 `C1_*` 和 `C2_*` 前缀配置不同集群的设置：

```bash
# C1 集群配置
C1_celeryworker_bff_enabled="true"
C1_celeryworker_bff_priority=1000

# C2 集群配置
C2_celeryworker_bff_enabled="false"
C2_celeryworker_bff_priority=500
```

## 组件列表

### 共享应用 (shared-apps)

| 组件ID | 路径 | 默认优先级 |
|--------|------|-----------|
| `celeryworker_bff` | `shared-apps/celeryworker-app/celeryworker-bff/deploy-celeryworker-bff/deploy-multi-celeryworker.sh` | 1000 |
| `document_converter_bff` | `shared-apps/document-converter-app/document-converter-bff/deploy-document-converter-bff/deploy-document-converter.sh` | 900 |
| `onlyoffice_docs_bff` | `shared-apps/onlyoffice-docs-app/onlyoffice-docs-bff/deploy-onlyoffice-docs/deploy-onlyoffice-docs.sh` | 800 |

### 业务应用 (business-apps)

| 组件ID | 路径 | 默认优先级 |
|--------|------|-----------|
| `incubator_bff` | `business-apps/incubator-app/incubator-app-bff/deploy-incubator-bff/deploy-incubator-bff.sh` | 700 |
| `incubator_ssr` | `business-apps/incubator-app/incubator-app-ssr/deploy-incubator-ssr/deploy-incubator-ssr.sh` | 600 |
| `llmops_bff` | `business-apps/llmops-app/llmops-app-bff/deploy-llmops-bff/deploy-llmops-service.sh` | 500 |
| `llmops_ssr` | `business-apps/llmops-app/llmops-app-ssr/deploy-llmops-ssr/deploy-llmops-ssr.sh` | 400 |

## 设计特点

1. **硬编码路径映射**：确保路径准确性，避免误匹配
2. **统一管理**：所有最低层级组件统一在配置文件中管理
3. **优先级控制**：通过数值控制部署顺序
4. **集群支持**：支持多集群配置映射
5. **灵活配置**：支持启用/禁用每个组件

## 与 data-platform 的区别

| 特性 | data-platform | app-platform |
|------|---------------|--------------|
| 组件位置 | 同一层级 | 多个目录（shared-apps, business-apps） |
| 路径构建 | 简单（固定模式） | 复杂（需要路径映射） |
| 组件数量 | 较少（5-6个） | 较多（7+个） |
| 命名规范 | 直接使用组件名 | 使用 `{app_name}_{component_type}` |

## 添加新组件

1. 在 `deploy-app-platform-all.sh` 的 `COMPONENT_PATHS` 中添加路径映射
2. 在 `deploy-app-platform-all.conf` 中添加启用标志和优先级
3. 确保部署脚本路径正确

示例：

```bash
# 在 deploy-app-platform-all.sh 中添加
["new_app_bff"]="business-apps/new-app/new-app-bff/deploy-new-app-bff/deploy-new-app-bff.sh"

# 在 deploy-app-platform-all.conf 中添加
new_app_bff_enabled="true"
new_app_bff_priority=300
```

