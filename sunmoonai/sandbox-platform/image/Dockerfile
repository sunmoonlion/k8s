# 沙箱镜像（0003-sandbox）：每用户一个 pod 里跑的东西——钉版 Codex app-server + 沙箱侧出站桥。
# 用户 key 不进镜像：运行时以 Secret 注入进程环境（OPENAI_API_KEY / 厂商 key），或挂 auth.json。
# 基底由部署链的物料锁给（NODE_IMAGE = 平台统一的 node 运行镜像，Debian trixie）；npm 源由构建链按下载模式传。
# Codex 的 linux-x64 二进制是静态链接的，glibc 和 musl 的基底都能跑。
ARG NODE_IMAGE=node:24.21.0-trixie-slim
FROM ${NODE_IMAGE}
ARG CODEX_VERSION=0.155.1
ARG NPM_CONFIG_REGISTRY=https://registry.npmjs.org
ARG PYPI_INDEX_URL=https://pypi.org/simple
# Debian 软件源：构建链按下载模式传（国内 mirrors.tuna.tsinghua.edu.cn），不传就用官方
ARG DEBIAN_MIRROR=
ENV CODEX_VERSION=${CODEX_VERSION} \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    CODEX_HOME=/data/codex \
    BRIDGE_PORT=47002 \
    APP_SERVER_PORT=47800
RUN if [ -n "$DEBIAN_MIRROR" ]; then sed -i "s|https\?://deb.debian.org|${DEBIAN_MIRROR}|g" /etc/apt/sources.list.d/debian.sources; fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip ca-certificates git ripgrep tini bash curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --index-url "$PYPI_INDEX_URL" "websockets>=13,<18" \
    && npm config set registry "$NPM_CONFIG_REGISTRY" \
    && npm install -g "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && codex --version | grep -q "${CODEX_VERSION}" \
    && useradd -u 10001 -m -s /bin/bash codex && mkdir -p /data/codex && chown -R codex:codex /data
COPY --chown=codex:codex bridge/sandbox_bridge.py /opt/sandbox/sandbox_bridge.py
COPY --chown=codex:codex image/entrypoint.sh /opt/sandbox/entrypoint.sh
RUN chmod +x /opt/sandbox/entrypoint.sh
USER codex
WORKDIR /data
# 不要在这里声明 VOLUME ["/data/codex"]：containerd 会按它挂一个随容器生灭的匿名卷，盖住 PVC 里的同名子目录，
# 线程 rollout 全写在匿名卷里，回收再拉起就没了（KIND 2026-09-26 第 15、16 轮查明）。持久化由 Pod 规格挂 PVC 到 /data 保证。
EXPOSE 47800
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/sandbox/entrypoint.sh"]
