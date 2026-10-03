# 业务应用构建与发布

用户配置、源码锁、原生构建编排与说明同处。已实现基础镜像物料准备及模板后端构建/发布；同一原生构建流程已接入Web/Admin前端参数，实际完成情况见本页末。应用运行时声明尚未交付。

## 配置入口

| 文件/字段 | 用途 |
| --- | --- |
| `config.yaml/application_base_image_ids` | 选择Python、Node构建与Node运行镜像，具体版本/摘要唯一读取artifacts锁 |
| `config.yaml/application_build_budget_bytes` | 后端构建峰值预留，目前4GiB；仍必须满足计数据盘未来增长后的50GiB底线 |
| `config.yaml/application_frontend_build_budget_bytes` | 每个前端构建峰值预留，目前6GiB，包含基镜像解包、依赖、缓存、归档 |
| `config.yaml/application_download_mode` | 单选domestic或official-proxy，源和代理配套切换；端点定义在download-modes.json |
| `sources.yaml` | 固定父仓及三个子模块提交。前端使用显式本地覆盖，必须是固定父仓gitlink的后代；三个组件都要求精确HEAD且干净 |
| `build.yaml` | 组件映射选择源码路径、Dockerfile、阶段和运行用户；一份流程导出Git对象、构建、核对解释器并校验OCI上传内容 |

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
make application-build-web
make application-publish-web
make application-build-admin
make application-publish-admin
```

前四项只处理已选基础镜像。后三组分别构建/发布后端、Web、Admin；发布读取 `.build/applications/{backend,web,admin}-images.lock.json` 中已构建的摘要，不重新构建。仅从已提交Git对象导出源码，不带入本地忽略文件或凭据。后端沿用应用仓 `app/Dockerfile`；前端沿用各子仓 `mybuild/Dockerfile`，均由固定Harbor摘要提供基础镜像。

镜像传输统一使用 `artifacts/publish.yaml` 及其逐镜像任务，平台和应用共享实现。发布拒绝覆盖内容不同的同名标签，使用独立puller复核远端摘要。旧 `services/materials.yaml` 已移动到物料模块，未留转发文件，原services Make入口保留。

基础镜像物料保留在 `releases/platform-kind-v1/images`；应用镜像只保留临时上传归档及来源记录，确认发布后清除归档。构建回执和私有日志在 `.build/applications`；它们不提交Git。后续正式应用发布还须把选定镜像摘要写入已提交的GitOps声明。

## 构建认证与隔离

宿主Docker的仓库专用CA供daemon使用；Buildx客户端申请token还需要信任CA。本入口仅给构建进程指定 `SSL_CERT_FILE` 为现有Harbor CA，临时复制只读认证文件，结束清除，不关闭TLS、不改全局系统信任。
参考：[Docker BuildKit认证说明](https://docs.docker.com/build/buildkit/toml-configuration/)。

转换归档的skopeo容器无网络、只读根文件系统、移除全部capabilities；root拥有独立输出和临时目录，结束清除。不能让无DAC权限的root写入其他UID的0700目录，也不能假设只读容器的 `/var/tmp` 可写。

## 当前完成范围

- Python3.13.15、Node24.21.0构建/精简运行三份基础镜像已离线核验并发布Harbor。
- 后端源码6674125cd1c14d9700c707b0b0f4b5d422d42f05已构建，实际运行解释器3.13.15、运行用户appuser。
- 后端manifest为 `sha256:5b38d39836dc6fe5e6d9d17eaa537d4ba52dd5db342dd95be0397e4c4e928ef0`，离线归档82,363,392字节；重复构建得到相同manifest，发布只读身份校验通过。
- Web已构建并发布 `sha256:7747a9fa70b49c2b1c6936c5a9e1e45afda48acd4b4e6bd6a241ef76e96f7293`，Node24.21.0、用户nextjs；发布确认后上传临时归档已删除。后端已有远端镜像时也已实际重复发布，无需本地归档。
- Admin初次在配套模式下因Fake-IP路径失败；所有者关闭代理后，国内模式完整构建ok43 changed15 failed0，发布ok35 changed2 failed0。Node24.21.0、nextjs用户，manifest `sha256:830a9e382927264850656694430b289404cfd2708ba402e3279785176e0961ec`；上传归档106,353,152字节，发布确认后已删除；随后常规50GiB门槛重复发布核对ok20 changed0 failed0，本批容量例外已结束。
- Python地址选择逻辑已接入；本轮未实际重建后端或运行official-proxy完整构建，不能声明这两项已通过。应用身份/独立迁移/运行声明和业务验收仍待完成。
- 本单元未启动业务服务或切换应用入口；前端只修改构建配方、Node版本文件和说明，未修改业务逻辑；运行平台维持原已验版本。未来源码更新必须先更新审核后的源码锁。

## 2026-10-03 前端构建与离线边界

前端源码仍由各子仓mybuild/Dockerfile维护，新体系覆盖NODE_IMAGE和NODE_RUNTIME_IMAGE为同属Debian/glibc的固定基镜像。源码开启Corepack签名校验；pnpm版本和锁文件不变。当前先完成实际构建，不能提前声称前端部署通过。

所有者要求不push，父仓暂不提交指向未推送子提交的gitlink；子仓改动保存在各自platform-kind-v1本地分支，sources.yaml明确固定父仓基线、原gitlink和覆盖提交。父仓git status因此显示两个子模块位置变化，这是本单元已知修改，不能误当成别人的脏文件清除。交付时要同时带这两个子仓提交，不能只传k8s仓。

所有者最新决定：日常使用国内在线源；确认依赖下载网络失败后，本次自动切换官方源，探测配置的代理，可用则只重试一次，不可用则非零退出。不等待对话输入。应用镜像通过在线构建发布到Harbor，集群按固定摘要拉取；不要求npm/Python离线包，也不把应用镜像tar作为部署前提。建群/Harbor启动物料保留既定离线路径。

日常只修改 `config.yaml` 的 `application_download_mode`，下载端点的配套定义在同目录 `download-modes.json`：

| 模式 | npm / Corepack / pnpm | Python工具与业务依赖 | 网络 |
| --- | --- | --- | --- |
| `domestic`（默认） | npmmirror | 清华源 | 清空构建代理，直接连接 |
| `official-proxy` | registry.npmjs.org | pypi.org / files.pythonhosted.org | 必须设置已开启的 `HTTPS_PROXY` |

Harbor在两种模式下都通过NO_PROXY直连。旧的独立网络、npm源和Python源字段被拒绝，避免只切一半。代理地址从执行环境取得，不写入仓库或镜像配置。官方模式的HTTP/HTTPS请求统一使用执行环境的HTTPS_PROXY。

非交互流程由 `build.yaml` 编排，两次尝试共用同目录 `build-attempt.yaml`，没有第二套构建器：

1. 默认国内源直连。编译、证书、身份、签名、哈希及其他非下载网络错误直接非零退出。
2. 只有依赖安装步骤发生下载网络错误时，本次切换为official-proxy；重新检查剩余容量，继续遵守本批预算。
3. 必须提供有效的HTTPS_PROXY，并通过所选官方源的HTTPS探测（连接超时5秒、总计15秒）；仅存在环境变量不算代理可用。探测不关闭TLS。
4. 探测通过后，用官方npm/Python配套来源只重试一次，每次Docker构建上限1200秒。失败或代理不可用均非零退出，不循环、不等待交互、不启动Windows代理。
5. `config.yaml`不改写，下次调用仍从配置的默认模式开始。开启/修复代理后，直接重跑原make命令，无需分别改npm和Python源。CI/CD须事先配置可用的HTTPS_PROXY，不能期待脚本弹窗等待。

也可显式配置official-proxy直接使用官方源；这种模式同样先探测代理，失败不再次自动重试。Harbor在所有分支均直连。分别保存 `*-build-domestic.log`、`*-build-official-proxy.log`，避免第二次尝试覆盖第一次失败原因。构建回执记录请求模式和实际使用模式。

Python不仅切pip安装工具的源：`select-python-source.py`在导出的临时Git构建上下文中同步选择pyproject/uv.lock中的索引和文件地址。只允许两组已知URL互换，保留版本、依赖图、文件路径、SHA256、大小与其他元数据；比较解析后的完整内容，非预期源拒绝处理。源码仓锁文件不改、不重新解依赖；投影前后摘要和工具摘要进入构建回执。两源缺少相同文件时明确失败，不放宽哈希。前端继续使用已有pnpm冻结锁与完整性校验。

证书、身份、签名与完整性错误单独提示；普通编译错误不当成网络问题。Web此前已成功的构建使用官方源/代理，不能当成国内模式通过的证据；Admin在关闭代理后已实际完整通过国内模式构建及发布。上述真实Admin构建先于最终自动回退编排；新增自动切换、代理探测及重试失败分支尚未做实际故障演练，不能声明它们均实测通过。

### 国内模式仍失败时先查DNS

清空HTTP(S)_PROXY仅控制进程是否使用显式代理，不能恢复Windows代理软件已接管的DNS。本次实际遇到：开启代理时registry.npmmirror.com返回198.18.0.72，国内直连连接超时；所有者关闭代理后返回真实公网地址，同一pnpm元数据请求HTTP200，清华Python源也HTTP200且TLS校验通过。因此不要仅凭下载超时就认定国内源不可用，也不要遇到证书问题就禁用验证。

先查看 `getent ahosts registry.npmmirror.com`，再用 `curl --noproxy '*' --connect-timeout 6 --max-time 15 -o /dev/null -w '%{http_code}\n' https://registry.npmmirror.com/pnpm/10.24.0` 核对直连。若出现198.18/15等代理Fake-IP，先核对Windows代理/DNS状态；不把CDN当前IP写死到hosts，不由部署脚本自动改Windows网络。返回200只证明该次元数据可达，完整依赖构建结果另记。

应用归档仅在 `.build/applications/transfer` 中暂存，用于skopeo传输；确认Harbor摘要后删除。发布失败保留待重试，远端已有同摘要时无需本地tar。源码/镜像摘要与回执仍保留；之后应用部署声明引用Harbor，不引用此临时目录。
