# Flux 与 SOPS 引导

`config.yaml` 保存开关及独立 SOPS 身份/备份路径，与引导实现放在一起；不保存私钥。
`templates/` 是源与根声明模板。`source.yaml` 只发布已提交 Git 内容，并由明确晋级的 OCI 摘要控制实际协调。

环境唯一源指针仍在 `../environments/kind/flux-source.yaml`，SOPS 公钥在同目录 `sops-recipient.txt`。
它们是环境身份，不复制进模块。私钥在工作树之外。

从 `infrastructure/` 使用 `make flux-bootstrap`、`make flux-source-status`。
操作详见 [Flux](../../docs/platform-kind-v1/flux.md) 和 [SOPS](../../docs/platform-kind-v1/secrets-foundations.md)。
