# Valkey

RAGFlow专用队列与缓存，官方8.1.10摘要来自单一镜像锁，不复用应用Redis账号。config.yaml设置卷、用户名、资源与内存上限；秘密由prepare.yaml一次生成至/etc/sunmoon/services/sunmoon-kind/valkey.yaml，并逐字节保存在独立备份目录，Git只存SOPS。

默认账号禁用；ragflow_queue可操作该独立实例的业务键/流/Lua，不可ACL/CONFIG/FLUSH；sunmoon_queue_probe只访问sunmoon:acceptance:*键。ACL以SHA256而非明文保存，文件只读挂载，恢复时仍使用同一身份。AOF everysec、noeviction；worker静态4Gi Retain卷、999非root、只读根。客户端当前同RAGFlow官方不支持TLS，依靠Calico限制，仅RAGFlow可连。单节点不具备HA。

原生services-bootstrap及services-check；后者真实KV读写、错误密码/管理/范围外键拒绝。持久化的完整备份恢复、WSL/KIND重建尚未验收。
