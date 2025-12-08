# 组件镜像清单目录

- 每个组件维护一份镜像清单：`<component>-images.txt`
- 一行一个镜像，格式：`repository:tag`
- harbor 工具会按该清单从本地 `~/packages-to-be-installed/images/` 匹配 tar 并按需推送到 Harbor。

示例：
```
postgres:15-alpine
postgres-exporter:v0.14.0
```
