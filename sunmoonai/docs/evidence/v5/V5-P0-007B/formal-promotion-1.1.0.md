# P0-007B Info Admin 正式镜像固化清单

状态：`READY_FOR_OPERATOR_PROMOTION`

## 范围

本清单只固化已经完成 P0-007B 真实业务试点并通过 P0-007C 模板冻结的 Info
React Admin。它不固化 Knowledge/Research；两者当前仍是 Vue 基线，必须等待各自
React 等价迁移和独立验收。

旧正式版本 `1.0.1` 继续保留为 Vue 回滚基线，不覆盖、不删除。`p0-*` candidate
也保留为审计和回滚证据，不作为普通部署默认值。

## Candidate 输入（不可变）

| 组件 | candidate | 期望 manifest digest |
| --- | --- | --- |
| Info Admin backend + celeryworker | `info-admin-backend:p0-007b-concurrency-20260714` | `sha256:d665089b011e798d2be0da2ad3f17c182259869fb970a7abfb14872214707dea` |
| Info Admin frontend | `info-admin-frontend:p0-007b-concurrency-20260714` | `sha256:3c1a7e4ad40d5e0abea4f7ad629ac6362216c4ea7cd910f3d1f2c8620ee6cd8b` |

这些 digest 已通过严格 TLS、浏览器身份、CSP、mutation、并发、恢复和无外连矩阵。
Promotion 前仍必须由执行者通过 registry inspect 复核，不能只相信本地 tag。

## Promotion 规则

1. 先确认源 candidate 的远程 digest 与上表一致。
2. 先确认目标 `1.1.0` 尚不存在；若已存在，停止并人工核对，不得覆盖既有 tag。
3. 将同一镜像内容推为正式 tag `1.1.0`；不得重新 build、修改 Dockerfile 或用新源码覆盖。
4. 复核 `1.1.0` 的远程 digest 与源 candidate 一致。
5. 仅将 Info Admin backend、celeryworker 和 frontend 的部署配置切到 `1.1.0`；Info Web、Knowledge、Research 不在本次切换范围。
6. 完成 rollout、imageID/digest 核对、匿名/身份/CSRF/业务 mutation/浏览器和回滚验证后，才能把本清单改为 `ACCEPTED`。

## 推荐执行命令

网络和 Harbor 操作由 operator 执行；可在本地已有 candidate 镜像上运行：

```bash
set -e

BACKEND=harbor.sunmoonai.com:30443/app-images/info-admin-backend
FRONTEND=harbor.sunmoonai.com:30443/app-images/info-admin-frontend

docker pull "$BACKEND:p0-007b-concurrency-20260714"
docker pull "$FRONTEND:p0-007b-concurrency-20260714"

docker tag "$BACKEND:p0-007b-concurrency-20260714" "$BACKEND:1.1.0"
docker tag "$FRONTEND:p0-007b-concurrency-20260714" "$FRONTEND:1.1.0"

docker push "$BACKEND:1.1.0"
docker push "$FRONTEND:1.1.0"

docker buildx imagetools inspect "$BACKEND:1.1.0"
docker buildx imagetools inspect "$FRONTEND:1.1.0"
```

只有两个 inspect 结果都与上表一致，才执行 KIND 部署：

```bash
cd /home/zymun/k8s

INFO_ADMIN_BACKEND_TAG=1.1.0 \
CELERYWORKER_INFO_ADMIN_BACKEND_TAG=1.1.0 \
INFO_ADMIN_FRONTEND_TAG=1.1.0 \
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  deploy --cluster KIND
```

部署后必须核对三个 Deployment 的镜像和 imageID；正式路径保持
`V5_FRONTEND_TEST_MODE=false`，禁止用隔离测试开关绕过 `p0-*` tag 门禁。

## 回滚

若任一门禁失败，立即使用旧 Vue 基线恢复：

```bash
cd /home/zymun/k8s

INFO_ADMIN_BACKEND_TAG=1.0.1 \
CELERYWORKER_INFO_ADMIN_BACKEND_TAG=1.0.1 \
INFO_ADMIN_FRONTEND_TAG=1.0.1 \
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  deploy --cluster KIND
```

回滚完成并重新核对 imageID 后，`1.1.0` 仍保留以便复盘；不得删除 candidate、旧
`1.0.1` 或通过复用 tag 隐藏失败版本。
