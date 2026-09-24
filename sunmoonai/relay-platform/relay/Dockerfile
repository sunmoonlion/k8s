FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 RELAY_HOST=0.0.0.0 RELAY_PORT=47100
WORKDIR /opt/relay
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd -r -u 10002 relay
COPY relay.py .
USER relay
EXPOSE 47100
HEALTHCHECK --interval=30s --timeout=3s CMD python3 -c "import urllib.request,sys;sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:47100/healthz',timeout=2).status==200 else 1)"
CMD ["python3", "relay.py"]
