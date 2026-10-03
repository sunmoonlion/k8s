# Flux 引导与 OCI 声明发布

本单元沿用已批准架构：Make/Ansible负责引导，Flux负责集群内声明；Harbor保存固定摘要的部署制品。运行目标只有 `sunmoon-kind`，kubeconfig为 `~/.kube/sunmoon-kind.config`，所有命令在本仓 `platform/` 下执行。不会调用旧luna部署链，也不会由Flux接管CNI或外置Harbor。

## 输入与职责

- Flux CLI 2.9.5的离线包记录在 `artifacts/files.lock.json`。四个配套控制器版本/manifest来自 `artifacts/upstream-images.lock.json`。
- 物料按类型存于 `releases/platform-kind-v1`。控制器OCI归档在 `images/`，逐个校验全部blob及描述符引用，再记录归档文件大小/SHA256；部署读取本地包和私有Harbor，不回退公网。
- `flux install --export`使用已校验CLI内嵌的官方清单；Kustomize只覆写摘要、引导所有者和控制器限制。Flux控制器生命周期由Ansible拥有，普通Helm/Kustomize声明由Flux拥有。
- `gitops/clusters/kind`是第一批声明。发布只从已提交Git对象导出，以完整Git SHA命名标签，启用reproducible；候选摘要须提升到受版本控制的 `environments/kind/flux-source.yaml` 后才改变集群源。
- 引导使用只读Harbor身份创建 `flux-system/registry-puller`；源另用 `harbor-ca` 验证私有CA。publisher仅宿主发布时使用，凭据通过私有文件传递，临时副本在退出时删除。
- 根Kustomization当前 `prune:false`、`deletionPolicy:Orphan`。本单元没有批准自动资源删除。SOPS解密密钥备份与加密业务Secret在后续平台单元接入，目前不发布业务秘密。

## 操作

站点保留 `flux_enabled` 开关；关闭时拒绝发布控制器或部署声明，状态查询仍可用。物料和已提升的源指针齐备后，`make flux-bootstrap` 顺序编排工具校验、离线核验、私有发布、控制器部署与根源协调；发布新版本则仍先提交声明并显式提升摘要。

```bash
make flux-plan                   # 只读显示四个控制器的固定来源与目标
make install-flux                # 从已校验本地包安装CLI
make flux-materials              # 显式联网准备缺失物料，可重复执行
make flux-verify-materials       # 离线核验，不下载
make flux-publish                # 按固定摘要发布，拒绝覆盖不同内容
make flux-deploy                 # 安装/核对控制器，不重建集群
make flux-status                # 核实际控制器镜像和Ready
make flux-release               # 已提交的gitops -> Harbor；只生成候选源指针
# 审核 .build/flux/source-candidate.yaml，提升为 environments/kind/flux-source.yaml 并提交。
make flux-source-apply          # 应用已提升摘要，等待实际协调
make flux-source-status         # 核当前generation、Ready、源/协调摘要与发布标记
```

发布与部署分开：日常部署不能重新生成发布版本。整套一键入口尚未完成，以上是其将复用的原生任务，不代表当前已经交付全平台一键部署。

当前根声明只创建平台命名空间和发布标记，用于先验证制品获取与持续协调；数据库、身份、消息、应用仍未部署。成功验收必须包含四控制器Ready、OCI源与根Kustomization在当前generation Ready、观察摘要与锁一致、实际声明存在和受控漂移修复。不能仅凭安装命令退出0宣称完成。

## 清理保护与恢复

宿主Docker镜像保留集合必须包括运行/停止容器引用、锁定部署工具及服务启动检查依赖。`goharbor/prepare`虽然没有常驻容器，却被Harbor存储守卫使用；skopeo是发布/恢复依赖；exporter虽未启用，仍是官方安装包的一部分。2026-10-03发现这三个宿主副本缺失，已从完整离线材料恢复；没有证据将缺失精确归因于某次删除命令。

归档才是可恢复来源：prepare/exporter位于官方Harbor安装包，skopeo有独立OCI归档。不得因“没有容器引用”把它们判作无用依赖。宿主工具从按内容ID导出的OCI归档恢复时可能没有原仓库别名，执行skopeo使用锁定manifest摘要；源仓库名仍保留在物料锁中作来源记录。

控制器故障先看 `flux check`、Pod事件及 `flux logs`；源故障看OCIRepository的Ready原因、CA/只读身份有效期与Harbor健康。回退部署声明时将源指针恢复为此前已验证的不可变摘要，再执行source-apply；首次引导无此前版本，暂停根协调即可保留已部署资源。不要自动卸载Flux CRD或删除命名空间。

## 容量与开机验收

默认50GiB底线保留。2026-10-03所有者批准仅本次Harbor/Flux使用40GiB；临时参数含操作范围和到期时间，不写入site默认值，单元结束移除。容量例外不能等同于实际Windows空间已恢复50GiB。

此次恢复不等于开机验收。旧控制面重启抢占30443、新控制面cgroup启动错误、Harbor/入口未启用开机启动，均已登记到cluster文档与CHECKPOINT。统一生命周期单元必须完成依赖顺序和实际Windows/WSL重启，以及KIND删除重建后的数据/摘要/拉取验收。

官方依据：[离线安装](https://fluxcd.io/flux/installation/configuration/air-gapped/)、[OCIRepository](https://fluxcd.io/flux/components/source/ocirepositories/)、[OCI制品发布](https://fluxcd.io/flux/cmd/flux_push_artifact/)。
