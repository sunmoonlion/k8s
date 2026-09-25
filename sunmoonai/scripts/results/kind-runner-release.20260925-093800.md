# KIND investment runner release — 2026-09-25

## 同步与 A 段

- `git pull --ff-only origin fable`：fast-forward 到 `fea0cf1a`。只同步 k8s；其他仓未同步。
- B3 的 A6 清单已逐项核对 `/tmp/investment-dev-20260926`。变化限于清单列出的 backend/web 镜像 digest、来源锁/注解/派生哈希、migration head `20260925_0011` 与 `runtime_identity_upgrade`，7 个 WORKBENCH 配置键、API 与 runner 的可选 Secret 引用，以及 API 出站策略。runner 到 sandbox-pool:47800 的规则已存在于旧 bundle；没有清单外差异。bundle 已更新。
- A1：backend 与 web 镜像 build/push 成功。
- A2：backend `harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:e853345914a3f8814d3baf775deb58b18fe40d976070c15d756e452403feee4d`；web `harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:412b8820a889014959a61a26199965525786c36f6b761babdf3ed16d13a0c85e`。
- A3：backend `e44dc1ff1397c6ddb6a7c5d9fc265fb10b6d6b0b`, tree `ed2996f2d3f888d3bafc57f54693ebdbad6232a1`；web `9eb4c0155c482af43a063f0e169753475d11a22f`, tree `73e17e78a387037b67113930eea3436b654015e1`；admin `2e1f5c67d583be02b43eb36d1052f5b4ad177f45`, tree `169fdb79f12ac7748fca55cd1baa1478417c45c8`。
- A4：development input 与 source lock 已同步，migration head 为 `20260925_0011`，身份准备摘要为 `787744b8adea7cd0998a949ad8f10cbd9e2b434420ad360e7ab226e57d1882ba`。deployment `.conf` 已同步 release/backend/web 声明，admin 未变。
- A5：renderer 返回 `result: rendered`，输出在 `/tmp/investment-dev-20260926`。
- A6：按 B3 新清单审查后替换 bundle；`git diff --check` 通过。
- A7：`verify-formal-instance.py --bundle deployment/bundle` 通过。
- A8：18 项中 17 项通过；仅 `test_committed_development_candidates` 的 knowledge 重渲染失败，与待办注明的 knowledge 源码锁漂移一致。investment、runner、formal component deploy、development release、deployment config 测试通过。
- A9：`plan --cluster KIND` 返回 `result: passed`。

## B 段

- B0：身份探针通过；plan SHA `787744b8adea7cd0998a949ad8f10cbd9e2b434420ad360e7ab226e57d1882ba`，database probes 18，AMQP authenticated roles 3，旧身份已退役。
- B4：API、worker、scheduler 缩容到 0；仅后端 Pod 退出，前端保持运行。
- B5：第一次使用系统 Python 返回 `{"status":"failed","reason":"ModuleNotFoundError"}`，仅因系统环境缺少脚本依赖。保留该次目录不动后，使用 investment-backend app venv 在新目录 `/home/zymun/private/investment-wb-20260926-retry1` 重跑成功。dump SHA256 `3751e0040b04d014fc30fe35f2307580d40db46413d2e728384910d7460ec58e`；18 张表。两轮隔离恢复均 `restore_catalog_equal=true`、`restore_all_rows_equal=true`，head `20260925_0011`，无网络并清理临时库。cutover receipt：`/home/zymun/private/investment-wb-20260926-retry1/cutover-receipt.json`。
- B6：`server-dry-run --cluster KIND` 通过；API 接受 migration Job、runner Deployment/PDB、API 与 runner NetworkPolicy 等资源。
- B7：deploy 命令完整输出已由终端保留；结果 `passed`。迁移 Job 完成并清理；API 2/2、worker 1/1、scheduler 1/1、runner 1/1、admin 2/2、web 2/2 均 rollout 成功。activation `complete.json` 存在且 `grants_only=true`。
- B8：investment Pod 检查显示 runner `1/1 Running`。runner 日志有 Redis/Postgres 初始化与 runner 启动记录；最近 20 行尚未出现轮询日志，也无可见异常。工作台 HTTPS 返回 200，页面标题为“工作台 | SunmoonAI Investment”；未通过交互式浏览器登录，机器/沙箱下拉状态未目视确认。
- B9：drift 返回 `drift: false`；status 显示 6 个 Deployment 均可用，镜像为本次 release digest。

