# No package upgrades: fix the official image's inaccessible UV interpreter.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
USER 0:0
RUN chmod 0755 /root
USER 1000:1000
RUN /ragflow/.venv/bin/python3 -c "import sys,ruamel.yaml; assert sys.version_info[:2] == (3,13)"
