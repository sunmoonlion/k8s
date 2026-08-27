# 本目录导航

> 取证时点：2026-08-27
>
> **入口是同目录下的 [`overall-architecture.md`](overall-architecture.md)**，先读它。
> 本文件只是 `repos/` `topics/` `decisions/` 三个子目录的导航：
> 总览回答「去哪看」，子目录回答「锚点在哪、规则是什么」。
>
> 另有两份与架构描述无关、按需读的流程文档：
> [`request-lifecycle.md`](request-lifecycle.md)（提开发请求时读）与
> [`cross-machine-review.md`](cross-machine-review.md)（推送、拉取、跨机审核时读）。

## 按任务找

| 我要… | 读 |
| --- | --- |
| 改某个仓的代码 | [`repos/`](repos/) 下对应文件的「硬规则」+「已知未实现」两节 |
| 加或改跨 App 契约 | [`topics/contracts.md`](topics/contracts.md) |
| 动登录、权限、服务间调用 | [`topics/identity.md`](topics/identity.md) |
| 加表、改迁移 | [`topics/data.md`](topics/data.md) |
| 发版、改部署清单 | [`topics/release.md`](topics/release.md) + [`repos/k8s.md`](repos/k8s.md) |
| 确认某个能力是否真的接线了 | 对应仓文件的**「已知未实现」**一节 |
| 知道「当初为什么这么定」 | [`decisions/`](decisions/)（13 条 ADR） |
| 推送改动、跨机拉取、审核别人的分支 | [`cross-machine-review.md`](cross-machine-review.md) |
| 复核本文档集的某条断言 | [`verify.md`](verify.md) |

## 目录

```
architecture/
├── README.md      本文件
├── verify.md      验证方法、本轮实测结果、易腐值真源、明确的盲区
├── cross-machine-review.md  推送/拉取顺序、跨机审核流程、子模块的坑
├── repos/         一仓一文件
│   ├── tpl-app.md          模板仓：定义标准形态，无领域
│   ├── info-app.md         资讯域：采集→治理→分发
│   ├── knowledge-app.md    知识域：两套契约的唯一 provider
│   ├── investment-app.md   智能体域：状态机 / 检查点 / 事件流
│   └── k8s.md              部署编排：bundle / apply 顺序 / 门禁
├── topics/        跨仓主题
│   ├── contracts.md   契约治理、provider-lock、双端测试
│   ├── identity.md    浏览器身份 vs 服务身份、Casdoor、scope
│   ├── data.md        主档归属、派生系统、迁移纪律、Outbox
│   └── release.md     发布单元、digest 纪律、门禁分层
└── decisions/     13 条 ADR，追加不覆写
```

## 两种修改语义，别混

| 目录 | 语义 | 怎么改 |
| --- | --- | --- |
| `repos/` `topics/` `verify.md` | **现状投影** | **覆盖式重写**：直接替换旧条文，只反映当前有效事实；历史由 git 承担 |
| `decisions/` | **决策历史** | **只追加**：推翻一条决策要写新的一条并在旧的上标注被取代，不删不改 |

## 写作约定

1. **每条断言可落到位置或可执行命令。**给不出取证的句子应删除，不靠推测补全。
2. **易腐值不写进正文**——镜像 digest、schema sha256、commit、迁移 head、副本数
   变化比文档维护快，写进来必然先于文档失效。只写规则并指向真源，值查
   [`verify.md`](verify.md) §4。
3. **主动写「已知未实现」。**投影描述现状，所以「静态占位页」「未接线」是合法且必要的
   事实陈述——这是文档主动暴露缺口的地方，通常也是读者最需要先知道的一节。
4. **每份文件带取证时点**，让「这份投影有多旧」一眼可见。
5. 与代码冲突时**永远以代码为准**，并请指出本文档需要更新。

## 本轮的已知缺口（读之前先知道）

- **未连集群**：所有运行态断言（Pod 状态、NetworkPolicy 实际生效、远程 profile）
  均未验证，见 [`verify.md`](verify.md) §6。
- **前端未逐文件深读**：约 570 个 ts/tsx，核到了结构、入口、契约与关键配置层。
- **各组件目录下的 `CLAUDE.md` 严重过期且会被自动注入**，
  逐条核对见 [`verify.md`](verify.md) §5——读到它们时以本文档集与代码为准。
