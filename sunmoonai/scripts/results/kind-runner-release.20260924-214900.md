# KIND runner 开发包：修复后本地回传

时间：2026-09-24T22:01:47.551095+08:00
本轮范围结论：**pass**（依所有者在本轮对话明确修订的范围）。
A1—A9 已执行；新开发包、两份输入/锁和部署声明留在工作区。B 段未执行。
**A8 原始命令仍 rc=1**：仅 knowledge 已知失败，所有者明确排除本轮；没有修改测试、隐藏失败或宣称全套全绿。

## 被测提交

- `k8s`: `1157a763b14e4e65b7249e337c89f0d7d6804634`
- `tpl-app`: `74ff0c54bc0f778feff4de6feaa67d513eb5ba39`
- `investment-app`: `7b5b205b5ccf8920622a1eeaae83537540d90fd7`
- `investment-app/investment-backend`: `e5084f8b6a525e8f41334c76c1b8081ab3f9fdeb`
- `investment-app/investment-web-frontend`: `f11cb56cd1ee0fc390435873676bd8edec59242d`
- `investment-app/investment-admin-frontend`: `2e1f5c67d583be02b43eb36d1052f5b4ad177f45`

后端 e5084f8 是所有者确认使用的 Pyright 修复版本，父仓 gitlink 一致，三个组件构建前干净。
早先旧提交的失败保留在 `kind-runner-release.20260924-212959.md` 及对应完整日志中。

## 所有者本轮明确补充

1. 源码锁使用新后端提交 e5084f8。
2. 接受 A6 中 API Deployment 新增的可选 WORKBENCH_CREDENTIAL_KEY Secret 引用，继续 A6—A9。
3. 待办漏写了同步 `.conf`：更新 RELEASE_ID、BACKEND_IMAGE、WEB_IMAGE，ADMIN_IMAGE 不动，重跑 A8/A9。
4. knowledge 的开发包/源码锁未跟随知识 MCP 源码更新，留到后续知识 MCP 部署处理；本轮 A8 中 investment 和 info 通过即接受。
5. 所有者说明远程文档补充在 k8s 1a33a4d1，不必同步，直接依上述说明执行。本地 k8s 仍为上列提交，未自行拉取。

## 逐步结果与原始输出

| 步骤 | 实际执行 | 原始退出码 | 完整日志 |
| --- | --- | --- | --- |
| A1 | 构建推送两个镜像 | 0 | [kind-runner-release.20260924-214900.A1.txt](kind-runner-release.20260924-214900.A1.txt) |
| A2 | 读取两个 RepoDigests | 0 | [kind-runner-release.20260924-214900.A2.txt](kind-runner-release.20260924-214900.A2.txt) |
| A3 | 更新源码锁 | 0 | [kind-runner-release.20260924-214900.A3.txt](kind-runner-release.20260924-214900.A3.txt) |
| A4 | 更新 development-input | 0 | [kind-runner-release.20260924-214900.A4.txt](kind-runner-release.20260924-214900.A4.txt) |
| A5 | 渲染到 /tmp/investment-dev | 0 | [kind-runner-release.20260924-214900.A5.txt](kind-runner-release.20260924-214900.A5.txt) |
| A6-diff | 完整 diff（1 表示存在差异） | 1 | [kind-runner-release.20260924-214900.A6-diff.txt](kind-runner-release.20260924-214900.A6-diff.txt) |
| A6-copy | 获准后替换 bundle，旧包已备份 | 0 | [kind-runner-release.20260924-214900.A6-copy.txt](kind-runner-release.20260924-214900.A6-copy.txt) |
| A6-conf | 所有者补充：同步部署声明 | 0 | [kind-runner-release.20260924-214900.A6-conf.txt](kind-runner-release.20260924-214900.A6-conf.txt) |
| A7 | 不可变开发包门禁 | 0 | [kind-runner-release.20260924-214900.A7.txt](kind-runner-release.20260924-214900.A7.txt) |
| A8 | 初次单测：knowledge 与 investment 两处错误 | 1 | [kind-runner-release.20260924-214900.A8.txt](kind-runner-release.20260924-214900.A8.txt) |
| A9 | 初次 plan：声明未同步 | 2 | [kind-runner-release.20260924-214900.A9.txt](kind-runner-release.20260924-214900.A9.txt) |
| A8-retry | 声明同步后单测：仅 knowledge 已知错误 | 1 | [kind-runner-release.20260924-214900.A8-retry.txt](kind-runner-release.20260924-214900.A8-retry.txt) |
| A9-retry | 声明同步后只读 KIND plan | 0 | [kind-runner-release.20260924-214900.A9-retry.txt](kind-runner-release.20260924-214900.A9-retry.txt) |

