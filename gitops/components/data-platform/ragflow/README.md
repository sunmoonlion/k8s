# RAGFlow

官方0.27.2镜像摘要只在infrastructure/artifacts/upstream-images.lock.json，依赖同版建议的Infinity0.7.3和专用Valkey8.1.10；不连接ELK的ES9索引。config.yaml放开关、独立数据库/桶、初始化代次、端口和资源，底层实现及说明在本目录。

原生顺序：platform-services（Infinity/Valkey/PG/S3/TEI）→ragflow-database与ragflow-storage→ragflow-initialize→ragflow-runtime。所有步骤由Flux声明，services-bootstrap统一执行，不要求人工先初始化。首次通过独立Job创建数据库结构和两套租户/令牌（knowledge与验收）；API/Worker直接使用官方image中的模块，绕过entrypoint.sh不可关闭的隐式DDL，以无CREATE的ragflow_runtime角色运行；API使用Hypercorn ASGI/TLS。升级必须独立备份、明确增加初始化代次，并验证同版本官方模块调用，不把此启动方式当作跨版本兼容保证。

原文不以RAGFlow为权威。对象只进ragflow-derived独立版本桶，账号不能访问业务原文桶/管理S3；索引可重建。API与Worker不持PG/AIStor管理员、初始化拥有者或知识服务API令牌。仅知识应用的受限客户端标签与本组件可访问内部HTTPS9380，无公共UI、开放注册、Docker socket、Sandbox执行器或公网下载。专用Infinity/Valkey的明文协议局限见各自README。单实例不具备HA。

秘密由prepare.yaml首次生成至/etc/sunmoon/services/sunmoon-kind/ragflow.yaml并逐字节独立备份；Git只存SOPS。独立TLS5年，使用平台CA验证主机名。临时logs/cache有emptyDir容量上限；正式数据在PG、S3、Infinity、Valkey。services-check验收真实隔离租户的创建/上传/解析/中文检索与拒绝路径，随机验收数据精确清理，不碰业务数据。完整领域链、WSL/KIND重建与备份恢复结果需另行记录。
