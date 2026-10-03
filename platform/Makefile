SHELL := /bin/bash
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

UV ?= uv
HOST_PYTHON ?= /usr/bin/python3
ANSIBLE := .venv/bin/ansible-playbook
ARTIFACTS ?= all
BINARIES ?= kind,kubectl,kubeadm
SITE ?= environments/kind/site.yaml

.PHONY: help tools images preflight check-images
help:
	@printf '%s\n' 'tools        Install locked Ansible into platform/.venv' 'images       Show selected upstream image identities' 'check-images Fail if an upstream image is unresolved' 'install-binaries Install verified tools into .tools/bin only' 'preflight    Read-only host mount checks (Ansible)' 'plan-artifacts Preview selected locked files without downloads' 'fetch-artifacts Download and verify selected files after capacity check' 'check-artifacts Verify selected files fully offline' 'plan-node-build Preview verified official KIND build inputs' 'build-node    Build and inspect a new node image; no cluster creation' 'check-node    Inspect existing node image without rebuilding' 'plan-bootstrap-images Preview node and Calico archive preparation' 'fetch-bootstrap-images Pull/export and verify immutable image archives' 'check-bootstrap-images Verify complete archives offline' 'prepare-harbor-materials Extract official installer and load verified images only' 'registry-plan Preview standalone registry paths and backend' 'registry-deploy Configure and start the new Harbor without switching ingress' 'registry-start / registry-stop / registry-status Control only the new Harbor' 'prepare-host-materials / check-host-materials Prepare or verify HAProxy and skopeo archives' 'entry-plan / entry-deploy / entry-start / entry-stop / entry-status Control TLS entry' 'registry-accounts Provision private project and bounded publisher/puller identities' 'registry-publish-check Publish and fully pull back the locked HAProxy image after cutover' 'scanner-db-plan / scanner-db-install / scanner-db-verify Manage locked offline databases' 'registry-scan-check Scan the published image through Harbor and save the report' 'registry-recovery-plan / registry-recovery-check Rehearse an explicit cold backup in isolation' 'cluster-plan / cluster-deploy / cluster-status Native isolated KIND bootstrap' 'cluster-pull-check Verify private pulls and DNS on all three nodes' 'install-flux / flux-plan / flux-materials / flux-verify-materials / flux-publish Manage locked Flux materials' 'flux-bootstrap Verify materials, publish, install and reconcile the promoted source' 'flux-deploy / flux-status Install and check controllers' 'flux-release / flux-source-apply / flux-source-status Publish and reconcile committed declarations' 'install-secrets-tools / secrets-prepare / secrets-apply / secrets-status Manage independent SOPS identity' 'foundations-bootstrap / foundations-check Deploy and verify SOPS and platform base declarations' 'services-plan / services-materials / services-publish Prepare pinned first-batch images' 'services-render / services-validate-release Review settings against the promoted GitOps release' 'services-bootstrap / services-check Deploy and verify the first service batch' 'Business application deployment targets are not implemented yet.'

tools:
	$(UV) venv --python '$(HOST_PYTHON)' --allow-existing .venv
	$(UV) pip sync --python .venv/bin/python --require-hashes --index-url https://pypi.org/simple tools/requirements.lock

images:
	@jq -r '.images[] | [.id, .status, .source, (.reference // "UNRESOLVED")] | @tsv' artifacts/upstream-images.lock.json

check-images:
	@jq -r ' .images[] | select(.status != "resolved") | "UNRESOLVED: " + .id + " — " + .reason' artifacts/upstream-images.lock.json
	@jq -e '.schema_version == 1 and .platform == "linux/amd64" and .complete == true and (.images | length > 0) and ([.images[].id] | length == (unique | length)) and all(.images[]; .status == "resolved" and .platform == "linux/amd64" and ((.reference | split("@")[1]) == .manifest_digest) and (.manifest_digest | test("^sha256:[a-f0-9]{64}$$")) and (.reference | test("^[^@]+@sha256:[a-f0-9]{64}$$")))' artifacts/upstream-images.lock.json >/dev/null

preflight:
	$(ANSIBLE) -i host/inventory.yaml host/preflight.yaml --extra-vars '@$(SITE)' --check

.PHONY: plan-artifacts fetch-artifacts check-artifacts
plan-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml --extra-vars '@$(SITE)' --extra-vars 'artifact_action=plan artifact_ids=$(ARTIFACTS)'

fetch-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml --extra-vars '@$(SITE)' --extra-vars 'artifact_action=fetch artifact_ids=$(ARTIFACTS)'

