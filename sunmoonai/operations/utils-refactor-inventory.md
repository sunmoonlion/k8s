# utils 逐目录、逐文件处置清单

基线 `f2e6b1a21d92237aa0ebca6665077a1e6beadb2f`；范围为原 `utils/` 全部 **131 个跟踪文件**。日期：2026-09-28。

这是用途、调用/采用方式、重复和替代关系的整理，不是对每个工具的完整功能或安全验收。没有运行任何工具的安装、SSH、数据库、K8s 或清理动作。逐文件 SHA、函数目录和引用候选见 [机器清单](../scripts/results/luna-utils-disposition.20260928.json)。

## 处置规则

- 公共库、人工工具、动态插件、组件列表和生成模板分别判断；零字面引用不是删除理由。
- 已确定被替代的实现先改调用方再删除；保留真实功能，不用废弃路径转发凑兼容。
- 保留人工连接、物料打包/分发、盘点与 local-path 修复工具；新增说明区分可复用能力与尚未完成新版适配的旧操作。
- 只合并逐字节相同的证书规范模板；两套 Secret 库接口不同，分别保留。
- 源码整理不触碰运行数据、物料根、受保护的节点/卷和云端待验证归档。

## db-provisioner 的核对结论

所有者指出模板仓/实例也在使用它，因此补查了四仓实际 DBCTL_BIN 配置：各 backend 默认用自己的同级实现；没有把它们改为跨仓依赖。Casdoor 默认使用 `k8s/utils/db-provisioner`，故本处不是纯备份。

`k8s/sunmoonai/utils/db-provisioner/` 的 19 文件副本已删除，平台保留根 `utils/db-provisioner/`。16 文件完全相同，3处差异为 README、Redis ACL 处理与 PostgreSQL 模板配置；保留实际使用的根实现，不把旧副本覆盖回去。已修正文档中指向副本的路径；四个应用仓均未修改。

## 逐文件处置（路径相对仓库根）

