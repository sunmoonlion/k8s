SHELL := /bin/bash
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

UV ?= uv
HOST_PYTHON ?= /usr/bin/python3
ANSIBLE := .venv/bin/ansible-playbook
SITE ?= environments/kind/site.yaml

.PHONY: help tools images preflight check-images
help:
	@printf '%s\n' 'tools        Install locked Ansible into platform/.venv' 'images       Show selected upstream image identities' 'check-images Fail if an upstream image is unresolved' 'preflight    Read-only host mount checks (Ansible)' 'Deployment/lifecycle targets are not implemented yet.'

tools:
	$(UV) venv --python '$(HOST_PYTHON)' --allow-existing .venv
	$(UV) pip sync --python .venv/bin/python --require-hashes --index-url https://pypi.org/simple tools/requirements.lock

images:
	@jq -r '.images[] | [.id, .status, .source, (.reference // "UNRESOLVED")] | @tsv' artifacts/upstream-images.lock.json

check-images:
	@jq -r ' .images[] | select(.status != "resolved") | "UNRESOLVED: " + .id + " — " + .reason' artifacts/upstream-images.lock.json
	@jq -e '.schema_version == 1 and .platform == "linux/amd64" and .complete == true and (.images | length > 0) and ([.images[].id] | length == (unique | length)) and all(.images[]; .status == "resolved" and (.manifest_digest | test("^sha256:[a-f0-9]{64}$$")) and (.reference | test("^[^@]+@sha256:[a-f0-9]{64}$$")))' artifacts/upstream-images.lock.json >/dev/null

preflight:
	$(ANSIBLE) -i host/inventory.yaml host/preflight.yaml --extra-vars '@$(SITE)' --check
