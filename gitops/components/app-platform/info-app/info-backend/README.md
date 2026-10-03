# 信息应用组件

用户字段在config.yaml；镜像摘要与源码在image.lock.yaml；生成的workload、SOPS与kustomization声明同处。共用机制由../../common直接渲染，不依赖tpl组件。

用户名与数据库/队列见后端config；口令在/etc/sunmoon/applications/sunmoon-kind/info及独立备份，仅SOPS密文进入Git。域名、端口、副本及资源在对应config。改变Job输入须显式提高Job revision，不能修改已完成的不可变Job。
