// Kaniko 构建 Pipeline 示例
// 使用 Kaniko 构建和推送 Docker 镜像

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  hostAliases:
  - ip: "101.126.151.0"  # Harbor 服务器 IP（请根据实际情况确认或调整）
    hostnames:
    - "harbor.sunmoonai.com"
  containers:
  - name: jnlp
    image: harbor.sunmoonai.com:30443/k8s-images/jenkins-agent:0.3327.0-debian-12-r1
    alwaysPullImage: false
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command:
    - /busybox/cat
    tty: true
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "2000m"
        memory: "2Gi"
    volumeMounts:
    - name: kaniko-secret
      mountPath: /kaniko/.docker
    env:
    - name: DOCKER_CONFIG
      value: /kaniko/.docker
  volumes:
  - name: kaniko-secret
    secret:
      secretName: kaniko-registry-secret
      items:
      - key: .dockerconfigjson
        path: config.json   # 在 /kaniko/.docker/config.json 暴露认证文件
  imagePullSecrets:
  - name: harbor-registry-secret
"""
        }
    }
    
    environment {
        // Harbor Registry 配置
        REGISTRY = 'harbor.sunmoonai.com:30443'
        // 项目名称（根据实际项目修改）
        PROJECT_NAME = 'k8s-images'
        // 镜像名称
        IMAGE_NAME = "${PROJECT_NAME}/my-app"
        // 镜像标签
        IMAGE_TAG = "${BUILD_NUMBER}"
        // 完整镜像地址
        FULL_IMAGE = "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        LATEST_IMAGE = "${REGISTRY}/${IMAGE_NAME}:latest"
    }
    
    stages {
        stage('Checkout') {
            steps {
                container('jnlp') {
                    script {
                        echo "检出代码..."
                        // 检查工作目录
                        sh 'pwd && ls -la'
                        // 如果没有代码仓库，创建一个测试 Dockerfile
                        // 使用 Harbor 中已有的 jenkins-agent 镜像（确认可以拉取）
                        sh '''
                            if [ ! -f Dockerfile ]; then
                                echo "未找到 Dockerfile，创建测试 Dockerfile（使用 Harbor 中的 jenkins-agent 镜像）..."
                                cat > Dockerfile << 'EOF'
FROM scratch
# 使用 scratch 空镜像，无需解包，构建最快
# 只添加一个简单的文件作为标识
COPY Dockerfile /Dockerfile
EOF
                                echo "测试 Dockerfile 已创建（使用 Harbor 中的 jenkins-agent 镜像）"
                            else
                                echo "检测到现有 Dockerfile"
                            fi
                            cat Dockerfile
                        '''
                    }
                }
            }
        }
        
        stage('Build and Push') {
            steps {
                container('kaniko') {
                    script {
                        echo "使用 Kaniko 构建镜像..."
                        echo "镜像地址: ${FULL_IMAGE}"
                        // 检查工作目录和 Dockerfile（两个容器共享 workspace volume）
                        sh 'pwd && ls -la'
                        sh 'if [ -f Dockerfile ]; then echo "✅ Dockerfile 存在"; cat Dockerfile; else echo "❌ 错误: Dockerfile 不存在"; exit 1; fi'
                        
                        // 检查认证文件（Secret 已通过 Pod 模板挂载为 config.json）
                        sh '''
                            echo "检查认证文件..."
                            if [ -f /kaniko/.docker/config.json ]; then
                                echo "✅ 认证文件存在"
                            elif [ -f /kaniko/.docker/.dockerconfigjson ]; then
                                echo "⚠️ 警告: 找到 .dockerconfigjson，但 Kaniko 需要 config.json"
                                echo "请检查 Pod 模板中的 Secret 挂载配置"
                            else
                                echo "❌ 错误: 未找到认证文件"
                                exit 1
                            fi
                        '''
                        
                        // 执行构建（hostAliases 已在 Pod 模板中配置，无需手动修改 hosts）
                        // 优化：使用单次快照和新的 run 实现，加快构建速度
                        sh """
                            /kaniko/executor \
                                --context . \
                                --dockerfile Dockerfile \
                                --destination ${FULL_IMAGE} \
                                --destination ${LATEST_IMAGE} \
                                --single-snapshot \
                                --use-new-run \
                                --skip-tls-verify \
                                --insecure-registry harbor.sunmoonai.com:30443 \
                                --insecure-pull \
                                --verbosity=info
                        """
                    }
                }
            }
        }
        
        stage('Verify') {
            steps {
                container('jnlp') {
                    script {
                        echo "验证镜像构建成功..."
                        echo "镜像已推送到: ${FULL_IMAGE}"
                        echo "最新标签: ${LATEST_IMAGE}"
                        // 可以添加镜像验证逻辑
                        // 例如：使用 curl 检查 Harbor API
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "Pipeline 执行完成"
        }
        success {
            echo "✅ 镜像构建成功！"
            echo "镜像地址: ${FULL_IMAGE}"
        }
        failure {
            echo "❌ 镜像构建失败！"
        }
    }
}

