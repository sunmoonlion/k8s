#!/usr/bin/env python3
"""
文档转换并存储脚本

功能：
1. 处理文件系统中的各种格式文件（PDF、Word等），支持单个文件或批量文件
2. 根据格式映射配置转换为多种格式
3. 根据存储配置保存到不同的存储系统（MongoDB、ES、对象存储、文件系统等）

使用方法：
    python batch_convert_and_store.py \
        --input-dir /path/to/documents \
        --format-mapping '{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}' \
        --storage-config '{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"]}' \
        --service-url https://www.sunmoonai.com/document-converter \
        --mongodb-uri mongodb://localhost:27017 \
        --mongodb-database mydb \
        --mongodb-collection documents

注意：--input-dir 可以指向单个文件所在的目录，处理单个文件时只需确保目录中只有一个匹配的文件
"""

import argparse
import sys
import json
from pathlib import Path
from typing import List, Dict, Optional, Set
from datetime import datetime
import logging
import hashlib
from io import BytesIO

import requests
from psycopg2 import connect, sql
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool
from elasticsearch import Elasticsearch
from minio import Minio
from minio.error import S3Error
import boto3
from botocore.exceptions import ClientError
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DocumentConverterClient:
    """文档转换服务客户端"""
    
    def __init__(self, service_url: str):
        self.service_url = service_url.rstrip('/')
        self.session = requests.Session()
        self.session.timeout = 300
    
    def health_check(self) -> bool:
        """检查服务健康状态"""
        try:
            response = self.session.get(f"{self.service_url}/health")
            response.raise_for_status()
            return True
        except Exception as e:
            logger.error(f"❌ 服务健康检查失败: {e}")
            return False
    
    def convert_file(self, file_path: Path, output_format: str) -> bytes:
        """
        转换文件为指定格式
        
        Returns:
            转换后的文件内容（字节）
        """
        logger.info(f"📄 转换文件: {file_path.name} -> {output_format}")
        
        with open(file_path, 'rb') as f:
            files = {'file': (file_path.name, f, 'application/octet-stream')}
            data = {'format': output_format}
            
            response = self.session.post(
                f"{self.service_url}/api/v1/convert",
                files=files,
                data=data
            )
            response.raise_for_status()
            result = response.json()
            
            if not result.get('success'):
                raise Exception(f"转换失败: {result.get('message', '未知错误')}")
            
            # 下载转换后的文件
            download_url = result['download_url']
            if download_url.startswith('/'):
                download_url = f"{self.service_url}{download_url}"
            
            download_response = self.session.get(download_url)
            download_response.raise_for_status()
            
            logger.info(f"✅ 转换成功: {result.get('converted_filename')}")
            return download_response.content
    


class ObjectStorage:
    """对象存储抽象类"""
    
    def upload_file(self, bucket: str, object_name: str, file_content: bytes, content_type: str) -> str:
        """上传文件到对象存储，返回存储路径"""
        raise NotImplementedError
    
    def get_file_url(self, bucket: str, object_name: str) -> str:
        """获取文件的访问URL"""
        raise NotImplementedError


class MinIOStorage(ObjectStorage):
    """MinIO 对象存储"""
    
    def __init__(self, endpoint: str, access_key: str, secret_key: str, secure: bool = False):
        self.client = Minio(
            endpoint.replace('http://', '').replace('https://', ''),
            access_key=access_key,
            secret_key=secret_key,
            secure=secure
        )
        self.endpoint = endpoint
    
    def upload_file(self, bucket: str, object_name: str, file_content: bytes, content_type: str) -> str:
        """上传文件到MinIO"""
        try:
            if not self.client.bucket_exists(bucket):
                self.client.make_bucket(bucket)
                logger.info(f"✅ 创建bucket: {bucket}")
            
            self.client.put_object(
                bucket,
                object_name,
                BytesIO(file_content),
                length=len(file_content),
                content_type=content_type
            )
            
            logger.info(f"✅ 文件已上传到MinIO: {bucket}/{object_name}")
            return f"{bucket}/{object_name}"
        
        except S3Error as e:
            raise Exception(f"MinIO上传失败: {e}")
    
    def get_file_url(self, bucket: str, object_name: str) -> str:
        """获取MinIO文件URL"""
        return f"{self.endpoint}/{bucket}/{object_name}"


