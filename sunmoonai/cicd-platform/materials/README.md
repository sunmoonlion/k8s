# 本次物料与 Harbor 保留入口

本目录属于 2026-09-26 的明确批次，不是可直接套用任意生产环境的总控部署脚本。先读 [物料手册](../../kind-infrastructure/docs/物料提交备齐方案和方法.md) 和 [Harbor 方案](../../kind-infrastructure/docs/harbor-preservation-plan.md)，复核路径、集群、版本和授权。

## 模板构建物料（T0–T4 已通过，2026-09-27）

`profile.json` 固定当前模板父仓/三个子仓提交、Linux amd64 基镜像摘要及 Node/pnpm/uv 版本。这些入口固定本批次；换源码、平台或版本应另建 profile/批次并评审适配，不能覆盖旧批次。

宿主依赖：Python 3.12、PyYAML（本次 6.0.1）、Git、Docker、curl、rsync、SSH；工具应提前准备。基镜像必须已按 profile 的精确引用存在于 Docker；从归档恢复时先按 `preparation.json` 校验，再 `docker load` 并核对 image ID/平台/引用，不能离线阶段临时拉取。

### 1. 初次准备源码、基镜像和工具

在本目录执行，下列前三步读本地仓库/镜像，`tools` 会访问公网。已验收批次无需重复 `snapshot`；它要求原工作树仍为批准的干净提交，源码推进后应使用已有 bundle 恢复。

```sh
python3 materials.py plan
python3 materials.py snapshot
python3 materials.py bases
python3 materials.py tools
python3 package_materials.py inputs
python3 package_materials.py plan
```

独立根为 `~/packages-to-be-installed/releases/build-template-20260926-linux-amd64`。`inputs` 从已校验 bundle 在新目录恢复依赖清单，并用精确 Python 基镜像的无网络容器读取 wheel 平台标签；已有输入不匹配时拒绝覆盖。`plan` 生成仅含公开包名、URL、原锁文件摘要的 `packages/public-package-manifest.json`，私有计划单独记录原始锁文件和公开清单 SHA256。

本次清单为 756 个 npm tarball + 58 个 Python wheel，共 814 个文件、276,598,294 字节。npm 排除 133 个非 Linux x64 条目，保留目标 musl/glibc；Python 按精确基镜像选择 wheel。新依赖若涉及 Git、私有源或缺少匹配 wheel，入口会停止要求审阅，不在线编译猜测。

工具下载可以使用已授权公开中转主机，回传后核验官方 pnpm SRI、PyPI wheel SHA256 与 Node 官方校验清单；不得上传私有源码/凭据。来源元数据自身经 TLS 获取；并未声称做了发布签名验证。原始日志与命令保留于批次 `evidence/`，成功文件散列在 `preparation.json`。

### 2. 公开依赖下载与回传

先人工/AI 审阅清单确实只有允许外传的公开包。本次已经取得所有文件，以下为实际流程的复用命令；只有缺项或明确复验时才联网。远程主机的身份、可用空间和授权每次复核，服务器到期后不能继续依赖该地址。

```sh
material_batch=/home/zymun/packages-to-be-installed/releases/build-template-20260926-linux-amd64
public_stage=/home/zym/.cache/sunmoon-artifacts/build-template-packages-20260927
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 txy-tokyo \
  "mkdir -p '$public_stage'"
rsync -a --partial --append-verify \
  -e 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10' \
  "$material_batch/packages/public-package-manifest.json" public_package_fetch.py public_package_resume_probe.py \
  "txy-tokyo:$public_stage/"
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 txy-tokyo \
  "python3 '$public_stage/public_package_fetch.py' '$public_stage/public-package-manifest.json' --root '$public_stage/archives' --minutes 20 --reserve-gib 8"
rsync -a --partial --append-verify \
  -e 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10' \
  "txy-tokyo:$public_stage/archives/" "$material_batch/packages/public-archives/"
python3 package_materials.py verify
```

