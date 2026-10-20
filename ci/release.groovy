// release 流水线的任务体（SDD 0033 第四节、第十节）。由控制器里的引导脚本在宿主代理上 load，跟着分支走。
// 第 4 步（2026-10-20）：十二个阶段全接上。前半段（1–7）在一段 node 里，人批（8）在 node 外面不占执行器，
// 后半段（9–12）另一段 node。入口只认 make 的公开目标，不认内部剧本名。D 段换 Argo 时第 7–10 阶段整段替换。

def main(params, reposDir, approver, rootRepo = 'k8s') {
    def apps = (params.APPS ?: '').trim() ? params.APPS.trim().split(/\s+/) as List : ['tpl', 'knowfeed', 'knowbase', 'knowbench', 'knowlab', 'knowmart']
    def branch = params.BRANCH.trim()
    def note = (params.NOTE ?: '').trim()
    def approvalMinutes = (params.APPROVAL_TIMEOUT_MINUTES ?: '1440').trim()
    if (!(branch ==~ /[A-Za-z0-9._\/-]{1,80}/) || branch.contains('..')) { error "BRANCH 不合法: ${branch}" }
    for (a in apps) { if (!(a ==~ /[a-z][a-z0-9]{1,20}/)) { error "APPS 里有不合法的名字: ${a}" } }
    if (!(params.PIN in ['heads', 'keep'])) { error "PIN 只能是 heads 或 keep" }
    if (note && !(note ==~ '[^\\r\\n\\t"\'`$\\\\]{1,120}')) { error 'NOTE 只能是一行，不含引号、反引号、$ 和反斜杠' }
    if (!(approvalMinutes ==~ /[1-9][0-9]{0,4}/)) { error 'APPROVAL_TIMEOUT_MINUTES 要是 1 到 99999 的整数' }
    if (!(approver ==~ /[a-z][a-z0-9_-]{0,31}/)) { error "批准人账号不合法: ${approver}" }

    if (!(rootRepo ==~ /[a-z][a-z0-9-]{0,30}/)) { error "根仓名不合法: ${rootRepo}" }
    def k8s = "${reposDir}/${rootRepo}"   // 根仓的克隆（名字由引导从 jenkins_root_repo 传入）
    def n = env.BUILD_NUMBER
    def out = "infrastructure/.build/release/${n}"
    def state = [commit: '', candidate: '', pointerCommit: '', tag: '', approvedBy: '', pushed: false, nothing: false]

    // 每个 make 的输出进一个日志文件（也进控制台）
    def logged = { String name, String cmd ->
        sh "#!/bin/bash\nset -o pipefail; ${cmd} 2>&1 | tee '${out}/${name}.log'"
    }
    // 已知秘密样子：age 私钥、PEM 私钥、JWT、Harbor 机器人口令。命中就把该次标红、产物里打码，值不进日志。
    def scanSecrets = {
        def hits = sh(script: """#!/bin/bash
set -uo pipefail
pat='AGE-SECRET-KEY-1[0-9A-Z]{50,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{15,}\\.[A-Za-z0-9_-]{15,}\\.[A-Za-z0-9_-]{10,}|robot\\\$[A-Za-z0-9_.-]+:[A-Za-z0-9]{20,}'
n=0
for f in '${out}'/*; do
  [ -f "\$f" ] || continue
  c=\$(grep -c -E "\$pat" "\$f" || true)
  if [ "\$c" != 0 ]; then echo "\$f: \$c 处"; sed -E -i "s/\$pat/[REDACTED]/g" "\$f"; n=\$((n+c)); fi
done
echo "total=\$n"
""", returnStdout: true).trim()
        echo hits
        if (hits.endsWith('total=0')) { return '' }
        currentBuild.result = 'FAILURE'
        currentBuild.description = "产物里出现了秘密的样子，已打码：${hits.split('\n')[0]}"
        return hits.split('\n')[0]
    }
    def archive = { archiveArtifacts artifacts: "${out}/**", allowEmptyArchive: true }

    // ---------- 前半段：核对 → 改钉 → 构建 → 暂存 → 计划 → 提交 → 发布 ----------
    node('host') { dir(k8s) {
        def head = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
        currentBuild.displayName = "#${n} ${branch}@${head.take(10)} ${apps.join(',')}"
        currentBuild.description = note ?: ''
        sh "mkdir -p '${out}'"
        try {
            stage('1 核对') {
                def dirty = sh(script: 'git status --porcelain --untracked-files=no -- gitops infrastructure/applications/sources.yaml infrastructure/environments', returnStdout: true).trim()
                if (dirty) { error "工作区不干净:\n${dirty}" }
                // 应用仓先同步到分支头（PIN=heads 要读 origin/<branch>），第 2 阶段末尾再按钉对齐
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
                // 构建链要求子仓 HEAD 恰等于钉的号：按钉对齐检出
                logged('2-align', "python3 ci/align-sources.py --repos '${reposDir}' --apps '${apps.join(' ')}'")
                // 前置核对：钉到的后端的 alembic 头要等于 expected_schema_revision；不对就停在这里，不进构建
                for (app in apps) { logged("2-plan-${app}", "make -C infrastructure application-deployment-plan APP=${app}") }
            }
            stage('3 构建') {
                for (app in apps) { logged("3-build-${app}", "make -C infrastructure platform-build OBJECT=app-platform/${app}-app") }
                sh """
for f in \$(git diff --name-only -- gitops | grep image.lock.yaml || true); do echo "\$f: \$(grep -E '^(source_revision|digest)' "\$f" | tr '\\n' ' ')"; done > '${out}/3-image-locks.txt'
[ -s '${out}/3-image-locks.txt' ] || echo "(no image lock changed: same pins rebuilt to the same digests)" > '${out}/3-image-locks.txt'
cat '${out}/3-image-locks.txt'
"""
            }
            stage('4 暂存') {
                for (app in apps) { logged("4-stage-${app}", "make -C infrastructure platform-stage OBJECT=app-platform/${app}-app") }
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
                for (app in apps) { logged("5-plan-${app}", "make -C infrastructure application-deployment-plan APP=${app}") }
                def touched = sh(script: 'git status --porcelain -- gitops infrastructure/applications/sources.yaml | wc -l', returnStdout: true).trim()
                if (touched == '0') {
                    state.nothing = true
                    currentBuild.result = 'NOT_BUILT'
                    currentBuild.description = "${note ? note + ' — ' : ''}无差异，不发（同一组钉已在线上）"
                }
            }
            if (!state.nothing) {
                stage('6 提交') {
                    sh """#!/bin/bash
set -euo pipefail
git add infrastructure/applications/sources.yaml gitops
git -c user.name=sunmoon-ci -c user.email=ci@sunmoonai.com commit -q -m "deploy(${apps.join(',')}): ${note ?: '按钉发布'}（release #${n}）"
{ git rev-parse HEAD; git show --stat --format='%H %an %s' HEAD; } | tee '${out}/6-commit.txt'
"""
                    state.commit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                }
                stage('7 发布') {
                    logged('7-release', 'make -C infrastructure flux-release')
                    // 候选文件由发布器以 root 写，拷一份无凭据的进产物（第 9 阶段用它写指针）
                    sh "sudo -n cat infrastructure/.build/flux/source-candidate.yaml > '${out}/7-source-candidate.yaml'; cat '${out}/7-source-candidate.yaml'"
                    state.candidate = sh(script: "cat '${out}/7-source-candidate.yaml'", returnStdout: true).trim()
                    def rev = sh(script: "grep -E '^revision:' '${out}/7-source-candidate.yaml' | awk '{print \$2}'", returnStdout: true).trim()
                    if (rev != state.commit) { error "候选的 revision ${rev} 不是第 6 阶段的提交 ${state.commit}" }
                }
            }
        } finally {
            stage('前半段收尾') {
                def hit = scanSecrets()
                archive()
                if (!state.commit) {
                    // 第 6 阶段之前停下（含无差异）：撤干净
                    sh 'git checkout -q -- gitops infrastructure/applications/sources.yaml && git status --short --untracked-files=no | head -20'
                } else {
                    // 已提交：先留个名字，推上去之前别丢
                    sh "git branch -f 'abandoned/release-${n}' '${state.commit}'"
                }
                if (hit) { error "秘密样子核查命中：${hit}" }
            }
        }
    } }
    if (state.nothing) { return }

    // ---------- 人批：不在 node 里，不占执行器 ----------
    stage('8 人批') {
        def summary = """发布 #${n}  分支 ${branch}  应用 ${apps.join(', ')}
说明：${note ?: '(无)'}
提交：${state.commit}
候选：
${state.candidate}
产物：${env.BUILD_URL}artifact/${out}/（2-sources.diff、3-image-locks.txt、4-gitops.stat、4-workload.diff）
批了就写指针、打 tag、部署到集群、检查、推送；${approvalMinutes} 分钟没人批自动中止。"""
        try {
            timeout(time: approvalMinutes as Integer, unit: 'MINUTES') {
                state.approvedBy = input(message: summary, ok: '批准发布', submitter: approver, submitterParameter: 'APPROVED_BY')
            }
        } catch (err) {
            currentBuild.result = 'ABORTED'
            currentBuild.description = "${note ? note + ' — ' : ''}第 8 阶段未获批准（拒绝或 ${approvalMinutes} 分钟超时）；提交留在代理克隆 abandoned/release-${n}，候选留在 Harbor，集群未动"
            throw err
        }
    }

    // ---------- 后半段：写指针 → 部署 → 检查 → 推送与回执 ----------
    node('host') { dir(k8s) {
        try {
            stage('9 写指针') {
                sh """#!/bin/bash
set -euo pipefail
# 两段之间 render-check 可能把工作区检到别处：按提交号回到第 6 阶段的提交，不信工作区
git checkout -q --detach '${state.commit}'
test -s '${out}/7-source-candidate.yaml'
echo "批准人 ${state.approvedBy}  \$(date -Is)" | tee '${out}/8-approval.txt'
cp '${out}/7-source-candidate.yaml' infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml
git -c user.name=sunmoon-ci -c user.email=ci@sunmoonai.com commit -q -m "release(kind): 晋级到 \$(git rev-parse --short '${state.commit}')（release #${n}）"
git -c url.git@github.com:.insteadOf=https://github.com/ fetch -q --tags origin
d=\$(date +%Y%m%d); k=\$(git tag -l "release-\$d-*" | wc -l); tag="release-\$d-\$((k+1))"
git tag "\$tag"
{ cat infrastructure/environments/kind/flux-source.yaml; echo "pointer-commit \$(git rev-parse HEAD)"; echo "tag \$tag"; } | tee '${out}/9-pointer.txt'
"""
                state.pointerCommit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                state.tag = sh(script: "grep '^tag ' '${out}/9-pointer.txt' | awk '{print \$2}'", returnStdout: true).trim()
                sh "git branch -f 'abandoned/release-${n}' '${state.pointerCommit}'"
            }
            stage('10 部署') {
                logged('10-apply', 'make -C infrastructure flux-source-apply')
                sh """#!/bin/bash
set -euo pipefail
export KUBECONFIG="\$HOME/.kube/sunmoon-kind.config"
K=infrastructure/.tools/bin/kubectl
for app in ${apps.join(' ')}; do
  \$K -n flux-system get kustomizations -o name | grep -E "/\${app}-" | xargs -r \$K -n flux-system wait --for=condition=Ready --timeout=30m
done 2>&1 | tee '${out}/10-wait.txt'
"""
            }
            stage('11 检查') {
                // 只跑 application-check；platform-check 对应用对象就是公网入口检查，边缘只放行三个域名，不是每个应用都有公网入口
                for (app in apps) { logged("11-check-${app}", "make -C infrastructure application-check APP=${app}") }
            }
            stage('12 推送与回执') {
                def hit = scanSecrets()
                if (hit) { error "秘密样子核查命中，不写回执不推：${hit}" }
                def stamp = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                def receipt = "scripts/results/release-${n}.${stamp}.md"
                sh """#!/bin/bash
set -euo pipefail
r='${receipt}'
{
  echo "# release #${n}：${note ?: '按钉发布'}"
  echo
  echo "- 时间：\$(date -Is)；分支 ${branch}；应用 ${apps.join(', ')}；PIN=${params.PIN}；由 Jenkins 任务 release 生成（${env.BUILD_URL}）"
  echo "- 提交：deploy ${state.commit}；指针 ${state.pointerCommit}；tag ${state.tag}；批准：\$(cat '${out}/8-approval.txt')"
  echo
  echo "## 改钉（2-sources.diff）"; echo; echo '```diff'; cat '${out}/2-sources.diff'; echo '```'; echo
  echo "## 镜像锁（3-image-locks.txt）"; echo; echo '```text'; cat '${out}/3-image-locks.txt'; echo '```'; echo
  echo "## 声明差异（4-gitops.stat；4-workload.diff 前 80 行）"; echo; echo '```text'; cat '${out}/4-gitops.stat'; echo '```'; echo '```diff'; head -80 '${out}/4-workload.diff'; echo '```'; echo
  echo "## 候选与指针（7-source-candidate.yaml / 9-pointer.txt）"; echo; echo '```yaml'; cat '${out}/9-pointer.txt'; echo '```'; echo
  echo "## 部署（10-apply.log 尾部、10-wait.txt）"; echo; echo '```text'; tail -n 15 '${out}/10-apply.log'; cat '${out}/10-wait.txt'; echo '```'; echo
  echo "## 检查（11-check-*.log 尾部）"; echo
  for f in '${out}'/11-check-*.log; do echo "### \$(basename "\$f")"; echo '```text'; tail -n 8 "\$f"; echo '```'; echo; done
  echo "完整控制台与全部产物在 Jenkins 构建页；代理克隆里的分支 abandoned/release-${n} 推送成功后可删。"
} > "\$r"
git add "\$r"
git -c user.name=sunmoon-ci -c user.email=ci@sunmoonai.com commit -q -m "release(kind): 回执 #${n}"
cp "\$r" '${out}/'
git -c url.git@github.com:.insteadOf=https://github.com/ push origin "HEAD:refs/heads/${branch}" "refs/tags/${state.tag}" 2>&1 | tee '${out}/12-push.txt'
# 镜像站（代理准备时按源工位的第二个 push 地址加的 remote mirror）：尽力推，推不上只记下，不算发布失败——GitHub 是真相所在
if git remote get-url mirror >/dev/null 2>&1; then
  git push mirror "HEAD:refs/heads/${branch}" "refs/tags/${state.tag}" 2>&1 | tee -a '${out}/12-push.txt' || echo "MIRROR PUSH FAILED (push by hand: git push mirror ${branch} ${state.tag})" | tee -a '${out}/12-push.txt'
else
  echo "(no mirror remote)" | tee -a '${out}/12-push.txt'
fi
"""
                state.pushed = true
                def mirrorNote = sh(script: "grep -c 'MIRROR PUSH FAILED' '${out}/12-push.txt' || true", returnStdout: true).trim() == '0' ? '' : '；镜像站没推上，见 12-push.txt'
                currentBuild.description = "${note ? note + ' — ' : ''}已发布：${state.tag}，指针 ${state.pointerCommit.take(10)}，回执 ${receipt}${mirrorNote}"
            }
        } finally {
            stage('后半段收尾') {
                def hit = scanSecrets()
                archive()
                if (!state.pushed) {
                    def where = state.pointerCommit ? '集群可能已是新版而 Git 还没推' : '集群未动'
                    // 用工作区的 HEAD，不用 state：第 9 阶段的 shell 块中途失败时 pointerCommit 还没赋值（b4 回执 #6）
                    def headNow = sh(script: 'git rev-parse --short=10 HEAD', returnStdout: true).trim()
                    currentBuild.description = "${note ? note + ' — ' : ''}后半段停下：${where}；提交留在代理克隆 abandoned/release-${n}（${headNow}）"
                    sh "git branch -f 'abandoned/release-${n}' HEAD"
                }
                if (hit) { error "秘密样子核查命中：${hit}" }
            }
        }
    } }
}

return this
