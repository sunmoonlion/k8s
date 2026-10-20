// render-check 的任务体（SDD 0033 第四节末）。由控制器里的引导脚本在宿主代理上 load；
// 跟着分支走，改它就是改检查。只读：核迁移头、渲染声明候选、把候选与 gitops 里已提交的差异存成产物。
// 不暂存、不提交、不发布、不碰 Harbor。make 目标就是人跑的那几个，入口不另造。

def run(params, reposDir) {
    def apps = (params.APPS ?: '').trim() ? params.APPS.trim().split(/\s+/) as List : ['tpl', 'knowfeed', 'knowbase', 'knowbench', 'knowlab', 'knowmart']
    def head = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
    currentBuild.displayName = "#${env.BUILD_NUMBER} ${params.BRANCH}@${head.take(10)}"

    stage('同步应用仓') {
        // 渲染要按钉住的提交读各应用后端的迁移链，所以六个应用仓也要有那些提交
        for (app in apps) {
            dir("${reposDir}/${app}-app") {
                sh "git fetch -q origin '+refs/heads/*:refs/remotes/origin/*' && git checkout -q --detach 'origin/${params.BRANCH}' && git submodule update --init -q"
            }
        }
    }

    stage('有没有新东西') {
        // 定时触发时，上一次核过的提交记在产物里；没变就不重跑
        def marker = "${reposDir}/.render-check.last"
        def last = fileExists(marker) ? readFile(marker).trim() : ''
        if (last == head && !params.FORCE) {
            currentBuild.result = 'NOT_BUILT'
            currentBuild.description = "分支头没变（${head.take(10)}），没跑"
            return
        }
        writeFile file: marker, text: head
    }
    if (currentBuild.result == 'NOT_BUILT') { return }

    stage('迁移头核对') {
        // application-deployment-plan：钉住的后端 alembic 头必须等于 expected_schema_revision（qwen-006 那次会停在这里）
        for (app in apps) {
            sh "make -C infrastructure application-deployment-plan APP=${app}"
        }
    }

    stage('渲染候选') {
        // application-render = 通用渲染器 OBJECT=app-platform/<app>-app；只写 .build/，不写 gitops/
        for (app in apps) {
            sh "make -C infrastructure application-render APP=${app}"
        }
    }

    stage('候选与已提交的差异') {
        // 渲染器把候选写在 infrastructure/.build/components/<路径>，与 gitops/components/<路径> 同形
        //（components/render.yaml 的 build 变量）。剔掉摘要行后看工作负载有没有结构变化；存成产物给人看，不判过不过。
        // sh 步默认用 /bin/sh（本机是 dash，不认 pipefail），所以第一行点名 bash。
        sh '''#!/bin/bash
set -euo pipefail
cand=infrastructure/.build/components/app-platform
out=infrastructure/.build/render-check
mkdir -p "$out"
: > "$out/diff.txt"
for d in "$cand"/*/; do
  [ -d "$d" ] || continue
  app=$(basename "$d")
  while IFS= read -r f; do
    f=${f#./}
    if [ -f "gitops/components/app-platform/$app/$f" ]; then
      diff -u "gitops/components/app-platform/$app/$f" "$d$f" | grep -v -E 'sha256:|digest|^([+]{3}|-{3}) ' >> "$out/diff.txt" || true
    else
      echo "NEW $app/$f" >> "$out/diff.txt"
    fi
  done < <(cd "$d" && find . -name '*.yaml' -not -name '*.sops.yaml' | sort)
done
wc -l "$out/diff.txt"
'''
        archiveArtifacts artifacts: 'infrastructure/.build/render-check/diff.txt', allowEmptyArchive: true
    }

    stage('工作区回到干净') {
        sh 'git status --porcelain --untracked-files=no | head -20; git checkout -q -- gitops infrastructure/applications/sources.yaml 2>/dev/null || true'
    }
}

return this
