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
	@printf '%s\n' 'tools        Install locked Ansible into platform/.venv' 'images       Show selected upstream image identities' 'check-images Fail if an upstream image is unresolved' 'install-binaries Install verified tools into .tools/bin only' 'preflight    Read-only host mount checks (Ansible)' 'plan-artifacts Preview selected locked files without downloads' 'fetch-artifacts Download and verify selected files after capacity check' 'check-artifacts Verify selected files fully offline' 'plan-node-build Preview verified official KIND build inputs' 'build-node    Build and inspect a new node image; no cluster creation' 'check-node    Inspect existing node image without rebuilding' 'plan-bootstrap-images Preview node and Calico archive preparation' 'fetch-bootstrap-images Pull/export and verify immutable image archives' 'check-bootstrap-images Verify complete archives offline' 'prepare-harbor-materials Extract official installer and load verified images only' 'registry-plan Preview standalone registry paths and backend' 'registry-deploy Configure and start the new Harbor without switching ingress' 'registry-start / registry-stop / registry-status Control only the new Harbor' 'prepare-host-materials / check-host-materials Prepare or verify HAProxy and skopeo archives' 'entry-plan / entry-deploy / entry-start / entry-stop / entry-status Control TLS entry' 'registry-accounts Provision private project and bounded publisher/puller identities' 'registry-publish-check Publish and fully pull back the locked HAProxy image after cutover' 'scanner-db-plan / scanner-db-install / scanner-db-verify Manage locked offline databases' 'registry-scan-check Scan the published image through Harbor and save the report' 'registry-recovery-plan / registry-recovery-check Rehearse an explicit cold backup in isolation' 'Cluster/application deployment targets are not implemented yet.'

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