class S3Storage(ObjectStorage):
    """AWS S3 对象存储"""
    
    def __init__(self, endpoint_url: Optional[str], access_key: str, secret_key: str, region: str = 'us-east-1'):
        self.s3_client = boto3.client(
            's3',
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region
        )
        self.endpoint_url = endpoint_url
    
    def upload_file(self, bucket: str, object_name: str, file_content: bytes, content_type: str) -> str:
        """上传文件到S3"""
        try:
            try:
                self.s3_client.head_bucket(Bucket=bucket)
            except ClientError:
                self.s3_client.create_bucket(Bucket=bucket)
                logger.info(f"✅ 创建bucket: {bucket}")
            
            self.s3_client.put_object(
                Bucket=bucket,
                Key=object_name,
                Body=file_content,
                ContentType=content_type
            )
            
            logger.info(f"✅ 文件已上传到S3: {bucket}/{object_name}")
            return f"{bucket}/{object_name}"
        
        except ClientError as e:
            raise Exception(f"S3上传失败: {e}")
    
    def get_file_url(self, bucket: str, object_name: str) -> str:
        """获取S3文件URL"""
        if self.endpoint_url:
            return f"{self.endpoint_url}/{bucket}/{object_name}"
        else:
            return f"https://{bucket}.s3.amazonaws.com/{object_name}"


class MongoDBStorage:
    """MongoDB 存储"""
    
    def __init__(self, uri: str, database: str, collection: str):
        self.uri = uri
        self.database_name = database
        self.collection_name = collection
        self.client = None
        self.collection = None
    
    def connect(self):
        """连接MongoDB"""
        try:
            logger.info(f"🔌 连接 MongoDB: {self.uri}")
            self.client = MongoClient(self.uri, serverSelectionTimeoutMS=5000)
            self.client.admin.command('ping')
            self.collection = self.client[self.database_name][self.collection_name]
            logger.info(f"✅ MongoDB 连接成功")
            logger.info(f"📚 数据库: {self.database_name}, 集合: {self.collection_name}")
        except (ConnectionFailure, ServerSelectionTimeoutError) as e:
            raise Exception(f"MongoDB 连接失败: {e}")
    
    def save_file(self, file_name: str, file_content: bytes, format: str, metadata: Optional[Dict] = None):
        """保存文件到MongoDB（二进制内容）"""
        try:
            doc = {
                'file_name': file_name,
                'format': format,
                'content': file_content,
                'content_length': len(file_content),
                'created_at': datetime.utcnow(),
                **(metadata or {})
            }
            result = self.collection.insert_one(doc)
            logger.info(f"✅ 文件已保存到MongoDB, ID: {result.inserted_id}")
            return result.inserted_id
        except Exception as e:
            raise Exception(f"保存到MongoDB失败: {e}")
    
    def save_document(self, original_filename: str, txt_content: str, metadata: Optional[Dict] = None):
        """
        保存文档到MongoDB（文本内容，兼容单文件脚本的接口）
        
        Args:
            original_filename: 原始文件名
            txt_content: TXT 内容（字符串）
            metadata: 额外的元数据（可选）
        """
        document = {
            'original_filename': original_filename,
            'txt_content': txt_content,
            'content_length': len(txt_content),
            'created_at': datetime.utcnow(),
            **(metadata or {})
        }
        
        try:
            result = self.collection.insert_one(document)
            logger.info(f"✅ 文档已保存到 MongoDB, ID: {result.inserted_id}")
            return result.inserted_id
        except Exception as e:
            raise Exception(f"保存到 MongoDB 失败: {e}")
    
    def close(self):
        """关闭连接"""
        if self.client:
            self.client.close()
            logger.info("🔌 MongoDB 连接已关闭")