远程只收到公开清单和独立下载/中断验证脚本；不要 rsync 整个批次。下载器最多并发 3、每 URL 两次、连接 10 秒/单次 90 秒，总预算默认 20 分钟，保留 8 GiB 磁盘余量。文件先写 `.partial`，与原锁摘要一致才接纳。完整文件重校验后复用；**HTTP 半文件重新下载，rsync 回传才使用断点续传**。失败保留收据，修复可达性后原命令重试；摘要变化必须调查，不能更新预期值掩盖。

本地 `verify` 按下载前已保存的清单 SHA 和原源码锁摘要逐件验证，不信任远程随文件返回的新摘要。单纯取得 receipt 不代表本地验收完成。

### 3. 无网络恢复、构建和负例

```sh
python3 package_materials.py hydrate
python3 package_materials.py trial
python3 package_materials.py negative
```

- `hydrate` 只在新临时副本里增加 `file:/archives/` tarball 地址，保留依赖图和原 integrity，用离线 pnpm fetch 构造专用 store。**应用安装/构建使用 bundle 中未修改的原锁文件**，构建前后复核锁摘要。该 store 是可重建派生物，原包归档才是恢复输入。
- `trial` 从 bundle 再恢复干净源码，每次创建新目录、包缓存副本和无网络容器，不借用工作树的 `node_modules`、`.venv` 或构建结果缓存。容器为宿主 UID、`--network=none --pull=never`、drop ALL capabilities、8 GiB 内存上限。
- 前端：pnpm 冻结离线安装、Next 生产构建、`prepare:standalone`；后端：uv 锁定导出、`--require-hashes --no-index --offline` 安装、冻结 sync、ruff/format、pyright、compileall。后端 pyright wheel 已带 JS，提供已校验 Node；`PYRIGHT_PYTHON_IGNORE_WARNINGS=1` 仅关闭上游版本提示，不忽略类型检查诊断。
- 沿用源码的安装脚本允许列表和现有构建的 Playwright 跳过浏览器下载设置；未改源码策略。浏览器资产与业务 E2E 另做，不能据此宣称它们的物料齐全。
- `negative` 只改新 wheelhouse 副本：移走 FastAPI wheel 必须明确缺包失败；改 ZIP comment 保持 wheel 结构有效但哈希错误，必须报 Hash mismatch；恢复原包后安装通过。最后复核全部 814 份原包未变。

已批准中断试验的复用入口（会在独立子目录重新下载一个公开大包，只中止自身进程组）：

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 txy-tokyo \
  "python3 '$public_stage/public_package_resume_probe.py' --batch '$public_stage'"
