# fable-c0a 回执：改名孤儿清理通过（luna）

WS=fable；任务基线 `a4d363468`；结论 **pass**。按所有者已批准的清单删除 71 个旧 investment 资源、10 个旧 Kustomization，未删除 PVC、库、桶、Harbor 镜像或 knowbench 资源；没有修改 gitops 或启动验收判据。

## 删除前完整清单（仅元数据，不读取 Secret 内容）

```text
KUSTOMIZATION investment-admin a8fa9fa2-2c07-47dc-9bb3-1bc96d919d66 prune=false deletionPolicy=Orphan
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-admin", "uid": "5e2e7397-ef86-4711-8cc3-af0e5c60346f", "owners": [], "kustomization": "investment-admin"}
{"kind": "Service", "namespace": "app-platform-dev", "name": "investment-admin", "uid": "50365256-0367-48e1-bed4-057c896abc23", "owners": [], "kustomization": "investment-admin"}
{"kind": "Ingress", "namespace": "app-platform-dev", "name": "investment-admin", "uid": "f490213e-1914-4f81-bbd7-4f9d2ea4125a", "owners": [], "kustomization": "investment-admin"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-admin", "uid": "3b580f0f-ff0f-443c-811c-4111fc091c6e", "owners": [], "kustomization": "investment-admin"}
KUSTOMIZATION investment-agent-releases 816c3d0a-5a00-4a12-aca5-fd582b30b1a8 prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "data-platform-dev", "name": "investment-agent-releases-v1", "uid": "a1a4d020-0e16-4fa7-88d4-8fa7ef199b98", "owners": [], "kustomization": "investment-agent-releases"}
{"kind": "ConfigMap", "namespace": "data-platform-dev", "name": "investment-agent-releases-policy-v1", "uid": "7f14a947-5a8f-417f-96ba-5f319f8c9dc6", "owners": [], "kustomization": "investment-agent-releases"}
{"kind": "Secret", "namespace": "data-platform-dev", "name": "investment-agent-releases-provision", "uid": "ec5d36ce-7483-4a6a-bf13-0415a0da047a", "owners": [], "kustomization": "investment-agent-releases"}
KUSTOMIZATION investment-database 1222502b-90dc-4ba2-b23c-6972bf38b9cb prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "data-platform-dev", "name": "investment-database-v1", "uid": "e385d0d8-3dc5-40ff-aa67-df2ca425c1e9", "owners": [], "kustomization": "investment-database"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-database-runtime", "uid": "98eefcf0-c962-46e6-90df-38092cf492c5", "owners": [], "kustomization": "investment-database"}
{"kind": "Secret", "namespace": "data-platform-dev", "name": "investment-database-bootstrap", "uid": "34a70716-02b0-4abd-bea6-9529efd4daaf", "owners": [], "kustomization": "investment-database"}
{"kind": "ServiceAccount", "namespace": "app-platform-dev", "name": "investment-runtime", "uid": "59016048-07c1-414b-99dd-5ca7abcfd2ed", "owners": [], "kustomization": "investment-database"}
KUSTOMIZATION investment-identity a03f9cd3-ec00-44b1-8f4e-9be41c2081eb prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "app-platform-dev", "name": "investment-identity-5a752f0f38f3-v3", "uid": "8f376186-b3c7-49cf-a72d-a5f6ee9cf936", "owners": [], "kustomization": "investment-identity"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-browser-identity", "uid": "6711fbbc-1f3e-40d9-8087-1a29e2eea829", "owners": [], "kustomization": "investment-identity"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-identity-provision-v1", "uid": "488e39d5-6a63-4db2-b468-345893824655", "owners": [], "kustomization": "investment-identity"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-identity-provision-v2", "uid": "471f5851-c4c9-4bb5-bd1b-57caf3ffc31a", "owners": [], "kustomization": "investment-identity"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-identity-provision-v3", "uid": "9417eb62-29ac-4989-8485-ed2d3cd7f42c", "owners": [], "kustomization": "investment-identity"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-browser-secrets", "uid": "dfdc2d66-6b59-40e3-afff-80cc151f4131", "owners": [], "kustomization": "investment-identity"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-identity-provision", "uid": "a224d341-be3d-40ce-9251-2591211dc9df", "owners": [], "kustomization": "investment-identity"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-identity-provision-in", "uid": "ca89a415-75e2-415b-b4b2-786c515cbe5d", "owners": [], "kustomization": "investment-identity"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-identity-provision-out", "uid": "8c3621d3-12b5-4e31-8a92-695d16f13d34", "owners": [], "kustomization": "investment-identity"}
KUSTOMIZATION investment-migration b6e0a745-07a0-472a-8efb-50ee509aad98 prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "app-platform-dev", "name": "investment-migrate-5a752f0f38f3-v7", "uid": "ef9bb808-2ec1-4ee4-bcf7-0106cd63f3c4", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v1", "uid": "fcc2c40a-1520-4c84-ade3-b6eac7f79b9e", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v2", "uid": "d654cb68-7380-4f10-ac7a-7fa9f05b4b46", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v3", "uid": "89217485-ab7a-4b70-8ff8-7bbf95f3e53b", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v4", "uid": "f178bcaf-2f94-45bd-a836-851d3b93e318", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v5", "uid": "035c7cdc-7745-4c53-9aa7-ca02ffe9a4b9", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v6", "uid": "7612fb9e-d192-4bae-8f82-381526d0dfd7", "owners": [], "kustomization": "investment-migration"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-schema-check-v7", "uid": "30448187-52e5-4627-97be-b75576eb34cf", "owners": [], "kustomization": "investment-migration"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-migration-auth", "uid": "7d6b9b82-33ff-47de-bcad-947380448f7d", "owners": [], "kustomization": "investment-migration"}
KUSTOMIZATION investment-rabbitmq 44acd97f-b727-48fd-853e-7b583b0d861d prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-5a752f0f38f3-v2", "uid": "55d67b3f-4635-475c-9fbf-69b2727596d8", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "ConfigMap", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-provision-v1", "uid": "c0965bdc-e44d-42a3-896b-42fb90544b87", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "ConfigMap", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-provision-v2", "uid": "f5220b4e-a119-4d2a-bfb3-fffe3a133ec6", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-rabbitmq-runtime", "uid": "a8bc4e2f-5710-4891-b6e0-fb771128fff6", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "Secret", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-provision", "uid": "53256d0b-bffe-4b33-8128-6bee634eb40a", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "NetworkPolicy", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-provision-in", "uid": "266b2e5d-8a0f-4a6a-827c-7655fa5da530", "owners": [], "kustomization": "investment-rabbitmq"}
{"kind": "NetworkPolicy", "namespace": "messaging-platform-dev", "name": "investment-rabbitmq-provision-out", "uid": "7aa76008-0e30-431d-89f5-d0bf0d0bb6a8", "owners": [], "kustomization": "investment-rabbitmq"}
KUSTOMIZATION investment-redis 06aa6978-cbdd-494d-a8da-6c0896079a12 prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "data-platform-dev", "name": "investment-redis-5a752f0f38f3-v3", "uid": "d948dda1-da9e-4d2c-a3f1-f94d425c646e", "owners": [], "kustomization": "investment-redis"}
{"kind": "ConfigMap", "namespace": "data-platform-dev", "name": "investment-redis-provision-v1", "uid": "65637b3a-99e8-44b8-9576-647c3feee734", "owners": [], "kustomization": "investment-redis"}
{"kind": "ConfigMap", "namespace": "data-platform-dev", "name": "investment-redis-provision-v2", "uid": "903f7ff0-9269-4089-a1b7-17b36d8451ec", "owners": [], "kustomization": "investment-redis"}
{"kind": "ConfigMap", "namespace": "data-platform-dev", "name": "investment-redis-provision-v3", "uid": "b30557ef-f2f1-4d6c-a905-b6b946b5a44d", "owners": [], "kustomization": "investment-redis"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-redis-runtime", "uid": "4030cff0-4938-4344-8dbd-9c4f11b499f2", "owners": [], "kustomization": "investment-redis"}
{"kind": "Secret", "namespace": "data-platform-dev", "name": "investment-redis-provision", "uid": "fd2159ab-6b9c-4c2f-92f1-8b181f99793e", "owners": [], "kustomization": "investment-redis"}
{"kind": "NetworkPolicy", "namespace": "data-platform-dev", "name": "investment-redis-provision-in", "uid": "81492fc9-0831-4750-b713-6d855ea0b7e8", "owners": [], "kustomization": "investment-redis"}
{"kind": "NetworkPolicy", "namespace": "data-platform-dev", "name": "investment-redis-provision-out", "uid": "7c14a8a3-bd8c-42fb-9dab-be5d0ed56c11", "owners": [], "kustomization": "investment-redis"}
KUSTOMIZATION investment-runtime 938abb5f-5af2-4554-afc2-57cf0008d36b prune=false deletionPolicy=Orphan
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-api", "uid": "adec1ddc-0eaf-431f-b951-1499b0347941", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-runner", "uid": "b1c13855-fc19-4cfb-928a-eaa249d3bbec", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-scheduler", "uid": "073c7c89-08de-493b-93fd-7ef553d11b00", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-worker", "uid": "7032c81b-a9e2-4eb4-b8e9-d22bdef9b9cc", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Service", "namespace": "app-platform-dev", "name": "investment-api", "uid": "4d53bff5-7c59-44a8-b3ae-ad8ac5905d40", "owners": [], "kustomization": "investment-runtime"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-celery-config", "uid": "e39b4ef2-72f6-4946-b138-48ee5a51e3ca", "owners": [], "kustomization": "investment-runtime"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-runtime", "uid": "7d22294a-cd20-4d92-bc69-5c99fc50a079", "owners": [], "kustomization": "investment-runtime"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-service-ca", "uid": "9b983564-ddbe-4b74-a581-a82709461a6e", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-agent-releases-runtime", "uid": "d85fdb65-34d1-44ae-907e-fbcdf1dc662d", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-domain-runtime", "uid": "fa7e7342-f184-4dd6-a226-a53d5418ecc3", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-knowbase-service", "uid": "a2f264dc-da44-46a8-b5dc-e318d1a4fcfd", "owners": [], "kustomization": "investment-runtime"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-tls", "uid": "a508e9e9-cce5-4926-8b10-4b7496eb0612", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-api-casdoor-in", "uid": "18347b80-347d-42ba-ab12-aae09677e7f5", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-api-casdoor-out", "uid": "5a32866d-1a44-452a-82b0-f33015d3b2f9", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-api-ingress", "uid": "cca60217-c329-437f-a06e-144731cb2f3f", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-provisioner-out", "uid": "773c9b41-7e42-4b8a-9e5d-0d6fcbf1bbab", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-relay-admin-out", "uid": "c38a79ab-ff02-4047-a41d-a6ac60ca2902", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-sandboxes-out", "uid": "99a16173-7f94-4c04-abdf-7e71fcb063c2", "owners": [], "kustomization": "investment-runtime"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-service-https-out", "uid": "fad5bf99-c3f7-4c2b-89c8-fba379e6d8d9", "owners": [], "kustomization": "investment-runtime"}
KUSTOMIZATION investment-service-identity 2f5a32dd-7ec3-4998-8b11-bfdb355c4e0e prune=false deletionPolicy=Orphan
{"kind": "Job", "namespace": "app-platform-dev", "name": "investment-service-identity-5a752f0f38f3-v1", "uid": "c209a8bb-f891-433a-b31f-29f2236233ad", "owners": [], "kustomization": "investment-service-identity"}
{"kind": "ConfigMap", "namespace": "app-platform-dev", "name": "investment-service-provision-v1", "uid": "8f58e931-1307-4f1b-8029-2ebb42d75451", "owners": [], "kustomization": "investment-service-identity"}
{"kind": "Secret", "namespace": "app-platform-dev", "name": "investment-service-provision", "uid": "c6ed2dff-bc9f-4980-8a23-4abfa107d1e0", "owners": [], "kustomization": "investment-service-identity"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-service-provision-out", "uid": "b7d01d05-b8bb-42ff-8cb2-ed68be959dee", "owners": [], "kustomization": "investment-service-identity"}
KUSTOMIZATION investment-web 2f04c7d5-df4c-4f20-8f64-2555d4544224 prune=false deletionPolicy=Orphan
{"kind": "Deployment", "namespace": "app-platform-dev", "name": "investment-web", "uid": "a81d96a5-4a67-4f62-b588-d447cb9603f0", "owners": [], "kustomization": "investment-web"}
{"kind": "Service", "namespace": "app-platform-dev", "name": "investment-web", "uid": "fdb1edda-f765-4938-9a2c-0923ce4f6e06", "owners": [], "kustomization": "investment-web"}
{"kind": "Ingress", "namespace": "app-platform-dev", "name": "investment-web", "uid": "6f7d05c7-1e4e-401c-8bf2-d603c609fe42", "owners": [], "kustomization": "investment-web"}
{"kind": "NetworkPolicy", "namespace": "app-platform-dev", "name": "investment-web", "uid": "5138b6f4-fb2c-4243-b932-72ca4e1f0896", "owners": [], "kustomization": "investment-web"}
SUMMARY {"kustomizations": 10, "delete_resources": 71, "by_kind": {"Deployment": 6, "Service": 3, "Ingress": 2, "NetworkPolicy": 16, "Job": 7, "ConfigMap": 21, "Secret": 15, "ServiceAccount": 1}, "excluded_investment_pvc": 0, "protected_all_pvc": 21, "protected_knowbench_resources": 141, "namespaces": ["app-platform-dev", "data-platform-dev", "messaging-platform-dev"], "knowbench_in_plan": 0}
Read-only inventory complete. No deletions performed.
exit=0
```

