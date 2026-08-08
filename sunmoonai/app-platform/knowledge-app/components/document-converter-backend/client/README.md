# 文档转换客户端工具

## 脚本说明

**batch_convert_and_store.py** - 文档转换和存储脚本

- ✅ 处理文件系统中的文件（单个或多个，自动识别）
- ✅ 支持灵活的格式映射和存储配置
- ✅ 支持多种存储方式（MongoDB、Elasticsearch、对象存储、文件系统、PostgreSQL）

## 安装依赖

```bash
pip install -r requirements-batch.txt
```

## 核心概念

### 格式映射（Format Mapping）

指定每个输入格式要转换成什么输出格式。

**格式**: JSON对象，键为输入格式（不含点），值为输出格式列表

**示例**:
```json
{
  "pdf": ["txt", "html"],
  "docx": ["pdf", "txt"],
  "doc": ["pdf", "txt", "html"]
}
```

表示：
- PDF文件 → 转换为 txt 和 html
- Word文件（docx）→ 转换为 pdf 和 txt
- Word文件（doc）→ 转换为 pdf、txt 和 html

### 存储配置（Storage Config）

指定每个输出格式要存储到哪些存储系统。

**格式**: JSON对象，键为输出格式，值为存储类型列表

**支持的存储类型**:
- `object_storage`: 对象存储（MinIO/S3）
- `mongodb`: MongoDB
- `elasticsearch`: Elasticsearch
- `filesystem`: 文件系统
- `postgres`: PostgreSQL（仅存储元数据）

**示例**:
```json
{
  "pdf": ["object_storage"],
  "txt": ["elasticsearch", "mongodb"],
  "html": ["filesystem", "object_storage"]
}
```

表示：
- PDF格式 → 存储到对象存储
- TXT格式 → 存储到Elasticsearch和MongoDB
- HTML格式 → 存储到文件系统和对象存储

## 快速开始

### 示例1: PDF转TXT，存储到ES和MongoDB

```bash
python batch_convert_and_store.py \
    --input-dir /path/to/documents \
    --format-mapping '{"pdf": ["txt"]}' \
    --storage-config '{"txt": ["elasticsearch", "mongodb"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents \
    --elasticsearch-url http://localhost:9200
```

### 示例2: 多格式转换，多存储方式

```bash
python batch_convert_and_store.py \
    --input-dir /path/to/documents \
    --format-mapping '{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}' \
    --storage-config '{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"], "html": ["filesystem"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --object-storage minio \
    --minio-endpoint http://localhost:9000 \
    --minio-access-key minioadmin \
    --minio-secret-key minioadmin \
    --bucket documents \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents \
    --elasticsearch-url http://localhost:9200 \
    --output-dir /path/to/output \
    --postgres-uri postgresql://user:password@localhost:5432/mydb
```

### 示例3: 处理单个文件

直接指定文件路径作为 `--input-dir`（脚本会自动识别）：

```bash
python batch_convert_and_store.py \
    --input-dir /path/to/document.docx \
    --format-mapping '{"docx": ["txt"]}' \
    --storage-config '{"txt": ["mongodb"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents
```

## 参数说明

### 必需参数

- `--input-dir`: 输入目录路径（可以是目录或文件路径，脚本会自动识别）
- `--format-mapping`: 格式映射JSON字符串
- `--storage-config`: 存储配置JSON字符串
- `--service-url`: 文档转换服务地址

### 可选参数（根据存储配置选择）

#### 对象存储参数（当使用 `object_storage` 时）

**MinIO**:
- `--object-storage minio`
- `--minio-endpoint`: MinIO端点地址
- `--minio-access-key`: MinIO访问密钥
- `--minio-secret-key`: MinIO秘密密钥
- `--minio-secure`: 使用HTTPS（可选）
- `--bucket`: bucket名称

