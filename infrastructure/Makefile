SHELL := /bin/bash
.DELETE_ON_ERROR:
# Native deployment and publication recipes must run serially, even when make -j is supplied.
.NOTPARALLEL:
.DEFAULT_GOAL := help

UV ?= uv
HOST_PYTHON ?= /usr/bin/python3
ANSIBLE := .venv/bin/ansible-playbook
# WSL：用户会话和 systemd（PID 1）可能不在同一个挂载命名空间；开机后才附上的数据盘只在 PID 1 那边可见，
# 从用户会话跑的预检、守卫、启停会把 /data/* 看成系统盘（2026-10-06 第一次真实开机实测）。
# 不一致时，所有剧本都钻进 PID 1 的挂载命名空间里跑，身份仍是当前用户。
NS_SELF := $(shell readlink /proc/self/ns/mnt 2>/dev/null)
NS_PID1 := $(shell sudo -n readlink /proc/1/ns/mnt 2>/dev/null)
ifneq ($(NS_SELF),$(NS_PID1))
ANSIBLE := sudo -n nsenter --target 1 --mount --wd=$(CURDIR) -- sudo -n -u $(shell id -un) -H env PATH="$(PATH)" $(CURDIR)/.venv/bin/ansible-playbook
endif
ARTIFACTS ?= all
MATERIAL_OWNER ?= all
# Optional subset of configured service material IDs; does not enable runtime components.
SERVICE_IMAGES ?= all
BINARIES ?= kind,kubectl,kubeadm
SITE ?= environments/kind/site.yaml
APP ?= tpl
OBJECT ?= all
SELECTION_ACTION ?= select
export OBJECT SITE
COMPONENT ?= backend
ifneq ($(filter application-build-% application-publish-% application-source-plan application-deployment-plan application-render application-stage application-validate-release application-check application-check-public application-bootstrap,$(MAKECMDGOALS)),)
ifneq ($(words $(APP)),1)
$(error APP must be tpl, info, knowledge or investment)
endif
ifneq ($(filter $(APP),tpl info knowledge investment),$(APP))
$(error APP must be tpl, info, knowledge or investment)
endif
endif
# Every ordinary field has one source; the explicit list also documents the input closure.
ifneq ($(filter application-source-plan,$(MAKECMDGOALS)),)
ifneq ($(words $(COMPONENT)),1)
$(error COMPONENT must be backend, web or admin)
endif
ifneq ($(filter $(COMPONENT),backend web admin),$(COMPONENT))
$(error COMPONENT must be backend, web or admin)
endif
endif
CONFIG_FILES := applications/config.yaml \
	../gitops/components/app-platform/tpl-app/config.yaml \
	../gitops/components/app-platform/tpl-app/tpl-backend/config.yaml \
	../gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml \
	../gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml \
	../gitops/components/app-platform/info-app/info-backend/config.yaml \
	../gitops/components/app-platform/info-app/info-web-frontend/config.yaml \
	../gitops/components/app-platform/info-app/info-admin-frontend/config.yaml \
	../gitops/components/app-platform/info-app/config.yaml \
	../gitops/components/app-platform/knowledge-app/config.yaml \
	../gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml \
	../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml \
	../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml \
	../gitops/components/app-platform/investment-app/config.yaml \
	../gitops/components/app-platform/investment-app/investment-backend/config.yaml \
	../gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml \
	../gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml \
	registry/config.yaml \
	entry/config.yaml \
	cluster/config.yaml \
	flux/config.yaml \
	services/config.yaml \
	host/config.yaml \
	../gitops/components/data-platform/postgresql/config.yaml \
	../gitops/components/data-platform/redis/config.yaml \
	../gitops/components/data-platform/object-storage/config.yaml \
	../gitops/components/data-platform/object-storage/ui/config.yaml \
	../gitops/components/data-platform/text-embeddings/config.yaml \
	../gitops/components/data-platform/elk/config.yaml \
	../gitops/components/data-platform/elk/elasticsearch/config.yaml \
	../gitops/components/data-platform/elk/collector/config.yaml \
	../gitops/components/data-platform/elk/kibana/data-view/config.yaml \
	../gitops/components/data-platform/elk/kibana/ui/config.yaml \
	../gitops/components/data-platform/neo4j/config.yaml \
	../gitops/components/data-platform/neo4j/ui/config.yaml \
	../gitops/components/data-platform/mongodb/config.yaml \
	../gitops/components/data-platform/infinity/config.yaml \
	../gitops/components/data-platform/valkey/config.yaml \
	../gitops/components/data-platform/ragflow/config.yaml \
	../gitops/components/messaging-platform/rabbitmq/config.yaml \
	../gitops/components/messaging-platform/rabbitmq/ui/config.yaml \
	../gitops/components/ingress-platform/traefik/config.yaml \
	../gitops/components/ingress-platform/traefik/service-access/config.yaml \
	../gitops/components/app-platform/auth-app/casdoor/config.yaml \
	../gitops/components/ops-platform/pgadmin/config.yaml \
	../gitops/components/ops-platform/redisinsight/config.yaml \
	../gitops/components/ops-platform/flower/config.yaml \
	../gitops/components/ops-platform/mongo-express/config.yaml \
	../gitops/components/relay-platform/relay/config.yaml \
	../gitops/components/sandbox-platform/provisioner/config.yaml
