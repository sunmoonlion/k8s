#!/bin/bash
# 批量文档转换并存储示例脚本

# 配置参数（根据实际情况修改）
INPUT_DIR="/path/to/documents"                    # 输入目录
SERVICE_URL="https://www.sunmoonai.com/document-converter"  # 转换服务地址

# 格式映射：指定每个输入格式要转换成什么输出格式
# 示例：PDF转txt和html，Word转pdf和txt
FORMAT_MAPPING='{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}'

# 存储配置：指定每个输出格式要存储到哪些存储系统
# 示例：PDF存储到对象存储，TXT存储到ES和MongoDB，HTML存储到文件系统
STORAGE_CONFIG='{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"], "html": ["filesystem"]}'

# MinIO配置
MINIO_ENDPOINT="http://localhost:9000"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="minioadmin"
BUCKET="documents"

# MongoDB配置
MONGODB_URI="mongodb://localhost:27017"
MONGODB_DATABASE="mydb"
MONGODB_COLLECTION="documents"

# PostgreSQL配置
POSTGRES_URI="postgresql://user:password@localhost:5432/mydb"

# Elasticsearch配置
ELASTICSEARCH_URL="http://localhost:9200"
ELASTICSEARCH_INDEX="documents"

# 文件系统输出目录
OUTPUT_DIR="/path/to/output"

# 执行批量转换
python batch_convert_and_store.py \
    --input-dir "${INPUT_DIR}" \
    --format-mapping "${FORMAT_MAPPING}" \
    --storage-config "${STORAGE_CONFIG}" \
    --extensions ".pdf,.doc,.docx" \
    --recursive \
    --service-url "${SERVICE_URL}" \
    --object-storage minio \
    --minio-endpoint "${MINIO_ENDPOINT}" \
    --minio-access-key "${MINIO_ACCESS_KEY}" \
    --minio-secret-key "${MINIO_SECRET_KEY}" \
    --bucket "${BUCKET}" \
    --mongodb-uri "${MONGODB_URI}" \
    --mongodb-database "${MONGODB_DATABASE}" \
    --mongodb-collection "${MONGODB_COLLECTION}" \
    --postgres-uri "${POSTGRES_URI}" \
    --elasticsearch-url "${ELASTICSEARCH_URL}" \
    --elasticsearch-index "${ELASTICSEARCH_INDEX}" \
    --output-dir "${OUTPUT_DIR}"