**S3**:
- `--object-storage s3`
- `--s3-access-key`: S3访问密钥
- `--s3-secret-key`: S3秘密密钥
- `--s3-endpoint-url`: S3端点URL（兼容S3的对象存储）
- `--s3-region`: S3区域（默认: `us-east-1`）
- `--bucket`: bucket名称

#### MongoDB参数（当使用 `mongodb` 时）

- `--mongodb-uri`: MongoDB连接URI
- `--mongodb-database`: MongoDB数据库名称
- `--mongodb-collection`: MongoDB集合名称

#### PostgreSQL参数（当使用 `postgres` 时）

- `--postgres-uri`: PostgreSQL连接URI

#### Elasticsearch参数（当使用 `elasticsearch` 时）

- `--elasticsearch-url`: Elasticsearch URL
- `--elasticsearch-index`: Elasticsearch索引名称（默认: `documents`）

#### 文件系统参数（当使用 `filesystem` 时）

- `--output-dir`: 文件系统输出目录

#### 其他参数

- `--extensions`: 要处理的文件扩展名，逗号分隔（默认: `.pdf,.doc,.docx`）
- `--recursive`: 递归处理子目录
- `--skip-health-check`: 跳过服务健康检查

## 使用场景

### 场景1: PDF转TXT，用于全文搜索

```bash
python batch_convert_and_store.py \
    --input-dir /archive/documents \
    --format-mapping '{"pdf": ["txt"]}' \
    --storage-config '{"txt": ["elasticsearch", "mongodb"]}' \
    --service-url http://document-converter.app-platform-dev.svc.cluster.local:8000 \
    --mongodb-uri mongodb://mongodb:27017 \
    --mongodb-database documents \
    --mongodb-collection texts \
    --elasticsearch-url http://elasticsearch:9200 \
    --recursive
```

### 场景2: 多格式归档

```bash
python batch_convert_and_store.py \
    --input-dir /uploads/new \
    --format-mapping '{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}' \
    --storage-config '{"pdf": ["object_storage"], "txt": ["elasticsearch"], "html": ["filesystem"]}' \
    --service-url https://www.sunmoonai.com/document-converter \
    --object-storage minio \
    --minio-endpoint http://minio:9000 \
    --minio-access-key minioadmin \
    --minio-secret-key minioadmin \
    --bucket archive \
    --elasticsearch-url http://elasticsearch:9200 \
    --output-dir /archive/html
```

### 场景3: 完整流程（所有存储方式）

```bash
python batch_convert_and_store.py \
    --input-dir /documents \
    --format-mapping '{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}' \
    --storage-config '{
        "pdf": ["object_storage", "postgres"],
        "txt": ["elasticsearch", "mongodb", "postgres"],
        "html": ["filesystem", "object_storage"]
    }' \
    --service-url https://www.sunmoonai.com/document-converter \
    --object-storage s3 \
    --s3-access-key YOUR_KEY \
    --s3-secret-key YOUR_SECRET \
    --bucket documents \
    --mongodb-uri mongodb://localhost:27017 \
    --mongodb-database mydb \
    --mongodb-collection documents \
    --postgres-uri postgresql://user:password@localhost:5432/mydb \
    --elasticsearch-url http://localhost:9200 \
    --output-dir /output/html
```

## 数据存储结构

### MongoDB 文档结构

**二进制内容存储**（非TXT格式）:
```json
{
  "_id": ObjectId("..."),
  "file_name": "document.pdf",
  "format": "pdf",
  "content": <二进制内容>,
  "content_length": 1234,
  "created_at": ISODate("2024-01-01T12:00:00Z"),
  "original_path": "/path/to/document.docx"
}
```

**文本内容存储**（TXT格式）:
```json
{
  "_id": ObjectId("..."),
  "original_filename": "document.docx",
  "txt_content": "转换后的文本内容...",
  "content_length": 1234,
  "converted_filename": "document.txt",
  "file_size": 5678,
  "format": "txt",
  "created_at": ISODate("2024-01-01T12:00:00Z"),
  "original_path": "/path/to/document.docx"
}
```

