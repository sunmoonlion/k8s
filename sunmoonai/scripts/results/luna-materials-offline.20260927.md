# 模板物料 T0–T4 实际结果

日期：2026-09-27。实现前提交：`0762d160d635503c236be7ba7a95343ef5469750`；交付以包含本文件的 `k8s/luna` 本地提交为准。机器可读结果及日志散列：[JSON](luna-materials-offline.20260927.json)。

## 范围与结果

本单元完成模板 Web 前端应用产物、模板后端依赖安装/静态构建检查所需的物料闭包与恢复试验。目标 Linux amd64；Node 24.18.0、Python 3.12.13、pnpm 10.24.0、uv 0.11.32。**未组装/发布生产 OCI 镜像，未完成真实 CI/CD 或业务迁移。**

| 条件 | 实际结果 |
| --- | --- |
| T0 固定输入 | profile 固定父仓、三个子仓、两份基镜像和工具版本；公开清单 756 npm + 58 wheel，排除 133 非目标 npm 条目 |
| T1 获取与校验 | 814 份公开依赖共 276,598,294 字节，远程下载/rsync 回传后按本地事先锁定清单及原 pnpm SRI/uv SHA256 全量核验 |
| T2 空目录恢复 | 前后端分别从已校验自包含 Git bundle 恢复到新目录，锁文件 SHA 与冻结输入相同；输入恢复入口另行执行通过 |
| T3 离线安装与构建 | 全部构建容器 `--network=none --pull=never`、新目录/venv；前端冻结安装、Next 生产构建和 standalone 通过；后端冻结安装、ruff/format、pyright、compileall 通过 |
| T4 缺包与损坏 | 临时副本缺 FastAPI wheel 明确失败；有效 ZIP 结构、错误哈希明确失败；恢复原 wheel 后安装成功；814 份正式归档未变 |
| T4 下载中断 | 仅中止自身下载进程组；40,960 字节半文件未被发布；完整小文件重校验后复用，大包重取后原始锁摘要一致 |
| T5 / T6 | 未实施：真实 CI、镜像组装/发布、业务数据库测试和正式 CD |

前端 pnpm store 由校验后的 tarball 离线构造，临时输入仅追加文件地址，保留 dependency graph/integrity；真实构建使用 bundle 中原锁文件。没有修改工作树源码/锁文件。后端 pyright wheel 已带 JS，配合已校验 Node 可离线执行，不需追加 npm 下载。pnpm 安装脚本策略沿用源码；Playwright 浏览器资产与 E2E 不在本轮。

## 固定输入

- 模板父仓：`3317c84d984fdd6dbeb4ab490685f9fcdff569a3`
- 后端：`6674125cd1c14d9700c707b0b0f4b5d422d42f05`
- Web 前端：`45ceed1a147cadb6dfd1b8a72b79ff5a266854bd`
- 管理前端：`ee1f542220386e15c8f97c6e40e317caf3c2e9e7`，只归档，未构建
- 公开依赖清单 SHA256：`decd851f3c4fa5721afa8c89d57325492dcad49be10c6dd379999dae406e55bb`
- pnpm 原锁 SHA256：`fff8c2a0e40453d2fb592301c1413a758d2ddd34bceefe6e0e99d4f49a41ae2d`
- uv 原锁 SHA256：`462ec0b72a6c0324f914a8fcee0c709e8a9ebfe0b87b1c86236c4cc573b5ac76`

基镜像的完整 registry 引用及摘要见 JSON/profile。工具与源码 bundle 的逐件散列在私有批次 `preparation.json`；公开归档逐件 SHA256 在 `packages/public-archives-verified.json`。上游元数据经 TLS 获取，包按原锁摘要校验；未做发布签名验证。

## 可复验命令与证据

工作目录：`sunmoonai/cicd-platform/materials/`。完整前置与下载命令见 [README](../../cicd-platform/materials/README.md)，获准批次可执行：

```sh
python3 package_materials.py inputs
python3 package_materials.py plan
python3 package_materials.py verify
python3 package_materials.py hydrate
python3 package_materials.py trial
python3 package_materials.py negative
```

批次根：`/home/zymun/packages-to-be-installed/releases/build-template-20260926-linux-amd64`。

| 证据 | 根目录内相对路径 |
| --- | --- |
| pnpm 离线 store 构造 | `evidence/20260927T093327476248.log` |
| 前端构建 | `evidence/20260927T093629287594.log` |
| 后端检查 | `evidence/20260927T093652794928.log` |
| 正例结果 | `work/offline-trial-1790472978821158770/result.json` |
| 缺包 / 哈希错误 / 补齐 | `evidence/20260927T094315583186.log` / `20260927T094318988867.log` / `20260927T094322768303.log` |
| 负例结果 | `work/offline-negative-1790473394048549144/result.json` |
| 中断恢复 | `evidence/public-download-interruption.json` |
| 文档输入恢复复验 | `evidence/20260927T094839159255.log`，前六条 git 命令为同批次 09:48:29–09:48:37 日志 |

同名 JSON 记录实际命令、耗时与退出码。前端 standalone `server.js` SHA256：`b50882dafa931be35c45a03e3800eb2ff867964ca84fe5f9f2d459ce25e02ac8`；这是单文件验收指纹，不声称整个产物可复现。

远程仅传公开清单/脚本，未传源码 bundle 或业务凭据。远程受控中断发生于 `~/.cache/sunmoon-artifacts/build-template-packages-20260927/interruption-proof-1790473228038347343/`。HTTP 下载恢复是“复用完整文件、重新下载半文件”；rsync 是另外一层断点回传。

## 失败记录与修正

1. 在线 pnpm fetch 因 `ECONNRESET` 有界失败，保留 `evidence/20260926T225021131846.log`。改为公开依赖清单，经已授权主机下载并按原锁校验；不据此认定家庭链路是唯一根因。
2. uv.lock 部分 wheel 无 size 字段，首轮计划生成停止；将 size 作为可选元数据，选择仍依靠平台标签和原 SHA256。
3. 首次损坏样本追加尾部垃圾，先被 ZIP 结构校验拒绝，不能充当哈希校验通过证据（`20260927T093914120743.log`）。保留该失败，改为 ZIP comment 变更后重新取得明确 `Hash mismatch`。

## 预算、回滚与未完成项

记录时批次全部普通文件逻辑大小 4,318,050,614 字节（含缓存/失败与成功工作目录），低于 30 GiB 上限；本地可用空间约 496.64 GiB。单次前端容器上限 900 秒，后端 600 秒，负例每次 120 秒；远程下载默认总预算 20 分钟、三并发、磁盘保留 8 GiB。结束时无本单元标识的遗留临时容器。

本单元没有修改集群部署；停止/回滚只涉及临时容器与代码，不删除共享物料、源仓或集群。已通过归档继续保留，损坏负例只在 scratch 副本中；本机同磁盘副本不等于灾备。

尚未覆盖全项目、管理前端、系统包扩展、生产 Dockerfile 历史 Corepack 配置修正、OCI 产物、数据库/单元/E2E 测试、内部包/Git 服务或真实 CI/CD。上述范围不可从本结果推导为通过。

新 KIND **不承载正式数据，切换前会重建**。所有者已确定独立数据盘与集群外 Harbor，实施仍待方案审阅；旧 worker2 沙箱卷必须保留。见 [交接](../../kind-infrastructure/docs/luna-handoff-and-inbox-targets.md) 和 [决策方案](../../kind-infrastructure/docs/storage-and-harbor-placement-decision.md)。
