# release #7：tpl ingress 补 /api/internal 收敛规则

- 时间：2026-10-21T00:14:48+08:00；分支 fable；应用 tpl；PIN=keep；由 Jenkins 任务 release 生成（https://jenkins.sunmoonai.com:30443/job/release/7/）
- 提交：deploy ef103e4db89ec082e7819ff57fb106f3a8f889cc；指针 a7985bffdcb20ba75c00b93102c5bcb836bb328c；tag release-20261021-1；批准：批准人 admin  2026-10-21T00:10:57+08:00

## 改钉（2-sources.diff）

```diff
```

## 镜像锁（3-image-locks.txt）

```text
(no image lock changed: same pins rebuilt to the same digests)
```

## 声明差异（4-gitops.stat；4-workload.diff 前 80 行）

```text
 .../components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml  | 4 ++++
 gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml | 4 ++++
 2 files changed, 8 insertions(+)
```
```diff
+++ b/gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml
@@ -79,6 +79,10 @@ spec:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-admin, port: {number: 3000}}}
+++ b/gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml
@@ -79,6 +79,10 @@ spec:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-web, port: {number: 3000}}}
```

## 候选与指针（7-source-candidate.yaml / 9-pointer.txt）

```yaml
digest: sha256:44f56adc0b3b9db50e1adae244da164605d12669b2e4da959e92e33384db1788
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: ef103e4db89ec082e7819ff57fb106f3a8f889cc
pointer-commit a7985bffdcb20ba75c00b93102c5bcb836bb328c
tag release-20261021-1
```

## 部署（10-apply.log 尾部、10-wait.txt）

```text

TASK [Require current generation Ready with the exact promoted digest] *********
ok: [localhost] => (item=ocirepository)
ok: [localhost] => (item=kustomization)

TASK [Require digest selection and reconciliation revision to agree] ***********
ok: [localhost]

TASK [Verify the actual declared platform release marker] **********************
ok: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=38   changed=3    unreachable=0    failed=0    skipped=28   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure'
kustomization.kustomize.toolkit.fluxcd.io/tpl-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-database condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-web condition met
```

## 检查（11-check-*.log 尾部）

### 11-check-tpl.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=45   changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure'
```

完整控制台与全部产物在 Jenkins 构建页；代理克隆里的分支 abandoned/release-7 推送成功后可删。
