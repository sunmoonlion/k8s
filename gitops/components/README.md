# 按组件维护配置和声明

找到组件目录即可找到它的 `config.yaml`、模板、部署声明、加密 Secret 和说明。

- **修改用户参数**：编辑该组件 `config.yaml`；共享环境名/命名空间在 `infrastructure/environments/kind/site.yaml`。
- **修改底层实现**：编辑同目录 `*.j2` 模板，平台服务通过 `make services-render` 生成候选；应用通过 `make application-stage APP=tpl` 生成可审查声明（均在 `infrastructure` 执行）。
- **发布**：审查候选，将生成声明提交并发布不可变 OCI 源后由 Flux 协调。不要只改生成的 `workload.yaml`。
- **秘密**：明文只在独立私有输入；`*.sops.yaml` 是密文。不把口令写进 `config.yaml`。
- **版本**：镜像和 chart 版本、摘要仍取统一物料锁，不在组件配置中覆盖。

Kustomization 显式列出部署文件，**不引用 `config.yaml`、模板或 README**。不能直接 `kubectl apply -f` 整个目录。
Casdoor 的 `database/`、`init/` 与主服务是三个独立 Flux 阶段，不将子阶段放进主服务 Kustomization，以保留数据库→初始化→服务的依赖等待。

目录代表代码职责，`metadata.namespace` 决定运行位置。Casdoor 专用建库 Job 归 Casdoor 维护，但在 `data-platform-dev` 执行。
`foundations/` 保存跨组件存储/网络/命名空间声明及模板，`core/` 只组合平台分类。
关闭组件不等于删除它的在用资源与数据；删除另按生命周期规则执行。

## 应用平台的层级

沿用“平台 → 应用 → 组件”：`app-platform/auth-app/casdoor/`；模板在 `app-platform/tpl-app/`，其下保留 `tpl-backend/`、`tpl-web-frontend/`、`tpl-admin-frontend/`，后端目录内接入 `database/` 和 `migration/`；API/Worker/Scheduler同属后端。实例依次放 `info-app/`、`knowledge-app/`、`investment-app/`，不另建平行分类。`infrastructure/applications/` 是共用编排工具的位置，部署声明仍按这里分类。