A1 使用先前验证有效的临时 Docker 代理配置，私有临时目录自动清理，未改全局 Docker 配置或构建脚本。
后端 Ruff/格式/Pyright 通过，两个镜像均 docker push 成功。

## A2 digest

```text
backend=harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:0736b1ee1fccff329c38b8e894c59a7ab847e55c332d3b4f5a47bf75d755e2ed
web=harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:3bf04caa667e9f96181b63aa0c0c6222d6e467631e5b115125377e33f12c2554
admin=harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:422e7c1e53d5b61eba14bcd242bf73a8e10428f1799e2a6370c1be95cec1923e
```

admin digest 沿用原值。
新 release ID：`kind-wb-20260925`；migration head：`20260924_0009`。

## A6 差异审查

- `00-prerequisites.yaml`：新增 runner ServiceAccount；ConfigMap 新增 WORKBENCH_ENABLED、WORKBENCH_REDIS_KEY_PREFIX、WORKBENCH_ENVIRONMENT_KEY、WORKBENCH_POLL_SECONDS；DEPLOYMENT_ID 随指定 release ID 更新。
- `10-migration.yaml`：迁移 Job 名称、release 标签、后端镜像随本次 release 更新。
- `20-runtime.yaml`：API/worker/scheduler 后端镜像和源码注解更新；web 镜像与源码注解更新；新增 runner Deployment（1 副本、Recreate）和 PDB；各配置哈希/release 注解相应更新。API 新增 WORKBENCH_CREDENTIAL_KEY → investment-workbench Secret 的 optional:true 引用，已由所有者明确接受。
- `30-network-policies.yaml`：新增 runner 出站 NetworkPolicy（数据平台 5432/6379，沙箱池 47800）。
- `40-ingress.yaml`：未变。
- `release.json`：更新 release ID、backend/web digest、资源哈希、渲染输入哈希、源码锁任务与后端/web commit/tree、migration head；增加 runner 副本声明。admin digest/commit 不变，formal_release=false、deployment_target=KIND 保持。
- 旧 bundle 留存 `/tmp/inbox06-original-bundle-20260924-214900`；新渲染目录 `/tmp/investment-dev`；当前 bundle 已替换为新包。

源码锁 task 为 workbench-runner-kind-20260925；各组件 remote_branch 仍为 origin/master。
development-input 内的锁与 investment-app/development-source-lock.json 完全一致。
部署声明的 RELEASE_ID、BACKEND_IMAGE、WEB_IMAGE 已按所有者补充同步；ADMIN_IMAGE 保持原值。

## A8 重跑完整输出

```text
time=2026-09-24T21:58:16.863561+08:00
cwd=/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/scripts
command=['python3', '-m', 'unittest', 'tests.test_committed_development_candidates', 'tests.test_investment_runner_role', 'tests.test_formal_component_deploy', 'tests.test_development_release', 'tests.test_deployment_config']
E.................
======================================================================
ERROR: test_all_bundles_reproduce_and_match_declarations (tests.test_committed_development_candidates.CommittedCandidatesTest.test_all_bundles_reproduce_and_match_declarations) (app='knowledge')
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/scripts/tests/test_committed_development_candidates.py", line 35, in test_all_bundles_reproduce_and_match_declarations
    subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
  File "/usr/lib/python3.12/subprocess.py", line 571, in run
    raise CalledProcessError(retcode, process.args,
subprocess.CalledProcessError: Command '['/usr/bin/python3', '-B', '/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/knowledge-app/deployment/render.py', '--output-dir', '/tmp/committed-release-wce4qlxp/bundle', '--release-id', 'kind-b7-20260919', '--development-input', '/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/knowledge-app/deployment/development-input.json', '--ingestion-dataset-bindings-file', '/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/knowledge-app/deployment/ingestion-dataset-bindings.kind.json']' returned non-zero exit status 1.

----------------------------------------------------------------------
Ran 18 tests in 1.715s

FAILED (errors=1)

exit=1
```

解读：18 个测试方法中，该跨 App 方法的 knowledge 子测试仍报错；info 和 investment 子测试均完成且没有报错，其余方法通过。knowledge 的根因由所有者说明为既有源码锁失配，本轮没有修改它。