| 文件 | 处置 | 依据/职责 |
| --- | --- | --- |
| `utils/KIND-README.md` | 删除 | 旧建群/节点导入教程与已停用入口冲突；现行入口为 formal/README.md |
| `utils/SECRET_SYSTEMS_COMPARISON.md` | 重写 | 区分参数式生成库和组合式分发层；仅相同规范去重，接口不同的库保留 |
| `utils/alembic-migration-gate.sh` | 保留公共库 | 独立 migration Secret 与迁移 Job 校验/执行能力；不是可随清理删除的备份 |
| `utils/app-config-checklist-template.md` | 保留模板 | 人工检查清单，有无代码引用不决定用途 |
| `utils/app-dependency-preflight.sh` | 保留公共库 | 组件依赖、前端发布标签和 Secret 覆盖校验，函数式供采用 |
| `utils/auth-integration-template/README.md` | 保留模板 | 人工接入样例说明；加注不是当前 tpl-app 身份实现真源 |
| `utils/auth-integration-template/fastapi-backend/config_example.py` | 保留模板 | FastAPI JWT/JWKS 验签及配置样例 |
| `utils/auth-integration-template/fastapi-backend/jwks_auth.py` | 保留模板 | FastAPI JWT/JWKS 验签及配置样例 |
| `utils/auth-integration-template/flask-backend/config_example.py` | 保留模板 | Flask JWT/JWKS 验签及配置样例 |
| `utils/auth-integration-template/flask-backend/jwks_auth.py` | 保留模板 | Flask JWT/JWKS 验签及配置样例 |
| `utils/auth-integration-template/nestjs-backend/auth.module.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nestjs-backend/config_example.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nestjs-backend/current-user.decorator.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nestjs-backend/jwks.guard.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nestjs-backend/jwks.service.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nestjs-backend/public.decorator.ts` | 保留模板 | NestJS module/guard/JWKS/装饰器接入样例 |
| `utils/auth-integration-template/nuxt-bff/app/composables/useAuth.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/nuxt-bff/nuxt.config.snippet.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/nuxt-bff/server/api/auth/login.get.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/nuxt-bff/server/api/auth/logout.post.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/nuxt-bff/server/middleware/auth.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/nuxt-bff/server/routes/auth/callback.get.ts` | 保留模板 | Nuxt BFF 登录回调、会话和服务端调用样例 |
| `utils/auth-integration-template/scripts/register-client.sh` | 保留模板 | 人工 OAuth 客户端注册工具；不在盘点时执行 |
| `utils/auth-integration-template/vite-spa-backend/fastapi/auth_router.py` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/fastapi/config_example.py` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/flask/auth_routes.py` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/flask/config_example.py` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/nestjs/auth.controller.ts` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/nestjs/auth.module.ts` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/nestjs/config_example.ts` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa-backend/nestjs/session.service.ts` | 保留模板 | 多框架会话、PKCE、登录回调/退出的服务端样例 |
| `utils/auth-integration-template/vite-spa/env.example` | 保留模板 | Vite 登录状态/路由/回调及配置样例 |
| `utils/auth-integration-template/vite-spa/src/composables/useAuth.ts` | 保留模板 | Vite 登录状态/路由/回调及配置样例 |
| `utils/auth-integration-template/vite-spa/src/pages/AuthCallback.vue` | 保留模板 | Vite 登录状态/路由/回调及配置样例 |
| `utils/auth-integration-template/vite-spa/src/router/authGuard.ts` | 保留模板 | Vite 登录状态/路由/回调及配置样例 |
| `utils/browser-oidc-gate.sh` | 保留公共库 | 浏览器 OIDC Secret 必需键和应用绑定校验，函数式供采用 |
| `utils/check-local-images.sh` | 保留并修正 | 主机 Docker/CRI/nerdctl 只读盘点；去掉全局 prune 建议 |
| `utils/check-node-images.sh` | 保留并修正 | Pod/Deployment 镜像、策略和节点信息；去掉删 Pod/节点镜像与重启建议 |
| `utils/check-remote-node-images.sh` | 保留人工工具 | 从 K8s API 汇总镜像 ID 与节点分布；不等于直接扫描完整节点缓存 |
| `utils/cluster-arg-parser.sh` | 保留公共库 | 统一参数解析的唯一实现；组件和模板 source |
| `utils/cluster-config-mapping.sh` | 保留公共库 | 按 C1/C2/C3/KIND 前缀映射组件配置；仍有实际调用 |
| `utils/components-images/README.md` | 保留清单 | 组件镜像清单说明 |
| `utils/components-images/auth-app-backend-images.txt` | 保留清单 | 按 --component 动态读取；auth-app-backend 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/auth-app-front-images.txt` | 保留清单 | 按 --component 动态读取；auth-app-front 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/casdoor-images.txt` | 保留清单 | 按 --component 动态读取；casdoor 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/document-converter-images.txt` | 保留清单 | 按 --component 动态读取；document-converter 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/elasticsearch-images.txt` | 保留清单 | 按 --component 动态读取；elasticsearch 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/flower-images.txt` | 保留清单 | 按 --component 动态读取；flower 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/jenkins-images.txt` | 保留清单 | 按 --component 动态读取；jenkins 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/kibana-images.txt` | 保留清单 | 按 --component 动态读取；kibana 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/logstash-images.txt` | 保留清单 | 按 --component 动态读取；logstash 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/mongo-express-images.txt` | 保留清单 | 按 --component 动态读取；mongo-express 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/mongodb-images.txt` | 保留清单 | 按 --component 动态读取；mongodb 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/neo4j-images.txt` | 保留清单 | 按 --component 动态读取；neo4j 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/object-storage-images.txt` | 保留清单 | 按 --component 动态读取；object-storage 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/pgadmin-images.txt` | 保留清单 | 按 --component 动态读取；pgadmin 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/postgresql-images.txt` | 保留清单 | 按 --component 动态读取；postgresql 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/rabbitmq-images.txt` | 保留清单 | 按 --component 动态读取；rabbitmq 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/ragflow-images.txt` | 保留清单 | 按 --component 动态读取；ragflow 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/redis-images.txt` | 保留清单 | 按 --component 动态读取；redis 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/components-images/redisinsight-images.txt` | 保留清单 | 按 --component 动态读取；redisinsight 的镜像输入，不能用固定路径零引用判断无用 |
| `utils/db-provisioner/README.md` | 保留平台实现 | 写明平台 Casdoor 与各 backend 自带实现的不同归属 |
| `utils/db-provisioner/adapters/external.sh` | 保留平台实现 | dbctl 的 external 凭据输出适配 |
| `utils/db-provisioner/adapters/k8s.sh` | 保留平台实现 | dbctl 的 k8s 凭据输出适配 |
| `utils/db-provisioner/bin/dbctl` | 保留平台实现 | dbctl 引擎分发/输出适配或模板生成入口 |
| `utils/db-provisioner/bin/init-service-provision-template.sh` | 保留平台实现 | dbctl 引擎分发/输出适配或模板生成入口 |
| `utils/db-provisioner/drivers/mongodb.sh` | 保留平台实现 | dbctl 动态分发的 mongodb 引擎驱动；不是应用仓备份 |
| `utils/db-provisioner/drivers/postgresql.sh` | 保留平台实现 | dbctl 动态分发的 postgresql 引擎驱动；不是应用仓备份 |
| `utils/db-provisioner/drivers/redis.sh` | 保留平台实现 | dbctl 动态分发的 redis 引擎驱动；不是应用仓备份 |
| `utils/db-provisioner/lib/common.sh` | 保留平台实现 | dbctl/驱动共用的配置、校验与等待函数 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/README.md` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/config/common.env` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/config/nodebull-redis.k8s.env` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/config/postgresql.k8s.env` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/config/redis.k8s.env` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/lib/k8s-deploy-context.sh` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/setup-external-db-access.sh` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/setup-k8s-db-access.sh` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/teardown-external-db-access.sh` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/db-provisioner/templates/db-access-bootstrap-template/teardown-k8s-db-access.sh` | 保留平台实现 | 组件自举生成模板/配置；Casdoor 等按需采用，不等同运行数据 |
| `utils/deploy-runtime-helpers.sh` | 保留公共库 | 项目与应用总控传递子脚本配置；旧状态回退需后续显式目标接线 |
| `utils/fix-local-path-helper-image.sh` | 保留人工工具 | 既有集群 helper 镜像/Secret 修复，有修改 ConfigMap 和重启操作；新建群用锁定 storage_resources.py |
| `utils/harbor-image-check.sh` | 合并后删除 | 唯一部署调用方 Document Converter 改用 registry-platform/images.py；移除 curl -k 与认证/网络失败放行 |
| `utils/k8s-admin-README.md` | 重写 | 说明真实存在的人工连接工具与 k8s-admin.conf，不再宣传不存在的存储菜单 |
| `utils/k8s-admin.conf` | 保留配置 | 连接工具、模板、总控和节点工具仍读取；未修改任何配置值 |
| `utils/k8s-connection-manager.ps1` | 保留人工工具 | Windows 参数、路径与隧道处理；不是 Shell 转发；未运行 Windows 操作 |
| `utils/k8s-connection-manager.sh` | 保留人工工具 | 人工 SSH 直连/跳板/隧道保活及查询菜单，未被新总控完整替代；存在工具安装/端口处理副作用 |
| `utils/kubeconfig-path-for-cluster.sh` | 保留公共库 | 总控/模板解析现有 k8s-admin.conf 的配置路径 |
| `utils/packages-management/export-component-image-tars.sh` | 保留人工工具 | 按组件名动态读列表并人工导出/同步 tar；不是 OCI 批次发布器，产物须额外准入 |
| `utils/packages-management/packages-management.sh` | 保留人工工具 | 自定义 deb/二进制打包、下载、chart、分发菜单能力尚未完整替代；旧安装/推送/清理不作为新正式路径 |
| `utils/packages-management/packages.conf` | 保留配置 | 两个人工物料工具实际 source；无自动调用不能据此删除配置 |
| `utils/prepare-secrets-from-examples.sh` | 保留并修正 | 总控实际调用的占位模板准备；改成保留已有文件，避免覆盖真实 Secret |
| `utils/prepend-dev-cli-path.sh` | 保留公共库 | 共享模板和 KIND CLI 帮助库实际 source；仅补 PATH |
| `utils/secret-management/CALLERS_ANALYSIS.md` | 删除 | 旧调用关系快照与已不存在的 ca-management 路径混杂；由本清单和实际代码取代 |
| `utils/secret-management/README.md` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/README-cert-core.md` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/README-secret-core.md` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/README-specifications.md` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/cert-conf-template/ca-specifications` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/cert-conf-template/ca-template.conf` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/cert-conf-template/server-specifications` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/cert-conf-template/server-template.conf` | 保留说明/模板 | 通用 Secret/证书接口说明或规范样例；保留一份权威模板 |
| `utils/secret-management/lib/cert-core.sh` | 保留公共库 | Traefik 调用的参数化叶证书生成，基于已有 CA |
| `utils/secret-management/lib/common.sh` | 保留公共库 | 简单参数读取/日志函数，供库使用或复用 |
| `utils/secret-management/lib/secret-core.sh` | 保留公共库 | 多组件实际 source 的 Secret YAML 生成接口 |
| `utils/secret-management/lib/secret-data.sh` | 保留公共库 | 组件 Secret 数据准备；已接独立仓库私有认证 |
| `utils/service-identity-gate.sh` | 保留公共库 | 服务身份关系/授权输入校验，函数式供采用 |
| `utils/storage-manager-README.md` | 删除 | 所述 storage-manager.sh 实际不存在；挂盘/持久化说明归当前 mount 与设计文档 |
| `utils/unified-cert-secret-management/CLUSTER-CROSS-HARBOR-TLS.md` | 保留分发能力 | 改写为独立仓库的多集群消费者信任说明 |
| `utils/unified-cert-secret-management/README.md` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/cert-secret.conf` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/deploy-all.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/lib/README-specifications.md` | 合并后删除 | 与 secret-management/lib/README-specifications.md 逐字节相同；保留后者为唯一规范/模板 |
| `utils/unified-cert-secret-management/lib/cert-conf-template/ca-specifications` | 合并后删除 | 与 secret-management/lib/cert-conf-template/ca-specifications 逐字节相同；保留后者为唯一规范/模板 |
| `utils/unified-cert-secret-management/lib/cert-conf-template/ca-template.conf` | 合并后删除 | 与 secret-management/lib/cert-conf-template/ca-template.conf 逐字节相同；保留后者为唯一规范/模板 |
| `utils/unified-cert-secret-management/lib/cert-conf-template/server-specifications` | 合并后删除 | 与 secret-management/lib/cert-conf-template/server-specifications 逐字节相同；保留后者为唯一规范/模板 |
| `utils/unified-cert-secret-management/lib/cert-conf-template/server-template.conf` | 合并后删除 | 与 secret-management/lib/cert-conf-template/server-template.conf 逐字节相同；保留后者为唯一规范/模板 |
| `utils/unified-cert-secret-management/lib/cert.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/lib/common.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/lib/secret-data.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/lib/ssh.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/deploy-client.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/deploy-server.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/plugins/client/traefik-D-deploy-client.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/plugins/client/traefik-K-deploy-client.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/plugins/client/traefik-N-deploy-client.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/plugins/server/traefik-C-deploy-server.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/plugins/server/traefik-K-deploy-server.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-cert-secret-management/scripts/sync-ca-from-k8s.sh` | 保留分发能力 | 组合配置/动态服务端客户端插件/SSH或证书生成分发链；ensure-kind-ca 和 Traefik 仍有依赖，接口不同于参数化库 |
| `utils/unified-deployment-template.md` | 重写 | 按真实公共接口写明连接、配置、镜像检查和未完成适配 |
| `utils/unified-deployment-template.sh` | 合并实现 | 删除重复的参数解析函数，source cluster-arg-parser.sh；大量组件依赖的连接逻辑保留 |

