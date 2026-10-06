# 组件阶段图与集群阶段声明

每个可部署对象（OBJECT）就是`gitops/components/`下含`stage.yaml`的目录；依赖图只来自这些文件，没有第二份集中映射。`gitops/clusters/kind/stages.yaml`由图渲染，Flux按它创建Kustomization阶段。

## stage.yaml 写法

```yaml
defaults: {enabled: '{{ services_enabled and services_postgresql_enabled }}'}   # 可选，作用于本文件全部阶段
stages:
  - name: postgresql            # 阶段名，全局唯一，也是Flux Kustomization名
    path: .                     # 相对本目录；默认 .
    dependsOn: [platform-foundations]
    images: [postgresql]        # 本阶段需要的平台物料ID；应用成品镜像不在此列
    # wait: true  timeout: 15m  healthChecks: [...]  按需覆盖
```

`enabled`与`dependsOn`可以是Jinja表达式，由Ansible按当前`config.yaml`求值；禁用的阶段不渲染，依赖了禁用阶段的选择会被拒绝。跨对象依赖写阶段名即可，不写路径。

## 文件职责

| 文件 | 责任 |
|---|---|
| [stages.py](stages.py) | `graph`扫描`stage.yaml`生成`.build/components/stages.yaml`（`component_stages`、`stage_paths`）；`select`按OBJECT求选择与依赖闭包 |
| [topology.yaml](topology.yaml) | 用图渲染`clusters/kind/stages.yaml.j2`；`render`只出候选，`stage`写回源树并拒绝改动未选阶段，`validate`要求已提交文件等于当前图 |

入口：`make -C infrastructure topology-render|topology-stage|topology-validate OBJECT=...`。`platform-stage`会在组件暂存后调用`topology-stage`；`services-validate-release`（`application-validate-release`已转接过来）会调用`topology-validate`。所有改动仍要提交、`flux-release`并显式晋级后才会被集群执行。

## 增减阶段

新增组件：建目录、写`config.yaml`/模板/`stage.yaml`，运行`platform-stage OBJECT=<路径>`生成声明并审阅提交。删除阶段：先按组件说明处理数据与运行对象，再删`stage.yaml`条目并重新stage；阶段`prune:false`，Flux不会自动下线对象。

## 后续

本目录已吸收应用候选渲染：四应用 `prepare.yaml` 由通用 `render.yaml` 调用；`applications/deploy.yaml` 仍负责 plan/check。检查实现尚未按组件拆出。
