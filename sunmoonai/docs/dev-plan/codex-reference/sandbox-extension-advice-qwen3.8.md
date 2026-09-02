# Sandbox 端口扩展独立建议（investment-backend，qwen3.8 独立版）

> 最后更新：2026-08-17
>
> 性质：设计建议（advice），非 baseline、不构成目标态承诺；转实施走
> `k8s/sunmoonai/docs/sunmoonai-architecture/requests/` 的 REQ 流程。
> 与 kimi 版 `~/sandbox-extension-advice-kimi.md` 平行存在：事实部分我今日独立复核
> 过一遍（行号以我的复核为准），建议部分有三处与 kimi 不同的侧重。

## 1. 现状复核（我今日逐条验证，非转引）

| 项 | 锚点（已验证） | 我的观察 |
| --- | --- | --- |
| Port 定义 | `app/app/domain/agent/sandbox.py`（全文件 41 行）：`SandboxAction`:9、`SandboxRequest`:16、`SandboxResult`:26、`SandboxPort`:39 | 值对象全 pydantic、无 infra 依赖，跨 HTTP 序列化无障碍 |
| 唯一实现 | `app/app/infrastructure/agent/fake_sandbox.py:6` `DeterministicFakeSandbox` | metadata 自带 `adapter: deterministic_fake` 标记——**设计时就预期多适配器并存**，这是好消息 |
| 回归测试 | `tests/test_agent_sandbox_port.py:25,44`：`rm -rf /` 不真执行、artifact_id 确定性断言 | 测试锚的是"端口行为契约"而非实现，换真实实现时测试语义可保留 |
| 工具权限 | `domain/agent/profiles.py:19-41`：`model_key`/`allowed_tools`/`denied_tools`，deny 优先 | 权限裁决与执行机制分离，维持不动 |
| 生产调用方 | **零**。全仓 grep 仅 5 处命中（定义 3 + fake 2） | 休眠能力实锤；首个真实实现即首个消费者 |

结论与 kimi 一致：方向对（port 在 domain、实现在 infra、权限在 profile），
接口瘦（一次性 run），且从未被真实流量验证。

## 2. 两个 kimi 未展开的判断

### 2.1 首个真实实现可以"零 port 改动"落地

现有 `run(request)` 签名足够支撑第一个 Docker 适配器：

- `shell` / `python` → `docker exec` 容器内执行（容器随 run 预建）；
- `file_read` / `file_write` → 容器内文件操作；
- `timeout_seconds`（1-300s 已限幅）→ exec 超时直接映射；
- `SandboxResult.artifact_ids` → 产物先落容器内路径，由实现层搬运后回引用 id。

**先让 port 被真实调用，再谈接口演进。** 这与 kimi"先实现后收敛"同向，但我说得
更硬：第一版 REQ 应明确"不得修改 `domain/agent/sandbox.py` 签名"，把接口变更
留给被真实需求顶出来之后的第二份 REQ——domain 契约变更在你的流程里值得单独
一次评审，不要和首个实现混在一起。

### 2.2 artifact 存储后端是隐性前置依赖

`SandboxResult` 只存引用是纪律（`infrastructure/graph/state.py:77`
`FORBIDDEN_ARTIFACT_KEYS = {body, bytes, content, file_body, raw}` 保证内容体
永不进 state/artifact）。但 DockerSandbox 一旦产出真实文件，引用背后必须有真实
存储：仓内已有 `investment-backend/storage-access-bootstrap/`（k8s 存储接入
脚手架），**P0 REQ 应把"artifact 落对象存储 + 引用对账"列为验收项**，否则
第一个真实实现会卡在"产物没地方放"。这是 kimi 清单里没有显式列的一块。

## 3. 机制选型：同意 kimi 四级表，补两个工程细节

路线维持 Fake（测试）→ Local（flag 守门、仅本机、禁入生产）→ Docker（首个真实
实现）→ Pod（预留 `runtimeClassName` 一行切 gVisor）。kimi 对 Local 的否决理由
（worker pod 内 DB/Redis 凭据对 LLM 代码可读，syscall 过滤限写不限读）我复核后
完全同意——这是决定性理由，不是偏好。

补充：