## 限制

本报告不含私有身份材料、数据库 dump、Secret 内容或认证令牌。KIND 页面验证仅确认 HTTPS 页面可达及标题；需要已登录的浏览器会话才能确认工作台空下拉状态。

## B7 部署命令输出（完整）

```text
serviceaccount/investment-backend-api unchanged
serviceaccount/investment-backend-worker unchanged
serviceaccount/investment-backend-scheduler unchanged
serviceaccount/investment-backend-runner created
serviceaccount/investment-backend-migration unchanged
serviceaccount/investment-admin-frontend unchanged
serviceaccount/investment-web-frontend unchanged
configmap/investment-backend-config configured
configmap/investment-admin-frontend-config configured
configmap/investment-web-frontend-config configured
service/investment-backend unchanged
service/investment-admin-frontend unchanged
service/investment-web-frontend unchanged
networkpolicy.networking.k8s.io/investment-default-deny unchanged
networkpolicy.networking.k8s.io/investment-dns-egress unchanged
networkpolicy.networking.k8s.io/investment-frontend-ingress unchanged
networkpolicy.networking.k8s.io/investment-frontend-egress unchanged
networkpolicy.networking.k8s.io/investment-backend-ingress unchanged
networkpolicy.networking.k8s.io/investment-backend-migration-egress unchanged
networkpolicy.networking.k8s.io/investment-backend-api-egress configured
networkpolicy.networking.k8s.io/investment-backend-worker-egress unchanged
networkpolicy.networking.k8s.io/investment-backend-scheduler-egress unchanged
networkpolicy.networking.k8s.io/investment-backend-runner-egress created
job.batch/investment-backend-migration-kind-wb-20260925 created
job.batch/investment-backend-migration-kind-wb-20260925 condition met
job.batch "investment-backend-migration-kind-wb-20260925" deleted from app-platform-dev namespace
deployment.apps/investment-backend-api configured
poddisruptionbudget.policy/investment-backend-api configured
horizontalpodautoscaler.autoscaling/investment-backend-api unchanged
deployment.apps/investment-backend-worker configured
poddisruptionbudget.policy/investment-backend-worker configured
deployment.apps/investment-backend-scheduler configured
deployment.apps/investment-backend-runner created
poddisruptionbudget.policy/investment-backend-runner created
deployment.apps/investment-admin-frontend configured
poddisruptionbudget.policy/investment-admin-frontend configured
horizontalpodautoscaler.autoscaling/investment-admin-frontend unchanged
deployment.apps/investment-web-frontend configured
poddisruptionbudget.policy/investment-web-frontend configured
horizontalpodautoscaler.autoscaling/investment-web-frontend unchanged
ingressroute.traefik.io/investment-admin-route unchanged
ingressroute.traefik.io/investment-web-route unchanged
ingressroute.traefik.io/investment-admin-api-route unchanged
ingressroute.traefik.io/investment-web-api-route unchanged
Waiting for deployment "investment-backend-api" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "investment-backend-api" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "investment-backend-api" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "investment-backend-api" rollout to finish: 1 of 2 updated replicas are available...
deployment "investment-backend-api" successfully rolled out
Waiting for deployment "investment-backend-worker" rollout to finish: 0 of 1 updated replicas are available...
deployment "investment-backend-worker" successfully rolled out
deployment "investment-backend-scheduler" successfully rolled out
deployment "investment-backend-runner" successfully rolled out
Waiting for deployment "investment-admin-frontend" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "investment-admin-frontend" rollout to finish: 1 old replicas are pending termination...
deployment "investment-admin-frontend" successfully rolled out
deployment "investment-web-frontend" successfully rolled out
{
  "task": "app-platform-investment-formal-reconcile",
  "result": "passed",
  "release_id": "kind-wb-20260925",
  "knowledge_active_caller": "investment",
  "legacy_replicas": 0,
  "migration_job_cleaned": true,
  "candidate_ingress_cleaned": true,
  "credentials_printed": false
}
```

## B9 status 输出（保留完整资源清单；gate JSON 展开为单行）

