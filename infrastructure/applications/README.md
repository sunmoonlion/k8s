# 业务应用构建与发布

用户配置、源码锁、原生构建编排与说明同处。本单元已实现基础镜像物料准备及模板后端构建/发布；应用运行时声明尚未交付。

## 配置入口

| 文件/字段 | 用途 |
| --- | --- |
| `config.yaml/application_base_image_ids` | 选择Python、Node构建与Node运行镜像，具体版本/摘要唯一读取artifacts锁 |
| `config.yaml/application_build_budget_bytes` | 后端构建峰值预留，目前4GiB；仍必须满足计数据盘未来增长后的50GiB底线 |
| `sources.yaml` | 五仓并列布局下的模板父仓及三个子模块固定提交；当前构建要求后端与父仓gitlink一致且后端工作区干净 |
| `build.yaml` | 导出已提交的后端源码、按锁定基础镜像构建、核对运行镜像并保存离线归档 |

应用数据库用户名、口令、域名和端口不由构建入口生成；后续应用运行模块接入时与对应声明同处，口令使用私有输入和SOPS。当前只有镜像准备成功，不能据此认为这些运行配置已实现。

## 日常入口

在 `infrastructure` 执行：

```sh
make application-plan
make application-materials
make application-verify-materials
make application-publish
make application-build-backend
make application-publish-backend
```

前四项只处理已选基础镜像。最后两项分别构建和发布模板后端；发布读取 `.build/applications/backend-images.lock.json` 中已构建的摘要，不重新构建。仅从已提交Git对象导出源码，不带入本地忽略文件或凭据。沿用应用仓 `app/Dockerfile`，用固定Harbor Python摘要覆盖基础镜像参数。

镜像传输统一使用 `artifacts/publish.yaml` 及其逐镜像任务，平台和应用共享实现。发布拒绝覆盖内容不同的同名标签，使用独立puller复核远端摘要。旧 `services/materials.yaml` 已移动到物料模块，未留转发文件，原services Make入口保留。

正式物料存入 `releases/platform-kind-v1/images`：归档按manifest命名，旁边JSON保存源提交、构建输入、归档SHA256和完整blob核验记录。构建回执和私有日志在 `.build/applications`；它们不提交Git。后续正式应用发布还须把选定镜像摘要写入已提交的GitOps声明。

## 构建认证与隔离

宿主Docker的仓库专用CA供daemon使用；Buildx客户端申请token还需要信任CA。本入口仅给构建进程指定 `SSL_CERT_FILE` 为现有Harbor CA，临时复制只读认证文件，结束清除，不关闭TLS、不改全局系统信任。
参考：[Docker BuildKit认证说明](https://docs.docker.com/build/buildkit/toml-configuration/)。

转换归档的skopeo容器无网络、只读根文件系统、移除全部capabilities；root拥有独立输出和临时目录，结束清除。不能让无DAC权限的root写入其他UID的0700目录，也不能假设只读容器的 `/var/tmp` 可写。

## 当前完成范围

- Python3.13.15、Node24.21.0构建/精简运行三份基础镜像已离线核验并发布Harbor。
- 后端源码6674125cd1c14d9700c707b0b0f4b5d422d42f05已构建，实际运行解释器3.13.15、运行用户appuser。
- 后端manifest为 `sha256:5b38d39836dc6fe5e6d9d17eaa537d4ba52dd5db342dd95be0397e4c4e928ef0`，离线归档82,363,392字节；重复构建得到相同manifest，发布只读身份校验通过。
- Python依赖仍按应用uv.lock从网络取得；不是完整断网重建承诺。uv安装包、前端依赖离线闭包、前端新基镜像适配、应用身份/独立迁移/运行声明和业务验收仍待接入。
- 本单元未启动业务服务、切换应用入口或修改业务源码；运行平台维持原已验版本。未来源码更新必须先更新审核后的源码锁。
