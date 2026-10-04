# Infinity

RAGFlow专用的可重建索引，官方0.7.3版本/摘要唯一在infrastructure/artifacts/upstream-images.lock.json；config.yaml调整卷、buffer与资源，infinity_conf.toml.j2跟随同版官方配置。

单节点worker、30Gi静态Retain卷，1000非root、只读根。仅RAGFlow Pod可访问23817，健康管理23820不暴露Service。不具备HA。该版客户端协议无身份/TLS，本期依靠Calico限制；不得当作可供任意应用共用的安全边界。实例与Valkey均为RAGFlow专用依赖，不保存唯一原文。

原生services-stage→提交→flux-release→核对晋级候选→services-bootstrap；services-check核对当前代次、固定镜像、卷和真实HTTP节点身份。删除/备份与整机重建验收另做。
