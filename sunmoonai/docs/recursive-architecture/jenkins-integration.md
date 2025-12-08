# Jenkins 集成部署方案

## 📋 概述

递归式部署架构与 Jenkins 的完美结合，提供了灵活、可配置的 CI/CD 解决方案。

## 🎯 集成优势

### 1. 配置驱动部署
- 通过 Jenkins 参数控制组件启用/禁用
- 支持环境差异化部署
- 便于 A/B 测试和灰度发布

### 2. 模块化部署
- 每个组件独立部署
- 支持并行部署
- 便于故障隔离和回滚

### 3. 可观测性
- 详细的部署日志
- 组件级别的部署状态
- 便于问题定位和调试

## 🔧 Jenkins Pipeline 配置

### 基础 Pipeline

```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'testing', 'production'],
            description: '部署环境'
        )
        booleanParam(
            name: 'MIDDLEWARE_ENABLED',
            defaultValue: true,
            description: '是否部署中间件'
        )
        booleanParam(
            name: 'INGRESS_ENABLED',
            defaultValue: true,
            description: '是否部署 Ingress'
        )
        booleanParam(
            name: 'SECRETS_ENABLED',
            defaultValue: false,
            description: '是否部署密钥管理'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: false,
            description: '是否干运行'
        )
    }
    
    environment {
        PROJECT_ID = 'sunmoonai'
        NAMESPACE = "cicd-platform-${params.ENVIRONMENT}"
        HARBOR_CONFIG = 'deploy-harbor-all.conf'
    }
    
    stages {
        stage('准备环境') {
            steps {
                script {
                    echo "准备部署环境: ${params.ENVIRONMENT}"
                    echo "项目ID: ${env.PROJECT_ID}"
                    echo "命名空间: ${env.NAMESPACE}"
                }
            }
        }
        
        stage('配置更新') {
            steps {
                script {
                    // 更新配置文件
                    sh """
                        sed -i 's/ENVIRONMENT=.*/ENVIRONMENT="${params.ENVIRONMENT}"/' ${env.HARBOR_CONFIG}
                        sed -i 's/middleware_enabled=.*/middleware_enabled="${params.MIDDLEWARE_ENABLED}"/' ${env.HARBOR_CONFIG}
                        sed -i 's/ingress_enabled=.*/ingress_enabled="${params.INGRESS_ENABLED}"/' ${env.HARBOR_CONFIG}
                        sed -i 's/secrets_enabled=.*/secrets_enabled="${params.SECRETS_ENABLED}"/' ${env.HARBOR_CONFIG}
                    """
                }
            }
        }
        
        stage('部署 Harbor') {
            steps {
                script {
                    sh """
                        ./deploy-harbor-all.sh deploy ${env.PROJECT_ID} ${env.NAMESPACE} ${params.ENVIRONMENT} ${params.DRY_RUN}
                    """
                }
            }
        }
        
        stage('验证部署') {
            steps {
                script {
                    sh """
                        kubectl get pods -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}
                        kubectl get svc -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}
                    """
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "部署完成，清理临时文件"
            }
        }
        success {
            script {
                echo "✅ 部署成功"
                // 发送成功通知
            }
        }
        failure {
            script {
                echo "❌ 部署失败"
                // 发送失败通知
            }
        }
    }
}
```

### 高级 Pipeline（支持并行部署）

```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'testing', 'production'],
            description: '部署环境'
        )
        booleanParam(
            name: 'MIDDLEWARE_ENABLED',
            defaultValue: true,
            description: '是否部署中间件'
        )
        booleanParam(
            name: 'INGRESS_ENABLED',
            defaultValue: true,
            description: '是否部署 Ingress'
        )
        booleanParam(
            name: 'SECRETS_ENABLED',
            defaultValue: false,
            description: '是否部署密钥管理'
        )
    }
    
    environment {
        PROJECT_ID = 'sunmoonai'
        NAMESPACE = "cicd-platform-${params.ENVIRONMENT}"
    }
    
    stages {
        stage('部署 Harbor 核心') {
            steps {
                script {
                    sh """
                        ./deploy-harbor-all.sh deploy ${env.PROJECT_ID} ${env.NAMESPACE} ${params.ENVIRONMENT} false
                    """
                }
            }
        }
        
        stage('并行部署子组件') {
            parallel {
                stage('部署中间件') {
                    when {
                        params.MIDDLEWARE_ENABLED
                    }
                    steps {
                        script {
                            sh """
                                cd middleware/deploy-middleware-all
                                ./deploy-middleware-all.sh ${env.PROJECT_ID} ${env.NAMESPACE} ${params.ENVIRONMENT} false
                            """
                        }
                    }
                }
                
                stage('部署 Ingress') {
                    when {
                        params.INGRESS_ENABLED
                    }
                    steps {
                        script {
                            sh """
                                cd ingress/deploy-ingress-all
                                ./deploy-ingress-all.sh ${env.PROJECT_ID} ${env.NAMESPACE} ${params.ENVIRONMENT} false
                            """
                        }
                    }
                }
                
                stage('部署密钥管理') {
                    when {
                        params.SECRETS_ENABLED
                    }
                    steps {
                        script {
                            sh """
                                cd secrets/deploy-secrets-all
                                ./deploy-secrets-all.sh ${env.PROJECT_ID} ${env.NAMESPACE} ${params.ENVIRONMENT} false
                            """
                        }
                    }
                }
            }
        }
        
        stage('健康检查') {
            steps {
                script {
                    sh """
                        # 检查 Harbor 服务
                        kubectl get pods -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}
                        
                        # 检查中间件
                        if [ "${params.MIDDLEWARE_ENABLED}" = "true" ]; then
                            kubectl get middleware -n ${env.NAMESPACE}
                        fi
                        
                        # 检查 Ingress
                        if [ "${params.INGRESS_ENABLED}" = "true" ]; then
                            kubectl get ingress -n ${env.NAMESPACE}
                        fi
                    """
                }
            }
        }
    }
}
```