## 实际删除计划与结果

```text
delete app-platform-dev deployments.apps/investment-admin uid=5e2e7397-ef86-4711-8cc3-af0e5c60346f
delete app-platform-dev services/investment-admin uid=50365256-0367-48e1-bed4-057c896abc23
delete app-platform-dev ingresses.networking.k8s.io/investment-admin uid=f490213e-1914-4f81-bbd7-4f9d2ea4125a
delete app-platform-dev networkpolicies.networking.k8s.io/investment-admin uid=3b580f0f-ff0f-443c-811c-4111fc091c6e
delete data-platform-dev jobs.batch/investment-agent-releases-v1 uid=a1a4d020-0e16-4fa7-88d4-8fa7ef199b98
delete data-platform-dev configmaps/investment-agent-releases-policy-v1 uid=7f14a947-5a8f-417f-96ba-5f319f8c9dc6
delete data-platform-dev secrets/investment-agent-releases-provision uid=ec5d36ce-7483-4a6a-bf13-0415a0da047a
delete data-platform-dev jobs.batch/investment-database-v1 uid=e385d0d8-3dc5-40ff-aa67-df2ca425c1e9
delete app-platform-dev secrets/investment-database-runtime uid=98eefcf0-c962-46e6-90df-38092cf492c5
delete data-platform-dev secrets/investment-database-bootstrap uid=34a70716-02b0-4abd-bea6-9529efd4daaf
delete app-platform-dev serviceaccounts/investment-runtime uid=59016048-07c1-414b-99dd-5ca7abcfd2ed
delete app-platform-dev jobs.batch/investment-identity-5a752f0f38f3-v3 uid=8f376186-b3c7-49cf-a72d-a5f6ee9cf936
delete app-platform-dev configmaps/investment-browser-identity uid=6711fbbc-1f3e-40d9-8087-1a29e2eea829
delete app-platform-dev configmaps/investment-identity-provision-v1 uid=488e39d5-6a63-4db2-b468-345893824655
delete app-platform-dev configmaps/investment-identity-provision-v2 uid=471f5851-c4c9-4bb5-bd1b-57caf3ffc31a
delete app-platform-dev configmaps/investment-identity-provision-v3 uid=9417eb62-29ac-4989-8485-ed2d3cd7f42c
delete app-platform-dev secrets/investment-browser-secrets uid=dfdc2d66-6b59-40e3-afff-80cc151f4131
delete app-platform-dev secrets/investment-identity-provision uid=a224d341-be3d-40ce-9251-2591211dc9df
delete app-platform-dev networkpolicies.networking.k8s.io/investment-identity-provision-in uid=ca89a415-75e2-415b-b4b2-786c515cbe5d
delete app-platform-dev networkpolicies.networking.k8s.io/investment-identity-provision-out uid=8c3621d3-12b5-4e31-8a92-695d16f13d34
delete app-platform-dev jobs.batch/investment-migrate-5a752f0f38f3-v7 uid=ef9bb808-2ec1-4ee4-bcf7-0106cd63f3c4
delete app-platform-dev configmaps/investment-schema-check-v1 uid=fcc2c40a-1520-4c84-ade3-b6eac7f79b9e
delete app-platform-dev configmaps/investment-schema-check-v2 uid=d654cb68-7380-4f10-ac7a-7fa9f05b4b46
delete app-platform-dev configmaps/investment-schema-check-v3 uid=89217485-ab7a-4b70-8ff8-7bbf95f3e53b
delete app-platform-dev configmaps/investment-schema-check-v4 uid=f178bcaf-2f94-45bd-a836-851d3b93e318
delete app-platform-dev configmaps/investment-schema-check-v5 uid=035c7cdc-7745-4c53-9aa7-ca02ffe9a4b9
delete app-platform-dev configmaps/investment-schema-check-v6 uid=7612fb9e-d192-4bae-8f82-381526d0dfd7
delete app-platform-dev configmaps/investment-schema-check-v7 uid=30448187-52e5-4627-97be-b75576eb34cf
delete app-platform-dev secrets/investment-migration-auth uid=7d6b9b82-33ff-47de-bcad-947380448f7d
delete messaging-platform-dev jobs.batch/investment-rabbitmq-5a752f0f38f3-v2 uid=55d67b3f-4635-475c-9fbf-69b2727596d8
delete messaging-platform-dev configmaps/investment-rabbitmq-provision-v1 uid=c0965bdc-e44d-42a3-896b-42fb90544b87
delete messaging-platform-dev configmaps/investment-rabbitmq-provision-v2 uid=f5220b4e-a119-4d2a-bfb3-fffe3a133ec6
delete app-platform-dev secrets/investment-rabbitmq-runtime uid=a8bc4e2f-5710-4891-b6e0-fb771128fff6
delete messaging-platform-dev secrets/investment-rabbitmq-provision uid=53256d0b-bffe-4b33-8128-6bee634eb40a
delete messaging-platform-dev networkpolicies.networking.k8s.io/investment-rabbitmq-provision-in uid=266b2e5d-8a0f-4a6a-827c-7655fa5da530
delete messaging-platform-dev networkpolicies.networking.k8s.io/investment-rabbitmq-provision-out uid=7aa76008-0e30-431d-89f5-d0bf0d0bb6a8
delete data-platform-dev jobs.batch/investment-redis-5a752f0f38f3-v3 uid=d948dda1-da9e-4d2c-a3f1-f94d425c646e
delete data-platform-dev configmaps/investment-redis-provision-v1 uid=65637b3a-99e8-44b8-9576-647c3feee734
delete data-platform-dev configmaps/investment-redis-provision-v2 uid=903f7ff0-9269-4089-a1b7-17b36d8451ec
delete data-platform-dev configmaps/investment-redis-provision-v3 uid=b30557ef-f2f1-4d6c-a905-b6b946b5a44d
delete app-platform-dev secrets/investment-redis-runtime uid=4030cff0-4938-4344-8dbd-9c4f11b499f2
delete data-platform-dev secrets/investment-redis-provision uid=fd2159ab-6b9c-4c2f-92f1-8b181f99793e
delete data-platform-dev networkpolicies.networking.k8s.io/investment-redis-provision-in uid=81492fc9-0831-4750-b713-6d855ea0b7e8
delete data-platform-dev networkpolicies.networking.k8s.io/investment-redis-provision-out uid=7c14a8a3-bd8c-42fb-9dab-be5d0ed56c11
delete app-platform-dev deployments.apps/investment-api uid=adec1ddc-0eaf-431f-b951-1499b0347941
delete app-platform-dev deployments.apps/investment-runner uid=b1c13855-fc19-4cfb-928a-eaa249d3bbec
delete app-platform-dev deployments.apps/investment-scheduler uid=073c7c89-08de-493b-93fd-7ef553d11b00
delete app-platform-dev deployments.apps/investment-worker uid=7032c81b-a9e2-4eb4-b8e9-d22bdef9b9cc
delete app-platform-dev services/investment-api uid=4d53bff5-7c59-44a8-b3ae-ad8ac5905d40
delete app-platform-dev configmaps/investment-celery-config uid=e39b4ef2-72f6-4946-b138-48ee5a51e3ca
delete app-platform-dev configmaps/investment-runtime uid=7d22294a-cd20-4d92-bc69-5c99fc50a079
delete app-platform-dev configmaps/investment-service-ca uid=9b983564-ddbe-4b74-a581-a82709461a6e
delete app-platform-dev secrets/investment-agent-releases-runtime uid=d85fdb65-34d1-44ae-907e-fbcdf1dc662d
delete app-platform-dev secrets/investment-domain-runtime uid=fa7e7342-f184-4dd6-a226-a53d5418ecc3
delete app-platform-dev secrets/investment-knowbase-service uid=a2f264dc-da44-46a8-b5dc-e318d1a4fcfd
delete app-platform-dev secrets/investment-tls uid=a508e9e9-cce5-4926-8b10-4b7496eb0612
delete app-platform-dev networkpolicies.networking.k8s.io/investment-api-casdoor-in uid=18347b80-347d-42ba-ab12-aae09677e7f5
delete app-platform-dev networkpolicies.networking.k8s.io/investment-api-casdoor-out uid=5a32866d-1a44-452a-82b0-f33015d3b2f9
delete app-platform-dev networkpolicies.networking.k8s.io/investment-api-ingress uid=cca60217-c329-437f-a06e-144731cb2f3f
delete app-platform-dev networkpolicies.networking.k8s.io/investment-provisioner-out uid=773c9b41-7e42-4b8a-9e5d-0d6fcbf1bbab
delete app-platform-dev networkpolicies.networking.k8s.io/investment-relay-admin-out uid=c38a79ab-ff02-4047-a41d-a6ac60ca2902
delete app-platform-dev networkpolicies.networking.k8s.io/investment-sandboxes-out uid=99a16173-7f94-4c04-abdf-7e71fcb063c2
delete app-platform-dev networkpolicies.networking.k8s.io/investment-service-https-out uid=fad5bf99-c3f7-4c2b-89c8-fba379e6d8d9
delete app-platform-dev jobs.batch/investment-service-identity-5a752f0f38f3-v1 uid=c209a8bb-f891-433a-b31f-29f2236233ad
delete app-platform-dev configmaps/investment-service-provision-v1 uid=8f58e931-1307-4f1b-8029-2ebb42d75451
delete app-platform-dev secrets/investment-service-provision uid=c6ed2dff-bc9f-4980-8a23-4abfa107d1e0
delete app-platform-dev networkpolicies.networking.k8s.io/investment-service-provision-out uid=b7d01d05-b8bb-42ff-8cb2-ed68be959dee
delete app-platform-dev deployments.apps/investment-web uid=a81d96a5-4a67-4f62-b588-d447cb9603f0
delete app-platform-dev services/investment-web uid=fdb1edda-f765-4938-9a2c-0923ce4f6e06
delete app-platform-dev ingresses.networking.k8s.io/investment-web uid=6f7d05c7-1e4e-401c-8bf2-d603c609fe42
delete app-platform-dev networkpolicies.networking.k8s.io/investment-web uid=5138b6f4-fb2c-4243-b932-72ca4e1f0896
```

