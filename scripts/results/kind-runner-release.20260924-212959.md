# KIND runner 开发包本地执行回传

时间：2026-09-24T21:41:19.447213+08:00
待办：`docs/dev-investment-agent/switch-test/inbox/2026-09-24-06-kind-runner-release.md`
结论：**fail**。A1 已执行；后端镜像的 Pyright 门禁失败，未生成本次可推送镜像，后续依赖步骤未执行。

## 被测提交

- `k8s`: `1157a763b14e4e65b7249e337c89f0d7d6804634`
- `tpl-app`: `74ff0c54bc0f778feff4de6feaa67d513eb5ba39`
- `investment-app`: `a50e9391003e787cc504400df6c16b7f27150c8c`
- `investment-app/investment-backend`: `5f0a0378572c2b8cf51275b886512e838a06f2ab`
- `investment-app/investment-web-frontend`: `f11cb56cd1ee0fc390435873676bd8edec59242d`
- `investment-app/investment-admin-frontend`: `2e1f5c67d583be02b43eb36d1052f5b4ad177f45`

执行前已核对三个组件工作区干净，HEAD 与父仓 gitlink 一致。k8s、tpl-app、investment-app 执行前也干净。

## 前提检查

- KIND：`kind` 集群存在；`kind-control-plane`、`kind-worker`、`kind-worker2` 均 Ready，Kubernetes v1.27.3。
- 查询节点使用当前会话先前导出的 `/tmp/codex-kind-kubeconfig`；没有覆盖默认 kubeconfig。
- Harbor：`https://harbor.sunmoonai.com:30443/api/v2.0/health` 返回整体及各组件 healthy。
- 本地 Docker 配置存在对应 Harbor auth entry；未打印凭据。由于构建未完成，本轮未能实际验证 push 授权。
- 规则对应：C-R2 要求 digest 固定，故没有用旧 tag/digest 代替本次构建；C-R5 本次目标只为 architecture-v2-dev；C-T3 使用现有后端源码构建，不新增业务源码。

## A1：已执行，两次 rc=1

原始命令（cwd：k8s/sunmoonai/app-platform/scripts）：

```bash
CLUSTER=KIND APPS=investment COMPONENTS="backend web-frontend" SOURCE_ROOT=/home/zymun/worktrees/fable bash build-push-app-images.sh
```

完整原始输出：[kind-runner-release.20260924-212959.A1.txt](kind-runner-release.20260924-212959.A1.txt)。
首次失败：Docker build 的 apt-get 无法连接清华 Debian 镜像源 HTTP 地址，解析地址为 198.18.0.26；apt-get rc=100，构建脚本 rc=1。

网络诊断：宿主机通过已有代理访问该镜像源 HTTP、HTTPS 均返回 200；Docker config 没有 proxies 配置。
重试使用私有临时 Docker config，把当前进程已有的 HTTP/HTTPS 代理传给 Docker build；保留现有 Harbor 身份；临时目录 0700、配置 0600；不输出凭据，退出后自动删除临时目录。
通过比较 Docker daemon ID 确认重试仍使用同一个本机 Docker daemon。全局 Docker 配置和仓库构建脚本均未改。

重试完整输出：[kind-runner-release.20260924-212959.A1-proxy-retry.txt](kind-runner-release.20260924-212959.A1-proxy-retry.txt)。
重试中 Debian 和 Python 依赖下载完成，Ruff lint 通过，153 个文件格式检查通过；Pyright 输出如下：

```text
/app/app/infrastructure/workbench/repository.py:732:18
  Cannot access attribute "rowcount" for class "Result[Any]" (reportAttributeAccessIssue)
/app/scripts/workbench_chain_driver.py:49:54
  Argument of type "ModuleSpec | None" cannot be assigned to parameter "spec" of type "ModuleSpec" (reportArgumentType)
/app/scripts/workbench_chain_driver.py:50:25
  "loader" is not a known attribute of "None" (reportOptionalMemberAccess)
/app/scripts/workbench_chain_driver.py:51:18
  "loader" is not a known attribute of "None" (reportOptionalMemberAccess)
4 errors, 0 warnings, 0 informations
```

本地对应源码为 `investment-app/investment-backend/app/app/infrastructure/workbench/repository.py` 和 `investment-app/investment-backend/app/scripts/workbench_chain_driver.py`。
脚本在 backend 构建阶段停止，未执行 backend push，未进入 web-frontend 构建/push。没有绕过门禁或修改源码。

## 后续步骤逐项状态

| 步骤 | 实际状态 |
| --- | --- |
| A2 两个 digest | 未执行；本轮没有成功构建推送的 digest |
| A3 source lock | 未执行，保持原文件 |
| A4 development-input | 未执行，保持原文件 |
| A5 渲染 | 未执行 |
| A6 diff 与 bundle 更新 | 未执行；没有本轮 20-runtime.yaml/release.json diff |
| A7 门禁 | 未执行 |
| A8 单测 | 未执行，无输出或退出码；没有将旧 bundle 的测试冒充本轮结果 |
| A9 KIND plan | 未执行，无输出或退出码 |
| B 部署 | 未执行，待办要求所有者确定流程后再做 |

静态观察（尚未通过 A8/A9 实测）：当前 deploy-investment-app-all.conf 的 RELEASE_ID 是 `kind-b7-20260919`，而 A5 指定 `kind-wb-20260925`；后续更新待办时应核对配置声明与新 bundle 是否一致。

## 覆盖与副作用

查了：源码提交、组件干净状态、KIND 节点、Harbor 健康、本地凭据配置存在性、真实 Docker build 路径和其检查输出。
没查：push 权限（构建先失败）、新 bundle/门禁/单测/plan、真实部署效果。
Docker 构建产生依赖下载与构建缓存；没有完成镜像推送，没有 apply 或其他集群资源变更。
只新增本次结果文件；没有提交、推送 git，也没有移动 inbox/done。

exit=1