```text
{"task":"app-platform-v2-declarative-instance-gate","result":"passed","formal_release":false,"deployment_target":"KIND","logical_app":"investment","resource_app":"investment","release_id":"kind-wb-20260925","deployments":{"investment-backend-api":2,"investment-backend-worker":1,"investment-backend-scheduler":1,"investment-backend-runner":1,"investment-admin-frontend":2,"investment-web-frontend":2},"ingress_routes":["investment-admin-api-route","investment-admin-route","investment-web-api-route","investment-web-route"],"legacy_deployments_in_bundle":[],"credentials_in_release":false}
NAME                                           READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                                                                                                                                    SELECTOR
deployment.apps/investment-admin-frontend      2/2     2            2           42d    admin        harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:422e7c1e53d5b61eba14bcd242bf73a8e10428f1799e2a6370c1be95cec1923e   app.kubernetes.io/component=admin-frontend,sunmoonai.com/app=investment
deployment.apps/investment-backend-api         2/2     2            2           42d    api          harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:e853345914a3f8814d3baf775deb58b18fe40d976070c15d756e452403feee4d          app.kubernetes.io/component=backend-api,sunmoonai.com/app=investment
deployment.apps/investment-backend-runner      1/1     1            1           4m7s   runner       harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:e853345914a3f8814d3baf775deb58b18fe40d976070c15d756e452403feee4d          app.kubernetes.io/component=backend-runner,sunmoonai.com/app=investment
deployment.apps/investment-backend-scheduler   1/1     1            1           42d    scheduler    harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:e853345914a3f8814d3baf775deb58b18fe40d976070c15d756e452403feee4d          app.kubernetes.io/component=backend-scheduler,sunmoonai.com/app=investment
deployment.apps/investment-backend-worker      1/1     1            1           42d    worker       harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:e853345914a3f8814d3baf775deb58b18fe40d976070c15d756e452403feee4d          app.kubernetes.io/component=backend-worker,sunmoonai.com/app=investment
deployment.apps/investment-web-frontend        2/2     2            2           42d    web          harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:412b8820a889014959a61a26199965525786c36f6b761babdf3ed16d13a0c85e     app.kubernetes.io/component=web-frontend,sunmoonai.com/app=investment
NAME                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
service/investment-admin-frontend   ClusterIP   10.96.199.134   <none>        3000/TCP   42d   app.kubernetes.io/component=admin-frontend,sunmoonai.com/app=investment
service/investment-backend          ClusterIP   10.96.169.197   <none>        8000/TCP   42d   app.kubernetes.io/component=backend-api,sunmoonai.com/app=investment
service/investment-web-frontend     ClusterIP   10.96.94.76   <none>        3000/TCP   42d   app.kubernetes.io/component=web-frontend,sunmoonai.com/app=investment
NAME                                                 AGE
ingressroute.traefik.io/investment-admin-api-route   42d
ingressroute.traefik.io/investment-admin-route       42d
ingressroute.traefik.io/investment-web-api-route      42d
ingressroute.traefik.io/investment-web-route          42d
NAME                                                                  POD-SELECTOR                                                                                     AGE
networkpolicy.networking.k8s.io/investment-backend-api-egress         app.kubernetes.io/component=backend-api,sunmoonai.com/app=investment                             42d
networkpolicy.networking.k8s.io/investment-backend-ingress            app.kubernetes.io/component=backend-api,sunmoonai.com/app=investment                             42d
networkpolicy.networking.k8s.io/investment-backend-migration-egress   app.kubernetes.io/component=backend-migration,sunmoonai.com/app=investment                       42d
networkpolicy.networking.k8s.io/investment-backend-runner-egress      app.kubernetes.io/component=backend-runner,sunmoonai.com/app=investment                          4m22s
networkpolicy.networking.k8s.io/investment-backend-scheduler-egress   app.kubernetes.io/component=backend-scheduler,sunmoonai.com/app=investment                       42d
networkpolicy.networking.k8s.io/investment-backend-worker-egress      app.kubernetes.io/component=backend-worker,sunmoonai.com/app=investment                             42d
networkpolicy.networking.k8s.io/investment-default-deny               sunmoonai.com/app=investment                                                                     42d
networkpolicy.networking.k8s.io/investment-dns-egress                 sunmoonai.com/app=investment                                                                     42d
networkpolicy.networking.k8s.io/investment-frontend-egress            app.kubernetes.io/component in (admin-frontend,web-frontend),sunmoonai.com/app in (investment)   42d
networkpolicy.networking.k8s.io/investment-frontend-ingress           app.kubernetes.io/component in (admin-frontend,web-frontend),sunmoonai.com/app in (investment)   42d
```

B9 drift：`{"result":"passed","action":"drift","drift":false}`。
