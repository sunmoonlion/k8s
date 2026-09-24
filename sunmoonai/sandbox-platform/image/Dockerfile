# 沙箱镜像（0003-sandbox）：每用户一个 pod 里跑的东西——钉版 Codex app-server + 沙箱侧出站桥。
# 用户 key 不进镜像：运行时以 Secret 注入进程环境（OPENAI_API_KEY / 厂商 key），或挂 auth.json。
ARG NODE_IMAGE=node:22-bookworm-slim
FROM ${NODE_IMAGE}
ARG CODEX_VERSION=0.155.1
ENV CODEX_VERSION=${CODEX_VERSION} \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    CODEX_HOME=/data/codex \
    BRIDGE_PORT=47002 \
    APP_SERVER_PORT=47800
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip ca-certificates git ripgrep tini \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir "websockets>=13,<18" \
    && npm install -g "@openai/codex@${CODEX_VERSION}" \
    && codex --version | grep -q "${CODEX_VERSION}" \
    && useradd -m -u 10001 -s /bin/bash codex && mkdir -p /data/codex && chown -R codex:codex /data
COPY --chown=codex:codex bridge/sandbox_bridge.py /opt/sandbox/sandbox_bridge.py
COPY --chown=codex:codex image/entrypoint.sh /opt/sandbox/entrypoint.sh
RUN chmod +x /opt/sandbox/entrypoint.sh
USER codex
WORKDIR /data
VOLUME ["/data/codex"]
EXPOSE 47800
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/sandbox/entrypoint.sh"]
