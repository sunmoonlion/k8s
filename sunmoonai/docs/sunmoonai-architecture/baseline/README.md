# baseline：五仓代码投影

> 最后更新：2026-08-15
> 本目录是**现有代码的投影**，唯一用途是让人与智能体在动手改代码前快速了解现状。
> 与代码冲突时永远是本目录错。每条断言都可落到 `file:line` 或可执行命令；
> 各文件的验证时点见 [`verify.md`](verify.md)。

## 我要做什么 → 读哪里

| 我的任务 | 先读 | 再读 |
| --- | --- | --- |
| 第一次接触这个项目 | [`map.md`](map.md) | 对应仓的 `repos/*.md` §1–§3 |
| 改某个仓的业务代码 | 该仓 `repos/*.md` §2 目录地图、§3 硬规则 | §4 分层与流程 |
| 加或改一个跨 App 契约 | [`shared/contracts.md`](shared/contracts.md) | provider 仓与 consumer 仓各自的 §6 |
| 动登录、权限、服务间调用 | [`shared/identity.md`](shared/identity.md) | 该仓 `repos/*.md` §3 |
| 加表、改迁移、动数据库 | [`shared/data.md`](shared/data.md) | 该仓 `repos/*.md` §5 |
| 发一个新版本、改部署清单 | [`shared/release.md`](shared/release.md) | [`repos/k8s.md`](repos/k8s.md) §4–§6 |
| 从模板起一个新 App | [`repos/tpl-app.md`](repos/tpl-app.md) | [`shared/conventions.md`](shared/conventions.md) |
| 本地把某个仓跑起来 | 该仓 `repos/*.md` §7 | — |
| 想知道某个功能到底做完没有 | 该仓 `repos/*.md` **§8 已知未实现** | — |
| 想知道当前镜像 digest / 迁移 head 是什么 | 本目录**不记这些值** | [`verify.md`](verify.md) §2 真源速查 |

## 目录

```text
baseline/
├── README.md      本文件：任务索引
├── map.md         五仓分工、依赖方向、平台构成
├── repos/         一仓一文件，八节固定结构
│   ├── tpl-app.md            info-app.md
│   ├── knowledge-app.md      investment-app.md
│   └── k8s.md
├── shared/        跨仓共同规则，按主题
│   ├── contracts.md   identity.md   data.md
│   ├── release.md     conventions.md
└── verify.md      验证方法、验证时点总表、易腐值真源速查
```

## 每份仓文件的固定八节

1｜这个仓是什么　2｜目录地图　3｜改动前必读的硬规则　4｜分层与关键流程
5｜数据与迁移　6｜契约与对外接口　7｜本地怎么跑与怎么验　8｜已知未实现

§3 只收**真正会导致失败**的规则（有校验、断言、抛错或门禁脚本作证），不罗列最佳实践。
§8 专门列那些**看起来做完了、其实是占位或未接线**的东西——这是本投影主动暴露缺口的地方，
也通常是读者最需要先知道的一节。

## 本目录不写什么

| 不写 | 去哪 |
| --- | --- |
| 将来要做什么、应该怎样 | `../requests/` 各请求的目标态 |
| 为什么这样设计 | `../decisions/`（ADR） |
| 做到第几步了 | 请求文件夹内的进度文件 |
| 镜像 digest、schema sha256、迁移 head、commit | [`verify.md`](verify.md) §2 指出真源，不落值 |