71 个资源：Deployment 6、Service 3、Ingress 2、NetworkPolicy 16、Job 7、ConfigMap 21、Secret 15、ServiceAccount 1。分属 app-platform-dev、data-platform-dev、messaging-platform-dev；没有 IngressRoute、StatefulSet、CronJob、Role、RoleBinding 或 PVC 待删。十个 Kustomization 的 prune=false、deletionPolicy=Orphan 均在删除前重新核对；逐项删除前也重核 UID。

完整实际删除输出：`fable-c0a.delete.20261021-113530.txt`，71 个资源及 10 个 Kustomization 均删除成功，exit=0。

## 删除后核对

```text
investment Kustomization count=0
total 95 not-ready []
investment pod count=0
investment get all count=0
platform-status exit=0
platform-start exit=0
protected_all_pvc unchanged UID count=21
protected_knowbench_resources unchanged UID count=141
```

完整原生启动与核对输出：`fable-c0a.verify.20261021-113650.txt`，exit=0。protected PVC 均没有指向待删资源的 ownerReference，未因级联删除触及 PVC。

## 执行命令就地修正

卡原来的 `get ... -A -o name` 丢掉 namespace，再用同名对象的第一行猜 namespace，可能选错。实际改为一次输出 kind/namespace/name/UID 元数据，按所有者的原范围生成精确清单并逐项核 UID；Secret 只输出元数据，不输出 data。IngressRoute 按卡的 owner-name 标签另查；不存在则不删。计数由 Python 判 0，避免 grep 正常匹配不到时的退出 1 被当失败。不改变删除范围或通过标准。

全部原始输出保留，只提交本次回执/输出及本卡移动。C0b 接下来只准备 Windows 独立启动材料，不在 WSL 中启动压缩。

exit=0
