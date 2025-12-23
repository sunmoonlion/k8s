# Document Converter 文档转换服务

基于 LibreOffice 的轻量级文档转换服务，提供 REST API 接口，支持多种文档格式互转（文档、表格、演示文稿、图像）。

## 概述

Document Converter 是一个基于 LibreOffice 的轻量级文档转换服务，提供 REST API 接口，支持 Word/PDF 等文档转 PDF、HTML 和 TXT。相比 ONLYOFFICE Docs，它更轻量、部署更简单，专注于文档转换功能。

## 特性

- ✅ 轻量级（512MB-1GB 内存，无需数据库）
- ✅ 快速部署（独立服务，无外部依赖）
- ✅ REST API 接口
- ✅ 支持所有格式互转（无需逐项配置）
- ✅ 文档格式：Word/PDF/ODT/RTF/HTML/TXT 互转
- ✅ 表格格式：Excel/ODS/CSV 互转
- ✅ 演示文稿：PowerPoint/ODP 互转
- ✅ 图像格式：PNG/JPG/GIF 等互转或转 PDF
- ✅ Kubernetes 原生部署
- ✅ 水平扩展支持
- ✅ 无状态服务（可水平扩展）
- ✅ 快速响应（1-5秒，取决于文档大小）

## 架构设计

```
┌─────────────┐
│  Nuxt.js    │
│   Frontend  │
└──────┬──────┘
       │ HTTP POST /convert
       ▼
┌─────────────────────────┐
│  Document Converter API │
│  (FastAPI)              │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  LibreOffice Headless   │
│  --convert-to pdf/html/txt │
└─────────────────────────┘
```

## 技术栈

- **运行时**: Python 3.11+
- **Web 框架**: FastAPI
- **转换引擎**: LibreOffice (headless)
- **容器化**: Docker
- **部署**: Kubernetes

## 快速开始

### 1. 构建 Docker 镜像

```bash
cd /home/zym/k8s/sunmoonai/document-converter-app/document-converter-bff/resources/source
docker build -f build/Dockerfile -t document-converter:latest .
```

### 2. 推送镜像到 Harbor

```bash
# 标记镜像
docker tag document-converter:latest harbor.sunmoonai.com:30443/k8s-images/document-converter:latest

# 登录 Harbor
docker login harbor.sunmoonai.com:30443

# 推送镜像
docker push harbor.sunmoonai.com:30443/k8s-images/document-converter:latest
```

### 3. 部署到 Kubernetes

```bash
cd /home/zym/k8s/sunmoonai/document-converter-app/document-converter-bff/deploy-document-converter-bff/app/deploy-app
./deploy-document-converter-bff.sh --cluster C2
```

## 配置说明

### 主配置文件

`deploy-document-converter-bff/deploy-document-converter.conf`

主要配置项：
- `DOCUMENT_CONVERTER_NAMESPACE`: 命名空间（默认：app-platform-dev）
- `DOCUMENT_CONVERTER_IMAGE_REGISTRY`: 镜像仓库地址
- `DOCUMENT_CONVERTER_IMAGE_TAG`: 镜像标签（默认：latest）
- `DOCUMENT_CONVERTER_REPLICAS`: 副本数（默认：2）
- `DOCUMENT_CONVERTER_CPU_REQUEST`: CPU 请求（默认：500m）
- `DOCUMENT_CONVERTER_MEMORY_REQUEST`: 内存请求（默认：512Mi）
- `ingress_enabled`: 是否启用 Ingress（默认：false）
- `DOCUMENT_CONVERTER_UNIFIED_HOST`: 统一域名（如：www.sunmoonai.com）

## API 设计

### 转换接口

```http
POST /api/v1/convert
Content-Type: multipart/form-data

{
  "file": <file>,
  "format": "pdf" | "html" | "txt",
  "options": {
    "embed_images": true,  // HTML 格式：是否嵌入图片
    "quality": "high"      // PDF 格式：质量设置
  }
}
```

**响应**:
```json
{
  "success": true,
  "format": "pdf",
  "original_filename": "document.docx",
  "converted_filename": "document.pdf",
  "download_url": "/api/v1/download/document.pdf",
  "file_size": 123456
}
```

### 健康检查

```http
GET /health
```

**响应**:
```json
{
  "status": "healthy",
  "libreoffice_version": "7.6.0",
  "supported_formats": ["pdf", "html", "txt"]
}
```

### 支持的格式

```http
GET /api/v1/formats
```

## API 使用示例

### 健康检查

```bash
curl https://www.sunmoonai.com/document-converter/health
```

