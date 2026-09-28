# 沙箱镜像（0003-sandbox）：每用户一个 pod 里跑的东西——钉版 Codex app-server + 沙箱侧出站桥。
# 用户 key 不进镜像：运行时以 Secret 注入进程环境（OPENAI_API_KEY / 厂商 key），或挂 auth.json。
# 基础镜像与平台其它镜像同一钉版（tpl/investment 前端用的 node:24.18.0-alpine）；内网构建传
#   --build-arg NODE_IMAGE=harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine@sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc
# Codex 的 linux-x64 二进制是 musl 静态链接，alpine 可直接跑。
ARG NODE_IMAGE=node:24.18.0-alpine
FROM ${NODE_IMAGE}
ARG CODEX_VERSION=0.155.1
ENV CODEX_VERSION=${CODEX_VERSION} \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    CODEX_HOME=/data/codex \
    BRIDGE_PORT=47002 \
    APP_SERVER_PORT=47800
RUN apk add --no-cache python3 py3-pip ca-certificates git ripgrep tini bash \
    && pip3 install --no-cache-dir "websockets>=13,<18" \
    && npm install -g "@openai/codex@${CODEX_VERSION}" \
    && codex --version | grep -q "${CODEX_VERSION}" \
    && adduser -D -u 10001 -s /bin/bash codex && mkdir -p /data/codex && chown -R codex:codex /data
COPY --chown=codex:codex bridge/sandbox_bridge.py /opt/sandbox/sandbox_bridge.py
COPY --chown=codex:codex image/entrypoint.sh /opt/sandbox/entrypoint.sh
RUN chmod +x /opt/sandbox/entrypoint.sh
USER codex
WORKDIR /data
# 不要在这里声明 VOLUME ["/data/codex"]：containerd 会按它挂一个随容器生灭的匿名卷，盖住 PVC 里的同名子目录，
# 线程 rollout 全写在匿名卷里，回收再拉起就没了（KIND 2026-09-26 第 15、16 轮查明）。持久化由 Pod 规格挂 PVC 到 /data 保证。
EXPOSE 47800
ENTRYPOINT ["/sbin/tini", "--", "/opt/sandbox/entrypoint.sh"]