## 保留工具的已知适配边界

- 连接工具/共享连接库仍有关闭 SSH 主机校验、自动连接/工具安装及状态回退路径；本轮保留人工能力，不宣称新版生产准入已通过。
- 物料菜单存在宽泛临时目录清理、口令参数、按文件存在跳过等旧行为；新版批次/签名/摘要链不使用这些旧安装发布分支。自定义打包等独立功能未被替代，须逐能力适配后再退役。
- 证书分发动态插件、旧 CA 同步及数据库凭据输出仍有后续适配项；此轮未轮换证书/账号，也没有建库。
- 三个镜像盘点工具属于人工只读观察，不证明仓库层完整或节点缓存覆盖全部架构。
- 占位 Secret 生成已改为保留既有文件；Document Converter 已用共享严格 Registry 检查替代旧失败放行逻辑。
- 后续按原迁移计划完成目标/配置接线、真实推拉与云实机验证；最终本机/东京临时物料清理仍保留为收尾门禁。

## 仓内另一份 db-provisioner 的逐文件合并记录

这些路径不计入上面的 131 文件；它们位于 `sunmoonai/utils/`。每一项都保留对应的根 `utils/db-provisioner/`，没有改动模板仓/实例仓的实现。

| 删除的重复路径 | 与根实现的基线关系 |
| --- | --- |
| `sunmoonai/utils/db-provisioner/README.md` | 存在差异；保留已在实际调用链上的根版本，旧字节可从基线 Git 恢复 |
| `sunmoonai/utils/db-provisioner/adapters/external.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/adapters/k8s.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/bin/dbctl` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/bin/init-service-provision-template.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/drivers/mongodb.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/drivers/postgresql.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/drivers/redis.sh` | 存在差异；保留已在实际调用链上的根版本，旧字节可从基线 Git 恢复 |
| `sunmoonai/utils/db-provisioner/lib/common.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/README.md` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/config/common.env` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/config/nodebull-redis.k8s.env` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/config/postgresql.k8s.env` | 存在差异；保留已在实际调用链上的根版本，旧字节可从基线 Git 恢复 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/config/redis.k8s.env` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/lib/k8s-deploy-context.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/setup-external-db-access.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/setup-k8s-db-access.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/teardown-external-db-access.sh` | 逐字节相同 |
| `sunmoonai/utils/db-provisioner/templates/db-access-bootstrap-template/teardown-k8s-db-access.sh` | 逐字节相同 |

机械检查：6 个修改 Shell 的 bash -n 与 ShellCheck error 级通过；76 个修改文档本地链接存在；131 条处置精确覆盖基线文件集合。没有运行测试套件或真实工具动作。
