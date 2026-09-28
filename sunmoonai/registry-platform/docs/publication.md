# 显式镜像发布：本地与云主机共用

更新：2026-09-28。入口 `./sunmoon harbor publish --batch <绝对路径 JSON>`，实现 `registry-platform/publish.py`。
此模块在执行命令的主机上读取离线 OCI 归档并向独立 Harbor 发布；云主机使用相同实现和配置结构。
**云端未经实机验证**，SSH 传输/调度仍待接线；本入口不自行选择云节点、连接 SSH 或调用 Kubernetes。

## 当前可用范围与前置

已准备 Ubuntu 官方 Skopeo `1.13.3+ds1-2ubuntu0.24.04.3` 及 78 个依赖包，独立运行目录的版本/参数查询、既有 Traefik OCI manifest 读取已通过。
已形成真实 Traefik 发布批次和只允许该归档的策略；**尚未执行实际推送**。准备方法、摘要和边界见 [发布工具物料](publisher-materials.md)。
正式入口仍是旧 KIND，不能把本页当作 Harbor 已完成接管的证明。

旧推送和通用 KIND 加载入口的逐项状态见 [迁移文档第 9 节](../../kind-infrastructure/docs/harbor-external-integration-plan.md#9-镜像脚本退役与保留清单2026-09-28)。建群自举导入保留；应用构建与 CI 尚未全部接入统一发布器。

支持单一根镜像的 OCI tar（根可为多架构 index），只发布到 `repo@sha256:<64hex>`。
不接受裸 tag、无锁的目录扫描、运行时从公网拉取、从 Docker 日志猜镜像名或推送失败后塞进 KIND 节点。
既有 Docker-save tar 必须在物料准备阶段明确转换/核验并形成 OCI 批次；本次没有转换或删除任何实际物料。
发布后不创建 tag 别名。已有组件 tag 清单仍需与部署 digest 锁对齐；发布别名通过单独晋级流程处理，不能用本模块覆盖 `1.0.0`/`2.0.0`。

## 日常配置与计划

[批次模板](../config/publication.example.json)放在 Git；路径、大小、摘要中的占位值均须用实际核对值替换。
不要把全部零的摘要当作可信锁。默认计划只检查结构、列出设置，不证明文件存在、工具可用或镜像完整。

```bash
./sunmoon harbor publish --batch /absolute/path/publication.json
# 已按迁移准入确认允许写入目标 Harbor 后执行：
./sunmoon harbor publish --batch /absolute/path/publication.json \
  --credentials-file "$HOME/private/registry-platform/publisher.json" --apply
```

`--config` / `REGISTRY_CONFIG_FILE` 选择同一独立仓库配置；`--credentials-file` 指向仅此用途的推送账号。
发布用账号和部署拉取账号分开；没有显式选择时沿用仓库配置中的私有文件路径，权限不足必须失败。

| 批次字段 | 要求 |
| --- | --- |
| `tool.path` / `tool.sha256` | 已准备的 Skopeo 绝对路径及二进制 SHA；不从 PATH 猜工具，不自动安装。具体版本和依赖应在对应物料锁记录 |
| `policy.path` / `policy.sha256` | 经审阅的 containers/image 信任策略及 SHA；不自动创建放行所有来源的策略，也不传 insecure-policy |
| `work_root` | 预先创建的工作目录；工具大文件临时目录也指向它，每次再创建私有子目录 |
| `minimum_free_gib` | 保留空间，至少 2 GiB；另需最大归档展开量的两倍；每件发布前复核 |
| `timeout_seconds` / `retry_times` | 每工具调用 30–7200 秒、最多 0–3 次重试；默认模板 1800 秒/2 次 |
| `images[].archive/archive_sha256/archive_bytes` | 明确归档绝对路径、文件摘要和字节数；拒绝软链、路径穿越和非普通文件 |
| `images[].manifest_digest/destination` | 根镜像 SHA256 和完整目标 `harbor.sunmoonai.com:30443/<project>/<repo>@sha256:...`，两者必须一致 |

批次 JSON 拒绝未知/重复字段、重复目标、空集合。清单和路径属于可信操作输入，来源文件在发布期间应停止修改。
归档可以来自东京中转，但须先回传并核 SHA，再纳入正式物料根；本模块不下载。

## 执行顺序与失败处理

1. 首先核工具/策略 SHA、每份归档 SHA/字节数及 OCI 布局，拒绝危险 tar 条目，不自行解包到源目录。
2. 核工作空间、锁定 CA、域名、Registry v2 响应、私有凭据格式。只读探测不代表账号有写权限。
3. 所有源镜像先用 Skopeo 读取原始 manifest，与清单摘要对比；尚未进入复制阶段。
4. 每件用 `copy --all --preserve-digests`、明确 TLS 校验/CA、私有 authfile、受限重试执行复制。不能维持摘要即失败。
5. 复制结果摘要必须一致，再从独立 Harbor 按同一 digest 回读 manifest。输出每件结果；节点和 CI 拉取验收仍为未完成。

发布进程清掉自己继承的 HTTP(S)/ALL_PROXY，目标是内网仓库；生成本次使用的直接仓库配置、独立签名配置目录，
明确工具临时目录，不修改 Docker/systemd/终端永久代理。没有 shell 拼接口令，也不打印工具原始认证诊断。

发布是**逐件完成**，不是整批事务。失败时已上传的层/已完成的镜像可能保留；不自动删除目标或源文件，
可修复问题后按同一摘要重跑。不会仅因目标 manifest 已存在就跳过整个复制，避免掩盖层不完整。
正常退出/异常抛出时回收本次私有临时目录；进程被强杀/断电可能留下目录，最终清理须精确识别 `.sunmoon-publish-*`。

工具按摘要完成复制及 manifest 回读，仍不能替代 Docker Engine、节点 containerd 和真实 CI 的独立拉取验收。
不记录“已核官方签名”除非实际策略和物料来源证明这一点；仅有 SHA 只能证明与所选批次的字节一致。

## 旧入口的去向

以下三个旧入口及其目录、废弃配置已删除，不再提供兼容转发；日常只使用 `./sunmoon harbor publish --batch <绝对路径 JSON>`：

- `kind-infrastructure/push-to-harbor/push-images-to-harbor.sh`
- `utils/registry-push-management/loadimage.sh`
- `utils/registry-push-management/registry-push-menu.sh`

旧实现已按摘要归档 `legacy/local` / `legacy/cloud`，原实现最前置拒绝执行；云上新路径实机验证前不删。
旧 `.conf` 已删除；日常控制使用 `registry-platform/config/` 下的仓库配置和发布批次 JSON。
RAGFlow 已取消读取旧配置补口令，使用独立仓库配置及私有文件。
旧 `load-images/`、`harbor-image-management/` 和 `utils/HARBOR-KIND-EXTERNAL/` 操作目录也已删除；精确范围见迁移文档第 9 节。
旧工具附带的清理功能移交统一回收方案，不在发布后附带清理镜像、容器、卷或离线物料。

## 工具准入与首次实际验收清单

- 已完成本批 Skopeo/依赖的东京下载、回传和 Ubuntu 签名核验；新机器仍须按物料说明核字节/宿主前置条件。
- 本批已查询实际二进制参数，支持 tmpdir、registries-conf、authfile、all、preserve-digests、digestfile；完整复制路径仍待验证，不删除保护参数绕过。
- 审阅并锁定签名策略、真实 OCI 归档、目标项目及专用账号；为无 tag 的发布摘要配置保留规则，防止 Harbor 策略过早删除待部署镜像。
- 在批准的目标完成单架构/多架构复制、错误摘要/认证/超时的失败行为，以及真实 Docker/节点/CI 拉取核对。
- 云端首次验证还须核主机身份、TLS/域名、NO_PROXY、工作空间和同一代码/物料锁；未验证前保留归档旧代码。

实现依据：[Skopeo copy 参数](https://github.com/containers/skopeo/blob/v1.13.3/docs/skopeo-copy.1.md)、
[全局参数实现](https://github.com/containers/skopeo/blob/v1.13.3/cmd/skopeo/main.go)、
[Registry manifest 写入实现](https://github.com/containers/image/blob/main/docker/docker_image_dest.go)。
这些上游资料说明工具能力；本项目锁定版本的完整推送验收仍须完成。
