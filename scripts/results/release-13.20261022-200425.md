# release #13：C2b 开发站点改 dev.sunmoonai.com（第四次，浏览器验收端口修复）

- 时间：2026-10-22T20:04:25+08:00；分支 fable；应用 tpl, knowfeed, knowbase, knowbench, knowlab, knowmart；PIN=keep；由 Jenkins 任务 release 生成（https://jenkins.dev.sunmoonai.com:30443/job/release/13/）
- 提交：deploy 115b593340ef8f24221712fb95b49ff38c845dba；指针 98bd736d0515684627e7357cd54f5cccc1e21c6a；tag release-20261022-4；批准：批准人 admin  2026-10-22T19:53:58+08:00

## 改钉（2-sources.diff）

```diff
```

## 镜像锁（3-image-locks.txt）

```text
gitops/components/app-platform/knowbase-app/knowbase-admin-frontend/image.lock.yaml: digest: sha256:a8dcfbd497d4fe4745cfd59da0574259177ba62fabe1fca2962798d6a2a650a5 source_revision: f097495080ef6ef7296beb0fcc9430b4079d8011 
gitops/components/app-platform/knowbase-app/knowbase-backend/image.lock.yaml: digest: sha256:52e6b4ffea7b6af1a25d0a9f448e8e16bfc70f471355314f8a68fd9fe9f82fae source_revision: ad1e2edcceb88e43df0842e1fe3be215406b855a 
gitops/components/app-platform/knowbase-app/knowbase-web-frontend/image.lock.yaml: digest: sha256:543ccea19e2023d0994ba0b0f73b0cf790ec07d45ebb2296f5547f31b0042984 source_revision: 8c338db2b7222702f71cef892fd283016c148210 
gitops/components/app-platform/knowbench-app/knowbench-admin-frontend/image.lock.yaml: digest: sha256:07ba70d1c2800ffc4439299ef74a6614774ca1125bdd205be1cb5bdcdcebb2d8 source_revision: 26964553ed9d581ac855c38edeaee8e65add792f 
gitops/components/app-platform/knowbench-app/knowbench-backend/image.lock.yaml: digest: sha256:cbd889f4674e1f52fd3c92e47f02132de71ad9a5b7eeb33e09ed0ce88ef19604 source_revision: 44888e23934fc50479fb0ddba978e794f62236a4 
gitops/components/app-platform/knowbench-app/knowbench-web-frontend/image.lock.yaml: digest: sha256:b73915d362578aee50c1c16bfc160829c2972633c9a1a5cc060ca0d93c67e9fd source_revision: 4748b94ebf589ee870ca5efa097f212a59a1d04e 
gitops/components/app-platform/knowfeed-app/knowfeed-admin-frontend/image.lock.yaml: digest: sha256:a2269f8197764c49e0e606bd853f0de148f287ab655bd8524347dd782203347f source_revision: b344c106c4f44522770b8cca3e9a8121e0b3ce32 
gitops/components/app-platform/knowfeed-app/knowfeed-backend/image.lock.yaml: digest: sha256:515ccfdb37de079cb03d9cfc6a08287b411f8a896ca724f51b0abf13ab80ede2 source_revision: 6239d224d9b2fc5bd4be03923800b5cd40490e8d 
gitops/components/app-platform/knowfeed-app/knowfeed-web-frontend/image.lock.yaml: digest: sha256:f7cab49c2d3c735cf3d5b07a135f56f2012f7a1f167d8e7a77144351c8664b2e source_revision: bca159f76befc47b1b38e7028c0f63c68b334759 
gitops/components/app-platform/knowlab-app/knowlab-admin-frontend/image.lock.yaml: digest: sha256:63c78b382f1eb0ee6c87523fa1e66ddbd3e7ddf03fca371ab70090819ac29a8a source_revision: 2d5c1124c0b3f76ec0efda2371fadbd5f13787b0 
gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml: digest: sha256:16b489d0aff64b2be7d076d647c1582ef415ef4dbf21dae60cacc7d9f4567eb8 source_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad 
gitops/components/app-platform/knowlab-app/knowlab-web-frontend/image.lock.yaml: digest: sha256:5df261c550b383290f19dac96294d1d374c6292499baca65fb1955e5ebee30d1 source_revision: d7589583436d7d42d90e390f91508acb6ed76a39 
gitops/components/app-platform/knowmart-app/knowmart-admin-frontend/image.lock.yaml: digest: sha256:1af12695257e262dc53d4dac7755d18b4e2148ebde7387e688e997e41c893010 source_revision: 107fda29642e9bf7259af274fa6d6c991302bfeb 
gitops/components/app-platform/knowmart-app/knowmart-backend/image.lock.yaml: digest: sha256:3a754bcd1f2e4196969b64dbbc140460d6d503a111b188fe70f372962bad0cd4 source_revision: c00eebf376e804984f3eabd070daaed50573cc13 
gitops/components/app-platform/knowmart-app/knowmart-web-frontend/image.lock.yaml: digest: sha256:fc58c9e43d73271fd94e58a23acc0451024d48afd40e8c76acd6663b794e8fd3 source_revision: 50e280ea37609f0ca198a5d1308aa02bc4074dc8 
gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml: digest: sha256:53ed12d5f5fc2bd13ec384529eeca4f6ccad564b1d0ff0a320fc9df518753ed4 source_revision: b89e474191109d807cdd50d56ecea971c0269a4a 
gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml: digest: sha256:79e6b4a2b828afe2b0d6460a441f9ea06964fca47bb6d6d4d53287c3f1f9d1b2 source_revision: ab7139389cbc40a04459a3403ffc5ee4c8e26d89 
gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml: digest: sha256:01178c08009e0e7778bef51fec0ae1300065fa441d41d4b86f82ec999ae25d39 source_revision: 479c7e6ce6e69a5e4daf41bb55aed5f3b95a87c7 
```

