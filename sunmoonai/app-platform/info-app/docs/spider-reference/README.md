# Info App Spider Reference

本目录保存爬虫项目相关的参考资料，来源于 `~/spider` 下的 ChatGPT 保存页。

这些文档用于帮助设计 `info-app` 的资讯采集、反爬治理、正文抽取、存储、检索、RAG 分发和 MVP 技术组合。它们不是当前部署现状，也不直接定义平台边界；平台边界仍以 `app-platform/docs/info-app.md`、ADR 和实施路线为准。

面向实施的采集与资讯治理架构见：[Info App 采集与资讯治理架构](../info-app-spider-architecture.md)。

## 文档

1. [爬虫项目：金融研究信息收集](./01-金融研究信息收集.md)
2. [爬虫项目：反爬问题解决方案](./02-反爬问题解决方案.md)
3. [爬虫项目：MVP 技术组合](./03-MVP技术组合.md)

## 架构归属

- 资讯源、采集任务、原文、版本、去重、分类、标签、摘要和预警属于 `info-app`。
- 文档转换、OCR、格式识别等通用处理能力可由 `tools-app` 提供。
- RAGFlow 入库、知识检索和问答通过 `knowledge-app` 封装，不由爬虫直接调用 RAGFlow 私有 API。
- 投资分析、研究观点和投资结论属于 `investment-app` 的使用场景。