export PLATFORM_CONFIG_FILES := $(CONFIG_FILES)
CONFIG_ARGS = $(foreach file,$(CONFIG_FILES),--extra-vars '@$(file)') --extra-vars '@$(SITE)'

.PHONY: help tools images preflight check-images
help:
	@printf '%s\n' 'platform-plan/config/status OBJECT=<平台/应用/组件> 查看依赖、配置和运行状态' 'platform-stage OBJECT=... 生成选中对象的声明候选；不发布' 'platform-build OBJECT=<业务应用或前后端组件> 在线构建并发布固定摘要' 'platform-deploy/check OBJECT=all|... 原生整套或选中对象部署/真实检查' 'platform-start/stop 统一启停已安装的本机平台' 'platform-account-plan/view OBJECT=... 查看维护账号能力与私有位置' 'platform-account-import 导入已批准的管理员表预设；不改已有账号' 'platform-account-check/stage/rotate/recover 按组件维护已支持的账号；参见host/accounts.md' 'platform-install-lifecycle/enable-boot 宿主安装与开机管理，需明确维护批准' 'material-inventory 显示组件物料与Harbor关系，MATERIAL_OWNER可过滤' 'config 查看全部配置来源；各模块底层入口见对应README'

tools:
	$(UV) venv --python '$(HOST_PYTHON)' --relocatable --allow-existing .venv
	$(UV) pip sync --python .venv/bin/python --require-hashes --index-url https://pypi.org/simple tools/requirements.lock

images:
	@jq -r '.images[] | [.id, .status, .source, (.reference // "UNRESOLVED")] | @tsv' artifacts/upstream-images.lock.json

check-images:
	@jq -r ' .images[] | select(.status != "resolved") | "UNRESOLVED: " + .id + " — " + .reason' artifacts/upstream-images.lock.json
	@jq -e '.schema_version == 1 and .platform == "linux/amd64" and .complete == true and (.images | length > 0) and ([.images[].id] | length == (unique | length)) and all(.images[]; .status == "resolved" and .platform == "linux/amd64" and ((.reference | split("@")[1]) == .manifest_digest) and (.manifest_digest | test("^sha256:[a-f0-9]{64}$$")) and (.reference | test("^[^@]+@sha256:[a-f0-9]{64}$$")))' artifacts/upstream-images.lock.json >/dev/null

preflight:
	$(ANSIBLE) -i host/inventory.yaml host/preflight.yaml $(CONFIG_ARGS) --check

.PHONY: material-inventory plan-artifacts fetch-artifacts check-artifacts
material-inventory:
	.venv/bin/python artifacts/inventory.py --site "$(SITE)" --owner "$(MATERIAL_OWNER)"

plan-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml $(CONFIG_ARGS) --extra-vars 'artifact_action=plan artifact_ids=$(ARTIFACTS)'

fetch-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml $(CONFIG_ARGS) --extra-vars 'artifact_action=fetch artifact_ids=$(ARTIFACTS)'

check-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml $(CONFIG_ARGS) --extra-vars 'artifact_action=verify artifact_ids=$(ARTIFACTS)'

.PHONY: install-binaries
install-binaries:
	$(ANSIBLE) -i host/inventory.yaml tools/install-binaries.yaml $(CONFIG_ARGS) --extra-vars 'binary_ids=$(BINARIES)'

.PHONY: plan-node-build build-node
plan-node-build:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml $(CONFIG_ARGS) --extra-vars node_action=plan

build-node:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml $(CONFIG_ARGS) --extra-vars node_action=build

.PHONY: check-node
check-node:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml $(CONFIG_ARGS) --extra-vars node_action=verify

.PHONY: plan-bootstrap-images fetch-bootstrap-images check-bootstrap-images
plan-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml $(CONFIG_ARGS) --extra-vars image_action=plan

fetch-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml $(CONFIG_ARGS) --extra-vars image_action=fetch

