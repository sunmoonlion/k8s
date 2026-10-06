# 新体系：把待办 23 做完——同步锁、构建 knowledge、暂存三个应用、部署计划（本地机；在 24 之前做）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（拉最新 → 同步三个应用的锁 → 构建 knowledge → tpl 暂存等价 → 三个应用暂存 → 部署计划 → 本地提交）
仓与提交：k8s 本条待办所在的 fable 头（含 application-lock-* 与 investment 配置的一处回退）
预计：40 分钟；一次应用构建（knowledge 三个镜像）；不停服
看什么：第 2 步 9 个锁变成 fable 的提交；第 3 步 knowledge 构建退出 0 并多 3 个锁；第 4 步 tpl 的声明除镜像相关行没有别的差异；第 5 步候选里 Secret 全是密文；第 6 步计划核到 fable 的迁移 head
前提：待办 23 的三次构建已把 9 个镜像发到 Harbor（不重建）；不 flux-release、不晋级、不 deploy
回传：k8s/sunmoonai/scripts/results/finish-apps.<时间>.md
```

## 23 查到的两件事和处理

1. 三次构建退出 0 但锁没变：当时的 k8s 还没有 `application-lock-*`（发布成功后把 `.build/` 里的锁拷进 `gitops/`）。这次先同步，不重建。
2. knowledge 选阶段就停：`Disabled dependency: investment-service-identity`。原因是我把 investment → knowledge 的检索身份关了，而 knowledge 的接收端把 ingest、retrieve 两个绑定写死成一对。已把那一项改回 `enabled: true`（撤销另开一轮，迁移账本 21）。

## 一、拉最新、核对

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -5
make -n application-lock-backend APP=tpl >/dev/null && echo "lock target: ok"
grep -n "enabled: true" gitops/components/app-platform/investment-app/investment-backend/config.yaml | head -3
ls -la infrastructure/.build/applications/*-deployment-image.yaml
```

应能看到 9 个 `*-deployment-image.yaml`（tpl、info、investment 各三个）。

## 二、同步 9 个锁

```bash
for a in tpl info investment; do for r in backend web admin; do make -C infrastructure application-lock-$r APP=$a; done; done
git status --short gitops/components/app-platform | grep -c image.lock   # 应是 9
git diff gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml
```

`source_revision` 应等于 `sources.yaml` 里 tpl 的 backend 提交 `834dff5a…`。

## 三、构建 knowledge

```bash
make -C infrastructure platform-build OBJECT=app-platform/knowledge-app; echo "exit=$?"
git status --short gitops/components/app-platform | grep -c image.lock   # 应是 12
```

## 四、tpl 暂存等价（证明共用模板的改动对没写新字段的应用没有影响）

```bash
make -C infrastructure platform-stage OBJECT=app-platform/tpl-app; echo "exit=$?"
git diff gitops/components/app-platform/tpl-app | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | grep -vE 'image:|digest:|config-sha256|DEPLOYMENT_ID|migrate-|source_revision|deployment_id|recipe|built_at|resolved_at' | head -20
```

最后一条**必须没有输出**。有别的行就贴出来停下。

## 五、三个应用暂存

先确认 investment 要读的两份平台级输入在：

```bash
sudo find /etc/sunmoon -maxdepth 3 \( -name 'relay.yaml' -o -name 'sandbox-provisioner.yaml' \) 2>/dev/null
```

`sandbox-provisioner.yaml` 不在就先 `make -C infrastructure platform-stage OBJECT=sandbox-platform/provisioner; echo "exit=$?"`（组件仍关着，只是让它的 prepare 生成输入），再查。还不在就停下贴出来。

```bash
for a in info knowledge investment; do echo "=== $a"; make -C infrastructure platform-stage OBJECT=app-platform/$a-app; echo "exit=$?"; done
git status --short gitops/components/app-platform | head -40
for f in $(git ls-files -o --exclude-standard gitops/components/app-platform) $(git diff --name-only gitops/components/app-platform | grep sops); do echo "$f: $(grep -c 'ENC\[' $f) 段密文, sops 头=$(grep -c '^sops:' $f)"; done
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^\+.*(kind: Deployment|name: investment-runner|NetworkPolicy|CROSS_APP|WORKBENCH_[A-Z_]+:)' | head -30
sudo ls -la /etc/sunmoon/applications/sunmoon-kind/investment/domain.yaml /mnt/sunmoon-data/backups/applications/sunmoon-kind/investment/domain.yaml /etc/sunmoon/services/sunmoon-kind/workbench-signing.yaml 2>&1 | sed 's/ [0-9]* [A-Z][a-z]* .*//'
```

## 六、部署计划（只读）

```bash
for a in tpl info knowledge investment; do echo "=== $a"; make -C infrastructure application-deployment-plan APP=$a; echo "exit=$?"; done
```

要核到 info `20260929_0013`、knowledge `20260927_0007`、investment `20260929_0012`、tpl `20260911_0003`。

## 七、本地提交

```bash
git add gitops/components/app-platform infrastructure/applications
git -c core.editor=true commit -m "test(local): 待办 23b 同步 12 个锁并暂存三个应用的候选"
git log --oneline -1
```

发布、晋级、部署都不做。

## 八、回传里要有的

1. 每步退出码；knowledge 构建用时与三个 digest 前 12 位。
2. 第四节最后那条命令的输出（应为空）。
3. 第五节的密文核对、私有输入存在性、investment 新增声明那几行。
4. 第六节四个计划的结论行。
5. 结论：通过 / 不通过 / 判断不了。