### Elasticsearch 文档结构

```json
{
  "_id": "abc123..._txt",
  "original_path": "/path/to/document.pdf",
  "file_name": "document.txt",
  "file_hash": "abc123...",
  "format": "txt",
  "content": "转换后的文本内容...",
  "content_length": 1234,
  "created_at": "2024-01-01T12:00:00",
  "metadata": {
    "original_path": "/path/to/document.pdf"
  }
}
```

### PostgreSQL 元数据结构

```sql
CREATE TABLE document_metadata (
    id SERIAL PRIMARY KEY,
    original_path VARCHAR(500) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_hash VARCHAR(64),
    format_mapping JSONB NOT NULL,      -- 格式映射
    storage_info JSONB NOT NULL,         -- 存储信息
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);
```

**示例数据**:
```json
{
  "id": 1,
  "original_path": "/path/to/document.pdf",
  "file_name": "document.pdf",
  "file_hash": "abc123...",
  "format_mapping": {
    "pdf": ["txt", "html"]
  },
  "storage_info": {
    "txt": {
      "elasticsearch": "saved",
      "mongodb": "saved"
    },
    "html": {
      "filesystem": "/output/html/document.html"
    }
  }
}
```

### 文件系统存储结构

```
output-dir/
├── txt/
│   ├── document1.txt
│   └── document2.txt
├── html/
│   ├── document1.html
│   └── document2.html
└── pdf/
    ├── document1.pdf
    └── document2.pdf
```

## 格式映射配置示例

### 示例1: 简单配置

```json
{
  "pdf": ["txt"]
}
```
PDF文件只转换为TXT

### 示例2: 多格式转换

```json
{
  "pdf": ["txt", "html"],
  "docx": ["pdf", "txt", "html"]
}
```
PDF转换为TXT和HTML，Word转换为PDF、TXT和HTML

### 示例3: 复杂配置

```json
{
  "pdf": ["txt", "html", "odt"],
  "docx": ["pdf", "txt"],
  "doc": ["pdf", "txt", "html"],
  "xlsx": ["pdf", "csv"]
}
```

## 存储配置示例

### 示例1: 单一存储

```json
{
  "txt": ["elasticsearch"]
}
```
TXT只存储到Elasticsearch

### 示例2: 多存储

```json
{
  "pdf": ["object_storage"],
  "txt": ["elasticsearch", "mongodb"]
}
```
PDF存储到对象存储，TXT存储到ES和MongoDB

### 示例3: 完整配置

```json
{
  "pdf": ["object_storage", "postgres"],
  "txt": ["elasticsearch", "mongodb", "postgres"],
  "html": ["filesystem", "object_storage"]
}
```

## 注意事项

1. **格式映射和存储配置必须匹配**: 存储配置中的格式必须在格式映射的输出格式中存在
2. **存储系统可选**: 只需要配置实际使用的存储系统参数
3. **文件去重**: 使用文件SHA256哈希进行去重
4. **错误处理**: 单个文件转换失败不会影响其他文件处理
5. **Elasticsearch索引**: 首次运行会自动创建索引，文本格式使用IK分词器
6. **MongoDB存储**: TXT格式使用文本存储（`txt_content`字段），其他格式使用二进制存储（`content`字段）

## 故障排查

### JSON格式错误

确保格式映射和存储配置是有效的JSON格式，可以使用在线JSON验证工具检查。

### 存储系统连接失败

检查对应的连接参数是否正确，网络是否可达。

### 格式转换失败

检查转换服务是否正常运行，文件格式是否支持。

## 性能优化建议

1. **批量处理**: 对于大量文件，考虑分批处理
2. **并发处理**: 可以修改脚本支持多线程/多进程
3. **增量处理**: 使用文件哈希避免重复处理
4. **存储选择**: 根据实际需求选择合适的存储方式，避免不必要的存储