check-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml $(CONFIG_ARGS) --extra-vars image_action=verify

.PHONY: prepare-harbor-materials
prepare-harbor-materials:
	$(ANSIBLE) -i host/inventory.yaml registry/materials.yaml $(CONFIG_ARGS)

.PHONY: registry-plan registry-deploy registry-start registry-stop registry-status
registry-plan registry-deploy registry-start registry-stop registry-status:
	$(ANSIBLE) -i host/inventory.yaml registry/service.yaml $(CONFIG_ARGS) --extra-vars 'registry_action=$(patsubst registry-%,%,$@)'

.PHONY: entry-plan entry-preview entry-deploy entry-start entry-stop entry-status
entry-plan entry-preview entry-deploy entry-start entry-stop entry-status:
	$(ANSIBLE) -i host/inventory.yaml entry/service.yaml $(CONFIG_ARGS) --extra-vars 'entry_action=$(patsubst entry-%,%,$@)'

.PHONY: prepare-host-materials check-host-materials
prepare-host-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml $(CONFIG_ARGS) --extra-vars 'image_group=host image_action=fetch'
check-host-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml $(CONFIG_ARGS) --extra-vars 'image_group=host image_action=verify'

.PHONY: registry-accounts
registry-accounts:
	$(ANSIBLE) -i host/inventory.yaml registry/accounts.yaml $(CONFIG_ARGS)

.PHONY: registry-publish-check
registry-publish-check:
	$(ANSIBLE) -i host/inventory.yaml registry/publish.yaml $(CONFIG_ARGS)

.PHONY: scanner-db-plan scanner-db-install scanner-db-verify registry-scan-check
scanner-db-plan scanner-db-install scanner-db-verify:
	$(ANSIBLE) -i host/inventory.yaml registry/scanner-databases.yaml $(CONFIG_ARGS) --extra-vars 'scanner_database_action=$(patsubst scanner-db-%,%,$@)'

registry-scan-check:
	$(ANSIBLE) -i host/inventory.yaml registry/scan.yaml $(CONFIG_ARGS)

.PHONY: registry-recovery-plan registry-recovery-check
registry-recovery-plan registry-recovery-check:
	$(ANSIBLE) -i host/inventory.yaml registry/recovery.yaml $(CONFIG_ARGS) --extra-vars 'recovery_action=$(patsubst registry-recovery-%,%,$@) recovery_backup=$(BACKUP) recovery_backup_sha256=$(BACKUP_SHA256)'

.PHONY: cluster-plan cluster-deploy cluster-status
cluster-plan cluster-deploy cluster-status:
	$(ANSIBLE) -i host/inventory.yaml cluster/deploy.yaml $(CONFIG_ARGS) --extra-vars 'cluster_action=$(patsubst cluster-%,%,$@)'

.PHONY: cluster-pull-check
cluster-pull-check: cluster-status
	$(ANSIBLE) -i host/inventory.yaml cluster/pull-check.yaml $(CONFIG_ARGS)

.PHONY: install-flux
install-flux:
	$(ANSIBLE) -i host/inventory.yaml flux/tools.yaml $(CONFIG_ARGS)

.PHONY: flux-plan flux-materials flux-verify-materials flux-publish
flux-plan:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml $(CONFIG_ARGS) --extra-vars flux_material_action=plan
flux-materials:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml $(CONFIG_ARGS) --extra-vars flux_material_action=prepare
flux-verify-materials:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml $(CONFIG_ARGS) --extra-vars flux_material_action=verify
flux-publish:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml $(CONFIG_ARGS) --extra-vars flux_material_action=publish

.PHONY: flux-deploy flux-status
flux-deploy:
	$(ANSIBLE) -i host/inventory.yaml flux/bootstrap.yaml $(CONFIG_ARGS) --extra-vars flux_action=deploy
flux-status:
	$(ANSIBLE) -i host/inventory.yaml flux/bootstrap.yaml $(CONFIG_ARGS) --extra-vars flux_action=status

.PHONY: flux-release flux-source-apply flux-source-status
flux-release:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml $(CONFIG_ARGS) --extra-vars flux_source_action=publish
flux-source-apply:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml $(CONFIG_ARGS) --extra-vars flux_source_action=apply $(if $(FLUX_SOURCE_FILE),--extra-vars 'source_lock_path=$(FLUX_SOURCE_FILE)')
flux-source-status:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml $(CONFIG_ARGS) --extra-vars flux_source_action=status