check-artifacts:
	$(ANSIBLE) -i host/inventory.yaml artifacts/files.yaml --extra-vars '@$(SITE)' --extra-vars 'artifact_action=verify artifact_ids=$(ARTIFACTS)'

.PHONY: install-binaries
install-binaries:
	$(ANSIBLE) -i host/inventory.yaml tools/install-binaries.yaml --extra-vars '@$(SITE)' --extra-vars 'binary_ids=$(BINARIES)'

.PHONY: plan-node-build build-node
plan-node-build:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml --extra-vars '@$(SITE)' --extra-vars node_action=plan

build-node:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml --extra-vars '@$(SITE)' --extra-vars node_action=build

.PHONY: check-node
check-node:
	$(ANSIBLE) -i host/inventory.yaml cluster/build-node.yaml --extra-vars '@$(SITE)' --extra-vars node_action=verify

.PHONY: plan-bootstrap-images fetch-bootstrap-images check-bootstrap-images
plan-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml --extra-vars '@$(SITE)' --extra-vars image_action=plan

fetch-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml --extra-vars '@$(SITE)' --extra-vars image_action=fetch

check-bootstrap-images:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml --extra-vars '@$(SITE)' --extra-vars image_action=verify

.PHONY: prepare-harbor-materials
prepare-harbor-materials:
	$(ANSIBLE) -i host/inventory.yaml registry/materials.yaml --extra-vars '@$(SITE)'

.PHONY: registry-plan registry-deploy registry-start registry-stop registry-status
registry-plan registry-deploy registry-start registry-stop registry-status:
	$(ANSIBLE) -i host/inventory.yaml registry/service.yaml --extra-vars '@$(SITE)' --extra-vars 'registry_action=$(patsubst registry-%,%,$@)'

.PHONY: entry-plan entry-deploy entry-start entry-stop entry-status
entry-plan entry-deploy entry-start entry-stop entry-status:
	$(ANSIBLE) -i host/inventory.yaml host/entry.yaml --extra-vars '@$(SITE)' --extra-vars 'entry_action=$(patsubst entry-%,%,$@)'

.PHONY: prepare-host-materials check-host-materials
prepare-host-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml --extra-vars '@$(SITE)' --extra-vars 'image_group=host image_action=fetch'
check-host-materials:
	$(ANSIBLE) -i host/inventory.yaml artifacts/image-archives.yaml --extra-vars '@$(SITE)' --extra-vars 'image_group=host image_action=verify'

.PHONY: registry-accounts
registry-accounts:
	$(ANSIBLE) -i host/inventory.yaml registry/accounts.yaml --extra-vars '@$(SITE)'

.PHONY: registry-publish-check
registry-publish-check:
	$(ANSIBLE) -i host/inventory.yaml registry/publish.yaml --extra-vars '@$(SITE)'

.PHONY: scanner-db-plan scanner-db-install scanner-db-verify registry-scan-check
scanner-db-plan scanner-db-install scanner-db-verify:
	$(ANSIBLE) -i host/inventory.yaml registry/scanner-databases.yaml --extra-vars '@$(SITE)' --extra-vars 'scanner_database_action=$(patsubst scanner-db-%,%,$@)'

registry-scan-check:
	$(ANSIBLE) -i host/inventory.yaml registry/scan.yaml --extra-vars '@$(SITE)'

.PHONY: registry-recovery-plan registry-recovery-check
registry-recovery-plan registry-recovery-check:
	$(ANSIBLE) -i host/inventory.yaml registry/recovery.yaml --extra-vars '@$(SITE)' --extra-vars 'recovery_action=$(patsubst registry-recovery-%,%,$@) recovery_backup=$(BACKUP) recovery_backup_sha256=$(BACKUP_SHA256)'

.PHONY: cluster-plan cluster-deploy cluster-status
cluster-plan cluster-deploy cluster-status:
	$(ANSIBLE) -i host/inventory.yaml cluster/deploy.yaml --extra-vars '@$(SITE)' --extra-vars 'cluster_action=$(patsubst cluster-%,%,$@)'

.PHONY: cluster-pull-check
cluster-pull-check: cluster-status
	$(ANSIBLE) -i host/inventory.yaml cluster/pull-check.yaml --extra-vars '@$(SITE)'

.PHONY: install-flux
install-flux:
	$(ANSIBLE) -i host/inventory.yaml flux/tools.yaml --extra-vars '@$(SITE)'

