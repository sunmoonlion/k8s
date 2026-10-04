# RAGFlow

官方0.27.2镜像摘要只在infrastructure/artifacts/upstream-images.lock.json，依赖同版建议的Infinity0.7.3和专用Valkey8.1.10；不连接ELK的ES9索引。config.yaml放开关、独立数据库/桶、初始化代次、端口和资源，底层实现及说明在本目录。

原生顺序：platform-services（Infinity/Valkey/PG/S3/TEI）→ragflow-database与ragflow-storage→ragflow-initialize→ragflow-runtime。所有步骤由Flux声明，services-bootstrap统一执行，不要求人工先初始化。首次通过独立Job创建数据库结构和两套租户/令牌（knowledge与验收）；API/Worker直接使用官方image中的模块，绕过entrypoint.sh不可关闭的隐式DDL，以无CREATE的ragflow_runtime角色运行；API使用Hypercorn ASGI/TLS。升级必须独立备份、明确增加初始化代次，并验证同版本官方模块调用，不把此启动方式当作跨版本兼容保证。

原文不以RAGFlow为权威。对象只进ragflow-derived独立版本桶，账号不能访问业务原文桶/管理S3；索引可重建。API与Worker不持PG/AIStor管理员、初始化拥有者或知识服务API令牌。仅知识应用的受限客户端标签与本组件可访问内部HTTPS9380，无公共UI、开放注册、Docker socket、Sandbox执行器或公网下载。专用Infinity/Valkey的明文协议局限见各自README。单实例不具备HA。

秘密由prepare.yaml首次生成至/etc/sunmoon/services/sunmoon-kind/ragflow.yaml并逐字节独立备份；Git只存SOPS。独立TLS5年，使用平台CA验证主机名。临时logs/cache有emptyDir容量上限；正式数据在PG、S3、Infinity、Valkey。services-check验收真实隔离租户的创建/上传/解析/中文检索与拒绝路径，随机验收数据精确清理，不碰业务数据。完整领域链、WSL/KIND重建与备份恢复结果需另行记录。

## 官方镜像的非root适配

实际核对0.27.2官方镜像：.venv/bin/python链接到/root/.local/share/uv/python/cpython-3.13.11-linux-x86_64-gnu，而/root权限0700。UID1000通过PATH会退回系统3.12，无法导入项目依赖。Dockerfile只将镜像自带/root目录设为0755、官方NLTK数据设为非root可读、默认用户1000，并验证原Python3.13和WordNet可用；不安装或升级包、不下载NLP语料。另有一处经官方文件SHA256守卫的批量写入补丁：运行期检查表已存在，替代不必要的CREATE TABLE IF NOT EXISTS；缺表明确失败，表结构仍只由独立初始化Job管理。运行与探针显式使用/ragflow/.venv/bin/python3。版本仍0.27.2，运行镜像是可审查的派生镜像，不宣称与官方摘要相同。

services-ragflow-image复用原生Ansible/容量检查：固定官方Harbor摘要→无网络Docker构建→非root依赖检查→现有skopeo转换与逐层验证。Dockerfile摘要、官方基底和派生摘要/归档摘要单独保存在本目录image.lock.json；上游锁不改。正式归档保存在platform-kind-v1/images，独立publish入口复用既有artifacts/publish，完整services-bootstrap包含它们。已有锁从不自动覆盖；升级需先审查新构建、提交并晋级固定Flux源。健康探针同处health.py，使用标准HTTP库编码请求和CA/SNI校验，避免内联CRLF转义。初次预算按官方已校验归档逐层实际解压字节测量（只读、不解包落盘），计入宿主镜像、转换工作区、归档和1GiB余量，直接从Docker导出至OCI，避免重复保存一份docker-save归档，后续复用归档；没有启动时下载依赖。官方镜像中的/root不保存用户秘密，用户秘密仍只放私有目录/SOPS和受限Secret。

内部API同时有Ingress与Egress精确规则；RAGFlow组件可访问同组件API9380，PG/S3/Infinity/Valkey/向量服务各按既有专属策略授权，不开放任意出站或公网。

官方API-token认证要求User.access_token非空，初始化Job首次补入独立随机会话标记；它不复用API令牌，不签发浏览器会话，不开放登录路径，已有值不覆盖。

源码适配范围只限api/db/db_utils.py的一处批量写入前置检查，官方文件SHA256为4db6691cd806ca04ef48f6cd034a55d90704ede815c807f57f8b1b0d38c30779。Dockerfile记录全部补丁字节，未来上游文件变化立即使构建失败；不能静默套用到新版本。此必要性由真实文档解析的schema权限拒绝证实，不放宽DML账号。

官方数据集删除API保留版本桶的旧版本。services-check只对本轮随机数据集执行精确版本清理，并独立核对对应DB行及S3前缀均为空；不改变业务保留策略或整桶删除。