.PHONY: flux-bootstrap
flux-bootstrap:
	$(MAKE) install-flux
	$(MAKE) flux-verify-materials
	$(MAKE) flux-publish
	$(MAKE) flux-deploy
	$(MAKE) install-secrets-tools
	$(MAKE) secrets-prepare
	$(MAKE) secrets-apply
	$(MAKE) flux-source-apply

.PHONY: install-secrets-tools secrets-prepare secrets-apply secrets-status foundations-bootstrap
install-secrets-tools:
	$(ANSIBLE) -i host/inventory.yaml tools/install-binaries.yaml $(CONFIG_ARGS) --extra-vars 'binary_ids=sops capacity_operation=sops-tools'
	$(ANSIBLE) -i host/inventory.yaml tools/install-age.yaml $(CONFIG_ARGS)
secrets-prepare secrets-apply secrets-status:
	$(ANSIBLE) -i host/inventory.yaml flux/secrets.yaml $(CONFIG_ARGS) --extra-vars 'secrets_action=$(patsubst secrets-%,%,$@)'
foundations-bootstrap:
	$(MAKE) install-secrets-tools
	$(MAKE) secrets-prepare
	$(MAKE) secrets-apply
	$(MAKE) flux-source-apply

.PHONY: foundations-check
foundations-check:
	$(MAKE) secrets-status
	$(MAKE) flux-source-status
	$(ANSIBLE) -i host/inventory.yaml flux/foundations-check.yaml $(CONFIG_ARGS)

.PHONY: services-plan services-materials services-verify-materials services-publish
services-plan:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=plan --extra-vars 'service_material_ids=$(SERVICE_IMAGES)' --extra-vars '{"publication_image_ids":"{{ selected_service_image_ids }}","publication_download_timeout_seconds":"{{ service_material_timeout_seconds }}","publication_enabled":"{{ services_enabled }}","publication_capacity_operation":"services-materials"}'
services-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=prepare --extra-vars 'service_material_ids=$(SERVICE_IMAGES)' --extra-vars '{"publication_image_ids":"{{ selected_service_image_ids }}","publication_download_timeout_seconds":"{{ service_material_timeout_seconds }}","publication_enabled":"{{ services_enabled }}","publication_capacity_operation":"services-materials"}'
services-verify-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=verify --extra-vars 'service_material_ids=$(SERVICE_IMAGES)' --extra-vars '{"publication_image_ids":"{{ selected_service_image_ids }}","publication_download_timeout_seconds":"{{ service_material_timeout_seconds }}","publication_enabled":"{{ services_enabled }}","publication_capacity_operation":"services-materials"}'
services-publish:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=publish --extra-vars 'service_material_ids=$(SERVICE_IMAGES)' --extra-vars '{"publication_image_ids":"{{ selected_service_image_ids }}","publication_download_timeout_seconds":"{{ service_material_timeout_seconds }}","publication_enabled":"{{ services_enabled }}","publication_capacity_operation":"services-materials"}'

.PHONY: services-tools services-chart services-render services-bootstrap
services-tools:
	$(ANSIBLE) -i host/inventory.yaml services/tools.yaml $(CONFIG_ARGS)
services-chart:
	$(ANSIBLE) -i host/inventory.yaml services/chart.yaml $(CONFIG_ARGS)
services-render:
	$(ANSIBLE) -i host/inventory.yaml components/render.yaml $(CONFIG_ARGS)
# Deploy the promoted, committed release. Rendering a changed release is a separate review step.
services-bootstrap:
	$(if $(filter all data-platform data-platform/postgresql data-platform/redis messaging-platform messaging-platform/rabbitmq app-platform app-platform/auth-app app-platform/auth-app/casdoor,$(OBJECT)),$(MAKE) services-credentials)
	$(MAKE) services-verify-materials
	$(MAKE) services-publish
	$(if $(filter all data-platform data-platform/ragflow,$(OBJECT)),$(MAKE) services-ragflow-image)
	$(if $(filter all data-platform data-platform/ragflow,$(OBJECT)),$(MAKE) services-ragflow-image-publish)
	$(if $(filter all ingress-platform ingress-platform/traefik,$(OBJECT)),$(MAKE) services-tools)
	$(if $(filter all data-platform data-platform/object-storage data-platform/ragflow,$(OBJECT)),$(MAKE) install-binaries BINARIES=mc)
	$(if $(filter all ingress-platform ingress-platform/traefik,$(OBJECT)),$(MAKE) services-chart)
	$(MAKE) services-render
	$(MAKE) services-validate-release
	$(MAKE) flux-source-apply
	$(MAKE) services-check

.PHONY: services-credentials
services-credentials:
	$(ANSIBLE) -i host/inventory.yaml services/credentials.yaml $(CONFIG_ARGS)