1. **kind 环境的 docker 接入**：dev 用 kind 时节点本身是容器，沙箱容器不要走
   dind（嵌套、慢、特权），推荐 worker 以受控方式访问宿主 docker（独立沙箱
   专用 socket 或 TCP + 白名单），且**该通道永不进生产 worker pod**（kimi 的
   §5 最后一条我升级为红线）。
2. **gVisor 验证时机**：不必等生产。kind 的 containerd 装 runsc 后，dev 阶段
   就能跑一遍"同镜像切 RuntimeClass"的演练，把升级路径变成做过的事而不是
   纸上的事——成本半天，收益是消灭一个未知数。

## 4. Port 演进草图（仅供第二份 REQ 讨论，现在不实施）

按 kimi 四类需求，我给一个更具体的形状（签名示意，非承诺）：

```python
class SandboxPort(Protocol):
    async def ensure(self, spec: SandboxSpec) -> SandboxHandle: ...   # 生命周期：一 run 一实例
    async def destroy(self, handle: SandboxHandle) -> None: ...
    async def run(self, handle: SandboxHandle, request: SandboxRequest) -> SandboxResult: ...
    async def exec_stream(self, handle, request) -> AsyncIterator[SandboxChunk]: ...  # 长进程/流式
    async def upload(self, handle, path: str, data: BinaryIO) -> None: ...
    async def download(self, handle, path: str) -> BinaryIO: ...
```

两条不变纪律沿用 kimi：值对象保持可序列化（未来沙箱独立成 HTTP 服务零改动）；
工具权限只在 profile 层裁决。另加一条：**`SandboxHandle` 必须可序列化且带
TTL 语义**——run 崩溃时孤儿容器靠 TTL 兜底回收，不能只依赖 `destroy()` 被
正常调用。取消语义与 `CancelRunCommand`（`domain/agent/commands.py:31`，休眠）
接线同属第二份 REQ。

## 5. Docker 加固清单（kimi 六条全收，我加四条）

kimi 已有：非 root、cap-drop ALL + 默认 seccomp + 禁 privileged、只读 rootfs +
tmpfs /workspace、CPU/内存/pids 限额、容器随 run 销毁、出口白名单经代理收拢、
docker.sock 不挂业务 pod。我追加：

7. **镜像 digest 钉死**：沙箱基础镜像按 `repository@sha256:...` 引用——与你
   release.json 的不可变 digest 发布纪律（baseline §3.2）同一套原则，别让沙箱
   镜像成为唯一的漂移口；
8. **每次 exec 落 DomainEvent**：命令、退出码、预算消耗进事件流——你已有
   `event_sink.py` 底座，沙箱执行的审计与其余 agent 行为同一条溯源链；
9. **沙箱内无凭据**：容器环境变量不放任何服务 token；需要调平台 API 时用
   短时效、单 scope 的委托令牌（你已有 DelegatedUser/service-identity 体系，
   baseline §3.7），沙箱拿到的是"最小委托身份"而不是 worker 的身份；
10. **出口白名单的默认拒绝语义**：不是"列出允许的"，而是默认 deny、逐项放行；
    研究 agent 需要的资讯源清单应该可配置、可审计（与第 8 条联动）。

## 6. 与 kimi 版的差异速览

| 议题 | kimi | 我 |
| --- | --- | --- |
| 首个实现的 port 策略 | 先实现后收敛 | 同向；第一份 REQ 明确**禁改** domain 签名 |
| artifact 存储 | 未显式列 | 列为 P0 隐性前置（storage-access-bootstrap 已有脚手架） |
| 接口草图 | 四类需求描述 | 给出含 Handle/TTL 的签名示意，加孤儿容器兜底 |
| 加固清单 | 六条 | +4：digest 钉死、exec 落事件、沙箱零凭据、默认拒绝出口 |
| gVisor 演练 | 上 k8s 时预留字段 | dev 阶段（kind+runsc）半天演练，提前消灭未知数 |

## 7. 复核命令（今日已跑，全部通过）

```bash
cd ~/master/investment-app/investment-backend/app
grep -rn "SandboxPort\|SandboxRequest" app/          # 应仍只有定义 + fake（5 处）
grep -n "class RunBudget" app/domain/agent/runtime.py # :62
grep -n "CancelRunCommand" app/domain/agent/commands.py # :31
grep -n "FORBIDDEN_ARTIFACT_KEYS" app/infrastructure/graph/state.py # :77
```
