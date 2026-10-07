# 新体系第 5 步：发布、晋级、部署到 sunmoon-kind（本地机；**要所有者在场的 2 小时维护窗口**）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（核对 → 维护前备份 → flux-release → 晋级并提交 → platform-deploy OBJECT=all → 检查 → 本地提交）
仓与提交：k8s 本条待办所在的 fable 头
预计：60–120 分钟；一次现网变更；应用在迁移和滚动期间中断；不碰旧 kind、不碰 Harbor 数据
看什么：发布候选的 revision 等于 HEAD；晋级后 platform-deploy 退出 0；阶段 63 → 70 全 Ready；四应用迁移 Job 成功；platform-check、application-check(-public) 四个应用退出 0
前提：所有者定了窗口并在场；platform-status 退出 0（现网在跑）；Harbor 在；工作区干净
回传：k8s/sunmoonai/scripts/results/release-promote-deploy.<时间>.md
```

## 这一轮是什么

0010 第 5 步：新体系第一次承载 fable 的应用。现网 `sunmoon-kind` 还在跑晋级指针 `e59bdc00` 那一包；这次把重构后的整套声明（多出的 ops 控制台、三个 UI、会合点、供给器 7 个阶段）和四个应用的新镜像、新配置、迁移一起上。路径就是 `docs/发布链.md` 写的：提交 → `flux-release`（把 HEAD 的 `gitops/` 打成 OCI 包推 Harbor）→ 显式晋级（把候选的五个字段写进 `flux-source.yaml` 并提交）→ `platform-deploy OBJECT=all`（核对工作区等于已晋级对象，再 source-apply、等 Ready、做模块检查）。

数据库 schema 不会随 Git 退回而回滚，所以部署前先 `pg_dumpall` 一份。Git tag 由远程在同步后打在晋级提交上（所有者 2026-10-06 定：第 5 步晋级时打 Git tag）。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。退回只按远程的指令做（第七节）。

## 一、核对（只读，10 分钟）

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -5 && git stash list
cat infrastructure/environments/kind/flux-source.yaml
make -C infrastructure platform-status; echo "exit=$?"
make -C infrastructure platform-plan OBJECT=all; echo "exit=$?"
make -C infrastructure platform-check OBJECT=all 2>&1 | tail -n 25; echo "exit=${PIPESTATUS[0]}"
K="kubectl --kubeconfig /home/zymun/.kube/sunmoon-kind.config"   # kubectl 不在 PATH 就用 infrastructure/.tools/bin/kubectl
$K get kustomization -A --no-headers | wc -l; $K get kustomization -A --no-headers | grep -vc " True "
$K get pod -A --no-headers | grep -v "Running\|Completed" | head
```

要看到：工作区干净；`flux-source.yaml` 还是 `e59bdc00` / `e26d2a19`；`platform-status` 退出 0；`platform-plan` 退出 0；`platform-check` 退出 2 且只因为「工作区阶段图比现网多」（这是部署前的已知状态）；63 个 Kustomization 全 Ready；没有非 Running/Completed 的 Pod。有别的异常就停下。

## 二、维护前备份（10 分钟）

```bash
TS=$(date +%Y%m%d-%H%M%S); echo "$TS"
sudo mkdir -p infrastructure/.build/flux && sudo cp -p infrastructure/environments/kind/flux-source.yaml infrastructure/.build/flux/flux-source.before-$TS.yaml
NS=$($K get pod -A --no-headers | awk '$2=="postgresql-0"{print $1}'); echo "NS=$NS"
sudo mkdir -p /mnt/sunmoon-data/backups/postgresql/sunmoon-kind && sudo chmod 700 /mnt/sunmoon-data/backups/postgresql
$K -n "$NS" exec postgresql-0 -- sh -ec 'export PGPASSWORD="$(cat /run/auth/password)"; pg_dumpall -h 127.0.0.1 -U postgres' | gzip | sudo tee /mnt/sunmoon-data/backups/postgresql/sunmoon-kind/pre-step5-$TS.sql.gz >/dev/null
sudo chmod 600 /mnt/sunmoon-data/backups/postgresql/sunmoon-kind/pre-step5-$TS.sql.gz
sudo ls -la /mnt/sunmoon-data/backups/postgresql/sunmoon-kind/ | sed 's/ [0-9]* [A-Z][a-z]* .*//'
sudo zcat /mnt/sunmoon-data/backups/postgresql/sunmoon-kind/pre-step5-$TS.sql.gz | grep -c "^CREATE DATABASE"
sudo du -sh /mnt/sunmoon-data/backups/postgresql/sunmoon-kind/pre-step5-$TS.sql.gz
```

