# V5-REC-001 前端执行偏差恢复证据

日期：2026-07-14  
状态：`ACCEPTED（worktree validation）`

## 目的

恢复前端版本真相，阻止 App 级 backend tag 隐式覆盖 frontend tag，并把“旧 Vue/旧 Next、旧 v4 试点、React 模板资格链、业务迁移”区分为不同状态。此次恢复不迁移三个业务 App，不启用 Knowledge 前端，也不删除 Harbor 镜像。

## 固化矩阵

| App | Admin Frontend | Web Frontend | 解释 |
|---|---:|---:|---|
| Info | `1.0.1` | `1.0.0` | 旧 Vue / 旧 Next 回滚基线 |
| Knowledge | `1.0.0` | `1.0.0` | 清单可生成但前端 Deployment 保持关闭 |
| Research | `1.0.0` | `1.0.1` | Research Web 仅为隔离旧 v4 Agent Console 试点，不是 Next v2 验收 |

六份生成清单均指向 `harbor.sunmoonai.com:30443/app-images` 下的组件级 tag，生成前端清单中没有 `p0-*` 镜像引用。

## 实施变更

- 三套 App 顶层配置增加独立的 `*_ADMIN_FRONTEND_TAG` / `*_WEB_FRONTEND_TAG`。
- Knowledge 顶层部署脚本改为组件级 tag 优先，避免 `KNOWLEDGE_APP_IMAGE_TAG` 覆盖前端。
- 三个 App scaffold 的配置/脚本模板同步该规则。
- `k8s/utils/app-dependency-preflight.sh` 增加前端 `p0-*` fail-closed 门禁；只有显式 `V5_FRONTEND_TEST_MODE=true` 才允许隔离测试。
- Info Admin 旧 Vue `1.0.1` 默认值补齐到直接部署脚本和生成配置。
- 执行计划 §1.6 和长期计划 §19.2 固化恢复顺序与经验教训。

本轮变更仍在四个仓库工作树中，尚未提交或推送；因此本证据不是新的可发布 release。提交时必须补充每仓 Git/SHA，不能用当前基础 HEAD 冒充实现 SHA。

## 验证

```text
六份前端清单 kubectl apply --dry-run=client --validate=false => PASS
Info validate-resources --cluster KIND                    => PASS
Knowledge validate-resources --cluster KIND                => PASS
Research validate-resources --cluster KIND                 => PASS
git diff --check（k8s/info-app/knowledge-app/research-app）  => PASS
bash -n（三套入口、三套 scaffold、共享 preflight）         => PASS
```

反向门禁：

```text
INFO_ADMIN_FRONTEND_TAG=p0-test deploy-info-app-all.sh validate-resources --cluster KIND
=> 拒绝：未固化的前端镜像 tag（退出码 1）
```

## 后续纪律

本证据不代表 React Admin 或 Next Web 已迁移。下一步必须回到 `P0-007A2/A2.2`，按 `P0-007A -> P0-007A2 -> P0-007B -> P0-007C` 完成 React Admin 模板资格链；之后再做 P0-008 Next Web 资格链；Gate P0 通过后才按 Info → Knowledge → Research 逐个迁移。每个任务关闭时必须同时记录任务状态、Git/SHA、镜像 tag+digest、Deployment、测试证据和回滚结论；缺一项保持 `IN_PROGRESS`。Harbor 临时 tag 只能在 digest、Deployment 引用和回滚基线三方确认后删除。
