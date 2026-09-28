harbor-image-management 使用说明

本目录提供 Harbor 安装后的镜像按需推送与全局清理能力，配合集中镜像清单使用。

核心脚本/配置
- 脚本：`harbor-image.sh`
- 配置：`harbor-image.conf`
- 清单：`k8s/utils/components-images/<component>-images.txt`

工作原理
1) 读取组件镜像清单 `components-images/<component>-images.txt`
2) 在本地 `~/packages-to-be-installed/images/` 匹配对应 tar
3) 将 tar 上传至控制平面，执行：load → tag（Harbor）→ push
4) 可选：推送成功后在控制平面删除临时镜像与 tar

就绪检测（内置）
- 推送前会自动等待 Harbor 就绪：
  - 成功响应 `API /api/v2.0/ping`
  - `Registry /v2/` 返回码为 200/401
- 可调参数（`harbor-image.conf`）：
  - `HARBOR_WAIT_TIMEOUT`（默认 180 秒）
  - `HARBOR_WAIT_INTERVAL`（默认 5 秒）
  - `HARBOR_INSECURE=true` 或 `VERIFY_SSL=false` 可放宽 SSL 校验

关键配置（harbor-image.conf）
- 访问：`HARBOR_REGISTRY`（如 `www.sunmoonai.com:30443`），`HARBOR_API_BASE`（如 `https://www.sunmoonai.com:30443`）
- 认证：`HARBOR_USERNAME`、`HARBOR_PASSWORD`
- 项目：`HARBOR_DEFAULT_PROJECT`（默认 `k8s-images`）
- 控制平面：`CONTROL_PLANE_HOST`、`CONTROL_PLANE_USER`、`CONTROL_PLANE_SSH_PORT`、`CONTROL_PLANE_SECRET|PASS`、`CONTROL_PLANE_IMAGE_DIR`
- containerd：`CONTAINERD_NAMESPACE`（默认 `k8s.io`）
- 行为：`AUTO_CLEANUP_AFTER_PUSH`、`PUSH_RETRY`、`PUSH_RETRY_INTERVAL`、`USE_SUDO`、`NERDCTL_BIN`
- 清单目录：`COMPONENT_IMAGES_DIR`（默认 `k8s/utils/components-images`）

常用命令
```bash
# 按需推送组件镜像到 Harbor（读取集中清单）
./harbor-image.sh ensure-component-images <component>

# 清理控制平面的该组件 tar（不影响已推送镜像）
./harbor-image.sh cleanup-component-tars <component>

# Harbor 安装后在所有节点进行一次全局清理（未使用镜像 + 包文件）
./harbor-image.sh cleanup-all-nodes-after-harbor

# 显示配置、Harbor API 连通性与节点摘要
./harbor-image.sh status
```

dry-run 与示例
```bash
# 预演按需推送（不执行实际 ssh/scp/load/push）
./harbor-image.sh ensure-component-images postgresql --dry-run

# 预演全局清理
./harbor-image.sh cleanup-all-nodes-after-harbor --dry-run
```

与组件部署集成
- 在各组件 `deploy-*.sh` 中，Helm 安装前调用：
  `harbor-image.sh ensure-component-images <component>`
- 安装成功后按组件开关清理控制平面 tar：

注意
- 仅对缺失于 Harbor 的镜像进行推送（避免重复）
- 默认会在推送成功后清理控制平面的临时镜像与 tar（可通过配置关闭）
- 需确保控制平面具备 `nerdctl` 与 `containerd`，且具备 SSH 访问权限


附：相关目录
- 集中镜像清单：`k8s/utils/components-images/`
- 本地镜像包：`~/packages-to-be-installed/images/`

附：工作流（Harbor 阶段）
1) Harbor 安装 → 等待就绪（API 与 Registry 双检查）
2) 全局清理所有节点未使用镜像与包文件（可选）
3) 组件部署前：按需将镜像 push 至 Harbor（仅控制平面）
4) 组件部署后：按组件开关清理控制平面 tar

实施检查清单（简版）
- [x] `harbor-image.conf` 已填写 Registry/API、认证与 CONTROL_PLANE_*
- [x] `status` 可达，Harbor `/api/v2.0/ping` 正常
- [x] `ensure-component-images <component>` 能识别清单并匹配本地 tar
- [x] `--dry-run` 预演输出完整

关键原则
1) 按需推送，幂等检查（存在则跳过）
2) 推送后及时清理控制平面缓存（可配置）
3) 永远不删除正在使用的镜像/容器


