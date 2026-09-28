# 人工导出 Harbor 拉取 Secret

入口：`./sunmoon harbor export-secret`；实现为 [export_pull_secret.py](../export_pull_secret.py)。
它保留人工准备资源的用途，不再从旧集群读取管理员口令，不自动寻找应用配置、namespace 或模板。
实际部署仍用[统一拉取 Secret 入口](pull-secrets.md)，不会自动读取导出文件。

```bash
./sunmoon harbor export-secret \
  --namespace app-platform-dev \
  --credentials-file "$HOME/private/registry-platform/consumer.json" \
  --output "$HOME/private/registry-platform/pull-secret-20260928.yaml"
```

默认只显示计划，不读凭据、不查询集群、不创建文件。确认具体输出后加 `--apply` 才导出；
`--dry-run` 与 `--apply` 冲突时拒绝，继承 dry-run 时也禁止实际写入。
示例私有文件路径需替换为实际已准备的路径；私有文件格式沿用仓库模块 credentials.py，
registry 固定 `harbor.sunmoonai.com:30443`。也可通过 REGISTRY_CREDENTIALS_FILE 指定输入。

输出必须是 `~/private` 下的绝对路径，父目录须事先存在、属于调用用户且权限不允许组或其他人访问（例如 0700）。
逐级以目录句柄打开，拒绝软链接和路径中的 `..`；拒绝 private 目录链中的 Git 工作树。
文件使用 0600，先完整写入临时文件，再原子发布；已有文件、软链接、备份一律不覆盖。
重做时用新的版本化文件名，不提供 force/overwrite 开关。内容是 Kubernetes 可读取的 JSON，可沿用 `.yaml` 后缀。

工具不输出口令或 Secret 内容，不传口令命令参数，不执行 kubectl/SSH/Docker，也不验证账号权限或镜像可拉取。
失败时保留已有文件；如果发布后的目录同步失败，完整输出可能已经存在，重新执行会因文件存在而拒绝覆盖。
生成文件属于 `~/private` 的备份范围，不属于可随重构清理的临时物料。

## 退役的旧路径

- `sunmoonai/app-platform/utils/generate-harbor-registry-secret.sh`
- `document-converter-backend/resources/k8s-resource/custom-values/secret/harbor-registry-secret/generate-harbor-registry-secret/` 下的脚本和配置
- `document-converter-backend/resources/k8s-resource/templates/secret/harbor-registry-secret.yaml`

上述四个 Git 跟踪源文件已删除，不保留转发脚本。旧生成文件、真实私有数据和历史结果记录没有清理，
如需回收仍按最终清理清单判定。历史 JSON 审计记录中的旧路径是当时快照，不表示现在仍可调用。

本次仅完成静态检查，未执行导出、行为测试或真实凭据读取；私有目录权限、文件已存在/软链接拒绝、
特殊字符编码与实际导出内容仍须在后续验收时验证。
