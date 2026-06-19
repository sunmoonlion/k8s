# 组件镜像清单目录

- 每个组件维护一份镜像清单：`<component>-images.txt`
- 一行一个镜像，格式：`repository:tag`
- 部署前会按该清单先检查目标 Harbor 是否已有镜像；Harbor 已有则跳过，缺失才从本地或远程 tar 补齐。
- 完整机制见：`../../sunmoonai/docs/harbor-component-image-ensure.md`

示例：
```
postgres:15-alpine
postgres-exporter:v0.14.0
```
