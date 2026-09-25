FROM python:3.12-slim
# 与其它后端镜像同一约定：默认清华镜像（本地机上默认源超时，KIND 09 实测）；海外构建传 --build-arg PYPI_INDEX_URL=https://pypi.org/simple
ARG PYPI_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ENV PYTHONUNBUFFERED=1 RELAY_HOST=0.0.0.0 RELAY_PORT=47100
WORKDIR /opt/relay
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url "$PYPI_INDEX_URL" -r requirements.txt && useradd -r -u 10002 relay
COPY relay.py .
USER relay
EXPOSE 47100
HEALTHCHECK --interval=30s --timeout=3s CMD python3 -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:47100/healthz',timeout=2).status==200 else 1)"
CMD ["python3", "relay.py"]
