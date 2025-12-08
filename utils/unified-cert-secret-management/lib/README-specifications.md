# Harbor证书生成规格文件使用说明

## 📋 规格文件说明

- `ca-specifications` - CA证书生成规格文件
- `server-specifications` - 服务器证书生成规格文件  
- `client-specifications` - 客户端证书生成规格文件

## 🚀 使用方法

### 1. 复制规格文件
```bash
cp ca-specifications ca.conf
cp server-specifications server.conf
cp client-specifications client.conf
```

### 2. 修改个性化配置

#### CA证书 (`ca.conf`)
```ini
# 修改CN字段
CN = YourOrg Root CA

# 修改个性化配置项
DAYS = 3650        # CA证书有效期（10年）
KEY_SIZE = 4096     # CA证书密钥长度（4096位）
```

#### 服务器证书 (`server.conf`)
```ini
# 修改CN字段
CN = your-server.domain.com

# 修改个性化配置项
DAYS = 365         # 服务器证书有效期（1年）
KEY_SIZE = 2048    # 服务器证书密钥长度（2048位）

# 修改域名和IP
DNS.1 = your-server.domain.com
DNS.2 = your-alias.domain.com
IP.2 = your-server-ip
```

#### 客户端证书 (`client.conf`)
```ini
# 修改CN字段
CN = username

# 修改个性化配置项
DAYS = 365         # 客户端证书有效期（1年）
KEY_SIZE = 2048    # 客户端证书密钥长度（2048位）

# 修改客户端标识
email.1 = user@yourdomain.com
DNS.2 = client.yourdomain.com
```

### 3. 生成证书
```bash
# 生成CA证书
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -config ca.conf

# 生成服务器证书
openssl req -new -key server.key -out server.csr -config server.conf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt -days 365 -extensions v3_req -extfile server.conf

# 生成客户端证书
openssl req -new -key client.key -out client.csr -config client.conf
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -out client.crt -days 365 -extensions v3_req -extfile client.conf
```

## 📝 说明

- **规格文件**: 包含完整的证书配置和详细说明
- **个性化配置**: 只需要修改CN字段和个性化配置项
- **天数配置**: CA证书10年，服务器和客户端证书1年
- **密钥长度**: CA证书4096位，其他证书2048位
- **避免重复**: 不需要重复写相同的配置
