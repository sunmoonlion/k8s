# Cursor 同机待办：Windows 第 2 段补验、两个候选镜像发布

所有者已明确：Luna 可以修改必要源码，构建/发布交 Cursor；两者同机，直接读本文件。
**不需要先推送或执行 human-local/human-remote。只在 luna 工位完成本条，保持其它工位原状。**
本条完成后写回执，Luna 接着真实联调并向 Fable 报备；不要把它当第 2 段整体通过。

```text
被测仓：k8s（~/worktrees/luna/k8s）；关联同级 runtime、investment-app/investment-backend
跑：一、补原生 symlink 夹具并普通用户全测；二、核源码锁并只构建后端/relay；三、原生 Flux 发布；四、检查与回执
仓与提交：runtime 6461f3f29c63d74dbdf0364a65de5c9ada7cdf7c；investment-backend db96b401944b43fc2541704b165951eaac808e84；relay 源 k8s 4d0ff0433628b8e821ca6239eebd8cf46f0a4fe3；部署配置为包含本待办的 luna 头
预计：60–90 分钟；需要 Docker/KIND/Harbor；原生 symlink 夹具需 Windows 管理员一次；测试本身普通用户
看什么：Windows 全部 150 项通过；两个镜像 source_revision 正确；仅 relay/investment 后端摘要变化；Flux 与对应服务检查通过
前提：Luna 的源码/本条已本地提交，工作区干净；未有其它维护进行；platform-status 正常；使用既定2小时窗口和10 GiB容量底线
回传：k8s/sunmoonai/scripts/results/luna-stage2-cursor.<时间>.md；只本地提交，最后 exit=<码>；不 push、不并 fable
```

## 一、先补 Windows 剩余一项，不跳过

Luna 已跑：Windows build/typecheck 通过，149 pass / 1 fail；唯一失败为
`rejects precreated native symbolic links as an ordinary user`。普通用户创建原生 symlink 返回 EPERM。
Node 为本机 v24.19.0，Codex 固定官方 0.155.1；Smart App Control 只读值为 1，未改变。

独立 Windows 测试副本：

```text
C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-20261008
```

1. 核副本 agent/src、native、test、contracts、package.json、pnpm-lock.yaml 与 runtime 固定源码提交
   内容相同（Luna 已核四个代码目录）；缺失时按该提交复制，仅此测试副本。保留既有日志，
   不从用户的 .codex 复制 auth.json 或 setup 秘密。
2. 管理员 PowerShell **只建本次新夹具**，脚本 SHA-256：
   `c5b9de85a0a2fd30e5f715acb2fe366b112ed0ad26108b9cab56854b0dc96595`。
   管理员操作仅因为 Windows 创建原生符号链接需要权限；不运行产品安装、不编译 exe、
   不启用开发者模式、不改执行策略或 Smart App Control。

```powershell
$ErrorActionPreference = 'Stop'
$Script = 'C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-20261008\scripts\prepare-windows-link-fixture.ps1'
if ((Get-FileHash -LiteralPath $Script -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c5b9de85a0a2fd30e5f715acb2fe366b112ed0ad26108b9cab56854b0dc96595') { throw '夹具脚本摘要不符' }
& $Script -FixtureRoot 'C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-native-links-20261008'
```

脚本拒绝覆盖已有目录。如果这一步已由本条之前一次执行成功，复核两条 LinkType=SymbolicLink、
目标为夹具 outside/secret.txt（正文 outside-control）即可，不重新执行或改其它链接。
不要使用普通用户先前留下的部分夹具 `windows-agent-2-20261008/symlink-fixture` 冒充通过。

3. **回到普通用户 PowerShell** 运行（管理员测试不能证明普通用户边界）：

```powershell
$ErrorActionPreference = 'Stop'
$env:SUNMOON_TEST_ELEVATED_HOME = 'C:\Users\zymun\.codex-probe-exec'
$env:SUNMOON_TEST_SYMLINK_FIXTURE = 'C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-native-links-20261008'
$Node = 'C:\Program Files\nodejs\node.exe'
$Pnpm = 'C:\Users\zymun\sunmoon-probe-runs\windows-agent-1d-20261008\corepack\v1\pnpm\10.24.0\bin\pnpm.cjs'
$Agent = 'C:\Users\zymun\sunmoon-probe-runs\windows-agent-2-20261008\agent'
Set-Location -LiteralPath $Agent
foreach ($Action in @('build','typecheck','test')) {
    & $Node $Pnpm $Action
    if ($LASTEXITCODE -ne 0) { throw "$Action 未通过，停止发布并回传" }
}
```