## 声明差异（4-gitops.stat；4-workload.diff 前 80 行）

```text
 .../knowbase-admin-frontend/image.lock.yaml        |  4 +-
 .../knowbase-admin-frontend/workload.yaml          | 10 ++---
 .../knowbase-backend/identity/workload.yaml        | 48 +++++++++++++++-------
 .../knowbase-app/knowbase-backend/image.lock.yaml  |  4 +-
 .../knowbase-backend/migration/workload.yaml       |  8 ++--
 .../knowbase-backend/rabbitmq/workload.yaml        |  4 +-
 .../knowbase-backend/redis/workload.yaml           |  4 +-
 .../knowbase-backend/runtime/tls.sops.yaml         | 18 ++++----
 .../knowbase-backend/runtime/workload.yaml         | 24 +++++------
 .../knowbase-web-frontend/image.lock.yaml          |  4 +-
 .../knowbase-web-frontend/workload.yaml            | 10 ++---
 .../knowbench-admin-frontend/image.lock.yaml       |  4 +-
 .../knowbench-admin-frontend/workload.yaml         | 12 +++---
 .../knowbench-backend/identity/workload.yaml       | 48 +++++++++++++++-------
 .../knowbench-backend/image.lock.yaml              |  4 +-
 .../knowlab-read-identity/workload.yaml            |  6 +--
 .../knowmart-summon-identity/workload.yaml         |  6 +--
 .../knowbench-backend/migration/workload.yaml      |  8 ++--
 .../knowbench-backend/rabbitmq/workload.yaml       |  4 +-
 .../knowbench-backend/redis/workload.yaml          |  4 +-
 .../runtime/agent-releases.sops.yaml               | 22 +++++-----
 .../knowbench-backend/runtime/tls.sops.yaml        | 18 ++++----
 .../knowbench-backend/runtime/workload.yaml        | 32 +++++++--------
 .../service-identity/workload.yaml                 |  6 +--
 .../knowbench-web-frontend/image.lock.yaml         |  4 +-
 .../knowbench-web-frontend/workload.yaml           | 10 ++---
 .../knowfeed-admin-frontend/image.lock.yaml        |  4 +-
 .../knowfeed-admin-frontend/workload.yaml          | 10 ++---
 .../knowfeed-backend/identity/workload.yaml        | 48 +++++++++++++++-------
 .../knowfeed-app/knowfeed-backend/image.lock.yaml  |  4 +-
 .../knowfeed-backend/migration/workload.yaml       |  8 ++--
 .../knowfeed-backend/rabbitmq/workload.yaml        |  4 +-
 .../knowfeed-backend/redis/workload.yaml           |  4 +-
 .../knowfeed-backend/runtime/tls.sops.yaml         | 18 ++++----
 .../knowfeed-backend/runtime/workload.yaml         | 22 +++++-----
 .../service-identity/workload.yaml                 |  6 +--
 .../knowfeed-web-frontend/image.lock.yaml          |  4 +-
 .../knowfeed-web-frontend/workload.yaml            | 10 ++---
 .../knowlab-admin-frontend/image.lock.yaml         |  4 +-
 .../knowlab-admin-frontend/workload.yaml           | 10 ++---
 .../knowlab-backend/identity/workload.yaml         | 48 +++++++++++++++-------
 .../knowlab-app/knowlab-backend/image.lock.yaml    |  4 +-
 .../knowbench-testrun-identity/workload.yaml       |  6 +--
 .../knowmart-deliver-identity/workload.yaml        |  6 +--
 .../knowlab-backend/migration/workload.yaml        |  8 ++--
 .../knowlab-backend/rabbitmq/workload.yaml         |  4 +-
 .../knowlab-backend/redis/workload.yaml            |  4 +-
 .../knowlab-backend/runtime/tls.sops.yaml          | 18 ++++----
 .../knowlab-backend/runtime/workload.yaml          | 22 +++++-----
 .../knowlab-web-frontend/image.lock.yaml           |  4 +-
 .../knowlab-app/knowlab-web-frontend/workload.yaml | 10 ++---
 .../knowmart-admin-frontend/image.lock.yaml        |  4 +-
 .../knowmart-admin-frontend/workload.yaml          | 10 ++---
 .../knowmart-backend/identity/workload.yaml        | 48 +++++++++++++++-------
 .../knowmart-app/knowmart-backend/image.lock.yaml  |  4 +-
 .../knowmart-backend/migration/workload.yaml       |  8 ++--
 .../knowmart-backend/rabbitmq/workload.yaml        |  4 +-
 .../knowmart-backend/redis/workload.yaml           |  4 +-
 .../knowmart-backend/runtime/tls.sops.yaml         | 18 ++++----
 .../knowmart-backend/runtime/workload.yaml         | 24 +++++------
 .../knowmart-web-frontend/image.lock.yaml          |  4 +-
 .../knowmart-web-frontend/workload.yaml            | 10 ++---
 .../tpl-app/tpl-admin-frontend/image.lock.yaml     |  4 +-
 .../tpl-app/tpl-admin-frontend/workload.yaml       | 10 ++---
 .../tpl-app/tpl-backend/identity/workload.yaml     | 48 +++++++++++++++-------
 .../tpl-app/tpl-backend/image.lock.yaml            |  4 +-
 .../tpl-app/tpl-backend/migration/workload.yaml    |  8 ++--
 .../tpl-app/tpl-backend/rabbitmq/workload.yaml     |  4 +-
 .../tpl-app/tpl-backend/redis/workload.yaml        |  4 +-
 .../tpl-app/tpl-backend/runtime/tls.sops.yaml      | 18 ++++----
 .../tpl-app/tpl-backend/runtime/workload.yaml      | 16 ++++----
 .../tpl-app/tpl-web-frontend/image.lock.yaml       |  4 +-
 .../tpl-app/tpl-web-frontend/workload.yaml         | 10 ++---
 73 files changed, 502 insertions(+), 382 deletions(-)
```
```diff
+++ b/gitops/components/app-platform/knowbase-app/knowbase-admin-frontend/image.lock.yaml
@@ -1,6 +1,6 @@
+++ b/gitops/components/app-platform/knowbase-app/knowbase-admin-frontend/workload.yaml
@@ -20,16 +20,16 @@ spec:
-            - {name: APP_ORIGIN, value: "https://knowbase-admin.sunmoonai.com:30443"}
+            - {name: APP_ORIGIN, value: "https://knowbase-admin.dev.sunmoonai.com:30443"}
-            - {name: DEPLOYMENT_ID, value: "knowbase-admin-frontend-75bd503601b746e8"}
+            - {name: DEPLOYMENT_ID, value: "knowbase-admin-frontend-a8dcfbd497d4fe47"}
@@ -74,9 +74,9 @@ metadata:
-  tls: [{hosts: [knowbase-admin.sunmoonai.com], secretName: knowbase-tls}]
+  tls: [{hosts: [knowbase-admin.dev.sunmoonai.com], secretName: knowbase-tls}]
-    - host: knowbase-admin.sunmoonai.com
+    - host: knowbase-admin.dev.sunmoonai.com
+++ b/gitops/components/app-platform/knowbase-app/knowbase-backend/identity/workload.yaml
@@ -1,6 +1,6 @@
@@ -40,6 +40,7 @@ data:
+        domain_migrated = []
@@ -151,6 +152,25 @@ data:
+                # SDD 0039 C2b: the third allowed migration, only when the site domain changed. The
+                # registered origin (homepageUrl) must be another exact HTTPS origin, and swapping it for
+                # the new origin in every registered redirect URI must give exactly the desired list.
+                # Client ID, secret, organization and every other field must already match.
+                domain_keys = {'redirectUris', 'homepageUrl'}
+                drift = {k for k, v in desired.items() if existing.get(k) != v}
+                old_origin = existing.get('homepageUrl') or ''
+                old = urlsplit(old_origin)
+                moved_uris = [config['origin'] + u[len(old_origin):] if u.startswith(old_origin + '/') else u
+                              for u in existing.get('redirectUris') or []]
+                if (drift and drift <= domain_keys and old_origin != config['origin']
+                        and old.scheme == 'https' and old.hostname and not old.username and not old.password
+                        and old.path in ('', '/') and not old.query and not old.fragment
+                        and moved_uris == desired['redirectUris']):
+                    changed = api('POST', '/api/update-application', dict(existing, **{k: desired[k] for k in drift}),
+                                  params={'id': 'admin/' + config['name']})
+                    require(changed == 'Affected', 'Site domain move was not applied')
+                    domain_migrated.append(surface)
+                    existing = api('GET', '/api/get-application', params={'id': 'admin/' + config['name']})
@@ -165,7 +185,7 @@ data:
-                          'single_sign_on_migrated': sso_migrated, 'single_sign_on': ['web'],
+                          'single_sign_on_migrated': sso_migrated, 'domain_migrated': domain_migrated, 'single_sign_on': ['web'],
@@ -207,7 +227,7 @@ spec:
@@ -221,16 +241,16 @@ spec:
-            - {name: CASDOOR_ORIGIN, value: 'https://casdoor.sunmoonai.com:30443'}
+            - {name: CASDOOR_ORIGIN, value: 'https://casdoor.dev.sunmoonai.com:30443'}
-              value: "{\"web\": {\"name\": \"sunmoonai-knowbase-web\", \"client_id\": \"sunmoon-kind-knowbase-web\", \"origin\": \"https://knowbase.sunmoonai.com:30443\"}, \"admin\": {\"name\": \"sunmoonai-knowbase-admin\", \"client_id\": \"sunmoon-kind-knowbase-admin\", \"origin\": \"https://knowbase-admin.sunmoonai.com:30443\"}}"
+              value: "{\"web\": {\"name\": \"sunmoonai-knowbase-web\", \"client_id\": \"sunmoon-kind-knowbase-web\", \"origin\": \"https://knowbase.dev.sunmoonai.com:30443\"}, \"admin\": {\"name\": \"sunmoonai-knowbase-admin\", \"client_id\": \"sunmoon-kind-knowbase-admin\", \"origin\": \"https://knowbase-admin.dev.sunmoonai.com:30443\"}}"
@@ -239,7 +259,7 @@ spec:
-        - {name: script, configMap: {name: 'knowbase-identity-provision-v4'}}
+        - {name: script, configMap: {name: 'knowbase-identity-provision-v5'}}
@@ -248,18 +268,18 @@ apiVersion: v1
-  CASDOOR_ENDPOINT: 'https://casdoor.sunmoonai.com:30443'
+  CASDOOR_ENDPOINT: 'https://casdoor.dev.sunmoonai.com:30443'
-  WEB_CASDOOR_REDIRECT_URI: 'https://knowbase.sunmoonai.com:30443/api/auth/web/callback'
-  WEB_FRONTEND_BASE_URL: 'https://knowbase.sunmoonai.com:30443'
-  WEB_FRONTEND_ALLOWED_ORIGINS: 'https://knowbase.sunmoonai.com:30443'
+  WEB_CASDOOR_REDIRECT_URI: 'https://knowbase.dev.sunmoonai.com:30443/api/auth/web/callback'
+  WEB_FRONTEND_BASE_URL: 'https://knowbase.dev.sunmoonai.com:30443'
+  WEB_FRONTEND_ALLOWED_ORIGINS: 'https://knowbase.dev.sunmoonai.com:30443'
-  ADMIN_CASDOOR_REDIRECT_URI: 'https://knowbase-admin.sunmoonai.com:30443/api/auth/admin/callback'
-  ADMIN_FRONTEND_BASE_URL: 'https://knowbase-admin.sunmoonai.com:30443'
-  ADMIN_FRONTEND_ALLOWED_ORIGINS: 'https://knowbase-admin.sunmoonai.com:30443'
+  ADMIN_CASDOOR_REDIRECT_URI: 'https://knowbase-admin.dev.sunmoonai.com:30443/api/auth/admin/callback'
+  ADMIN_FRONTEND_BASE_URL: 'https://knowbase-admin.dev.sunmoonai.com:30443'
+  ADMIN_FRONTEND_ALLOWED_ORIGINS: 'https://knowbase-admin.dev.sunmoonai.com:30443'
+++ b/gitops/components/app-platform/knowbase-app/knowbase-backend/image.lock.yaml
@@ -1,6 +1,6 @@
+++ b/gitops/components/app-platform/knowbase-app/knowbase-backend/migration/workload.yaml
@@ -58,7 +58,7 @@ data:
@@ -72,7 +72,7 @@ spec:
@@ -80,8 +80,8 @@ spec:
-            - {name: ADMIN_FRONTEND_BASE_URL, value: 'https://knowbase-admin.sunmoonai.com:30443'}
-            - {name: WEB_FRONTEND_BASE_URL, value: 'https://knowbase.sunmoonai.com:30443'}
+            - {name: ADMIN_FRONTEND_BASE_URL, value: 'https://knowbase-admin.dev.sunmoonai.com:30443'}
+            - {name: WEB_FRONTEND_BASE_URL, value: 'https://knowbase.dev.sunmoonai.com:30443'}
+++ b/gitops/components/app-platform/knowbase-app/knowbase-backend/rabbitmq/workload.yaml
@@ -158,7 +158,7 @@ spec:
@@ -172,7 +172,7 @@ spec:
+++ b/gitops/components/app-platform/knowbase-app/knowbase-backend/redis/workload.yaml
@@ -102,7 +102,7 @@ spec:
@@ -116,7 +116,7 @@ spec:
```