要看到：`CREATE DATABASE` 至少 6 个（casdoor、ragflow、tpl、info、knowledge、investment）；文件不是空的。备份内容不贴进回传，只贴条数和大小。

## 三、发布（5 分钟）

```bash
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml
git rev-parse HEAD
```

要看到：退出 0；候选的 `revision` 等于 HEAD；`repository` 是 `oci://harbor.sunmoonai.com:30443/platform/deployments-kind`；`path` 是 `./clusters/kind`；`requires_sops: true`。候选里没有秘密，可以整份贴。

## 四、晋级并提交（5 分钟）

```bash
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml
git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（0010 第 5 步：fable 的应用第一次上新体系）"
git log --oneline -2; git status --short | head -3
```

要看到：diff 只有 `digest` 和 `revision` 两行变化（`repository`、`path`、`requires_sops` 不变）；提交后工作区干净。

## 五、部署（30–60 分钟，中间不要动）

```bash
TS2=$(date +%Y%m%d-%H%M%S); echo "=== deploy $TS2"
make -C infrastructure platform-deploy OBJECT=all 2>&1 | sudo tee infrastructure/.build/platform-deploy-$TS2.log | grep -E "^TASK|^PLAY|fatal|FAILED|failed=|exit|changed=" ; echo "exit=${PIPESTATUS[0]} $(date +%T)"
make -C infrastructure flux-source-status; echo "exit=$?"
```

要看到：`platform-deploy` 退出 0；每个 PLAY RECAP 都是 `failed=0`；`flux-source-status` 退出 0。

退出不是 0：贴失败的 TASK 名和它前后 40 行（`sudo grep -n -B5 -A35 "fatal:" infrastructure/.build/platform-deploy-$TS2.log | head -120`），再贴第六节前三条命令的输出，然后停下。

## 六、检查（15 分钟）

```bash
$K get kustomization -A --no-headers | wc -l; $K get kustomization -A --no-headers | grep -v " True " | head
$K get pod -A --no-headers | grep -v "Running\|Completed" | head
for a in tpl info knowledge investment; do $K get job -A --no-headers | grep -E "^[a-z-]+ +$a-(database|migration|redis|rabbitmq|identity)-" ; done
make -C infrastructure platform-check OBJECT=all 2>&1 | tail -n 30; echo "exit=${PIPESTATUS[0]}"
for a in tpl info knowledge investment; do echo "=== check $a"; make -C infrastructure application-check APP=$a 2>&1 | tail -n 8; echo "exit=${PIPESTATUS[0]}"; done
for a in tpl info knowledge investment; do echo "=== public $a"; make -C infrastructure application-check-public APP=$a 2>&1 | tail -n 8; echo "exit=${PIPESTATUS[0]}"; done
$K -n app-platform-dev get deploy | grep -E "runner|api|worker|scheduler"
$K -n sandbox-platform-dev get deploy,svc 2>/dev/null; $K -n relay-platform-dev get deploy,svc 2>/dev/null
```

要看到：70 个 Kustomization 全 Ready；没有非 Running/Completed 的 Pod；四个应用的 migration Job `1/1`；`platform-check` 退出 0；八个 application-check 退出 0；`investment-runner` 在；供给器和会合点的 Deployment 在。

## 七、退回（只在远程说退回时做）

```bash
sudo cp infrastructure/.build/flux/flux-source.before-*.yaml infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 退回到 e59bdc00"
make -C infrastructure flux-source-apply; make -C infrastructure flux-source-status
```

退回只换声明包，不卸载这次新增的对象（`prune: false`），不回滚数据库。数据库要不要从第二节的备份恢复，由所有者定，另开一轮。

## 八、回传与本地提交

回传里要有：一到六节每条命令的退出码；第三节候选整份；第四节的 diff；第五节的用时与 RECAP 汇总；第六节的阶段数、Job 状态、八个检查的结论行；结论：通过 / 不通过 / 判断不了。

```bash
git add sunmoonai/scripts/results
git -c core.editor=true commit -m "test(local): 2026-10-06-27-release-promote-deploy.md 结果"
git log --oneline -3
```

晋级提交和结果提交一起由所有者推回，远程在晋级提交上打 Git tag 后推到 GitHub、Gitee。