既有 elevated 测试家必须无 auth.json，只供能力探测；不要复制 .sandbox-secrets。
预期 150/150。**本阶段任何测试失败都停止，不发布**，报告失败输出和步骤交 Luna。
不要使用临时 `run.mjs` 代替以上命令；它会尝试普通用户创建另一处夹具。

## 二、核锁、备份与只构建两个镜像

以下命令全部从 `~/worktrees/luna/k8s` 执行。每条核退出码，失败即止；不要用 tail 管道吞掉退出码。
仓与提交是同机固定对象，禁止自动 fetch/reset 到远端旧 luna。

- `infrastructure/applications/sources.yaml` 的 investment.backend_revision 应为 `db96b401…`。
  其它应用/前端锁保持；parent_revision / backend_parent_revision 是已有构建祖先锚点，本轮未改。
- `infrastructure/applications/component-images.yaml` 的 images.relay.revision 应为 `4d0ff043…`，
  sandbox 与 provisioner 源锁不变。两个新源码都已提交，部署脚本按锁导出上下文。
- 先 `make -C infrastructure platform-status`。保存**当前** flux-source、两个 image.lock、
  当前 imageID/Pod/Flux Ready 到本轮全新目录（例如 infrastructure/.build/luna-stage2-release-<时间>）。
  不使用以前的 source-before.yaml；先核实际集群是 `sunmoon-kind`、kubeconfig 为
  `~/.kube/sunmoon-kind.config`，kubectl 用 `infrastructure/.tools/bin/kubectl`。

```sh
make -C infrastructure platform-build OBJECT=app-platform/investment-app/investment-backend
make -C infrastructure platform-build OBJECT=relay-platform/relay
```

原生入口包含固定摘要发布和锁更新。只重建这两个镜像；不重建网页、admin、sandbox、provisioner，
不改基础镜像、工具版本、账号或数据库 schema，不重建集群，不替换真实用户代理。
下载按既有国内优先/代理规则，签名/TLS/摘要检查不得关闭。

## 三、原生发布与显式晋级

```sh
make -C infrastructure platform-stage OBJECT=app-platform/investment-app
make -C infrastructure platform-stage OBJECT=relay-platform/relay
make -C infrastructure application-deployment-plan APP=investment
```

审阅 diff：只允许这两个镜像锁/source_revision 与所属渲染 workload/注解更新。
后端迁移 Job 名可能随镜像摘要变化，schema head/revision 及 SOPS 内容不得意外变化。
出现其它对象/秘密变化或绕过门禁才能继续时停止回传。
提交这些候选后，按 `infrastructure/flux/README.md` 原有流程：

```sh
make -C infrastructure flux-release
```

核 `infrastructure/.build/flux/source-candidate.yaml` 的 revision 等于刚提交的候选；
核 repository/digest/path/requires_sops，复制整份候选到 `infrastructure/environments/kind/flux-source.yaml`，
本地提交晋级，再执行：

```sh
make -C infrastructure flux-source-apply
make -C infrastructure flux-source-status
make -C infrastructure platform-check OBJECT=relay-platform/relay
make -C infrastructure application-check APP=investment
make -C infrastructure application-check-public APP=investment
```

两个服务可以滚动，relay 重启会短断现有控制连接；新代理尚未启用，所以不要伪称真实权限回执通过。
如果 relay 比后端先就绪，临时扩权仍会等不到回执而保守失败，不会先放行。
失败恢复本轮维护前核对的固定 Flux 源，执行 source-apply/status 和对应检查；保留本轮候选与日志。
本轮无 DB 迁移，已有账本事件不删除。不要对整个环境做 reset、清理卷或换用旧回退锁。

## 四、回传要求

1. Windows 普通用户与应用控制状态、完整150项结果、两种沙箱模式是否通过、夹具路径。
2. 每条构建/发布/检查的退出码；源码提交、镜像 digest/source_revision、实际 Pod imageID。
3. 发布候选及晋级提交、前后 Flux Ready；若失败精确步骤、是否已恢复。
4. 只说已完成的检查；**MCP 真实调用、本机 CLI 审批 → 工作台审计回执、两次旧投影拒绝定位**
   由 Luna 下一步继续，不能在本条直接记 pass。代理不改为无沙箱，也不自动启动真实 Windows 测试代理。
5. 回执本地提交，告诉所有者一句“Cursor 本地回执已写好”。不要 push，不修改 luna-feedback.md。

Luna 报告及证据：`../runtime/scripts/results/windows-agent-2.20261008-2130.md`。