.PHONY: services-check services-check-public
services-check:
	$(ANSIBLE) -i host/inventory.yaml services/verify.yaml $(CONFIG_ARGS)

services-check-public:
	$(ANSIBLE) -i host/inventory.yaml services/verify.yaml $(CONFIG_ARGS) --extra-vars '{"services_ui_verify_port":"{{ entry_port }}"}'

.PHONY: services-validate-release
services-validate-release:
	$(ANSIBLE) -i host/inventory.yaml components/validate-release.yaml $(CONFIG_ARGS)

.PHONY: config
config:
	@printf '%s\n' '$(SITE)' $(CONFIG_FILES)

.PHONY: application-plan application-materials application-verify-materials application-publish
application-plan:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=plan --extra-vars '{"publication_image_ids":"{{ application_base_image_ids }}","publication_enabled":true,"publication_capacity_operation":"application-materials"}'
application-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=prepare --extra-vars '{"publication_image_ids":"{{ application_base_image_ids }}","publication_enabled":true,"publication_capacity_operation":"application-materials"}'
application-verify-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=verify --extra-vars '{"publication_image_ids":"{{ application_base_image_ids }}","publication_enabled":true,"publication_capacity_operation":"application-materials"}'
application-publish:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=publish --extra-vars '{"publication_image_ids":"{{ application_base_image_ids }}","publication_enabled":true,"publication_capacity_operation":"application-materials"}'

.PHONY: application-source-plan application-build-backend application-build-web application-build-admin
application-source-plan:
	$(ANSIBLE) -i host/inventory.yaml applications/build.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) build_component=$(COMPONENT) build_action=plan'
application-build-backend application-build-web application-build-admin:
	$(ANSIBLE) -i host/inventory.yaml applications/build.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) build_component=$(patsubst application-build-%,%,$@)'

.PHONY: application-publish-backend application-publish-web application-publish-admin
application-publish-backend application-publish-web application-publish-admin: APPLICATION_ROLE = $(patsubst application-publish-%,%,$@)
application-publish-backend application-publish-web application-publish-admin: APPLICATION_REPOSITORY = $(APP)-$(if $(filter backend,$(APPLICATION_ROLE)),backend,$(APPLICATION_ROLE)-frontend)
application-publish-backend application-publish-web application-publish-admin:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=publish --extra-vars '{"publication_image_ids":["$(APPLICATION_REPOSITORY)"],"publication_enabled":true,"publication_capacity_operation":"application-publish-$(APP)-$(APPLICATION_ROLE)","publication_lockfile":"$(CURDIR)/.build/applications/$(APPLICATION_REPOSITORY)-images.lock.json","publication_image_directory":"$(CURDIR)/.build/applications/transfer","publication_remove_transport":true}'
	$(MAKE) application-lock-$(APPLICATION_ROLE) APP=$(APP)

# 发布成功后，把构建写在 .build/ 里的「可审阅的部署镜像锁」拷进组件目录的 image.lock.yaml（渲染只认 gitops 里这一份）。
# 没有这一步，构建完的镜像不会进入声明（2026-10-06 发现）。单独调用也行：make application-lock-backend APP=info
.PHONY: application-lock-backend application-lock-web application-lock-admin
application-lock-backend application-lock-web application-lock-admin: APPLICATION_ROLE = $(patsubst application-lock-%,%,$@)
application-lock-backend application-lock-web application-lock-admin: APPLICATION_REPOSITORY = $(APP)-$(if $(filter backend,$(APPLICATION_ROLE)),backend,$(APPLICATION_ROLE)-frontend)
application-lock-backend application-lock-web application-lock-admin:
	@.venv/bin/python applications/sync-image-lock.py "$(CURDIR)/.build/applications/$(APPLICATION_REPOSITORY)-deployment-image.yaml" "$(CURDIR)/../gitops/components/app-platform/$(APP)-app/$(APPLICATION_REPOSITORY)/image.lock.yaml"

.PHONY: application-rehearse-downloads
application-rehearse-downloads:
	.venv/bin/python applications/tests/rehearse-downloads.py $(CONFIG_ARGS)

.PHONY: application-deployment-plan application-render application-stage application-validate-release application-check application-check-public application-bootstrap
application-deployment-plan:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=plan'
application-render:
	$(MAKE) services-render OBJECT=app-platform/$(APP)-app
application-stage:
	$(MAKE) services-stage OBJECT=app-platform/$(APP)-app
application-validate-release:
	$(MAKE) services-validate-release OBJECT=app-platform/$(APP)-app
application-check-public:
	$(MAKE) install-binaries BINARIES=mc
	$(ANSIBLE) -i host/inventory.yaml applications/verify.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=check application_check_public=true'