## A9 重跑完整输出

```text
time=2026-09-24T21:58:19.410526+08:00
cwd=/home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/investment-app
command=['./deploy-investment-app-all/deploy-investment-app-all.sh', 'plan', '--cluster', 'KIND']
{
  "task": "app-platform-v2-declarative-instance-gate",
  "result": "passed",
  "formal_release": false,
  "deployment_target": "KIND",
  "logical_app": "investment",
  "resource_app": "investment",
  "release_id": "kind-wb-20260925",
  "deployments": {
    "investment-backend-api": 2,
    "investment-backend-worker": 1,
    "investment-backend-scheduler": 1,
    "investment-backend-runner": 1,
    "investment-admin-frontend": 2,
    "investment-web-frontend": 2
  },
  "ingress_routes": [
    "investment-admin-api-route",
    "investment-admin-route",
    "investment-web-api-route",
    "investment-web-route"
  ],
  "legacy_deployments_in_bundle": [],
  "credentials_in_release": false
}
{
  "result": "passed",
  "action": "plan",
  "schema_version": 2,
  "architecture": "app-platform-v2-development",
  "logical_app": "investment",
  "resource_app": "investment",
  "namespace": "app-platform-dev",
  "release_id": "kind-wb-20260925",
  "formal_release": false,
  "images": {
    "backend": "harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:0736b1ee1fccff329c38b8e894c59a7ab847e55c332d3b4f5a47bf75d755e2ed",
    "admin": "harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:422e7c1e53d5b61eba14bcd242bf73a8e10428f1799e2a6370c1be95cec1923e",
    "web": "harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:3bf04caa667e9f96181b63aa0c0c6222d6e467631e5b115125377e33f12c2554"
  },
  "origins": {
    "admin": "https://investment-admin.sunmoonai.com:30443",
    "web": "https://investment.sunmoonai.com:30443",
    "casdoor": "https://casdoor.sunmoonai.com:30443"
  },
  "resources": [
    "00-prerequisites.yaml",
    "10-migration.yaml",
    "20-runtime.yaml",
    "30-network-policies.yaml",
    "40-ingress.yaml"
  ],
  "sha256": {
    "00-prerequisites.yaml": "39ca243764459756c4353d268fac1b29ce37e8674582696cb2d2d859726737e2",
    "10-migration.yaml": "c13d433c07b8fa253213e098a4850b267715697ab54d223cde4b9fb877489615",
    "20-runtime.yaml": "aeb43ba5a1503643b8b1c9edb5c553734e0fc5cadebf5495b57ff7f6a97bf725",
    "30-network-policies.yaml": "59c129390e4460ee438f28ceda67c9b767c7183bbfa538cde33227ac0836cb9c",
    "40-ingress.yaml": "9f5fa10feb105cf71e9e796d35c1a64044c774b453c39948409d00177bbbeafd"
  },
  "deployment_replicas": {
    "investment-backend-api": 2,
    "investment-backend-worker": 1,
    "investment-backend-scheduler": 1,
    "investment-backend-runner": 1,
    "investment-admin-frontend": 2,
    "investment-web-frontend": 2
  },
  "ingress_routes": {
    "investment-admin-route": [
      {
        "match": "Host(`investment-admin.sunmoonai.com`) && PathPrefix(`/api`)",
        "priority": 100,
        "services": [
          {
            "name": "investment-backend",
            "port": 8000
          }
        ]
      },
      {
        "match": "Host(`investment-admin.sunmoonai.com`) && PathPrefix(`/`)",
        "priority": 10,
        "services": [
          {
            "name": "investment-admin-frontend",
            "port": 3000
          }
        ]
      }
    ],
    "investment-web-route": [
      {
        "match": "Host(`investment.sunmoonai.com`) && PathPrefix(`/api`)",
        "priority": 100,
        "services": [
          {
            "name": "investment-backend",
            "port": 8000
          }
        ]
      },
      {
        "match": "Host(`investment.sunmoonai.com`) && PathPrefix(`/`)",
        "priority": 10,
        "services": [
          {
            "name": "investment-web-frontend",
            "port": 3000
          }
        ]
      }
    ],
    "investment-admin-api-route": [
      {
        "match": "Host(`investment-admin-api.sunmoonai.com`) && PathPrefix(`/`)",
        "priority": null,
        "services": [
          {
            "name": "investment-backend",
            "port": 8000
          }
        ]
      }
    ],
    "investment-web-api-route": [
      {
        "match": "Host(`investment-api.sunmoonai.com`) && PathPrefix(`/`)",
        "priority": null,
        "services": [
          {
            "name": "investment-backend",
            "port": 8000
          }
        ]
      }
    ]
  },
  "legacy_deployments": [],
  "external_secrets": [
    "harbor-registry-secret",
    "investment-tls",
    "investment-backend-runtime",
    "investment-backend-migration-postgresql-conn",
    "investment-browser-identity",
    "investment-backend-redis-conn",
    "investment-knowledge-retrieval-client"
  ],
  "knowledge_binding": "knowledge-active-retrieval-service-binding",
  "forbidden_markers": [
    "investment-admin-r5.sunmoonai.com",
    "investment-web-r5.sunmoonai.com",
    "investment.r5.candidate",
    "research-admin-backend-postgresql-conn"
  ],
  "contains_credentials": false,
  "renderer_inputs_sha256": {
    "k8s:sunmoonai/app-platform/scripts/render_investment_release_base.py": "24daad848830c9836c635b7ba8f8813d7e5bbac4cb4b06923fbba0d47bb01bfa",
    "tpl-app:k8s-deployment/scaffold.py": "eb625d86f9a3b75111d8b2605c23152b759e7b2e04eb9d8661bb1a67def90c33",
    "tpl-app:k8s-deployment/templates/00-prerequisites.yaml.tpl": "31bdecaf21010840bb5b00fefdbd6f59f804b9c7dadfb606bcb429b7f4418334",
    "tpl-app:k8s-deployment/templates/10-migration.yaml.tpl": "2a78b9770f61b94cc267f267449b0e0593b147a61a444a7463fe4f3fcc1508f4",
    "tpl-app:k8s-deployment/templates/20-runtime.yaml.tpl": "93bade1d5c9e96a0a4708bd76e88f90e15fa7a7c54a9a118adb993c492eb866e",
    "tpl-app:k8s-deployment/templates/30-network-policies.yaml.tpl": "b8018d309f7e7d9ec5c72fd463d0b44f8a091e197fa1b47a9a110f36ae59261d",
    "tpl-app:k8s-deployment/templates/40-ingress.yaml.tpl": "5f79e6a40bdfa8a581b92eeabe1a9f0cbf3a031221f5c9a40708b4682190ce3d",
    "development-release-input": "e0f581a6fd2e2b63387af67872ac36821d3ea16f38aa9b911fc666a57a0be780",
    "k8s:sunmoonai/app-platform/scripts/development_release.py": "49a26804e03f6481e09e45430ccdadf997383c546aacda6202ffb013fd4f16c8"
  },
  "deployment_target": "KIND",
  "development_source_lock": {
    "schema_version": 1,
    "kind": "development-source-lock",
    "repository": "investment-app",
    "formal_release": false,
    "task": "workbench-runner-kind-20260925",
    "release_boundary": "Immutable development candidate source; actual deployment requires the matching KIND release, prepared independent identities, and verified quiescent backup.",
    "components": [
      {
        "path": "investment-backend",
        "commit": "e5084f8b6a525e8f41334c76c1b8081ab3f9fdeb",
        "tree": "4b86416abeefa5c085dad5317107d5df1e4dec87",
        "remote_branch": "origin/master"
      },
      {
        "path": "investment-admin-frontend",
        "commit": "2e1f5c67d583be02b43eb36d1052f5b4ad177f45",
        "tree": "169fdb79f12ac7748fca55cd1baa1478417c45c8",
        "remote_branch": "origin/master"
      },
      {
        "path": "investment-web-frontend",
        "commit": "f11cb56cd1ee0fc390435873676bd8edec59242d",
        "tree": "e6ca30745beddc81d507f4e27c9d94489fc5e8b4",
        "remote_branch": "origin/master"
      }
    ]
  },
  "migration_head": "20260924_0009",
  "runtime_identity_mode": "independent-v1"
}

exit=0
```

## 覆盖与交回

查了：真实镜像构建/推送、镜像 digest、源码 commit/tree、渲染差异、门禁、指定单测、只读部署 plan。
没查：真实部署、迁移和运行时业务；B 段仍等所有者确定流程。
结果与产物均留在工作区；未提交或推送 git，未移动 inbox/done。
最后退出码保留 A8 原始非零值，不代表否定所有者已明确接受的本轮范围；各步骤实际退出码见上表。

exit=1
