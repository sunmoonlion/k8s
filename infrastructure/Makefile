SHELL := /bin/bash
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

UV ?= uv
HOST_PYTHON ?= /usr/bin/python3
ANSIBLE := .venv/bin/ansible-playbook
ARTIFACTS ?= all
# Optional subset of configured service material IDs; does not enable runtime components.
SERVICE_IMAGES ?= all
BINARIES ?= kind,kubectl,kubeadm
SITE ?= environments/kind/site.yaml
APP ?= tpl
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
	../gitops/components/data-platform/text-embeddings/config.yaml \
	../gitops/components/data-platform/elk/config.yaml \
	../gitops/components/data-platform/neo4j/config.yaml \
	../gitops/components/messaging-platform/rabbitmq/config.yaml \
	../gitops/components/ingress-platform/traefik/config.yaml \
	../gitops/components/app-platform/auth-app/casdoor/config.yaml
CONFIG_ARGS = $(foreach file,$(CONFIG_FILES),--extra-vars '@$(file)') --extra-vars '@$(SITE)'

.PHONY: help tools images preflight check-images
help:
	@printf '%s\n' 'config       List the authoritative user configuration files' 'tools        Install locked Ansible into infrastructure/.venv' 'images       Show selected upstream image identities' 'check-images Fail if an upstream image is unresolved' 'install-binaries Install verified tools into .tools/bin only' 'preflight    Read-only host mount checks (Ansible)' 'plan-artifacts Preview selected locked files without downloads' 'fetch-artifacts Download and verify selected files after capacity check' 'check-artifacts Verify selected files fully offline' 'plan-node-build Preview verified official KIND build inputs' 'build-node    Build and inspect a new node image; no cluster creation' 'check-node    Inspect existing node image without rebuilding' 'plan-bootstrap-images Preview node and Calico archive preparation' 'fetch-bootstrap-images Pull/export and verify immutable image archives' 'check-bootstrap-images Verify complete archives offline' 'prepare-harbor-materials Extract official installer and load verified images only' 'registry-plan Preview standalone registry paths and backend' 'registry-deploy Configure and start the new Harbor without switching ingress' 'registry-start / registry-stop / registry-status Control only the new Harbor' 'prepare-host-materials / check-host-materials Prepare or verify HAProxy and skopeo archives' 'entry-plan / entry-preview / entry-deploy / entry-start / entry-stop / entry-status Control TLS entry' 'registry-accounts Provision private project and bounded publisher/puller identities' 'registry-publish-check Publish and fully pull back the locked HAProxy image after cutover' 'scanner-db-plan / scanner-db-install / scanner-db-verify Manage locked offline databases' 'registry-scan-check Scan the published image through Harbor and save the report' 'registry-recovery-plan / registry-recovery-check Rehearse an explicit cold backup in isolation' 'cluster-plan / cluster-deploy / cluster-status Native isolated KIND bootstrap' 'cluster-pull-check Verify private pulls and DNS on all three nodes' 'install-flux / flux-plan / flux-materials / flux-verify-materials / flux-publish Manage locked Flux materials' 'flux-bootstrap Verify materials, publish, install and reconcile the promoted source' 'flux-deploy / flux-status Install and check controllers' 'flux-release / flux-source-apply / flux-source-status Publish and reconcile committed declarations' 'install-secrets-tools / secrets-prepare / secrets-apply / secrets-status Manage independent SOPS identity' 'foundations-bootstrap / foundations-check Deploy and verify SOPS and platform base declarations' 'services-plan / services-materials / services-publish Prepare pinned first-batch images' 'services-render / services-stage / services-validate-release Review settings against the promoted GitOps release' 'services-bootstrap / services-check Deploy and verify the first service batch' 'application-plan / application-materials / application-verify-materials / application-publish Prepare locked application base images' 'application-build-backend / application-publish-backend Build and publish backend; APP=tpl|info|knowledge|investment' 'application-build-web / application-build-admin Build frontends of the selected APP' 'application-publish-web / application-publish-admin Publish verified frontend archives' 'application-source-plan APP=tpl COMPONENT=backend Check clean pinned sources without building' 'application-rehearse-downloads Exercise real dependency download fallback' 'application-deployment-plan / application-stage APP=tpl|info|knowledge|investment Prepare selected identities and runtime declarations' 'application-bootstrap / application-check APP=tpl|info|knowledge|investment Reconcile selected declarations and verify identities and runtime'

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

.PHONY: plan-artifacts fetch-artifacts check-artifacts
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
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml $(CONFIG_ARGS) --extra-vars flux_source_action=apply
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
	$(ANSIBLE) -i host/inventory.yaml services/render.yaml $(CONFIG_ARGS)
# Deploy the promoted, committed release. Rendering a changed release is a separate review step.
services-bootstrap:
	$(MAKE) services-credentials
	$(MAKE) services-verify-materials
	$(MAKE) services-publish
	$(MAKE) services-tools
	$(MAKE) install-binaries BINARIES=mc
	$(MAKE) services-chart
	$(MAKE) services-render
	$(MAKE) services-validate-release
	$(MAKE) flux-source-apply
	$(MAKE) services-check

.PHONY: services-credentials
services-credentials:
	$(ANSIBLE) -i host/inventory.yaml services/credentials.yaml $(CONFIG_ARGS)

.PHONY: services-check
services-check:
	$(ANSIBLE) -i host/inventory.yaml services/verify.yaml $(CONFIG_ARGS)

.PHONY: services-validate-release
services-validate-release:
	$(ANSIBLE) -i host/inventory.yaml services/validate-release.yaml $(CONFIG_ARGS)

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

.PHONY: application-rehearse-downloads
application-rehearse-downloads:
	.venv/bin/python applications/tests/rehearse-downloads.py $(CONFIG_ARGS)

.PHONY: application-deployment-plan application-render application-stage application-validate-release application-check application-check-public application-bootstrap
application-deployment-plan:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=plan'
application-render:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=render'
application-stage:
	$(MAKE) application-render APP=$(APP)
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=stage'
application-validate-release:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=validate'
application-check-public:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=check application_check_public=true'

application-check:
	$(ANSIBLE) -i host/inventory.yaml applications/deploy.yaml $(CONFIG_ARGS) --extra-vars 'application_name=$(APP) application_action=check'
# Executes only the explicitly promoted Git release. Source publication precedes deployment.
application-bootstrap:
	$(MAKE) application-render APP=$(APP)
	$(MAKE) application-validate-release APP=$(APP)
	$(MAKE) flux-source-apply
	$(MAKE) application-check APP=$(APP)

.PHONY: services-stage
services-stage:
	$(ANSIBLE) -i host/inventory.yaml services/render.yaml $(CONFIG_ARGS) --extra-vars services_action=stage