application-check:
	# 对象存储与知识源的验证脚本要用本工位的 .tools/bin/mc（第 27 轮：整套部署没跑到装它那一步，检查报 FileNotFoundError）
	$(MAKE) install-binaries BINARIES=mc
	$(ANSIBLE) -i host/inventory.yaml applications/verify.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=check'
# Executes only the explicitly promoted Git release. Source publication precedes deployment.
application-bootstrap:
	$(MAKE) application-render APP=$(APP)
	$(MAKE) application-validate-release APP=$(APP)
	$(MAKE) flux-source-apply
	$(MAKE) application-check APP=$(APP)

.PHONY: services-stage
services-stage:
	$(ANSIBLE) -i host/inventory.yaml components/render.yaml $(CONFIG_ARGS) --extra-vars components_action=stage
	$(MAKE) topology-stage

# Cluster stage declarations come only from gitops/components/**/stage.yaml (see components/README.md).
.PHONY: topology-render topology-stage topology-validate
topology-render topology-stage topology-validate:
	$(ANSIBLE) -i host/inventory.yaml components/topology.yaml $(CONFIG_ARGS) --extra-vars 'topology_action=$(patsubst topology-%,%,$@)'

.PHONY: services-ragflow-image services-ragflow-image-publish
services-ragflow-image:
	$(ANSIBLE) -i host/inventory.yaml ../gitops/components/data-platform/ragflow/image-build.yaml $(CONFIG_ARGS)
services-ragflow-image-publish:
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=publish --extra-vars '{"publication_lockfile":"{{ playbook_dir }}/../../gitops/components/data-platform/ragflow/image.lock.json","publication_image_ids":["ragflow-runtime"],"publication_enabled":"{{ services_ragflow_enabled }}","publication_skip_disabled":true,"publication_capacity_operation":"ragflow-runtime-publication"}'

# Serial native module invocation isolates facts between independent playbooks.
# The generated include contains only booleans, derived afresh on each deployment.
SELECTION_PREFIX := .build/host/selections/$(subst /,--,$(OBJECT))
-include $(SELECTION_PREFIX).mk
.PHONY: platform-deploy platform-deploy-selected platform-check platform-selection
platform-selection:
	$(ANSIBLE) -i host/inventory.yaml host/deployment.yaml $(CONFIG_ARGS) --extra-vars 'deployment_action=$(SELECTION_ACTION)'
platform-deploy: SELECTION_ACTION=deploy
platform-deploy: platform-selection
	$(MAKE) platform-deploy-selected
platform-deploy-selected:
	@.venv/bin/python -c 'import json,os; d=json.load(open("$(SELECTION_PREFIX).json")); assert d["object"]==os.environ["OBJECT"] and d["action"]=="deploy", "Run the public platform-deploy entry to validate this object afresh"'
	$(MAKE) preflight
	$(ANSIBLE) -i host/inventory.yaml host/dependencies.yaml $(CONFIG_ARGS)
	$(if $(or $(filter true,$(PLATFORM_REGISTRY)),$(filter true,$(PLATFORM_ENTRY))),$(MAKE) install-binaries BINARIES=compose)
	$(if $(filter true,$(PLATFORM_REGISTRY)),$(MAKE) prepare-harbor-materials)
	$(if $(filter true,$(PLATFORM_REGISTRY)),$(MAKE) registry-deploy)
	$(if $(filter true,$(PLATFORM_ENTRY)),$(MAKE) entry-deploy)
	$(if $(filter true,$(PLATFORM_CLUSTER)),$(MAKE) cluster-deploy)
	# 先把选中阶段要用的平台镜像发到 Harbor，再让 Flux 应用源：整套声明是一个包，源一应用所有阶段就开始拉镜像
	# （2026-10-06 第 27 轮：三个控制台镜像没发布，根调和等 10 分钟超时，发布那一段排在源应用之后根本没跑到）
	$(if $(filter true,$(PLATFORM_SERVICES)),$(MAKE) services-verify-materials services-publish SERVICE_IMAGES=$(PLATFORM_SERVICE_IMAGES))
	$(if $(filter true,$(PLATFORM_FLUX)),$(MAKE) flux-bootstrap)
	$(if $(filter true,$(PLATFORM_FLUX)),$(MAKE) foundations-check)
	$(if $(and $(filter true,$(PLATFORM_FOUNDATIONS)),$(filter false,$(PLATFORM_SERVICES))),$(MAKE) services-render services-validate-release foundations-bootstrap foundations-check)
	$(if $(filter true,$(PLATFORM_SERVICES)),$(MAKE) services-bootstrap SERVICE_IMAGES=$(PLATFORM_SERVICE_IMAGES))
	$(if $(filter true,$(PLATFORM_TPL)),$(MAKE) application-bootstrap APP=tpl)
	$(if $(filter true,$(PLATFORM_INFO)),$(MAKE) application-bootstrap APP=info)
	$(if $(filter true,$(PLATFORM_KNOWLEDGE)),$(MAKE) application-bootstrap APP=knowledge)
	$(if $(filter true,$(PLATFORM_INVESTMENT)),$(MAKE) application-bootstrap APP=investment)
	$(if $(filter host,$(OBJECT)),$(MAKE) platform-install-lifecycle)

