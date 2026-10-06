# 沙箱镜像

每用户一个的沙箱 Pod 里跑的镜像：钉版 Codex app-server + 沙箱侧出站桥（源码 `sunmoonai/sandbox-platform/{image,bridge}`）。只构建、不单独部署：供给器读这里的 `image.lock.yaml` 决定拉起哪个镜像。

```sh
make -C infrastructure platform-build OBJECT=sandbox-platform/sandbox
```

构建从 `infrastructure/applications/component-images.yaml` 钉的本仓提交导出 context，产物发到 Harbor `platform/sandbox`，锁由 `component-lock` 改写。镜像里 Codex 的配置由入口脚本按环境变量生成：关子代理与「目标」，接知识服务与工作台两个 MCP。
