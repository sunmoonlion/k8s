# Flux 与 SOPS 引导

`config.yaml` 保存开关及独立 SOPS 身份/备份路径，与引导实现放在一起；不保存私钥。
`templates/` 是源与根声明模板。`source.yaml` 只发布已提交 Git 内容，并由明确晋级的 OCI 摘要控制实际协调。

环境唯一源指针仍在 `../environments/kind/flux-source.yaml`，SOPS 公钥在同目录 `sops-recipient.txt`。
它们是环境身份，不复制进模块。私钥在工作树之外。

从 `infrastructure/` 使用 `make flux-bootstrap`、`make flux-source-status`。
操作详见 [Flux](../../docs/platform-kind-v1/flux.md) 和 [SOPS](../../docs/platform-kind-v1/secrets-foundations.md)。

## 配置字段与修改条件

配置真源为本目录 `config.yaml`，由现有Make入口明确传给Ansible。下表说明当前支持边界；有字段不等于已有实例可直接修改。

| 字段 | 用途 | 修改条件与限制 |
| --- | --- | --- |
| `flux_enabled` | Flux部署/源应用准入 | 不是停止或卸载控制器的开关。现有调谐不会因仅改文件自动停止。 |
| `sops_enabled` | 密钥引导准入 | 已加密发布requires_sops时不允许借关闭开关绕过解密要求；不删除已有密钥。 |
| `sops_config_dir` | 主解密身份目录 | 守卫限定/etc/sunmoon/flux/<集群名>；age.agekey为秘密，不能放Git或随意重建。 |
| `sops_backup_dir` | 独立数据盘密钥副本 | 守卫限定/mnt/sunmoon-data/backups/flux/<集群名>；与系统盘同物理盘，不是机器外灾备。 |

环境源在../environments/kind/flux-source.yaml：repository、digest、revision、path、requires_sops必须对应同一个已提交/已发布产物；不手填不存在的摘要。SOPS公钥在同目录sops-recipient.txt，私钥不随代码移动。轮换密钥需先保留旧解密能力、重新加密和验证备份，当前没有一键轮换交付。