### 转换 Word 为 PDF

```bash
curl -X POST "https://www.sunmoonai.com/document-converter/api/v1/convert" \
  -F "file=@document.docx" \
  -F "format=pdf"
```

### 转换 Word 为 HTML

```bash
curl -X POST "https://www.sunmoonai.com/document-converter/api/v1/convert" \
  -F "file=@document.docx" \
  -F "format=html"
```

### 转换 Word 为 TXT

```bash
curl -X POST "https://www.sunmoonai.com/document-converter/api/v1/convert" \
  -F "file=@document.docx" \
  -F "format=txt"
```

### 转换 PDF 为 TXT

```bash
curl -X POST "https://www.sunmoonai.com/document-converter/api/v1/convert" \
  -F "file=@document.pdf" \
  -F "format=txt"
```

**注意**：
- PDF 转 TXT 会提取文本内容，可能会丢失格式和布局信息
- PDF 转 PDF 会重新处理，可能改变文件大小

### 获取支持的格式

```bash
curl https://www.sunmoonai.com/document-converter/api/v1/formats
```

## 访问方式

### 1. 集群内部访问（默认方式）

如果 `ingress_enabled="false"`（默认配置），服务仅通过 Kubernetes Service 在集群内部访问：

**Service 地址**：
- 完整域名：`http://document-converter.app-platform-dev.svc.cluster.local:8000`
- 短域名（同命名空间）：`http://document-converter:8000`
- Service IP：通过 `kubectl get svc document-converter -n app-platform-dev` 获取

**API 端点**：
```bash
# 健康检查
curl http://document-converter.app-platform-dev.svc.cluster.local:8000/health

# 转换接口
curl -X POST http://document-converter.app-platform-dev.svc.cluster.local:8000/api/v1/convert \
  -F "file=@document.docx" \
  -F "format=pdf"

# 获取支持的格式
curl http://document-converter.app-platform-dev.svc.cluster.local:8000/api/v1/formats
```

**适用场景**：
- 集群内部服务调用（如其他 Pod、Job、CronJob）
- 通过 Kubernetes Service 代理访问
- 不需要外部暴露的场景

### 2. 外部访问（通过 Ingress）

如果 `ingress_enabled="true"`，服务通过 Traefik IngressRoute 暴露到集群外部：

**访问地址**：
- 统一域名：`https://www.sunmoonai.com/document-converter`
- 节点 IP：`https://<节点IP>:30443/document-converter`
  - 例如：`https://115.190.153.150:30443/document-converter`

**API 端点**：
```bash
# 健康检查
curl https://www.sunmoonai.com/document-converter/health

# 转换接口
curl -X POST "https://www.sunmoonai.com/document-converter/api/v1/convert" \
  -F "file=@document.docx" \
  -F "format=pdf"

# 获取支持的格式
curl https://www.sunmoonai.com/document-converter/api/v1/formats
```

**配置方式**：
在 `deploy-document-converter-bff/deploy-document-converter.conf` 中设置：
```bash
ingress_enabled="true"  # 启用 Ingress
DOCUMENT_CONVERTER_UNIFIED_HOST="www.sunmoonai.com"  # 统一域名
```

**适用场景**：
- 前端应用调用（如 Nuxt.js、React）
- 外部系统集成
- 浏览器直接访问
- 需要 HTTPS 访问的场景

### 3. 端口转发（临时访问）

如果需要临时访问服务，可以使用 `kubectl port-forward`：

```bash
# 转发本地端口到 Service
kubectl port-forward svc/document-converter 8000:8000 -n app-platform-dev

# 然后通过本地访问
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/v1/convert \
  -F "file=@document.docx" \
  -F "format=pdf"
```

**适用场景**：
- 本地开发和测试
- 临时调试
- 不需要持久化配置的场景

## Nuxt.js 前端集成

### 配置方式

1. **如果启用了 Ingress**（`ingress_enabled="true"`）：
   ```javascript
   // nuxt.config.ts 或 .env
   export default {
     runtimeConfig: {
       public: {
         documentConverterUrl: 'https://www.sunmoonai.com/document-converter'
       }
     }
   }
   ```

