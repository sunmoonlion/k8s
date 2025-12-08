# SunMoonAI 数据平台访问说明

## 🌐 公网访问信息

- **服务器IP**: `101.126.151.0`
- **Traefik端口**: `30090` (HTTP)
- **数据库端口**: `30432` (PostgreSQL), `30433` (MongoDB), `30434` (Redis)

## 📋 服务访问总览

| 服务 | 访问方式 | 端口 | 协议 | 说明 |
|------|----------|------|------|------|
| **Traefik Dashboard** | HTTP | 30090 | HTTP | 统一管理界面 |
| **PostgreSQL** | TCP | 30432 | TCP | 数据库连接 |
| **MongoDB** | TCP | 30433 | TCP | 数据库连接 |
| **Redis** | TCP | 30434 | TCP | 数据库连接 |
| **Elasticsearch** | HTTP | 30090 | HTTP | 搜索引擎API |
| **Kibana** | HTTP | 30090 | HTTP | 日志分析界面 |
| **Logstash** | HTTP | 30090 | HTTP | 日志收集 |

---

## 🔧 Traefik Dashboard

### 访问地址
```
http://101.126.151.0:30090/dashboard/
```

### 功能说明
- 查看所有路由配置
- 监控服务状态
- 管理中间件
- 查看实时统计

---

## 🗄️ 数据库服务

### PostgreSQL 连接

#### 连接信息
- **主机**: `101.126.151.0`
- **端口**: `30432`
- **数据库**: `sunmoonai_dev`
- **用户名**: `sunmoonai_dev`
- **密码**: `sunmoonai_dev_2024!`

#### 连接命令
```bash
# 命令行连接
psql -h 101.126.151.0 -p 30432 -U sunmoonai_dev -d sunmoonai_dev

# 连接字符串
postgresql://sunmoonai_dev:sunmoonai_dev_2024!@101.126.151.0:30432/sunmoonai_dev
```

#### 客户端工具配置
- **DBeaver**: 主机 `101.126.151.0`，端口 `30432`
- **pgAdmin**: 主机 `101.126.151.0`，端口 `30432`
- **DataGrip**: 主机 `101.126.151.0`，端口 `30432`

### MongoDB 连接

#### 连接信息
- **主机**: `101.126.151.0`
- **端口**: `30433`

#### 连接命令
```bash
# 命令行连接
mongosh mongodb://101.126.151.0:30433/

# 连接字符串
mongodb://101.126.151.0:30433/
```

### Redis 连接

#### 连接信息
- **主机**: `101.126.151.0`
- **端口**: `30434`

#### 连接命令
```bash
# 命令行连接
redis-cli -h 101.126.151.0 -p 30434

# 连接字符串
redis://101.126.151.0:30434
```

---

## 📊 ELK 日志分析栈

### Elasticsearch API

#### 访问地址
```
http://101.126.151.0:30090/elasticsearch/
```

#### 常用操作
```bash
# 检查集群状态
curl http://101.126.151.0:30090/elasticsearch/_cluster/health

# 查看索引
curl http://101.126.151.0:30090/elasticsearch/_cat/indices

# 搜索数据
curl http://101.126.151.0:30090/elasticsearch/_search
```

### Kibana Web 界面

#### 访问地址
```
http://101.126.151.0:30090/kibana/
```

#### 功能说明
- 日志分析和可视化
- 仪表板创建
- 索引模式管理
- 查询和过滤

### Logstash HTTP 输入

#### 访问地址
```
http://101.126.151.0:30090/logstash/
```

#### 发送日志示例
```bash
# 发送日志到 Logstash
curl -X POST http://101.126.151.0:30090/logstash/ \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello Logstash", "level": "info"}'
```

---

## 🔐 安全架构说明

### 服务隔离
```
外部客户端 → Traefik (NodePort) → 内部服务 (ClusterIP)
     ↓              ↓                    ↓
  公网访问      流量转发              集群内部
```

### 访问控制
- 所有服务通过 Traefik 统一入口访问
- 数据库服务不直接暴露到公网
- 支持域名和路径路由
- 可配置认证和访问控制

---

## 🛠️ 管理命令

### 检查服务状态
```bash
# 检查 Traefik 状态
KUBECONFIG=~/.kube/cluster-admin.conf kubectl get pods -n ingress-platform -l app.kubernetes.io/name=traefik

# 检查数据库服务
KUBECONFIG=~/.kube/cluster-admin.conf kubectl get services -n data-platform

# 检查路由配置
KUBECONFIG=~/.kube/cluster-admin.conf kubectl get ingressroute,ingressroutetcp -n data-platform
```

### 部署和更新
```bash
# 部署数据库路由
cd ~/k8s/sunmoonai/ingress-platform/ingress/data-platform
KUBECONFIG=~/.kube/cluster-admin.conf ./deploy.sh apply

# 部署 ELK 路由
cd ~/k8s/sunmoonai/ingress-platform/ingress/data-platform/elk
KUBECONFIG=~/.kube/cluster-admin.conf ./deploy-ingress.sh apply
```

---

## 📝 注意事项

### 防火墙配置
确保云服务器防火墙开放以下端口：
- `30090` - HTTP 访问
- `30432` - PostgreSQL
- `30433` - MongoDB
- `30434` - Redis

### 网络要求
- 客户端需要能够访问服务器公网IP
- 建议使用稳定的网络连接
- 生产环境建议配置VPN或专线

### 安全建议
- 定期更新密码
- 监控访问日志
- 配置访问控制
- 备份重要数据

---

## 🆘 故障排除

### 连接问题
```bash
# 测试端口连通性
telnet 101.126.151.0 30090
telnet 101.126.151.0 30432
telnet 101.126.151.0 30433
telnet 101.126.151.0 30434

# 检查服务状态
curl http://101.126.151.0:30090/dashboard/
```

### 日志查看
```bash
# 查看 Traefik 日志
KUBECONFIG=~/.kube/cluster-admin.conf kubectl logs -n ingress-platform -l app.kubernetes.io/name=traefik

# 查看数据库日志
KUBECONFIG=~/.kube/cluster-admin.conf kubectl logs -n data-platform -l app.kubernetes.io/name=postgresql
```

---

## 📞 技术支持

如有问题，请检查：
1. 服务是否正常运行
2. 网络连接是否正常
3. 防火墙配置是否正确
4. 服务日志是否有错误

**最后更新**: 2025-09-16
**版本**: v1.0
