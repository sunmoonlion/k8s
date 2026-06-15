# AIStor Console 访问说明

## 1. 访问方式

AIStor Console 默认使用 `ClusterIP` Service，只能在 Kubernetes 集群内部
访问。平台不通过公共 Ingress 或 NodePort 长期暴露对象存储管理界面。

需要管理对象存储时，在 WSL 终端运行：

```bash
cd ~/k8s

./sunmoonai/data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND console
```

终端出现以下信息后：

```text
AIStor Console: http://127.0.0.1:19090
Forwarding from 127.0.0.1:19090 -> 9090
```

使用 Windows 或 WSL 中的浏览器访问：

```text
http://127.0.0.1:19090
```

运行该命令的终端必须保持打开。按 `Ctrl+C` 会关闭访问通道，但不会停止
AIStor、删除对象或影响应用通过集群内部 S3 API 访问对象存储。

## 2. 端口说明

| 地址或端口 | 作用 |
|---|---|
| `127.0.0.1:19090` | WSL 本机临时访问地址，浏览器使用此地址 |
| `9090` | Kubernetes Console Service 的集群内部端口 |
| `minio:80` | Kubernetes 集群内部 S3 API 地址 |

不能直接在 Windows 浏览器中访问 `127.0.0.1:9090`。部署脚本将本机
`19090` 临时转发到集群内的 `9090`。

本机监听地址固定为 `127.0.0.1`，不会向局域网或公网开放。默认端口定义在：

```text
deploy-object-storage/deploy-object-storage.conf
```

## 3. 登录凭据

开发环境的 Console 管理账号由以下配置创建：

```text
deploy-object-storage/deploy-object-storage.conf
```

对应配置项：

```text
OBJECT_STORAGE_ROOT_USER
OBJECT_STORAGE_ROOT_PASSWORD
```

部署脚本将其写入 Kubernetes Secret：

```text
Namespace: data-platform-dev
Secret:    object-storage-root-credentials
```

业务 Backend 不得使用该管理账号。后续由平台 provisioner 为每个 App 和
Backend 创建最小权限的独立 S3 凭据。

## 4. 集群重建后的访问

Kind 集群重建后，先重新部署对象存储：

```bash
cd ~/k8s

./sunmoonai/data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND deploy
```

部署脚本会自动读取：

```text
~/.config/sunmoonai/licenses/minio.license
```

并重新创建 License Secret。ObjectStore 健康后，再执行 `console` 命令开启
本地访问通道。

## 5. 常见问题

### 浏览器显示连接被拒绝

确认运行 `console` 命令的终端仍然打开，并访问的是：

```text
http://127.0.0.1:19090
```

不是 `127.0.0.1:9090`。

### 本机端口被占用

临时指定其他端口：

```bash
export OBJECT_STORAGE_CONSOLE_LOCAL_PORT=19091

./sunmoonai/data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND console
```

然后访问 `http://127.0.0.1:19091`。

### 检查对象存储状态

```bash
./sunmoonai/data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND status
```

正常状态应包含：

```text
STATE:  Initialized
HEALTH: green
```