.PHONY: host-lifecycle-plan platform-install-lifecycle platform-enable-boot platform-start platform-stop platform-status
host-lifecycle-plan platform-install-lifecycle platform-enable-boot platform-start platform-stop:
	$(ANSIBLE) -i host/inventory.yaml host/lifecycle.yaml $(CONFIG_ARGS) --extra-vars 'host_action=$(if $(filter platform-install-lifecycle,$@),install,$(if $(filter host-lifecycle-plan,$@),plan,$(patsubst platform-%,%,$@)))'

platform-check: SELECTION_ACTION=check
platform-check: platform-selection
	$(MAKE) platform-check-selected
.PHONY: platform-check-selected
platform-check-selected:
	@.venv/bin/python -c 'import json,os; d=json.load(open("$(SELECTION_PREFIX).json")); assert d["object"]==os.environ["OBJECT"] and d["action"]=="check", "Run the public platform-check entry to validate this object afresh"'
	$(if $(filter host,$(OBJECT)),$(ANSIBLE) -i host/inventory.yaml host/lifecycle.yaml $(CONFIG_ARGS) --extra-vars host_action=status)
	$(if $(filter true,$(PLATFORM_CLUSTER)),$(MAKE) cluster-status)
	$(if $(filter true,$(PLATFORM_REGISTRY)),$(MAKE) registry-status)
	$(if $(filter true,$(PLATFORM_ENTRY)),$(MAKE) entry-status)
	$(if $(filter true,$(PLATFORM_FLUX)),$(MAKE) flux-source-status)
	$(if $(filter true,$(PLATFORM_SERVICES)),$(MAKE) services-check-public)
	$(if $(filter true,$(PLATFORM_TPL)),$(MAKE) application-check-public APP=tpl)
	$(if $(filter true,$(PLATFORM_INFO)),$(MAKE) application-check-public APP=info)
	$(if $(filter true,$(PLATFORM_KNOWLEDGE)),$(MAKE) application-check-public APP=knowledge)
	$(if $(filter true,$(PLATFORM_INVESTMENT)),$(MAKE) application-check-public APP=investment)

# Public object navigation is read-only. Lifecycle candidate generation is an internal host operation.
.PHONY: platform-plan platform-config platform-status
platform-plan platform-config:
	$(ANSIBLE) -i host/inventory.yaml host/deployment.yaml $(CONFIG_ARGS) --extra-vars 'deployment_action=$(patsubst platform-%,%,$@)'
platform-status:
ifneq ($(filter $(OBJECT),all host),)
	$(ANSIBLE) -i host/inventory.yaml host/lifecycle.yaml $(CONFIG_ARGS) --extra-vars host_action=status
endif
ifneq ($(filter $(OBJECT),registry entry cluster flux),)
	$(MAKE) $(if $(filter flux,$(OBJECT)),flux-source-status,$(OBJECT)-status)
endif
	$(ANSIBLE) -i host/inventory.yaml host/deployment.yaml $(CONFIG_ARGS) --extra-vars deployment_action=status

# Reviewed candidate generation and application source builds use the same object contract.
.PHONY: platform-stage platform-stage-selected platform-build platform-build-selected
platform-stage: SELECTION_ACTION=stage
platform-stage: platform-selection
	$(MAKE) platform-stage-selected
platform-stage-selected:
	@.venv/bin/python -c 'import json,os; d=json.load(open("$(SELECTION_PREFIX).json")); assert d["object"]==os.environ["OBJECT"] and d["action"]=="stage", "Run the public platform-stage entry to validate this object afresh"'
	$(if $(filter true,$(PLATFORM_FOUNDATIONS) $(PLATFORM_SERVICES) $(PLATFORM_TPL) $(PLATFORM_INFO) $(PLATFORM_KNOWLEDGE) $(PLATFORM_INVESTMENT)),$(MAKE) services-stage)
platform-build: SELECTION_ACTION=build
platform-build: platform-selection
	$(MAKE) platform-build-selected
