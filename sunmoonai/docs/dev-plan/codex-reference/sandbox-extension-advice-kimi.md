# Sandbox 机制扩展建议（investment-backend · kimi 版）

> 最后更新：2026-08-17
>
> 性质：设计建议（advice），不是 baseline、不构成目标态承诺；转为实施请走
> `k8s/sunmoonai/docs/sunmoonai-architecture/requests/` 的 REQ 流程。
> 文中锚点深读时间为 2026-08-17，与代码冲突时以代码为准。

## 1. 现状（事实）

| 项 | 锚点 | 说明 |
| --- | --- | --- |
| Port 定义 | `app/app/domain/agent/sandbox.py:9,16,26,39` | `SandboxAction`（shell/python/file_read/file_write）、`SandboxRequest`、`SandboxResult`、`SandboxPort.run()` |
| 唯一实现 | `app/app/infrastructure/agent/fake_sandbox.py:6` | `DeterministicFakeSandbox`，确定性假实现，不执行真实命令 |
| 安全测试 | `app/tests/test_agent_sandbox_port.py` | 含 `rm -rf /` 不真执行的回归测试 |
| 工具权限 | `app/app/domain/agent/profiles.py:20,31,37` | profile 层 `allowed_tools`/`denied_tools` 裁决工具可用性 |
| 生产调用方 | 无 | 复核：`rg -ln "SandboxPort\|SandboxRequest" app/app`，仅命中定义处与 fake 实现 |

结论：方向正确（port 在 domain、实现在 infrastructure、值对象天然可序列化），
但接口是一次性执行抽象，且从未被真实调用方验证过——属休眠能力，第一个真实
实现大概率会重塑它。

## 2. 差距分析（对照 mooc-manus 的 Sandbox 协议）

参考实现：`imooc/imooc-mas/mooc-manus/api/app/domain/external/sandbox.py`（协议）
与 `api/app/infrastructure/external/sandbox/docker_sandbox.py`（Docker 实现）。

| 能力 | 当前 port | mooc-manus | 缺口的后果 |
| --- | --- | --- | --- |
| 生命周期（ensure/destroy/create/get） | 无 | 有 | 无法表达"一个 run 一个沙箱实例" |
| 有状态 shell 会话（读输出/等待/写 stdin/杀进程） | 无（一次性 run） | 有 | 跑不了长进程（dev server、watch），无法交互 |
| 产物跨边界（upload/download BinaryIO） | 无（仅 artifact_ids 引用） | 有 | 容器化后产物取不出来 |
| 浏览器（cdp_url/vnc_url） | 无 | 有 | 研究 agent 抓动态网页/截图做不了（可后置） |
| 流式输出 | 无 | 部分 | 长命令体验差（可后置） |

## 3. 机制选型（按环境，不是单选）

| 实现 | 环境 | 隔离承诺 | 备注 |
| --- | --- | --- | --- |
| `DeterministicFakeSandbox`（已有） | 测试 / CI | 无（也不需要有） | 保持现状 |
| `LocalSandbox`（subprocess） | 仅本机开发 | **无**，feature flag 守门，禁入生产 | 打通链路用；worker pod 内有 DB/Redis 凭据，"CLI 式"系统调用过滤限写不限读，凭据对 LLM 代码可读即泄露 |
| `DockerSandbox`（容器 + docker socket） | docker-compose 开发 / 单机部署 | 命名空间级 | 第一个真实实现，照 §5 加固；参考 mooc-manus 实现改造 |
| `PodSandbox`（k8s API） | 生产（kind 先行验证） | Pod 级，可升 VM 级 | 沙箱 = 独立 Deployment 或 pod-per-run；预留 `runtimeClassName`，将来一行切 gVisor |

## 4. Port 演进建议（先实现、后收敛）

不要现在就扩接口——休眠 port 的每次预设都是猜测。正确顺序：先写
`DockerSandbox`，让它把真实需求顶出来，再回头收敛 port。预计会顶出来的四类：

1. 生命周期：`ensure() / destroy()`（挂在 run 的创建与收尾上）；
2. 会话化执行：`exec` 返回句柄，支持读输出 / 写 stdin / 终止（长进程）；
3. 产物传输：`upload / download`（二进制、按 artifact_id 对账）；
4. 取消语义：与 `CancelRunCommand`（现为休眠能力）对齐。

保持不变的两条纪律：`SandboxRequest`/`SandboxResult` 维持纯值对象（跨 HTTP
边界无痛）；工具权限继续只在 profile 层裁决，不渗进 port。

## 5. Docker 加固清单（第一个真实实现必须带全）

- 非 root 用户运行；`--cap-drop ALL`；默认 seccomp profile；`--privileged` 永假
- 只读 rootfs + tmpfs 挂 `/workspace`
- `--cpus` / `--memory` / `--pids-limit` 限额
- 容器随 run 销毁（或按 session TTL 回收），不复用跨 run
- 网络出口白名单：研究 agent 必须联网，但出口经代理收拢（这条与运行时隔离同等重要）
- 不把 `/var/run/docker.sock` 挂进业务 worker pod（等于宿主机 root）

## 6. 与 k8s / gVisor 的衔接

- 沙箱工作负载与业务组件分离部署：独立 namespace + 独立 Deployment（或 Job-per-run），
  worker 走 HTTP 调用，不共享容器
- YAML 预留 `runtimeClassName` 字段位；威胁模型升级（多租户 / 大规模不可信网页内容）
  时：节点装 runsc → 建 `RuntimeClass: gvisor` → 填上该字段，同镜像零代码改动
- kind 的 containerd 可跑 gVisor，dev 环境即可验证升级路径
- Kata 现阶段不评估：隔离过剩、kind 上运维成本高

## 7. 复核命令

```bash
cd ~/master/investment-app
# 生产调用方应仍为空（或只有新实现）
rg -ln "SandboxPort|SandboxRequest" investment-backend/app/app
# 休眠能力全景
rg -l "RunBudget|CancelRunCommand|AgentMemoryService" investment-backend/app/app
```
