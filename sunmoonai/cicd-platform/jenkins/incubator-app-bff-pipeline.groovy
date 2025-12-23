// Incubator App BFF 构建和部署 Pipeline
// 使用 Jenkins 拉取代码，调用自定义构建脚本构建镜像，然后调用部署脚本部署
//
// 配置说明：
// 1. 在 Jenkins 中创建 Pipeline 任务
// 2. 配置 SCM（Git）仓库地址
// 3. 设置 Pipeline 脚本路径为：incubator-app-bff-pipeline.groovy
// 4. 配置定时构建（Poll SCM）或 Webhook 触发

pipeline {
    // 不使用 agent，直接在 Jenkins 节点上执行
    agent any
    
    environment {
        // 项目路径配置
        // 代码仓库路径（Jenkins 工作空间）
        WORKSPACE_DIR = "${WORKSPACE}"
        
        // 构建脚本路径（相对于代码仓库根目录）
        BUILD_SCRIPT_PATH = "mybuild/build-image.sh"
        
        // 部署脚本路径（绝对路径）
        DEPLOY_SCRIPT_PATH = "/home/zym/k8s/sunmoonai/incubator-app/incubator-app-bff/deploy-incubator-bff/app/deploy-app/deploy-incubator-bff.sh"
        
        // 镜像构建配置（可通过 Jenkins 参数覆盖）
        // 默认使用 BUILD_NUMBER，如果有 Git 提交信息则添加
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        
        // 部署配置（可通过 Jenkins 参数覆盖）
        DEPLOY_PROJECT_ID = "sunmoonai"
        DEPLOY_NAMESPACE = "app-platform-dev"
        DEPLOY_ENVIRONMENT = "development"
        
        // 集群配置（可选）
        CLUSTER = ""
    }
    
    parameters {
        // 镜像标签参数
        string(
            name: 'IMAGE_TAG_PARAM',
            defaultValue: '',
            description: '自定义镜像标签（留空则使用 BUILD_NUMBER-GIT_COMMIT）'
        )
        
        // 部署参数
        string(
            name: 'DEPLOY_PROJECT_ID_PARAM',
            defaultValue: 'sunmoonai',
            description: '部署项目ID'
        )
        string(
            name: 'DEPLOY_NAMESPACE_PARAM',
            defaultValue: 'app-platform-dev',
            description: '部署命名空间'
        )
        choice(
            name: 'DEPLOY_ENVIRONMENT_PARAM',
            choices: ['development', 'production'],
            description: '部署环境'
        )
        
        // 集群参数（可选）
        string(
            name: 'CLUSTER_PARAM',
            defaultValue: '',
            description: '集群标识（如 C1, C2，留空则不指定）'
        )
        
        // 构建选项
        booleanParam(
            name: 'SKIP_BUILD',
            defaultValue: false,
            description: '跳过构建步骤（仅部署）'
        )
        booleanParam(
            name: 'SKIP_DEPLOY',
            defaultValue: false,
            description: '跳过部署步骤（仅构建）'
        )
        booleanParam(
            name: 'PUSH_IMAGE_AFTER_BUILD',
            defaultValue: true,
            description: '构建后自动推送镜像到仓库'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "=========================================="
                    echo "步骤 1: 从代码仓库拉取代码"
                    echo "=========================================="
                    echo "工作空间: ${WORKSPACE_DIR}"
                    // 尝试获取 Git 信息（如果可用）
                    sh '''
                        if [ -d .git ]; then
                            echo "Git 提交: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')"
                            echo "Git 分支: $(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
                        else
                            echo "Git 信息: 未检测到 Git 仓库"
                        fi
                    '''
                    
                    // Jenkins 会自动执行 checkout（如果配置了 SCM）
                    // 这里只是显示信息
                    sh '''
                        echo "当前工作目录:"
                        pwd
                        echo ""
                        echo "代码仓库内容:"
                        ls -la
                        echo ""
                        echo "Git 信息:"
                        git log -1 --oneline || true
                        git branch || true
                    '''
                }
            }
        }
        
        stage('Build Image') {
            when {
                not { params.SKIP_BUILD }
            }
            steps {
                script {
                    echo "=========================================="
                    echo "步骤 2: 构建 Docker 镜像"
                    echo "=========================================="
                    
                    // 确定镜像标签
                    def imageTag = params.IMAGE_TAG_PARAM
                    if (!imageTag) {
                        // 尝试获取 Git 提交信息
                        def gitCommit = sh(
                            script: 'git rev-parse --short HEAD 2>/dev/null || echo ""',
                            returnStdout: true
                        ).trim()
                        if (gitCommit) {
                            imageTag = "${env.BUILD_NUMBER}-${gitCommit}"
                        } else {
                            imageTag = "${env.BUILD_NUMBER}"
                        }
                    }
                    env.IMAGE_TAG = imageTag
                    
                    echo "镜像标签: ${imageTag}"
                    echo "构建脚本: ${BUILD_SCRIPT_PATH}"
                    
                    // 检查构建脚本是否存在
                    sh """
                        if [ ! -f "${BUILD_SCRIPT_PATH}" ]; then
                            echo "❌ 错误: 构建脚本不存在: ${BUILD_SCRIPT_PATH}"
                            exit 1
                        fi
                        echo "✅ 构建脚本存在"
                        ls -lh "${BUILD_SCRIPT_PATH}"
                    """
                    
                    // 检查构建配置文件
                    sh """
                        if [ ! -f "mybuild/build.conf" ]; then
                            echo "⚠️  警告: 构建配置文件不存在: mybuild/build.conf"
                        else
                            echo "✅ 构建配置文件存在"
                        fi
                    """
                    
                    // 设置构建配置（如果需要推送镜像）
                    if (params.PUSH_IMAGE_AFTER_BUILD) {
                        echo "配置: 构建后自动推送镜像"
                        // 修改 build.conf 中的 PUSH_IMAGES_AFTER_BUILD 为 true
                        sh """
                            if [ -f "mybuild/build.conf" ]; then
                                # 备份原配置
                                cp mybuild/build.conf mybuild/build.conf.bak
                                # 更新配置
                                sed -i 's/^PUSH_IMAGES_AFTER_BUILD=.*/PUSH_IMAGES_AFTER_BUILD="true"/' mybuild/build.conf
                                echo "✅ 已更新构建配置: PUSH_IMAGES_AFTER_BUILD=true"
                            fi
                        """
                    }
                    
                    // 执行构建脚本（使用自定义标签）
                    sh """
                        cd "${WORKSPACE_DIR}"
                        chmod +x "${BUILD_SCRIPT_PATH}"
                        "${BUILD_SCRIPT_PATH}" --tag "${imageTag}"
                    """
                    
                    echo "✅ 镜像构建完成: ${imageTag}"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            when {
                not { params.SKIP_DEPLOY }
            }
            steps {
                script {
                    echo "=========================================="
                    echo "步骤 3: 部署到 Kubernetes"
                    echo "=========================================="
                    
                    // 确定部署参数
                    def projectId = params.DEPLOY_PROJECT_ID_PARAM ?: env.DEPLOY_PROJECT_ID
                    def namespace = params.DEPLOY_NAMESPACE_PARAM ?: env.DEPLOY_NAMESPACE
                    def environment = params.DEPLOY_ENVIRONMENT_PARAM ?: env.DEPLOY_ENVIRONMENT
                    def cluster = params.CLUSTER_PARAM ?: env.CLUSTER
                    
                    echo "部署配置:"
                    echo "  项目ID: ${projectId}"
                    echo "  命名空间: ${namespace}"
                    echo "  环境: ${environment}"
                    if (cluster) {
                        echo "  集群: ${cluster}"
                    }
                    echo "部署脚本: ${DEPLOY_SCRIPT_PATH}"
                    
                    // 检查部署脚本是否存在
                    sh """
                        if [ ! -f "${DEPLOY_SCRIPT_PATH}" ]; then
                            echo "❌ 错误: 部署脚本不存在: ${DEPLOY_SCRIPT_PATH}"
                            exit 1
                        fi
                        echo "✅ 部署脚本存在"
                        ls -lh "${DEPLOY_SCRIPT_PATH}"
                    """
                    
                    // 构建部署命令
                    def deployCmd = "bash \"${DEPLOY_SCRIPT_PATH}\" deploy \"${projectId}\" \"${namespace}\" \"${environment}\""
                    
                    // 如果指定了集群，添加集群参数
                    if (cluster) {
                        deployCmd = "bash \"${DEPLOY_SCRIPT_PATH}\" deploy --cluster=${cluster} \"${projectId}\" \"${namespace}\" \"${environment}\""
                    }
                    
                    echo "执行部署命令: ${deployCmd}"
                    
                    // 执行部署脚本
                    sh """
                        chmod +x "${DEPLOY_SCRIPT_PATH}"
                        ${deployCmd}
                    """
                    
                    echo "✅ 部署完成"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "=========================================="
                echo "Pipeline 执行完成"
                echo "=========================================="
                
                // 恢复构建配置文件（如果修改过）
                sh """
                    if [ -f "mybuild/build.conf.bak" ]; then
                        mv mybuild/build.conf.bak mybuild/build.conf
                        echo "✅ 已恢复构建配置文件"
                    fi
                """
            }
        }
        success {
            echo "✅ Pipeline 执行成功！"
            echo ""
            echo "构建信息:"
            echo "  镜像标签: ${env.IMAGE_TAG}"
            if (!params.SKIP_DEPLOY) {
                echo ""
                echo "部署信息:"
                echo "  项目ID: ${params.DEPLOY_PROJECT_ID_PARAM ?: env.DEPLOY_PROJECT_ID}"
                echo "  命名空间: ${params.DEPLOY_NAMESPACE_PARAM ?: env.DEPLOY_NAMESPACE}"
                echo "  环境: ${params.DEPLOY_ENVIRONMENT_PARAM ?: env.DEPLOY_ENVIRONMENT}"
            }
        }
        failure {
            echo "❌ Pipeline 执行失败！"
            echo ""
            echo "请检查:"
            echo "  1. 构建脚本是否正确"
            echo "  2. 部署脚本路径是否正确"
            echo "  3. Kubernetes 连接是否正常"
            echo "  4. 镜像仓库认证是否配置"
        }
        cleanup {
            // 清理临时文件
            sh """
                # 清理构建配置文件备份
                rm -f mybuild/build.conf.bak || true
            """
        }
    }
}