2. **如果仅内部访问**（`ingress_enabled="false"`）：
   需要通过 Nuxt.js 的 API 路由作为代理：
   ```javascript
   // server/api/document-converter/[...].ts
   export default defineEventHandler(async (event) => {
     const url = `http://document-converter.app-platform-dev.svc.cluster.local:8000${event.node.req.url}`
     return await $fetch(url, {
       method: event.node.req.method,
       body: event.node.req.method !== 'GET' ? await readBody(event) : undefined
     })
   })
   ```

### 创建 Composable

```javascript
// composables/useDocumentConverter.js
export const useDocumentConverter = () => {
  const config = useRuntimeConfig()
  const apiBase = config.public.documentConverterApi || 
                  config.public.documentConverterUrl || 
                  'https://www.sunmoonai.com/document-converter'
  
  const convertDocument = async (file, format = 'pdf') => {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('format', format)
    
    const response = await $fetch(`${apiBase}/api/v1/convert`, {
      method: 'POST',
      body: formData
    })
    
    return response
  }
  
  const downloadFile = async (filename) => {
    const url = `${apiBase}/api/v1/download/${filename}`
    window.open(url, '_blank')
  }
  
  const getHealth = async () => {
    return await $fetch(`${apiBase}/health`)
  }
  
  const getFormats = async () => {
    return await $fetch(`${apiBase}/api/v1/formats`)
  }
  
  return { 
    convertDocument,
    downloadFile,
    getHealth,
    getFormats
  }
}
```

### 使用示例

```vue
<template>
  <div>
    <input type="file" @change="handleFileChange" accept=".doc,.docx" />
    <button @click="convertToPDF">转换为 PDF</button>
    <button @click="convertToHTML">转换为 HTML</button>
    <div v-if="convertedUrl">
      <a :href="convertedUrl" target="_blank">下载转换后的文件</a>
    </div>
  </div>
</template>

<script setup>
const { convertDocument, downloadFile } = useDocumentConverter()
const file = ref(null)
const convertedUrl = ref(null)

const handleFileChange = (event) => {
  file.value = event.target.files[0]
}

const convertToPDF = async () => {
  if (!file.value) return
  
  try {
    const result = await convertDocument(file.value, 'pdf')
    convertedUrl.value = result.download_url
  } catch (error) {
    console.error('转换失败:', error)
  }
}

const convertToHTML = async () => {
  if (!file.value) return
  
  try {
    const result = await convertDocument(file.value, 'html')
    convertedUrl.value = result.download_url
  } catch (error) {
    console.error('转换失败:', error)
  }
}
</script>
```

## 客户端工具

### batch_convert_and_store.py

文档转换和存储脚本，处理文件系统中的文件（单个或多个）：

```bash
# 安装依赖
cd client
pip install -r requirements-batch.txt

# 处理单个文件（直接指定文件路径）
python batch_convert_and_store.py \
    --input-dir /path/to/document.docx \
    --format-mapping '{"docx": ["txt"]}' \
    --storage-config '{"txt": ["mongodb"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents

# 批量处理多个文件
python batch_convert_and_store.py \
    --input-dir /path/to/documents \
    --format-mapping '{"pdf": ["txt"], "docx": ["pdf", "txt"]}' \
    --storage-config '{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents \
    --elasticsearch-url http://localhost:9200 \
    --recursive
