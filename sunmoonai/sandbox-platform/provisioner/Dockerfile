FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /opt/provisioner
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd -r -u 10003 provisioner
COPY provisioner.py .
USER provisioner
EXPOSE 8080
CMD ["uvicorn", "provisioner:app", "--host", "0.0.0.0", "--port", "8080"]
