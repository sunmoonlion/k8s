# 信息应用组件

用户字段在config.yaml；镜像摘要与源码在image.lock.yaml；生成的workload、SOPS与kustomization声明同处。共用机制由../../common直接渲染，不依赖tpl组件。

用户名与数据库/队列见后端config；口令在/etc/sunmoon/applications/sunmoon-kind/info及独立备份，仅SOPS密文进入Git。域名、端口、副本及资源在对应config。改变Job输入须显式提高Job revision，不能修改已完成的不可变Job。

## 原文 S3 配置

config.yaml.object_storage 保存 info_storage、info-originals 和 Job revision；端点/区域取对象存储组件配置。
独立口令在上述 private_dir 的 s3.yaml，非覆盖备份在 backup_dir；只有密文入 Git。
后端三个角色使用 HTTPS 与平台 CA。桶版本控制是业务代码硬要求，不允许用容器本地目录或取消版本号校验绕过。
