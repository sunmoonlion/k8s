# 工程落点与共同约束

> 工程落点由产品合同搬入；共同约束是这一层各模块都要守的。


- 桌面客户端新建，采用 **Electron + Vite + React Router**，是做研究工作的唯一界面；
- 现有网页前端本轮不开发、沿用现状，继续承担官网、下载页与内部管理后台；
- **界面不共享**：网页前端用 Next.js，桌面应用用 Vite + React Router，各按各自技术栈开发。
  两者运行模型不同（SSR 与 hydration／Electron 渲染进程与 preload），强行共享组件会让两边都被对方的约束绑住；
- **接口契约单一真源**：两端调的是同一个后端，接口形状以后端的 OpenAPI / schema 为准，
  两端各自生成客户端，**不手写第二份**——同一事实只能有一个权威写入面；
- 管理后台沿用平台模板的 admin 前端；
- **两个新仓，不合并**：`runtime` 单独成仓**且开源**（合同「让用户能验证」要求可复现构建与公开连接域名，与闭源壳合仓则兑现不了），`desktop-app` 是 Electron 薄壳、随包带 runtime；两者都属**客户端仓**，不参与 k8s 部署、无并列要求（`C-T6`、`C-T7`）；
- **版本配对靠发布清单**：runtime 版、① 协议版、desktop 版三个一起钉（`C-T8`）；
- 后端的执行端口保持中性（领域概念不进签名），新增经 ① 派往 runtime 的适配器；
- 以上工程决定须符合 [`constraints.md`](../../rules/constraints.md)；需要改动其条款时按其修订程序进行。

同层的其他定稿：[`constraints.md`](../../rules/constraints.md) 是代码必须遵守的规则，
[`constraints.md`](../../rules/constraints.md) 的「设计原则」是设计取舍的依据，
[`protocol/`](../../../dev-human/protocol/README.md) 是多方竞争在本平台的做法。

## 共同约束


- 状态机只有一套，场景差异只体现在 Profile 与 workflow（[SDD 规则](../../../dev-human/sdd/finalize.md) P0）；
- 同一事实只有一个权威写入面（P1）；
- 跨进程仍须正确的不变量由持久存储承担，不放在执行进程本地；
- 执行层租用不自建，领域概念不进执行端口的签名。