class ElasticsearchStorage:
    """Elasticsearch 存储"""
    
    def __init__(self, url: str, index_name: str = "documents"):
        self.es = Elasticsearch([url])
        self.index_name = index_name
    
    def create_index_if_not_exists(self, format: str = "txt"):
        """创建索引（如果不存在）"""
        if not self.es.indices.exists(index=self.index_name):
            mapping = {
                "mappings": {
                    "properties": {
                        "original_path": {"type": "keyword"},
                        "file_name": {"type": "keyword"},
                        "file_hash": {"type": "keyword"},
                        "format": {"type": "keyword"},
                        "content_length": {"type": "integer"},
                        "created_at": {"type": "date"},
                        "metadata": {"type": "object"}
                    }
                }
            }
            
            # 如果是文本格式，添加文本字段
            if format in ['txt', 'html']:
                mapping["mappings"]["properties"]["content"] = {
                    "type": "text",
                    "analyzer": "ik_max_word",
                    "search_analyzer": "ik_smart"
                }
            else:
                mapping["mappings"]["properties"]["content"] = {"type": "keyword"}
            
            self.es.indices.create(index=self.index_name, body=mapping)
            logger.info(f"✅ 创建Elasticsearch索引: {self.index_name}")
    
    def save_file(self, file_path: str, file_hash: str, file_content: bytes, format: str, metadata: Optional[Dict] = None):
        """保存文件到Elasticsearch"""
        try:
            # 尝试解码文本内容
            if format in ['txt', 'html']:
                try:
                    content_text = file_content.decode('utf-8', errors='ignore')
                except:
                    content_text = file_content.decode('gbk', errors='ignore')
            else:
                content_text = None
            
            doc = {
                "original_path": file_path,
                "file_name": Path(file_path).name,
                "file_hash": file_hash,
                "format": format,
                "content_length": len(file_content),
                "created_at": datetime.utcnow().isoformat(),
                "metadata": metadata or {}
            }
            
            if content_text:
                doc["content"] = content_text
            
            # 使用文件哈希+格式作为文档ID
            doc_id = f"{file_hash}_{format}"
            self.es.index(index=self.index_name, id=doc_id, body=doc)
            logger.info(f"✅ 文件已保存到Elasticsearch, ID: {doc_id[:32]}...")
        
        except Exception as e:
            raise Exception(f"保存到Elasticsearch失败: {e}")


class FileSystemStorage:
    """文件系统存储"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def save_file(self, file_name: str, file_content: bytes, format: str, metadata: Optional[Dict] = None):
        """保存文件到文件系统"""
        try:
            # 按格式创建子目录
            format_dir = self.output_dir / format
            format_dir.mkdir(parents=True, exist_ok=True)
            
            file_path = format_dir / file_name
            file_path.write_bytes(file_content)
            
            logger.info(f"✅ 文件已保存到文件系统: {file_path}")
            return str(file_path)
        except Exception as e:
            raise Exception(f"保存到文件系统失败: {e}")


class PostgreSQLStorage:
    """PostgreSQL 存储（用于元数据）"""
    
    def __init__(self, connection_uri: str):
        self.connection_uri = connection_uri
        self.pool = None
    
    def connect(self):
        """创建连接池"""
        try:
            self.pool = SimpleConnectionPool(1, 10, self.connection_uri)
            logger.info("✅ PostgreSQL 连接池创建成功")
        except Exception as e:
            raise Exception(f"PostgreSQL 连接失败: {e}")
    
    def save_metadata(self, file_path: str, file_hash: str, format_mapping: Dict, storage_info: Dict, metadata: Optional[Dict] = None):
        """保存文档元数据到PostgreSQL"""
        conn = self.pool.getconn()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS document_metadata (
                        id SERIAL PRIMARY KEY,
                        original_path VARCHAR(500) NOT NULL,
                        file_name VARCHAR(255) NOT NULL,
                        file_hash VARCHAR(64),
                        format_mapping JSONB NOT NULL,
                        storage_info JSONB NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        metadata JSONB,
                        UNIQUE(file_hash)
                    )
                """)
                
                cur.execute("""
                    INSERT INTO document_metadata 
                    (original_path, file_name, file_hash, format_mapping, storage_info, metadata)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (file_hash) 
                    DO UPDATE SET 
                        format_mapping = EXCLUDED.format_mapping,
                        storage_info = EXCLUDED.storage_info,
                        updated_at = CURRENT_TIMESTAMP,
                        metadata = EXCLUDED.metadata
                    RETURNING id
                """, (
                    file_path,
                    Path(file_path).name,
                    file_hash,
                    json.dumps(format_mapping),
                    json.dumps(storage_info),
                    json.dumps(metadata or {})
                ))
                
                result = cur.fetchone()
                conn.commit()
                doc_id = result['id']
                logger.info(f"✅ 文档元数据已保存到PostgreSQL, ID: {doc_id}")
                return doc_id
        
        except Exception as e:
            conn.rollback()
            raise Exception(f"保存到PostgreSQL失败: {e}")
        finally:
            self.pool.putconn(conn)
    
    def close(self):
        """关闭连接池"""
        if self.pool:
            self.pool.closeall()
            logger.info("🔌 PostgreSQL 连接池已关闭")