```

**功能特点**：
- ✅ 处理文件系统中的文件（单个或多个，自动识别）
- ✅ **灵活的格式映射**：用户指定每个输入格式要转换成什么输出格式
- ✅ **灵活的存储配置**：用户指定每个输出格式要存储到哪些存储系统
- ✅ **多种存储方式**：支持MongoDB、Elasticsearch、对象存储（MinIO/S3）、文件系统、PostgreSQL
- ✅ 自动去重（基于文件哈希）
- ✅ 支持递归处理子目录

**格式映射示例**:
```json
{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}
```
表示：PDF文件转换为txt和html，Word文件转换为pdf和txt

**存储配置示例**:
```json
{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"]}
```
表示：PDF格式存储到对象存储，TXT格式存储到Elasticsearch和MongoDB

详细使用方法请参考：
- [client/README.md](client/README.md) - 完整使用说明
- [client/BATCH_USAGE.md](client/BATCH_USAGE.md) - 详细文档

## 目录结构

```
document-converter/
├── docs/                          # 文档
│   └── README.md
├── resources/                     # Kubernetes 资源
│   ├── source/                   # 源代码和 Dockerfile
│   │   ├── app.py               # FastAPI 应用
│   │   ├── requirements.txt     # Python 依赖
│   │   └── build/               # 构建相关
│   │       └── Dockerfile       # Docker 镜像构建
│   ├── deployment.yaml           # Deployment 配置
│   └── service.yaml             # Service 配置
├── client/                       # 客户端工具
│   ├── batch_convert_and_store.py      # 文档转换和存储脚本
│   ├── requirements-batch.txt    # 依赖文件
│   ├── requirements.txt          # 已整合到 requirements-batch.txt
│   ├── README.md                 # 客户端使用说明
│   ├── BATCH_USAGE.md           # 详细使用文档
│   └── example_batch.sh         # 使用示例脚本
├── deploy-document-converter-bff/    # 部署配置
│   ├── deploy-document-converter.sh
│   ├── deploy-document-converter.conf
│   └── resources/
│       └── document-converter/
│           ├── deployment.yaml
│           └── service.yaml
├── middleware/                   # Traefik 中间件
│   ├── document-converter-stripprefix.yaml
│   └── deploy-middleware-all/
│       └── deploy-middleware-all.sh
└── ingress/                      # Ingress 配置
    ├── ingress.yaml
    └── deploy-ingress/
        └── deploy-ingress.sh
```

## 资源需求

### 最小配置
- CPU: 0.5 cores
- 内存: 512MB
- 存储: 1GB（临时文件）

### 推荐配置
- CPU: 1 core
- 内存: 1GB
- 存储: 2GB（临时文件）

## 实现方案

### 方案1：简单同步服务（推荐）

适合小规模使用，同步处理请求。

**特点**:
- 实现简单
- 响应时间：1-5秒（取决于文档大小）
- 适合并发请求 < 10

### 方案2：异步服务（可选）

使用 Celery 或 FastAPI BackgroundTasks 处理转换。

**特点**:
- 支持高并发
- 可水平扩展
- 需要消息队列（Redis/RabbitMQ）

## 部署架构

```
┌─────────────────────────────────────┐
│  Kubernetes Cluster 2              │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  Document Converter Service   │  │
│  │  (Deployment)                │  │
│  │  - Replicas: 2-3             │  │
│  │  - Resources: 1CPU, 1GB RAM  │  │
│  └───────────────────────────────┘  │
│           │                          │
│           ▼                          │
│  ┌───────────────────────────────┐  │
│  │  Traefik IngressRoute         │  │
│  │  - Path: /document-converter  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 注意事项

1. **字体支持**
   - 确保容器中包含常用字体（中文字体）
   - 或挂载字体卷

2. **临时文件清理**
   - 定期清理转换后的临时文件
   - 设置文件保留时间

3. **错误处理**
   - 处理转换失败的情况
   - 返回友好的错误信息

4. **安全性**
   - 文件大小限制
   - 文件类型验证
   - 请求频率限制

## 与 ONLYOFFICE Docs 对比

| 特性 | ONLYOFFICE Docs | Document Converter |
|------|----------------|-------------------|
| 资源占用 | 4GB+ 内存 | 512MB-1GB 内存 |
| 依赖服务 | PostgreSQL、Redis、RabbitMQ | 无 |
| 部署复杂度 | 高 | 低 |
| 功能 | 完整 Office 套件 | 文档转换 |
| 适用场景 | 在线编辑、协作 | Word→PDF/HTML/TXT 转换 |

如果只需要文档转换功能，LibreOffice 转换服务是更好的选择：

- ✅ 资源占用低（1GB vs 4GB+）
- ✅ 部署简单（无需数据库、消息队列）
- ✅ 维护成本低
- ✅ 满足 Word→PDF/HTML/TXT 需求

如果需要在线编辑、协作等功能，才需要 ONLYOFFICE Docs。

## 故障排查

### 检查 Pod 状态

```bash
kubectl get pods -n app-platform-dev -l app=document-converter
```

### 查看日志

```bash
kubectl logs -n app-platform-dev -l app=document-converter --tail=100
```

### 检查服务

```bash
kubectl get svc -n app-platform-dev document-converter
```

### 检查 IngressRoute

```bash
kubectl get ingressroute -n app-platform-dev document-converter-route
```

## 维护

### 更新镜像

```bash
# 1. 构建新镜像
cd resources/source
docker build -f build/Dockerfile -t document-converter:v1.1.0 .

# 2. 推送镜像
docker tag document-converter:v1.1.0 harbor.sunmoonai.com:30443/k8s-images/document-converter:v1.1.0
docker push harbor.sunmoonai.com:30443/k8s-images/document-converter:v1.1.0

# 3. 更新配置
vim deploy-document-converter-bff/deploy-document-converter.conf
# 修改 DOCUMENT_CONVERTER_IMAGE_TAG="v1.1.0"

# 4. 重新部署
./deploy-document-converter.sh --cluster C2
```

### 扩展副本数

```bash
kubectl scale deployment document-converter -n app-platform-dev --replicas=3
```

## 许可证

内部使用