```

原始输出分别在批次 `evidence/`、`work/offline-trial-*/result.json`、`work/offline-negative-*/result.json`；`offline-*-latest.json` 仅是最近一次指针，失败不会删除历史。中断证明已回传到 `evidence/public-download-interruption.json`。

### 4. 结果、故障与边界

模板 Web 前端应用产物、模板后端依赖安装与静态构建检查、缺包/哈希损坏/补齐和下载中断恢复均已通过。完整记录见 [物料试验结果](../../scripts/results/luna-materials-offline.20260927.md)。

历史 `materials.py packages` 在线预取在 npm ECONNRESET 后有界失败，日志保留；当前采用上述公开归档路径，不要求先重跑失败命令。首次损坏负例添加尾部垃圾触发 ZIP 格式拒绝，不能用它证明哈希门禁；改为有效 ZIP comment 后才取得明确 Hash mismatch。

**本结果不包含生产 OCI 镜像组装/发布、数据库测试、模板管理前端构建、全项目 12 个组件、CI/CD 或业务部署。**生产 Dockerfile 中历史 Corepack 设置等问题也尚未整改。新集群角色与宿主挂载/Harbor 决策见 [交接说明](../../kind-infrastructure/docs/luna-handoff-and-inbox-targets.md)。

取消本试验时停止已标识的本轮临时容器，保留批次和失败日志；不需要回滚集群。代码可通过普通 revert 回退，不能用清空共享物料目录代替回滚。不要把本机同一磁盘内的物料副本算作独立介质灾备。

## Harbor（独立范围）

| 入口 | 动作 |
| --- | --- |
| `harbor_inventory.py --output <新文件>` | 使用已有 Docker 登录凭据，GET 分页盘点；展开索引子清单/附件，输出不含凭据 |
| `harbor_prepare.py --output <新目录>` | 只读导出相关资源、必要 Secret、chart、节点启动镜像；输出必须留在私有目录 |
| `harbor_cold_backup.py --output <获准批次新目录>` | **会停止旧 Harbor**；必须事先确认停服窗口；固定本机目标，不支持任意传入集群 |
| `harbor_cold_backup.py --resume-services <已有备份目录>` | 根据持久化状态恢复精确控制器副本与原只读值；不覆盖源数据 |
| `harbor_verify_backup.py <备份目录>` | 核对归档散列和内部 registry blob/manifest 依赖；不等于隔离恢复通过 |
| `harbor_restore_plan.py --output <新目录>` | 从备份生成独立 namespace/存储/镜像摘要/TLS/网络策略清单，全部控制器为 0 副本；不连接集群或实施恢复 |
| `harbor_restore.py prepare` | 仅执行已批准的 20260926 清单；复核摘要、独立路径与服务端准入，导入启动镜像、解包六卷，再应用 0 副本资源；已有运行目录时拒绝重复准备 |
| `harbor_restore.py start` / `stop` | 显式新 kubeconfig 与 namespace UID 校验，按依赖启动只读副本或停到 0；不启动 jobservice，不删除卷 |
| `harbor_restore_verify.py` | 已启动副本的完整目录/TLS/实际跨节点拉取/网络拒绝/registry 重启检查；结束时删除精确临时 Pod、停副本、撤销新 worker2 的临时配置并复核旧 Harbor |

冷备份的失败/中断恢复命令也写入备份目录 `RECOVER-SERVICES.txt`。冷备份入口使用文件锁防止并发执行。不会强制删除 Pod，不清理数据，不改变 Harbor 版本。

隔离恢复使用独立 `restore-run-20260926/restore.lock`，不与冷备份并行运行。私有运行目录保存阶段、命令日志、完整目录、节点原文件/散列与 `trust.json`；校验失败会保留历次 `acceptance-previous-*.json`。脚本是本批次执行记录，不能修改几个常量就用于其他集群。已经恢复成功后，不应再次执行 `prepare` 或伪造“无缓存”拉取条件。

若进程被强制终止或主机断电，先核对 namespace UID、节点及运行记录，再恢复：删除仅本轮的 `restore-pull-proof` Pod，执行 `harbor_restore.py stop`；在本目录运行 `python3 -c 'from harbor_restore_verify import restore_trust; restore_trust()'` 恢复节点配置。临时 port-forward 的 PID/命令保存在 `port-forward-process.json`，必须确认实际进程仍与记录一致才停止。不要删除恢复数据，不要重新覆盖备份。节点回滚检查当前文件等于本轮写入摘要；遇到其他修改会拒绝覆盖并留下现场。

`harbor_prepare.py` 导出的是命名空间内恢复输入；实际 TLS 入口可能在别处。本次已另外保存 Traefik 默认 TLSStore、`ingress-platform-dev/traefik-tls-secret` 与客户端 CA，索引在私有批次 `preparation/tls-addendum.json`。将来重新执行时必须重新定位并纳入这类跨命名空间依赖，不能认为仅执行准备脚本就覆盖完整入口。

脚本依赖 Python 3.12、kubectl、helm、Docker/节点 ctr、节点 tar；具体运行证据和未完成项写入检查点和方案。私有备份不能提交 Git、推送公开物料中转服务器，或把 Secret 内容复制到终端日志。

本次隔离恢复见 [具体方案](../../kind-infrastructure/docs/harbor-isolated-restore-plan.md)。动态 Trivy PVC/PV 元数据已补读至 `preparation/private/storage-addendum.json`（数据本来已归档）；准备脚本现沿 Pod PVC 引用补全存储，避免依赖不一致的 instance 标签。恢复生成器使用补充清单及散列；这个一次性兼容输入不能当成任意备份批次的通用自动发现逻辑。
