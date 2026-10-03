# Casdoor

`config.yaml` 是本组件普通用户参数的唯一入口。`workload.yaml.j2` 是实现模板，`workload.yaml` 是审查提交后的部署声明；修改参数后通过 `make -C infrastructure services-render`（从仓库根执行）生成候选并按统一发布流程晋级。

配置和声明不会因为文件相邻自动关联：现有 Make/Ansible 读取明确配置并渲染，Flux 读取 Kustomization 中明确列出的声明。密文由已有 SOPS 流程管理。

`database/` 创建专用库/角色，运行在数据命名空间；`init/` 初始化身份，主服务和初始化均在应用命名空间。主目录 Kustomization 只引用主服务，不递归部署子阶段。

操作和输入边界见 [组件说明](../../../README.md) 与 [服务操作](../../../../../docs/platform-kind-v1/services.md)。
