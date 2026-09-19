# 问数展示服务（研究 Demo）

把第 25 课 `integrated_agent_service` 以单副本 FastAPI 挂到现有 Kind 集群，只用于访问展示，不进正式 bundle / 门禁。

## 访问

- https://127.0.0.1:30443/
- https://question.sunmoonai.com:30443/（需 hosts：`127.0.0.1 question.sunmoonai.com`）

证书是集群已有的 `*.sunmoonai.com`，浏览器可能提示不受信任，继续访问即可。

## 部署

```bash
cd /home/zymun/master/k8s/sunmoonai/app-platform/question-data-demo
chmod +x deploy.sh
./deploy.sh
```

默认从第 23 课 `.env` 读取 `DEEPSEEK_API_KEY`，源码目录是第 25 课 `integrated_agent_service`。可用环境变量覆盖：

```text
QUESTION_DATA_SOURCE_DIR
DEEPSEEK_ENV_FILE
KUBECONFIG   # 默认 ~/.kube/kind-config
```

## 说明

- 单副本、内存任务存储，重启会丢进行中的任务
- 问数数据是课程自带的 SQLite 演示库
- 企业微信 / Codex 未部署
