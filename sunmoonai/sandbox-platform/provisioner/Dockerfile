# 供给器镜像。基底由部署链的物料锁给（PYTHON_IMAGE），和四个应用的后端同一个 python 基底；
# 依赖源由构建链按下载模式传（PYPI_INDEX_URL），不在这里写死国内或官方。
ARG PYTHON_IMAGE=python:3.13.15-slim-trixie
FROM ${PYTHON_IMAGE}
ARG PYPI_INDEX_URL=https://pypi.org/simple
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /opt/provisioner
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url "$PYPI_INDEX_URL" -r requirements.txt && useradd -r -u 10003 provisioner
COPY provisioner.py .
USER provisioner
EXPOSE 8080
CMD ["uvicorn", "provisioner:app", "--host", "0.0.0.0", "--port", "8080"]