.PHONY: flux-plan flux-materials flux-verify-materials flux-publish
flux-plan:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml --extra-vars '@$(SITE)' --extra-vars flux_material_action=plan
flux-materials:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml --extra-vars '@$(SITE)' --extra-vars flux_material_action=prepare
flux-verify-materials:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml --extra-vars '@$(SITE)' --extra-vars flux_material_action=verify
flux-publish:
	$(ANSIBLE) -i host/inventory.yaml flux/materials.yaml --extra-vars '@$(SITE)' --extra-vars flux_material_action=publish

.PHONY: flux-deploy flux-status
flux-deploy:
	$(ANSIBLE) -i host/inventory.yaml flux/bootstrap.yaml --extra-vars '@$(SITE)' --extra-vars flux_action=deploy
flux-status:
	$(ANSIBLE) -i host/inventory.yaml flux/bootstrap.yaml --extra-vars '@$(SITE)' --extra-vars flux_action=status

.PHONY: flux-release flux-source-apply flux-source-status
flux-release:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml --extra-vars '@$(SITE)' --extra-vars flux_source_action=publish
flux-source-apply:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml --extra-vars '@$(SITE)' --extra-vars flux_source_action=apply
flux-source-status:
	$(ANSIBLE) -i host/inventory.yaml flux/source.yaml --extra-vars '@$(SITE)' --extra-vars flux_source_action=status

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
	$(ANSIBLE) -i host/inventory.yaml tools/install-binaries.yaml --extra-vars '@$(SITE)' --extra-vars 'binary_ids=sops capacity_operation=sops-tools'
	$(ANSIBLE) -i host/inventory.yaml tools/install-age.yaml --extra-vars '@$(SITE)'
secrets-prepare secrets-apply secrets-status:
	$(ANSIBLE) -i host/inventory.yaml flux/secrets.yaml --extra-vars '@$(SITE)' --extra-vars 'secrets_action=$(patsubst secrets-%,%,$@)'
foundations-bootstrap:
	$(MAKE) install-secrets-tools
	$(MAKE) secrets-prepare
	$(MAKE) secrets-apply
	$(MAKE) flux-source-apply

.PHONY: foundations-check
foundations-check:
	$(MAKE) secrets-status
	$(MAKE) flux-source-status
	$(ANSIBLE) -i host/inventory.yaml flux/foundations-check.yaml --extra-vars '@$(SITE)'

.PHONY: services-plan services-materials services-verify-materials services-publish
services-plan:
	$(ANSIBLE) -i host/inventory.yaml services/materials.yaml --extra-vars '@$(SITE)' --extra-vars service_material_action=plan
services-materials:
	$(ANSIBLE) -i host/inventory.yaml services/materials.yaml --extra-vars '@$(SITE)' --extra-vars service_material_action=prepare
services-verify-materials:
	$(ANSIBLE) -i host/inventory.yaml services/materials.yaml --extra-vars '@$(SITE)' --extra-vars service_material_action=verify
services-publish:
	$(ANSIBLE) -i host/inventory.yaml services/materials.yaml --extra-vars '@$(SITE)' --extra-vars service_material_action=publish

.PHONY: services-tools services-chart services-render services-bootstrap
services-tools:
	$(ANSIBLE) -i host/inventory.yaml services/tools.yaml --extra-vars '@$(SITE)'
services-chart:
	$(ANSIBLE) -i host/inventory.yaml services/chart.yaml --extra-vars '@$(SITE)'
services-render:
	$(ANSIBLE) -i host/inventory.yaml services/render.yaml --extra-vars '@$(SITE)'
# Deploy the promoted, committed release. Rendering a changed release is a separate review step.
services-bootstrap:
	$(MAKE) services-credentials
	$(MAKE) services-verify-materials
	$(MAKE) services-publish
	$(MAKE) services-tools
	$(MAKE) services-chart
	$(MAKE) services-render
	$(MAKE) services-validate-release
	$(MAKE) flux-source-apply
	$(MAKE) services-check

.PHONY: services-credentials
services-credentials:
	$(ANSIBLE) -i host/inventory.yaml services/credentials.yaml --extra-vars '@$(SITE)'

.PHONY: services-check
services-check:
	$(ANSIBLE) -i host/inventory.yaml services/verify.yaml --extra-vars '@$(SITE)'

.PHONY: services-validate-release
services-validate-release:
	$(ANSIBLE) -i host/inventory.yaml services/validate-release.yaml --extra-vars '@$(SITE)'
