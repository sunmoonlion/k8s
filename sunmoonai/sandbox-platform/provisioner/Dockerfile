FROM python:3.12-slim
# 与其它后端镜像同一约定：默认清华镜像（本地机上默认源超时，KIND 09 实测）；海外构建传 --build-arg PYPI_INDEX_URL=https://pypi.org/simple
ARG PYPI_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ENV PYTHONUNBUFFERED=1
WORKDIR /opt/provisioner
COPY requirements.txt .
RUN pip install --no-cache-dir --index-url "$PYPI_INDEX_URL" -r requirements.txt && useradd -r -u 10003 provisioner
COPY provisioner.py .
USER provisioner
EXPOSE 8080
CMD ["uvicorn", "provisioner:app", "--host", "0.0.0.0", "--port", "8080"]