## 🔧 Jenkins 配置管理

### 1. 环境变量配置

```bash
# Jenkins 系统配置
JENKINS_HOME=/var/jenkins_home

# 环境变量
export KUBECONFIG=/var/jenkins_home/.kube/config
export HELM_HOME=/var/jenkins_home/.helm
export HARBOR_CONFIG_DIR=/var/jenkins_home/harbor-configs
```

### 2. 配置文件管理

```bash
# 创建环境特定配置
mkdir -p $HARBOR_CONFIG_DIR/{development,testing,production}

# 开发环境配置
cp deploy-harbor-all/deploy-harbor-all.conf $HARBOR_CONFIG_DIR/development/
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT="development"/' $HARBOR_CONFIG_DIR/development/deploy-harbor-all.conf

# 测试环境配置
cp deploy-harbor-all/deploy-harbor-all.conf $HARBOR_CONFIG_DIR/testing/
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT="testing"/' $HARBOR_CONFIG_DIR/testing/deploy-harbor-all.conf

# 生产环境配置
cp deploy-harbor-all/deploy-harbor-all.conf $HARBOR_CONFIG_DIR/production/
sed -i 's/ENVIRONMENT=.*/ENVIRONMENT="production"/' $HARBOR_CONFIG_DIR/production/deploy-harbor-all.conf
```

### 3. 密钥管理

```bash
# 使用 Jenkins 密钥管理
# 在 Jenkins 中配置以下密钥：
# - HARBOR_ADMIN_PASSWORD
# - POSTGRES_PASSWORD
# - REDIS_PASSWORD
# - TLS_CERT
# - TLS_KEY
```

## 🚀 部署策略

### 1. 蓝绿部署

```groovy
stage('蓝绿部署') {
    steps {
        script {
            // 部署到绿色环境
            sh """
                ./deploy-harbor-all.sh deploy ${env.PROJECT_ID}-green ${env.NAMESPACE} ${params.ENVIRONMENT} false
            """
            
            // 健康检查
            sh """
                kubectl get pods -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}-green
            """
            
            // 切换流量
            sh """
                kubectl patch service ${env.PROJECT_ID}-harbor -n ${env.NAMESPACE} -p '{"spec":{"selector":{"app.kubernetes.io/instance":"${env.PROJECT_ID}-green"}}}'
            """
        }
    }
}
```

### 2. 金丝雀部署

```groovy
stage('金丝雀部署') {
    steps {
        script {
            // 部署金丝雀版本
            sh """
                ./deploy-harbor-all.sh deploy ${env.PROJECT_ID}-canary ${env.NAMESPACE} ${params.ENVIRONMENT} false
            """
            
            // 设置流量比例
            sh """
                kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: harbor-vs
spec:
  http:
  - route:
    - destination:
        host: ${env.PROJECT_ID}-harbor
      weight: 90
    - destination:
        host: ${env.PROJECT_ID}-canary
      weight: 10
EOF
            """
        }
    }
}
```

## 📊 监控和告警

### 1. 部署状态监控

```groovy
stage('部署监控') {
    steps {
        script {
            sh """
                # 检查部署状态
                kubectl get pods -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}
                
                # 检查服务状态
                kubectl get svc -n ${env.NAMESPACE} -l app.kubernetes.io/instance=${env.PROJECT_ID}
                
                # 检查 Ingress 状态
                kubectl get ingress -n ${env.NAMESPACE}
            """
        }
    }
}
```

### 2. 告警配置

```groovy
post {
    failure {
        script {
            // 发送告警
            emailext (
                subject: "Harbor 部署失败 - ${env.JOB_NAME}",
                body: "Harbor 部署失败，请检查日志",
                to: "admin@sunmoonai.com"
            )
        }
    }
}
```

## 🎯 最佳实践

### 1. 配置管理
- 使用 Jenkins 参数化构建
- 环境变量管理敏感信息
- 配置文件版本控制

### 2. 部署策略
- 支持蓝绿部署
- 支持金丝雀部署
- 支持回滚机制

### 3. 监控告警
- 部署状态监控
- 服务健康检查
- 告警通知机制

### 4. 安全考虑
- 密钥安全管理
- 访问权限控制
- 审计日志记录

## 🔍 故障排除

### 1. 常见问题
- 配置文件路径问题
- 权限问题
- 依赖组件缺失

### 2. 调试方法
```bash
# 启用详细日志
export DEBUG=true

# 检查 Jenkins 环境
kubectl version --client
helm version

# 检查配置文件
cat deploy-harbor-all/deploy-harbor-all.conf
```

## 📚 总结

递归式部署架构与 Jenkins 的结合提供了：

1. **灵活性**: 通过参数控制部署行为
2. **可观测性**: 详细的部署日志和状态
3. **可维护性**: 模块化的部署结构
4. **可扩展性**: 易于添加新的部署组件

这种架构特别适合企业级的 CI/CD 环境，提供了强大的部署能力和良好的可维护性。