platform-build-selected:
	@.venv/bin/python -c 'import json,os; d=json.load(open("$(SELECTION_PREFIX).json")); assert d["object"]==os.environ["OBJECT"] and d["action"]=="build", "Run the public platform-build entry to validate this object afresh"'
	$(if $(filter true,$(PLATFORM_TPL_BACKEND)),$(MAKE) application-build-backend application-publish-backend APP=tpl)
	$(if $(filter true,$(PLATFORM_TPL_WEB)),$(MAKE) application-build-web application-publish-web APP=tpl)
	$(if $(filter true,$(PLATFORM_TPL_ADMIN)),$(MAKE) application-build-admin application-publish-admin APP=tpl)
	$(if $(filter true,$(PLATFORM_INFO_BACKEND)),$(MAKE) application-build-backend application-publish-backend APP=info)
	$(if $(filter true,$(PLATFORM_INFO_WEB)),$(MAKE) application-build-web application-publish-web APP=info)
	$(if $(filter true,$(PLATFORM_INFO_ADMIN)),$(MAKE) application-build-admin application-publish-admin APP=info)
	$(if $(filter true,$(PLATFORM_KNOWLEDGE_BACKEND)),$(MAKE) application-build-backend application-publish-backend APP=knowledge)
	$(if $(filter true,$(PLATFORM_KNOWLEDGE_WEB)),$(MAKE) application-build-web application-publish-web APP=knowledge)
	$(if $(filter true,$(PLATFORM_KNOWLEDGE_ADMIN)),$(MAKE) application-build-admin application-publish-admin APP=knowledge)
	$(if $(filter true,$(PLATFORM_INVESTMENT_BACKEND)),$(MAKE) application-build-backend application-publish-backend APP=investment)
	$(if $(filter true,$(PLATFORM_INVESTMENT_WEB)),$(MAKE) application-build-web application-publish-web APP=investment)
	$(if $(filter true,$(PLATFORM_INVESTMENT_ADMIN)),$(MAKE) application-build-admin application-publish-admin APP=investment)
	$(foreach image,$(subst $(COMMA), ,$(PLATFORM_COMPONENT_IMAGES)),$(MAKE) component-build component-publish IMAGE=$(image) &&) true

# 自研的非应用镜像（applications/component-images.yaml）：同一条构建链，产物到 Harbor 的 platform/<名字>，锁进 gitops/components/<对象>/image.lock.yaml
COMMA := ,
REQUIRE_IMAGE = $(if $(IMAGE),,$(error IMAGE must be one of the names in applications/component-images.yaml))
.PHONY: component-build component-publish component-lock
component-build:
	@$(REQUIRE_IMAGE)true
	$(ANSIBLE) -i host/inventory.yaml applications/build.yaml $(CONFIG_ARGS) --extra-vars 'build_kind=component build_component=$(IMAGE)'
component-publish:
	@$(REQUIRE_IMAGE)true
	$(ANSIBLE) -i host/inventory.yaml artifacts/publish.yaml $(CONFIG_ARGS) --extra-vars publication_action=publish --extra-vars '{"publication_image_ids":["$(IMAGE)"],"publication_enabled":true,"publication_capacity_operation":"component-publish-$(IMAGE)","publication_lockfile":"$(CURDIR)/.build/applications/$(IMAGE)-images.lock.json","publication_image_directory":"$(CURDIR)/.build/applications/transfer","publication_remove_transport":true}'
	$(MAKE) component-lock IMAGE=$(IMAGE)
component-lock:
	@$(REQUIRE_IMAGE)true
	@.venv/bin/python applications/sync-image-lock.py "$(CURDIR)/.build/applications/$(IMAGE)-deployment-image.yaml" "$(CURDIR)/../gitops/components/$$(.venv/bin/python -c 'import yaml;print(yaml.safe_load(open("applications/component-images.yaml"))["images"]["$(IMAGE)"]["object"])')/image.lock.yaml" "$(IMAGE)"

# Human accounts follow the same object classification; import changes presets only.
.PHONY: platform-account-plan platform-account-import platform-account-view platform-account-check platform-account-stage platform-account-rotate platform-account-recover
platform-account-plan platform-account-import platform-account-view platform-account-check platform-account-stage platform-account-rotate platform-account-recover:
	$(ANSIBLE) -i host/inventory.yaml host/accounts.yaml $(CONFIG_ARGS) --extra-vars 'account_action=$(patsubst platform-account-%,%,$@) account_operation=$(ACCOUNT_OPERATION) account_maintenance_deadline=$(or $(ACCOUNT_DEADLINE),0)'
