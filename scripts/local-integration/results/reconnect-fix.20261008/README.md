# 投资应用断线恢复：本次发布结果

所有者临时授权 Luna 直接修复源代码并验收，再由所有者同步给 Fable；未 push。
完整问题、代码解释与用户网页回执见并列 runtime 仓：
`scripts/results/windows-agent-1b.20261008-1900.md`，本目录只保存发布证据。

## 发布对象

- 后端源码 `ab4da3064dac5f047b4204fa44f573b5f8cf2ab9`，镜像
  `harbor.sunmoonai.com:30443/platform/investment-backend@sha256:d2e6ed5d20a3d9872170832f7efe29abab4a4d13785447b45ce98a648311d9c0`。
- 网页源码 `9c47e303de255a357703a26ec6d818f037c6e9af`，镜像
  `harbor.sunmoonai.com:30443/platform/investment-web-frontend@sha256:f2e2e6a1d9b646b124751694fa5e6e89451527fa10c742b811ca016838f40581`。
- k8s 候选 `dfe30caaf016765e788017dcfd5284d7c4a91f82`，晋级 `1fd485d3`。
- 当前 OCI `sha256:e761175adf35e18eb525de2d977b637e8a80c2257069971fd3ee7918b1537b0e`。

通过原生 `make -C infrastructure` 的 application-build/publish、platform-stage、flux-release、
flux-source-apply 完成。application-check APP=investment 最后 play 为 ok=50、changed=0、failed=0。
后端测试 63 项、前端 192 项通过（2 项原有跳过），细节在 runtime 报告。

## 数据与边界

没有数据库 schema 迁移、没有改业务账号口令。只为 investment_runtime 增加
`investment:workbench:*` 的 publish/subscribe/unsubscribe；原 key 边界不变。
v3 Redis 初始化的真实回环及越界拒绝结果在 [deployed-check.json](deployed-check.json)。
其它三个应用的 Redis 初始化声明逐字节未变。

[runtime-check.json](runtime-check.json) 显示部署前 139 个 Pod 中 134 个 UID 保持，
替换的 5 个均为投资应用运行组件，旧其它服务 Pod 未替换。
新的 9 个 investment Flux 阶段均 Ready，运行镜像与固定摘要一致；没有重建节点、卷或 Harbor。

原专家 Task `5e77067c-983d-4e0d-a88e-e4e77f68fa71` 18:56:12 只恢复一次，
18:57:09 SUCCEEDED，保留旧失败 Attempt；所有者确认操作权与输入框恢复。
原 work 会话随后实际读写通过。没有直接 SQL 更改该任务或绕过项目互斥。

## 回退定位

本地旧源锁曾落后于现网，因此先获取并逐文件比较真实现网 artifact。
[source-diff.json](source-diff.json) 只包含本次 12 个预期文件变化。
[source-before.yaml](source-before.yaml) 是实际旧源：
`sha256:4615fc1ab69c89b9b609bd15ad59f57600f7ff5aaaebc86ad376d7daf6ad4608`，
revision `ee0b19a94c41f22f5860f82f40cc8813fb605e0c`。

需要回退时，按当时维护批准用原 `flux-source-apply` 的 FLUX_SOURCE_FILE 指定此绝对路径。
回退也会恢复旧应用与旧 Redis 初始化行为，新恢复修复将不再生效；本轮未执行回退。

## 约束自检

| 规则 | 本次处理 |
| --- | --- |
| C-D11、C-A3 | Task 在账房原子迁移，探测不另存第二套状态 |
| C-C7/C-C8、C-A9 | Codex 两端保持 0.155.1，只用公开环境探测；supervisor 不调用模型 |
| C-A10/C-A11/C-A12 | 不恢复人类/资源等待，不扩大 Windows 本地权限，不回退云端本地执行 |
| C-R1/C-R2/C-T5 | 源码提交、不可变镜像、固定 OCI 及真实旧源一起记录 |

维护窗口 2026-10-08 18:48:31–20:48:31（北京时间）；10 GiB 底线通过。
运行中聊天/工作断线、UI 和代理停止的最终证据以 runtime 同轮报告为准，不能用本目录 Pod Ready 代替。
