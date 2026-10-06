# 新体系：按 fable 的源码构建四个应用的 12 个镜像，再暂存三个应用的新配置（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s；源码在并列的 ~/worktrees/fable/{tpl,info,knowledge,investment}-app
跑：按编号步骤做（核对源码 → 构建发布 12 个镜像 → tpl 暂存等价 → 三个应用暂存 → 部署计划 → 本地提交）
仓与提交：k8s 本条待办所在的 fable 头；四个应用父仓 fable 头（tpl 6579f30、info 6729dd0、investment 8bb0a42、knowledge 116930f），子仓就是父仓记录的那一个
预计：2 到 3 小时，大头是 12 次在线构建（国内源）；不停服；不碰现网
看什么：第 2 步每次构建退出 0；第 3 步 tpl 的声明除镜像摘要相关的行以外没有别的差异；第 4 步三个应用的候选里 Secret 全是密文；第 5 步计划核到 fable 的迁移 head
前提：Harbor、现网在跑；磁盘按 host/config.yaml 的底线（构建预算后端 4 GiB、前端 6 GiB，脚本自己核）；不 flux-release、不晋级、不 deploy
回传：k8s/sunmoonai/scripts/results/build-fable-apps.<时间>.md（口令、密钥、age 不贴；构建日志只贴失败那一步的尾部）
```

## 这一轮是什么

新体系里跑的还是 master 版的应用。这一轮把 `sources.yaml` 钉到 fable、按新体系的链构建 12 个镜像写进各组件的 `image.lock.yaml`，再把三个应用的新配置（0010 第三节：`domain_env`、`domain_secrets`、`runner`、出入站、迁移版本）暂存成候选。**只到候选和本地提交，不发布、不晋级、不部署。**

共用模板这次加了东西（0010 第二节）。它在远程机上用四个应用的旧变量渲染过，改前改后逐字节相同；第 3 步在真链上再证一次。

## 一、核对源码

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1
for a in tpl info knowledge investment; do echo "== $a $(git -C ~/worktrees/fable/$a-app rev-parse --short HEAD)"; git -C ~/worktrees/fable/$a-app submodule status | cut -c1-60; git -C ~/worktrees/fable/$a-app status --short | head -3; done
grep -nE "revision:" infrastructure/applications/sources.yaml | head -32
make -C infrastructure application-verify-materials; echo "exit=$?"
```

子仓的提交要和 `sources.yaml` 里的一致，工作树要干净；不一致就停下贴出来。

## 二、构建并发布 12 个镜像

一次一个应用，顺序 tpl → info → knowledge → investment；每条记退出码和用时：

```bash
for a in tpl info knowledge investment; do
  echo "=== $a $(date +%T)"; make -C infrastructure platform-build OBJECT=app-platform/$a-app; echo "exit=$? $(date +%T)"
done
git status --short gitops/components/app-platform | head -20
git diff --stat gitops/components/app-platform | tail -3
```

某个应用退出不是 0：贴 `.build/applications/` 里那次构建日志的最后 60 行（去掉口令），**后面的应用继续构建**，但第三节起不做。下载失败按手册会自动切一次官方源 + 代理，再失败就是真失败。

通过的样子：12 个 `image.lock.yaml` 变了（新 digest、`source_revision` 等于 sources.yaml 里的提交）。

## 三、tpl 暂存：证明共用模板的改动对没写新字段的应用没有影响

```bash
make -C infrastructure platform-stage OBJECT=app-platform/tpl-app; echo "exit=$?"
git diff gitops/components/app-platform/tpl-app | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | grep -vE 'image:|digest:|config-sha256|DEPLOYMENT_ID|migrate-|source_revision|deployment_id|recipe|built_at|resolved_at' | head -20
```

最后一条**必须没有输出**：tpl 的声明只能因为镜像换了而变（镜像行、摘要注解、迁移 Job 名、锁文件的字段）。有别的行就贴出来停下。

## 四、三个应用暂存

先确认 investment 要读的两份平台级输入在（供给器现在默认关，它的输入可能还没生成）：

```bash
sudo ls -la /etc/sunmoon/services/sunmoon-kind/ 2>/dev/null | grep -E "relay|sandbox-provisioner|workbench-signing" ; sudo find /etc/sunmoon -maxdepth 3 -name 'relay.yaml' -o -maxdepth 3 -name 'sandbox-provisioner.yaml' 2>/dev/null
```

`sandbox-provisioner.yaml` 不在就先 `make -C infrastructure platform-stage OBJECT=sandbox-platform/provisioner; echo "exit=$?"` 让它的 prepare 生成一次（组件仍然关着，不会进阶段图），再查一遍。还不在就停下贴出来。

然后：

```bash
for a in info knowledge investment; do echo "=== $a"; make -C infrastructure platform-stage OBJECT=app-platform/$a-app; echo "exit=$?"; done
git status --short gitops/components/app-platform | head -40
for f in $(git ls-files -o --exclude-standard gitops/components/app-platform) $(git diff --name-only gitops/components/app-platform | grep sops); do echo "$f: $(grep -c 'ENC\[' $f) 段密文, sops 头=$(grep -c '^sops:' $f)"; done
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^\+.*(kind: Deployment|name: investment-runner|NetworkPolicy|CROSS_APP|WORKBENCH_[A-Z_]+:)' | head -30
sudo ls -la /etc/sunmoon/applications/sunmoon-kind/investment/domain.yaml /mnt/sunmoon-data/backups/applications/sunmoon-kind/investment/domain.yaml /etc/sunmoon/services/sunmoon-kind/workbench-signing.yaml 2>&1 | sed 's/ [0-9]* [A-Z][a-z]* .*//'
```

要看到：三个 `runtime/domain.sops.yaml` 是密文；`investment/domain.yaml` 和它的备份都在（root 0600）；签名密钥对的输入在；仓库里没有任何 PEM 明文。

## 五、部署计划（只读校验，不部署）

```bash
for a in tpl info knowledge investment; do echo "=== $a"; make -C infrastructure application-deployment-plan APP=$a; echo "exit=$?"; done
```

要核到 info `20260929_0013`、knowledge `20260927_0007`、investment `20260929_0012`、tpl `20260911_0003`。退出不是 0 就贴它的输出。

## 六、本地提交

```bash
git add gitops/components/app-platform infrastructure/applications
git -c core.editor=true commit -m "test(local): 待办 23 构建 fable 的 12 个镜像并暂存三个应用的候选"
git log --oneline -1
```

发布（`flux-release`）、晋级、部署都**不做**：远程先看候选的差异，再定维护窗口。

## 七、回传里要有的

1. 每步退出码；12 次构建各自的用时和写进 `image.lock.yaml` 的 digest 前 12 位。
2. 第三节最后那条命令的输出（应为空）。
3. 第四节的密文核对、私有输入存在性、investment 新增声明那几行。
4. 第五节四个计划的结论行。
5. 结论：通过 / 不通过 / 判断不了。
