// release 流水线的任务体（SDD 0033 第四节）。由控制器里的引导脚本在宿主代理上 load，跟着分支走。
// B 段第 3 步（2026-10-20）：只到第 5 阶段「计划」为止，不提交、不发布、不晋级；结束时 gitops/ 与 sources.yaml 回到干净。
// 后面的阶段（提交、发布、人批、写指针、部署、检查、推送）第 4 步加。入口只认 make 的公开目标，不认内部剧本名。

def run(params, reposDir) {
    def apps = (params.APPS ?: '').trim() ? params.APPS.trim().split(/\s+/) as List : ['tpl', 'knowfeed', 'knowbase', 'knowbench', 'knowlab', 'knowmart']
    def branch = params.BRANCH.trim()
    def note = (params.NOTE ?: '').trim()
    if (!(branch ==~ /[A-Za-z0-9._\/-]{1,80}/) || branch.contains('..')) { error "BRANCH 不合法: ${branch}" }
    for (a in apps) { if (!(a ==~ /[a-z][a-z0-9]{1,20}/)) { error "APPS 里有不合法的名字: ${a}" } }
    if (!(params.PIN in ['heads', 'keep'])) { error "PIN 只能是 heads 或 keep" }
    if (note && !(note ==~ '[^\\r\\n\\t"\'`$\\\\]{1,120}')) { error 'NOTE 只能是一行，不含引号、反引号、$ 和反斜杠' }

    def head = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
    def out = "infrastructure/.build/release/${env.BUILD_NUMBER}"
    currentBuild.displayName = "#${env.BUILD_NUMBER} ${branch}@${head.take(10)} ${apps.join(',')}"
    currentBuild.description = note ?: ''
    sh "mkdir -p '${out}'"

    // 每个 make 的输出进一个日志文件（也进控制台），结束时统一查一遍已知的秘密样子（第五节）
    def logged = { String name, String cmd ->
        sh "#!/bin/bash\nset -o pipefail; ${cmd} 2>&1 | tee '${out}/${name}.log'"
    }

    try {
        stage('1 核对') {
            // 工作区必须干净（引导已经把 k8s 检到分支头；这里看的是上次有没有留下东西）
            def dirty = sh(script: 'git status --porcelain --untracked-files=no -- gitops infrastructure/applications/sources.yaml', returnStdout: true).trim()
            if (dirty) { error "工作区不干净:\n${dirty}" }
            for (app in apps) {
                dir("${reposDir}/${app}-app") {
                    sh "git fetch -q origin '+refs/heads/*:refs/remotes/origin/*' && git checkout -q --detach 'origin/${branch}' && git submodule update --init -q"
                }
            }
            logged('1-platform-status', 'make -C infrastructure platform-status')
        }

        stage('2 改钉') {
            if (params.PIN == 'heads') {
                logged('2-pin', "python3 ci/pin-sources.py --repos '${reposDir}' --branch '${branch}' --apps '${apps.join(' ')}'")
            } else {
                echo 'PIN=keep：sources.yaml 按已提交的钉，不改'
            }
            sh "git diff -- infrastructure/applications/sources.yaml > '${out}/2-sources.diff'; git diff --stat -- infrastructure/applications/sources.yaml"
            // 前置核对：钉到的后端的 alembic 头要等于 expected_schema_revision；不对就停在这里，不进构建
            for (app in apps) {
                logged("2-plan-${app}", "make -C infrastructure application-deployment-plan APP=${app}")
            }
        }

        stage('3 构建') {
            for (app in apps) {
                logged("3-build-${app}", "make -C infrastructure platform-build OBJECT=app-platform/${app}-app")
            }
            sh """
for f in \$(git diff --name-only -- gitops | grep image.lock.yaml || true); do echo "\$f: \$(grep -E '^(source_revision|digest)' "\$f" | tr '\\n' ' ')"; done | tee '${out}/3-image-locks.txt'
"""
        }

        stage('4 暂存') {
            for (app in apps) {
                logged("4-stage-${app}", "make -C infrastructure platform-stage OBJECT=app-platform/${app}-app")
            }
            sh """#!/bin/bash
set -euo pipefail
if grep -rln 'BEGIN [A-Z ]*PRIVATE KEY\\|BEGIN PUBLIC KEY' gitops/ ; then echo '暂存结果里有密钥字样'; exit 1; fi
git status --short -- gitops | awk '{print \$2}' | sed -E 's#^gitops/(components/[^/]+/[^/]+(/[^/]+)?|clusters/kind)/.*#\\1#' | sort | uniq -c | tee '${out}/4-gitops-touched.txt'
git diff --stat -- gitops | tee '${out}/4-gitops.stat'
git diff -- gitops | grep -E '^(\\+\\+\\+|@@|[-+] )' | grep -v -E 'sha256:|digest|image:' > '${out}/4-workload.diff' || true
wc -l '${out}/4-workload.diff'
"""
        }

        stage('5 计划') {
            for (app in apps) {
                logged("5-plan-${app}", "make -C infrastructure application-deployment-plan APP=${app}")
            }
            def touched = sh(script: 'git status --porcelain -- gitops | wc -l', returnStdout: true).trim()
            currentBuild.description = "${note ? note + ' — ' : ''}到第 5 阶段为止（B3）；gitops 变更 ${touched} 个文件，未提交"
        }
    } finally {
        stage('秘密样子核查与产物') {
            // 已知样子：age 私钥、PEM 私钥、JWT、Harbor 机器人口令。命中就把该次标红、产物里打码，值不进日志。
            def hits = sh(script: """#!/bin/bash
set -uo pipefail
pat='AGE-SECRET-KEY-1[0-9A-Z]{50,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{15,}\\.[A-Za-z0-9_-]{15,}\\.[A-Za-z0-9_-]{10,}|robot\\\$[A-Za-z0-9_.-]+:[A-Za-z0-9]{20,}'
n=0
for f in '${out}'/*; do
  c=\$(grep -c -E "\$pat" "\$f" || true)
  if [ "\$c" != 0 ]; then echo "\$f: \$c 处"; sed -E -i "s/\$pat/[REDACTED]/g" "\$f"; n=\$((n+c)); fi
done
echo "total=\$n"
""", returnStdout: true).trim()
            echo hits
            if (!hits.endsWith('total=0')) { currentBuild.result = 'FAILURE'; currentBuild.description = "产物里出现了秘密的样子，已打码：${hits.split('\n')[0]}" }
            archiveArtifacts artifacts: "${out}/**", allowEmptyArchive: true
        }
        stage('工作区回到干净') {
            // 第 6 阶段之前停下都这样收：sources.yaml 与 gitops 回到已提交的样子（.build/ 里的候选留着，不进 git）
            sh 'git checkout -q -- gitops infrastructure/applications/sources.yaml && git status --short --untracked-files=no | head -20'
        }
    }
}

return this