## 候选与指针（7-source-candidate.yaml / 9-pointer.txt）

```yaml
digest: sha256:debf5bbfad43a9df7170ba324b7f0149a2ac4ca57a123e12548f0191219a6fc9
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 115b593340ef8f24221712fb95b49ff38c845dba
pointer-commit 98bd736d0515684627e7357cd54f5cccc1e21c6a
tag release-20261022-4
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

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
kustomization.kustomize.toolkit.fluxcd.io/tpl-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-database condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/tpl-web condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-database condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-service-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-storage condition met
kustomization.kustomize.toolkit.fluxcd.io/knowfeed-web condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-database condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-provider condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbase-web condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-agent-releases condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-database condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-knowlab-read-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-knowmart-summon-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-service-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-test-computer condition met
kustomization.kustomize.toolkit.fluxcd.io/knowbench-web condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-database condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-knowbench-testrun-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-knowmart-deliver-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-storage condition met
kustomization.kustomize.toolkit.fluxcd.io/knowlab-web condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-admin condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-database condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-identity condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-migration condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-rabbitmq condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-redis condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-runtime condition met
kustomization.kustomize.toolkit.fluxcd.io/knowmart-web condition met
```

## 检查（11-check-*.log 尾部）

### 11-check-knowbase.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=52   changed=2    unreachable=0    failed=0    skipped=22   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

### 11-check-knowbench.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=50   changed=0    unreachable=0    failed=0    skipped=24   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

### 11-check-knowfeed.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=54   changed=0    unreachable=0    failed=0    skipped=20   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

### 11-check-knowlab.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=50   changed=0    unreachable=0    failed=0    skipped=24   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

### 11-check-knowmart.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=45   changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

### 11-check-tpl.log
```text
        "web_member_organization": "sunmoonai"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=45   changed=0    unreachable=0    failed=0    skipped=29   rescued=0    ignored=0   

make: Leaving directory '/mnt/sunmoon-data/jenkins/repos/sunmoonun/infrastructure'
```

完整控制台与全部产物在 Jenkins 构建页；代理克隆里的分支 abandoned/release-13 推送成功后可删。
