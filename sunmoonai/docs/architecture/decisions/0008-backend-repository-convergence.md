# ADR-0008：以现有 Admin Backend 历史主线收敛规范 Backend 仓库

- 状态：已接受
- 日期：2026-08-01

## 背景

规范 Backend 需要稳定 Git 历史。新建空仓再复制两套代码会丢失 blame、迁移沿革、标签和
安全修复来源；保留两个活跃 Backend 仓又会继续产生双重事实源。

三个实例的主要领域代码位于现有 `*-admin-backend`，Web Backend 主要承载 BFF、会话和
interaction 能力。模板也具有相同形态。

## 决策

- `tpl-admin-backend` 重命名为 `tpl-backend`；
- `info-admin-backend`、`knowledge-admin-backend` 分别重命名为 `info-backend`、
  `knowledge-backend`；历史 `research-admin-backend` 随领域改名收敛为
  `investment-backend`；
- Web Backend 中仍有效的能力通过有审计的能力清单迁入规范 Backend；
- 旧 `*-web-backend` 仓在迁移期间只接受兼容/回滚修复，完成观察窗后归档为只读；
- 仓库重命名必须同步 Gitee、`.gitmodules`、本地 URL、CI、构建脚本、Harbor 仓名、K8s
  生成器、文档和 release manifest；
- 重命名前后必须验证 commit/tree/tag 连续性和 Gitee redirect；
- 不删除旧镜像仓，直到 `2.0.0` 回滚窗结束。

## 门禁

- 重命名前建立不可变源码与镜像基线；
- 父仓不得出现悬空 gitlink；
- 新仓名 clean clone + submodule update 成功；
- Admin/Web 两条配对链和旧拓扑回滚都通过；
- 归档前不存在部署、CI、文档或消费者引用旧仓写入路径。

## 结果

规范 Backend 保留领域历史，Web Backend 历史继续可追溯但不再是长期活跃产品仓。
截至 R7.1，三个活动领域仓分别为 `info-backend`、`knowledge-backend` 和
`investment-backend`；活动 K8s 树中不存在 `research-app` Backend。
