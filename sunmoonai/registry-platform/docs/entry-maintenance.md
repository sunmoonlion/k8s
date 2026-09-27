# 本地入口维护步骤与回退边界

本文件是正式切换的实施准备，**还不能执行停旧控制面或接管 30443**。新managed备份独立恢复已通过；最新源端停写同步、正式切换执行器及所有者维护窗口仍未齐备。当前可执行的操作只有下面的只读盘点与备用端口候选验收；云端独立仓库不使用本模块。

## 已核实的路径

| 当前入口 | 实际旧节点端口 | 停旧控制面后的影响 |
| --- | --- | --- |
| `127.0.0.1:43001` | 控制面 6443 | 旧 API 不可用，发布/调度/沙箱控制暂停 |
| `0.0.0.0:30443` | 控制面 30443 → Traefik | 可由宿主 SNI 接管；过渡默认后端为旧 worker |
| `0.0.0.0:80` | 控制面 30080 → Traefik | TLS-only 过渡不承接，维护期不可用 |
| `0.0.0.0:30444–30446` | 控制面同号 NodePort | TLS-only 过渡不承接，维护期不可用 |

旧 Traefik Service 为 `ingress-platform-dev/traefik-sunmoonai`，五个 TCP NodePort 为 30080、30443–30446，`externalTrafficPolicy=Cluster`。实际 Ready 端点 `10.244.1.16` 在 `kind-worker`；控制面不是入口 Pod 所在节点。2026-09-27 的快照是 worker `172.18.0.3`、worker2 `172.18.0.4`，两者经严格 CA/域名校验的 Harbor `/v2/` 均为401、`/api/v2.0/health` 为200/healthy，证书与原公开入口一致。`sunmoonai.com/` 为404，只证明该 TLS/HTTP 路径可达，**不代表业务页面通过验收**。

证据：[完整只读盘点](../../scripts/results/luna-entry-handoff-inspection.20260927.json)。其中包括三节点完整容器 ID、网络 ID、挂载、原端口和集群 UID。IP 是快照，WSL 重启后必须复核，不能只因名字相同就继续用；`kind-worker2` 容器/卷必须保留。

## 已实现并实测的过渡候选

与最终新集群入口有两个阶段：

```text
阶段一，维护过渡：Harbor SNI → 127.0.0.1:18443；其他 SNI → 旧 worker:30443
阶段二，新集群入口验收后：Harbor SNI → 127.0.0.1:18443；其他 SNI → 127.0.0.1:19443
```

`sni_proxy.py` 的 `transition-candidate` 使用独立回环端口38443，支持 prepare/create/start/check/stop；`transition` 模式只能校验配置和渲染，实际动作仍拒绝。候选固定旧 worker 的名称、容器 ID、Docker 网络 ID 和 IP，prepare/start 前逐项检查，漂移后停止，不自动寻找替代后端。普通 candidate 的28443接口保持兼容。

本轮创建 `sunmoon-sni-transition-candidate-20260927`，复用已锁定NGINX1.30.5镜像，仅挂公开配置，无私钥/数据卷。实际验收结果：[过渡候选](../../scripts/results/luna-sni-transition-candidate.20260927.json)。Harbor 严格 TLS/401/认证realm验证通过；6种 ClientHello 的上游观察符合映射。普通/未知/无SNI观察不等于后端应用认证或大文件/WebSocket验收。未停旧控制面，不能声称停控制面后的路径已验证。

验收结束新代理和新只读 Harbor 均停止，旧 Harbor healthy；运行容器仍只有旧/验证集群的6个节点。Docker卷现场仍46个；代理自身没有新增卷。没有删除任何容器、卷或数据。

从 k8s 仓根执行：

```sh
# 默认仅打印；--check 只读旧 API、容器身份与 TLS。
python3 -B sunmoonai/registry-platform/entry_handoff.py
sudo -n python3 -B sunmoonai/registry-platform/entry_handoff.py --check

# 备用候选仍受同一受管生命周期约束；没有正式 30443 切换动作。
python3 -B sunmoonai/registry-platform/sni_proxy.py render --config sunmoonai/registry-platform/config/sni-local-transition-candidate.json
sudo -n python3 -B sunmoonai/registry-platform/sni_proxy.py check --config sunmoonai/registry-platform/config/sni-local-transition-candidate.json --apply

# 重复验收前必须确认候选和新 Harbor 均停止、Harbor mode=read-only。
sudo -n python3 -B sunmoonai/registry-platform/sni_verify.py --config sunmoonai/registry-platform/config/sni-local-transition-candidate.json --harbor-config sunmoonai/registry-platform/config/harbor-main-local.json --apply
```

