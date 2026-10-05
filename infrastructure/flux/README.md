# Flux发布与协调维护

控制器工具/镜像与部署声明是两类物料。共享源指针唯一在[flux-source.yaml](../environments/kind/flux-source.yaml)，加密recipient在同环境目录，私钥在[秘密维护](secrets.md)说明的私有根。当前实现使用Harbor上的不可变OCI声明，不依赖Flux直接访问远端Git。

## 引导与查看

```sh
make -C infrastructure flux-plan
make -C infrastructure flux-verify-materials
make -C infrastructure flux-bootstrap
make -C infrastructure flux-status
make -C infrastructure flux-source-status
```

bootstrap包括固定工具/镜像、控制器部署、SOPS身份与晋级源协调，有写入；verify-materials校验已有物料。缺物料用`flux-materials`，发布控制器镜像用`flux-publish`。独立秘密/基础入口见[secrets](secrets.md)、[foundations](../../gitops/components/foundations/README.md)。

## 发布与显式晋级

1. 在组件权威config或模板修改，通过所属services/application render与stage生成声明；审阅公开对象和秘密语义，提交源代码。工作树保持干净、秘密仅SOPS密文。
2. 从k8s根目录发布：

```sh
make -C infrastructure flux-release
```

发布器只导出已提交Git对象，递归构建各子Kustomize根，拒绝明文Secret，经独立publisher把声明发到Harbor，写`infrastructure/.build/flux/source-candidate.yaml`。这一步不自动改变活跃source。

3. 对照候选的repository、digest、revision、path、requires_sops与已审提交，显式更新`infrastructure/environments/kind/flux-source.yaml`并本地提交。不要手填未经发布的摘要或把候选revision改成晋级提交的HEAD。
4. 协调并检查：

```sh
make -C infrastructure flux-source-apply
make -C infrastructure flux-source-status
```

apply先server-side diff再apply，使用固定field manager，不日常force冲突；即使spec没差异仍等待当前源/子阶段generation Ready。OCI source Ready不等于依赖Job、Pod或业务全部通过。再执行所属模块的协议检查；应用公共入口另外验收。

## 操作和配置边界
当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `flux_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `sops_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `sops_config_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `sops_backup_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |

`flux_enabled`与`sops_enabled`不是停止/卸载控制器或删除Secret的开关。`requires_sops=true`不可通过关闭开关绕过。Git revision和OCI digest属于同一发布产物；Makefile配置顺序、共享环境责任见[环境README](../environments/kind/README.md)。

## 故障与退回

- Source认证/x509：核Harbor/token CA、puller期限、仓库地址；[仓库](../registry/README.md)修复，不关闭TLS。
- SOPS失败：核recipient与同一age主备身份；[secrets](secrets.md)恢复，不重新生成已有环境私钥。
- 阶段未Ready：从[声明依赖](../../gitops/clusters/kind/README.md)检查Job、schema、Pod与网络，保留失败代次。
- 字段冲突：查看UID/resourceVersion、当前值及managedFields；停止并审具体归属。禁止直接清managedFields或日常force接管。
- 源/候选不一致：render/validate会拒绝；走发布晋级，不能skip校验部署旧值。

维护前保存原flux-source。退回时恢复已验证的固定source并提交，再source-apply/status与协议检查。`prune:false`/`deletionPolicy:Orphan`保留已存在对象，退回不自动卸载新增对象；需要精确退役。数据库schema、初始化身份和持久数据不会随Git退回自动回滚，涉及它们时必须恢复匹配备份并另定维护范围。
