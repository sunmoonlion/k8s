# 会合点镜像。基底由部署链的物料锁给（PYTHON_IMAGE）；依赖源由构建链按下载模式传（PYPI_INDEX_URL）。
ARG PYTHON_IMAGE=python:3.13.15-slim-trixie
FROM ${PYTHON_IMAGE}
ARG PYPI_INDEX_URL=https://pypi.org/simple
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 RELAY_HOST=0.0.0.0 RELAY_PORT=47100
WORKDIR /opt/relay
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url "$PYPI_INDEX_URL" -r requirements.txt && useradd -r -u 10002 relay
COPY relay.py permission_reports.py .
USER relay
EXPOSE 47100
HEALTHCHECK --interval=30s --timeout=3s CMD python3 -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:47100/healthz',timeout=2).status==200 else 1)"
CMD ["python3", "relay.py"]