## 维护窗口的顺序及停止条件

以下为正式执行器应落实的顺序；该执行器尚未实现，不把下面文字当成已自动化。

1. **停写与新备份恢复先完成。** 旧 Harbor 是现行权威源，冻结推送/删除/GC/复制等写端；形成最新逻辑库、镜像层、身份密钥和全目录清单，新实例逐项对账。候选中已有 canary 项目，不能直接用候选总数去判旧仓库数据完全一致。新 managed 布局独立恢复验收完成前不进入切换。
2. **维护前固定身份与窗口。** 记录旧集群 UID、三节点 ID/挂载、端口、旧入口证书、worker 的 TLS 与真实业务域名响应；暂停 inbox 和沙箱控制。由所有者批准停服范围、开始时间和最长时限。80/30444–30446 若要求维护期间仍可用，必须先实现并验证额外 TCP 转发；当前候选没有此功能。
3. **所有者关闭 WSL、手动压缩、恢复挂载。** 按既有[空间方案](../../kind-infrastructure/docs/wsl-space-reclamation-plan.md)核压缩前后 VHDX Length/C盘free；不启用自动收缩。重启后先核数据 UUID、PID1/Docker视图、旧路径 inode/设备以及节点/卷身份，再恢复必要服务。上述静态 IP 必须重新核实，不能因为快照存在就忽略漂移。
4. **源端停写保持，候选仍只读。** 宿主 Harbor 启动于18443，核五年叶、目录摘要、账号权限和恢复状态。实际镜像推拉另用隔离验收项目及受限账号；此处不把匿名401当成推拉成功。
5. **才可停旧控制面、接过渡30443。** 只停止已登记 ID，保留所有节点/卷；不删除旧控制面，不动旧 worker2。接管后复核新 Harbor 身份和旧 worker 后端，验证实际业务域名。旧 API 此时不可用，不能恢复 inbox。正式切换初期保持新 Harbor 只读，避免回退遗漏新写入。
6. **P3通过后建main。** 三节点六挂载、实际registry信任/拉取、CNI和共享平台入口就绪后，验证19443，再把非Harbor默认后端从旧worker切到19443。原80/30444–30446由main相应映射接回。不得在19443尚不存在时直接使用最终preview配置。
7. **新写入单独启用。** 完成推拉/CI/CD及恢复验收，记录新集群UID和精确工具路径后再更新inbox并启用正常写入。确认一次重建不影响外置Harbor数据。最终清理必须做，仍保护回退观察期内的旧节点/卷。

### 时限与回退

设计窗口原建议60–90分钟，入口接管失败的回退上限30分钟；**还不是所有者已批准的具体窗口**。新集群平台部署如果做不完，不能无限延长旧API停机，应恢复旧入口并继续离线准备。新仓库仍只读且源端写入冻结时，可按固定ID停止新30443监听、启动原控制面，复核原UID/端口/Harbor/业务入口后恢复旧写端和inbox。

新仓库一旦对外接受写入，禁止简单启旧库当回退：先冻结新写端，保全新逻辑库、镜像层及身份变更，经数据对账和反向恢复后再切。新建main若已占80/30444–30446，必须先停止其对应受管监听/节点（保留数据），确认端口空闲才能启动旧控制面。候选阶段没有执行上述动作；正式执行器需要把这些条件做成持久状态与失败恢复路径。

## 当前剩余工作

新版managed备份独立恢复已通过；仅获准提前回收的两处历史registry内容已处理，其余清理最后。正式KIND创建器/CNI代码已接共享renderer，尚未实机执行。旧源最新停写同步、正式入口执行器/自动启动、正式集群与共享平台、真实Docker/CI推拉、重建仓库独立性和最终其余清理仍未完成。不要把本次备用端口路由验收说成完成迁移。
