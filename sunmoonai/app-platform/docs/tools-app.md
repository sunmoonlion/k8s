# Tools App 架构

> **当前状态（2026-08-09）**：旧四组件 `tools-app` 源码与运行拓扑已经退役。本文只保留未来
> Tools 领域的边界设计，不描述当前已部署系统。后续必须从 Architecture v2 `tpl-app` 重新
> 实例化为两个 Next.js 前端、一个统一 FastAPI Backend，以及同一 Backend 镜像的
> API/Worker/Scheduler/Migration 运行角色；禁止恢复旧 Admin/Web 双 Backend 和独立 Worker
> 源码副本。

## 1. 系统定位

`tools-app` 提供跨领域、无明确业务所有者、可独立复用的工具能力。

它是工具运行与治理平台，不是放置暂时找不到归属功能的公共目录。带有明确资讯、投资或身份业务语义的能力应留在对应 App。

## 2. 准入规则

能力进入 `tools-app` 必须同时满足：

1. 至少可被两个领域复用，或具有明确的通用性。
2. 输入输出不依赖某个领域内部数据库。
3. 工具不拥有调用方业务主数据。
4. 可以通过稳定、受控的契约调用。

适合：

- 文档格式转换。
- OCR 和图片处理。
- 压缩、解压、哈希和格式识别。
- 通用网页截图和受控内容提取。

不适合：

- 资讯去重和资讯分类。
- 投资估值、风险计算和策略规则。
- 用户授权判断。
- Prompt 和知识库管理。

## 3. 核心模型

```text
ToolDefinition
ToolVersion
ToolCapability
ToolJob
InputArtifactReference
OutputArtifact
ExecutionPolicy
UsageRecord
```

工具版本必须可追踪。处理结果需要记录工具版本、参数、输入哈希、输出哈希、耗时和错误。

## 4. 文件所有权

- 调用方始终拥有输入业务文件。
- 小文件可以通过请求上传，但只在受控临时目录保存。
- 大文件优先通过短期授权对象地址传递。
- 输出产物由调用方接收并写入自己的对象存储。
- Tools App 的临时产物按生命周期自动清理。
- 只有工具运行记录属于 Tools App 主数据。

例如 Info App 调用文档转换器时，转换后的 Markdown 是否成为资讯版本，由 Info App 决定。

## 5. 执行模式

### 同步模式

适用于时间短、文件小且结果能够在请求超时内产生的工具。

### 异步模式

适用于大文件、OCR、批处理和资源密集型任务：

```text
Caller
  -> create ToolJob
  -> Queue
  -> Worker
  -> result reference / callback event
```

任务需要支持：

- 幂等键。
- 超时、取消和重试。
- 优先级和配额。
- 死信和人工重跑。
- 输入输出大小限制。

## 6. 对外能力

建议 API：

```text
GET  /api/v1/tools
POST /api/v1/tool-jobs
GET  /api/v1/tool-jobs/{job_id}
POST /api/v1/tool-jobs/{job_id}/cancel
```

建议事件：

```text
tools.job.completed.v1
tools.job.failed.v1
tools.job.cancelled.v1
```

调用方不依赖 LibreOffice 等具体引擎名称，只依赖能力，例如 `document.convert.pdf`。

## 7. 安全与资源隔离

工具会处理不可信文件，必须：

- 限制文件类型、大小、页数和压缩展开量。
- 使用非 root、最小权限和隔离临时目录。
- 设置 CPU、内存、磁盘和执行时间上限。
- 禁止宏、脚本和非必要网络访问。
- 对高风险格式执行恶意文件扫描。
- 日志中不输出文件正文和敏感参数。

不同资源等级的工具可以使用独立 Worker 池。

## 8. 下一次实例化的目标组件

目标源码拓扑：

```text
tools-app
├── tools-admin-frontend
├── tools-web-frontend
└── tools-backend
```

文档转换器与 ONLYOFFICE BFF 的保留代码当前位于 Knowledge App 的 `components/`，不属于
已部署 Tools Runtime。未来是否迁入新 Tools App 必须另行完成契约、数据所有权和安全评审。

目标逻辑模块：

```text
tool-catalog
tool-job-service
worker-pools
artifact-transfer
usage-governance
administration
```

## 9. 分阶段建设

### 第一阶段

- 将 Document Converter 纳入统一工具契约。
- 建立 ToolJob、任务状态和临时文件清理。
- 支持 Info App 通过对象引用调用转换。

### 第二阶段

- 增加 OCR、格式识别和图片处理。
- 建立配额、并发控制和独立 Worker 池。
- 完善恶意文件防护和运行指标。

### 第三阶段

- 工具版本发布、质量评测和能力市场。
- 按租户和业务优先级调度。
- 大规模批处理和成本治理。

## 10. 验收标准

- Tools App 不成为业务文件主档。
- 调用方不依赖具体工具引擎。
- 长任务可以查询、取消、重试和审计。
- 临时文件能够可靠清理。
- 不可信文件受到资源和安全隔离。
