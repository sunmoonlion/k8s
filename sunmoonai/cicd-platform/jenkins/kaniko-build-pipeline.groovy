// 构建制品示例；不发布镜像。KIND / 云端均尚未完成真实 CI 验收，云端未经实机验证。
// 只给构建容器只读拉取身份；发布使用 registry-platform 的独立账号和同一 Skopeo 发布器。
// 必须在 Jenkins 作业中明确选 Kubernetes cloud；不能默认选中生产 cloud。
pipeline {
    agent none
    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }
    parameters {
        string(name: 'KUBERNETES_CLOUD', defaultValue: '', description: '已核实目标集群的 Jenkins Kubernetes cloud 名称')
        string(name: 'JNLP_IMAGE', defaultValue: '', description: '已准入的内部 jenkins-agent repo@sha256，包含 git 和 sh')
        string(name: 'KANIKO_IMAGE', defaultValue: '', description: '已准入的内部 Kaniko debug repo@sha256，含 /busybox/sh')
        string(name: 'CA_SHA256', defaultValue: '', description: 'registry-ca Secret 中 ca.crt 的准入 SHA256')
        string(name: 'IMAGE_REPOSITORY', defaultValue: '', description: 'app-images 下仓库名，不带 tag；例 investment-backend')
    }
    stages {
        stage('Validate configuration') {
            steps {
                script {
                    if (!(params.KUBERNETES_CLOUD ==~ /[a-zA-Z0-9_-]+/)) {
                        error('必须明确配置已核实的 Kubernetes cloud')
                    }
                    for (image in [params.JNLP_IMAGE, params.KANIKO_IMAGE]) {
                        if (!(image ==~ /harbor\.sunmoonai\.com:30443\/k8s-images\/[a-z0-9._\/-]+@sha256:[a-f0-9]{64}/)) {
                            error('构建器和 agent 必须使用内部仓库的已准入摘要引用')
                        }
                    }
                    if (!(params.CA_SHA256 ==~ /[a-f0-9]{64}/) ||
                        !(params.IMAGE_REPOSITORY ==~ /[a-z0-9]+(?:[._-][a-z0-9]+)*/)) {
                        error('必须提供 CA 摘要和应用镜像仓库名')
                    }
                }
            }
        }
        stage('Build archive') {
            steps {
                script {
                    podTemplate(cloud: params.KUBERNETES_CLOUD, yaml: """
apiVersion: v1
kind: Pod
spec:
  automountServiceAccountToken: false
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: jnlp
    image: ${params.JNLP_IMAGE}
  - name: kaniko
    image: ${params.KANIKO_IMAGE}
    command: [/busybox/cat]
    tty: true
    resources:
      requests:
        cpu: '500m'
        memory: 512Mi
        ephemeral-storage: 4Gi
      limits:
        cpu: '2000m'
        memory: 2Gi
        ephemeral-storage: 16Gi
    volumeMounts:
    - name: registry-auth
      mountPath: /kaniko/.docker
      readOnly: true
    - name: registry-ca
      mountPath: /sunmoon-ca
      readOnly: true
  volumes:
  - name: registry-auth
    secret:
      secretName: kaniko-registry-secret
      items:
      - key: .dockerconfigjson
        path: config.json
  - name: registry-ca
    secret:
      secretName: registry-ca
      items:
      - key: ca.crt
        path: ca.crt
  imagePullSecrets:
  - name: harbor-registry-secret
""") {
                        node(POD_LABEL) {
                            container('jnlp') {
                                dir('source') {
                                    checkout scm
                                    sh '''
                                        set -eu
                                        test -f Dockerfile
                                        changes="$(git status --porcelain --untracked-files=all --ignore-submodules=none)"
                                        test -z "$changes"
                                    '''
                                }
                                sh '''
                                    set -eu
                                    test ! -e sunmoon-build-artifacts
                                    mkdir -m 0700 sunmoon-build-artifacts
                                    git -C source rev-parse HEAD > sunmoon-build-artifacts/source-commit.txt
                                '''
                            }
                            withEnv(["EXPECTED_CA_SHA256=${params.CA_SHA256}",
                                     "EXPORT_REPOSITORY=${params.IMAGE_REPOSITORY}",
                                     'NO_PROXY=harbor.sunmoonai.com', 'no_proxy=harbor.sunmoonai.com']) {
                                container('kaniko', shell: '/busybox/sh') {
                                    sh '''#!/busybox/sh
                                        set -eu
                                        test -r /kaniko/.docker/config.json
                                        printf '%s  /sunmoon-ca/ca.crt\n' "$EXPECTED_CA_SHA256" | sha256sum -c -
                                        /kaniko/executor \
                                            --context "$WORKSPACE/source" \
                                            --dockerfile "$WORKSPACE/source/Dockerfile" \
                                            --destination "harbor.sunmoonai.com:30443/app-images/$EXPORT_REPOSITORY:candidate" \
                                            --no-push --no-push-cache --cache=false \
                                            --tar-path "$WORKSPACE/sunmoon-build-artifacts/docker.tar" \
                                            --digest-file "$WORKSPACE/sunmoon-build-artifacts/builder-digest.txt" \
                                            --registry-certificate harbor.sunmoonai.com:30443=/sunmoon-ca/ca.crt
                                        cd "$WORKSPACE/sunmoon-build-artifacts"
                                        sha256sum docker.tar > docker.tar.sha256
                                    '''
                                }
                            }
                            container('jnlp') {
                                sh '''
                                    set -eu
                                    changes="$(git -C source status --porcelain --untracked-files=all --ignore-submodules=none)"
                                    test -z "$changes"
                                    observed="$(git -C source rev-parse HEAD)"
                                    expected="$(cat sunmoon-build-artifacts/source-commit.txt)"
                                    test "$observed" = "$expected"
                                '''
                            }
                            archiveArtifacts(artifacts: 'sunmoon-build-artifacts/*', fingerprint: true, onlyIfSuccessful: true)
                            echo '只完成构建制品导出；在发布主机用 harbor prepare-image 转换后，再用 harbor publish 发布。'
                        }
                    }
                }
            }
        }
    }
}