def get_content_type(format: str) -> str:
    """根据格式获取Content-Type"""
    content_types = {
        'pdf': 'application/pdf',
        'txt': 'text/plain',
        'html': 'text/html',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'doc': 'application/msword',
        'odt': 'application/vnd.oasis.opendocument.text',
        'rtf': 'application/rtf'
    }
    return content_types.get(format.lower(), 'application/octet-stream')


def calculate_file_hash(file_path: Path) -> str:
    """计算文件SHA256哈希"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def process_file(
    file_path: Path,
    converter: DocumentConverterClient,
    format_mapping: Dict[str, List[str]],
    storage_config: Dict[str, List[str]],
    storages: Dict[str, any],
    bucket: Optional[str] = None
):
    """处理单个文件"""
    logger.info("=" * 80)
    logger.info(f"📄 处理文件: {file_path}")
    
    try:
        # 获取文件扩展名（不含点）
        file_ext = file_path.suffix.lower().lstrip('.')
        
        # 查找该格式需要转换的目标格式
        target_formats = format_mapping.get(file_ext, [])
        if not target_formats:
            logger.warning(f"⚠️  文件格式 {file_ext} 未在格式映射中，跳过")
            return False
        
        logger.info(f"📋 目标格式: {', '.join(target_formats)}")
        
        # 转换文件为各种格式
        converted_files = {}
        storage_info = {}
        
        for target_format in target_formats:
            try:
                # 转换文件
                file_content = converter.convert_file(file_path, target_format)
                file_name = f"{file_path.stem}.{target_format}"
                
                # 获取该格式的存储配置
                storage_types = storage_config.get(target_format, [])
                if not storage_types:
                    logger.warning(f"⚠️  格式 {target_format} 未配置存储方式，跳过")
                    continue
                
                logger.info(f"💾 格式 {target_format} 存储到: {', '.join(storage_types)}")
                
                # 根据存储配置保存文件
                format_storage_info = {}
                
                for storage_type in storage_types:
                    try:
                        if storage_type == 'object_storage' and 'object_storage' in storages:
                            if not bucket:
                                logger.warning("⚠️  未配置bucket，跳过对象存储")
                                continue
                            content_type = get_content_type(target_format)
                            storage_path = storages['object_storage'].upload_file(
                                bucket=bucket,
                                object_name=file_name,
                                file_content=file_content,
                                content_type=content_type
                            )
                            format_storage_info['object_storage'] = storage_path
                        
                        elif storage_type == 'mongodb' and 'mongodb' in storages:
                            # 对于TXT格式，使用save_document保存文本内容（兼容原脚本）
                            if target_format == 'txt':
                                try:
                                    txt_content = file_content.decode('utf-8', errors='ignore')
                                    doc_id = storages['mongodb'].save_document(
                                        original_filename=file_path.name,
                                        txt_content=txt_content,
                                        metadata={
                                            'original_path': str(file_path),
                                            'format': target_format
                                        }
                                    )
                                    format_storage_info['mongodb'] = f'saved (ID: {doc_id})'
                                except Exception as e:
                                    logger.warning(f"⚠️  使用save_document失败，尝试save_file: {e}")
                                    # 回退到save_file
                                    storages['mongodb'].save_file(
                                        file_name=file_name,
                                        file_content=file_content,
                                        format=target_format,
                                        metadata={'original_path': str(file_path)}
                                    )
                                    format_storage_info['mongodb'] = 'saved'
                            else:
                                # 非TXT格式使用save_file保存二进制内容
                                storages['mongodb'].save_file(
                                    file_name=file_name,
                                    file_content=file_content,
                                    format=target_format,
                                    metadata={'original_path': str(file_path)}
                                )
                                format_storage_info['mongodb'] = 'saved'
                        
                        elif storage_type == 'elasticsearch' and 'elasticsearch' in storages:
                            file_hash = calculate_file_hash(file_path)
                            storages['elasticsearch'].save_file(
                                file_path=str(file_path),
                                file_hash=file_hash,
                                file_content=file_content,
                                format=target_format,
                                metadata={'original_path': str(file_path)}
                            )
                            format_storage_info['elasticsearch'] = 'saved'
                        
                        elif storage_type == 'filesystem' and 'filesystem' in storages:
                            file_path_saved = storages['filesystem'].save_file(
                                file_name=file_name,
                                file_content=file_content,
                                format=target_format,
                                metadata={'original_path': str(file_path)}
                            )
                            format_storage_info['filesystem'] = file_path_saved
                        
                        elif storage_type == 'postgres' and 'postgres' in storages:
                            # PostgreSQL只存储元数据，不存储文件内容
                            format_storage_info['postgres'] = 'metadata_only'
                        
                        else:
                            logger.warning(f"⚠️  存储类型 {storage_type} 未配置或不可用")
                    
                    except Exception as e:
                        logger.error(f"❌ 保存到 {storage_type} 失败: {e}")
                        continue
                
                converted_files[target_format] = format_storage_info
                storage_info[target_format] = format_storage_info
            
            except Exception as e:
                logger.error(f"❌ 转换格式 {target_format} 失败: {e}")
                continue
        
        if not converted_files:
            raise Exception("所有格式转换都失败了")
        
        # 计算文件哈希
        file_hash = calculate_file_hash(file_path)
        
        # 保存元数据到PostgreSQL（如果配置了）
        postgres_id = None
        if 'postgres' in storages:
            postgres_id = storages['postgres'].save_metadata(
                file_path=str(file_path),
                file_hash=file_hash,
                format_mapping={file_ext: target_formats},
                storage_info=storage_info,
                metadata={
                    'file_size': file_path.stat().st_size,
                    'processed_at': datetime.utcnow().isoformat()
                }
            )
        
        logger.info(f"✅ 文件处理完成: {file_path.name}")
        logger.info(f"   - 转换格式: {', '.join(converted_files.keys())}")
        if postgres_id:
            logger.info(f"   - PostgreSQL ID: {postgres_id}")
        logger.info("=" * 80)
        
        return True
    
    except Exception as e:
        logger.error(f"❌ 处理文件失败 {file_path}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='转换文档并根据配置存储到不同存储系统',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
格式映射示例:
  --format-mapping '{"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}'
  表示：PDF文件转换为txt和html，Word文件转换为pdf和txt

存储配置示例:
  --storage-config '{"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"]}'
  表示：PDF格式存储到对象存储，TXT格式存储到Elasticsearch和MongoDB

支持的存储类型:
  - object_storage: 对象存储（MinIO/S3）
  - mongodb: MongoDB
  - elasticsearch: Elasticsearch
  - filesystem: 文件系统
  - postgres: PostgreSQL（仅存储元数据）

注意：--input-dir 可以指向包含单个文件的目录，处理单个文件时只需确保目录中只有一个匹配的文件
        """
    )
    
    # 输入参数
    parser.add_argument('--input-dir', type=str, required=True,
                       help='输入目录路径（可以包含单个或多个文件）')
    
    parser.add_argument('--format-mapping', type=str, required=True, 
                       help='格式映射JSON，例如: {"pdf": ["txt", "html"], "docx": ["pdf", "txt"]}')
    parser.add_argument('--storage-config', type=str, required=True,
                       help='存储配置JSON，例如: {"pdf": ["object_storage"], "txt": ["elasticsearch", "mongodb"]}')
    parser.add_argument('--extensions', type=str, default='.pdf,.doc,.docx', 
                       help='要处理的文件扩展名，逗号分隔（仅批量模式有效）')
    
    # 转换服务
    parser.add_argument('--service-url', type=str, required=True, help='文档转换服务地址')
    
    # 对象存储（可选）
    parser.add_argument('--object-storage', type=str, choices=['minio', 's3'], help='对象存储类型')
    parser.add_argument('--bucket', type=str, help='对象存储bucket名称')
    parser.add_argument('--minio-endpoint', type=str, help='MinIO端点地址')
    parser.add_argument('--minio-access-key', type=str, help='MinIO访问密钥')
    parser.add_argument('--minio-secret-key', type=str, help='MinIO秘密密钥')
    parser.add_argument('--minio-secure', action='store_true', help='MinIO使用HTTPS')
    parser.add_argument('--s3-endpoint-url', type=str, help='S3端点URL')
    parser.add_argument('--s3-access-key', type=str, help='S3访问密钥')
    parser.add_argument('--s3-secret-key', type=str, help='S3秘密密钥')
    parser.add_argument('--s3-region', type=str, default='us-east-1', help='S3区域')
    
    # MongoDB（可选）
    parser.add_argument('--mongodb-uri', type=str, help='MongoDB连接URI')
    parser.add_argument('--mongodb-database', type=str, help='MongoDB数据库名称')
    parser.add_argument('--mongodb-collection', type=str, help='MongoDB集合名称')
    
    # PostgreSQL（可选）
    parser.add_argument('--postgres-uri', type=str, help='PostgreSQL连接URI')
    
    # Elasticsearch（可选）
    parser.add_argument('--elasticsearch-url', type=str, help='Elasticsearch URL')
    parser.add_argument('--elasticsearch-index', type=str, default='documents', help='Elasticsearch索引名称')
    
    # 文件系统（可选）
    parser.add_argument('--output-dir', type=str, help='文件系统输出目录')
    
    # 其他参数
    parser.add_argument('--recursive', action='store_true', help='递归处理子目录')
    parser.add_argument('--skip-health-check', action='store_true', help='跳过服务健康检查')
    
    args = parser.parse_args()
    
    # 解析格式映射
    try:
        format_mapping = json.loads(args.format_mapping)
        if not isinstance(format_mapping, dict):
            raise ValueError("格式映射必须是JSON对象")
    except json.JSONDecodeError as e:
        logger.error(f"❌ 格式映射JSON解析失败: {e}")
        sys.exit(1)
    except ValueError as e:
        logger.error(f"❌ 格式映射格式错误: {e}")
        sys.exit(1)
    
    # 解析存储配置
    try:
        storage_config = json.loads(args.storage_config)
        if not isinstance(storage_config, dict):
            raise ValueError("存储配置必须是JSON对象")
    except json.JSONDecodeError as e:
        logger.error(f"❌ 存储配置JSON解析失败: {e}")
        sys.exit(1)
    except ValueError as e:
        logger.error(f"❌ 存储配置格式错误: {e}")
        sys.exit(1)
    
    # 解析文件扩展名
    extensions = set(ext.strip().lower() for ext in args.extensions.split(','))
    
    try:
        # 初始化转换服务客户端
        converter = DocumentConverterClient(args.service_url)
        if not args.skip_health_check:
            if not converter.health_check():
                logger.error("❌ 转换服务不可用")
                sys.exit(1)
        
        # 初始化存储系统
        storages = {}
        
        # 对象存储
        if args.object_storage:
            if args.object_storage == 'minio':
                if not all([args.minio_endpoint, args.minio_access_key, args.minio_secret_key]):
                    logger.error("❌ MinIO需要提供endpoint、access-key和secret-key")
                    sys.exit(1)
                storages['object_storage'] = MinIOStorage(
                    args.minio_endpoint,
                    args.minio_access_key,
                    args.minio_secret_key,
                    secure=args.minio_secure
                )
            elif args.object_storage == 's3':
                if not all([args.s3_access_key, args.s3_secret_key]):
                    logger.error("❌ S3需要提供access-key和secret-key")
                    sys.exit(1)
                storages['object_storage'] = S3Storage(
                    args.s3_endpoint_url,
                    args.s3_access_key,
                    args.s3_secret_key,
                    region=args.s3_region
                )
        
        # MongoDB
        if args.mongodb_uri:
            if not all([args.mongodb_database, args.mongodb_collection]):
                logger.error("❌ MongoDB需要提供database和collection")
                sys.exit(1)
            mongodb = MongoDBStorage(args.mongodb_uri, args.mongodb_database, args.mongodb_collection)
            mongodb.connect()
            storages['mongodb'] = mongodb
        
        # PostgreSQL
        if args.postgres_uri:
            postgres = PostgreSQLStorage(args.postgres_uri)
            postgres.connect()
            storages['postgres'] = postgres
        
        # Elasticsearch
        if args.elasticsearch_url:
            elasticsearch = ElasticsearchStorage(args.elasticsearch_url, args.elasticsearch_index)
            elasticsearch.create_index_if_not_exists()
            storages['elasticsearch'] = elasticsearch
        
        # 文件系统
        if args.output_dir:
            storages['filesystem'] = FileSystemStorage(args.output_dir)
        
        # 验证存储配置
        all_storage_types = set()
        for formats in storage_config.values():
            all_storage_types.update(formats)
        
        available_storage_types = set(storages.keys())
        missing_storage_types = all_storage_types - available_storage_types - {'postgres'}
        if missing_storage_types:
            logger.warning(f"⚠️  存储配置中指定的存储类型未配置: {missing_storage_types}")
        
        # 查找并处理文件
        input_dir = Path(args.input_dir).expanduser().resolve()
        if not input_dir.exists():
            logger.error(f"❌ 输入目录不存在: {input_dir}")
            sys.exit(1)
        
        # 检查是目录还是文件
        if input_dir.is_file():
            # 如果是文件，直接处理
            files = [input_dir]
        elif args.recursive:
            # 递归查找文件
            files = [f for f in input_dir.rglob('*') if f.is_file() and f.suffix.lower() in extensions]
        else:
            # 只查找当前目录的文件
            files = [f for f in input_dir.iterdir() if f.is_file() and f.suffix.lower() in extensions]
        
        if not files:
            logger.warning(f"⚠️  在 {input_dir} 中未找到匹配的文件")
            sys.exit(0)
        
        logger.info(f"📁 找到 {len(files)} 个文件需要处理")
        
        # 处理文件
        success_count = 0
        fail_count = 0
        
        for file_path in files:
            if process_file(
                file_path,
                converter,
                format_mapping,
                storage_config,
                storages,
                bucket=args.bucket
            ):
                success_count += 1
            else:
                fail_count += 1
        
        logger.info("=" * 80)
        logger.info(f"✅ 处理完成!")
        logger.info(f"   - 成功: {success_count}")
        logger.info(f"   - 失败: {fail_count}")
        logger.info("=" * 80)
        
        # 关闭连接
        if 'mongodb' in storages:
            storages['mongodb'].close()
        if 'postgres' in storages:
            storages['postgres'].close()
    
    except Exception as e:
        logger.error(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
