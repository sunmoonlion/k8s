# luna 卡 fable-b4：release 全程一次——失败路径、超时路径、真发布 tpl（0033 第八节第 4 步）

> 状态：**可执行**（远程 Fable 2026-10-20 深夜写，设计在 0033 第十节，所有者「按推荐」）。B3 已过。这张卡：① 控制器重启装新引导（`release` 任务现在十二个阶段，人批在执行器外）；② 三次跑：失败路径（改旧迁移头，停在第 2 阶段）、超时路径（2 分钟没人批，中止）、真发布（tpl 两个 ingress 补 `/api/internal`，**所有者在页面上点批**，走完到推送）。第三次会真的动集群（tpl 的两个 ingress）和分支 fable（三个提交加一个 tag）。
>
> **本卡的临时授权（所有者 2026-10-20 夜定，只对平台线的卡，不是长期规矩）**：撞到**这张卡改到的文件**（`ci/*.groovy`、`ci/*.py`、`infrastructure/jenkins/**`、`infrastructure/Makefile` 的 jenkins 段、本卡的命令）里让步骤过不去的错，可以就地改、自己验、接着跑，代码改动直接提交推 `origin/fable`。**不能自己定的**：改「怎样算通过」；碰安全约束（不关证书校验、不打印口令与 crumb、不读 `ca.key`）；改设计（东西放哪、分几步、用什么机制）；碰产品线代码、`gitops/` 声明、集群、Harbor 已有镜像；**第三次跑之后集群上的东西**——这些停下来写 `inbox/fable/`。回执单列「就地修了什么」。
>
> 远程这边没法编译 Groovy，第一次跑新引导和后半段最可能撞到写法问题，这正是授权的用武之地。

```text
被测仓：k8s；工位 WS=fable：~/worktrees/fable/k8s，分支 fable；远程和本地都只推拉这个分支（本卡例外：临时测试分支 fable-b4-test，用完删）
改动（本次）：ci/release.groovy（12 阶段）、infrastructure/jenkins/templates/04-release.groovy.j2（三段引导、自更新）、Makefile（APPROVAL_TIMEOUT_MINUTES）、README、使用说明
会联网的：构建、应用仓 fetch、推 Harbor、推 GitHub/Gitee（代理用宿主用户的 SSH 钥匙）
停下的规则：exit 不是 0 先看是不是授权范围内能修的；能修就修、记下、续跑；不能就停，输出原样进回执
不碰：手改集群、手改 gitops、Harbor 已有镜像；不写库；不替所有者点批；不读、不抄口令与 crumb
```

## 一、核对与拉取（只读）

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -1 && git status --short | head -3
grep -c "stage('" ci/release.groovy; grep -n "body.main\|APPROVAL_TIMEOUT_MINUTES" infrastructure/jenkins/templates/04-release.groovy.j2 | head -3
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash <<'SH'
grep -l '<duration>0</duration>' /mnt/sunmoon-data/jenkins/home/jobs/*/builds/*/build.xml 2>/dev/null || echo "no build in progress"
grep -c 'BuildableItem\|WaitingItem' /mnt/sunmoon-data/jenkins/home/queue.xml 2>/dev/null || echo "queue empty"
SH
```

要看到：HEAD 是本卡这次提交或更新；stage 计数 16 上下、04 里有 `body.main` 和 `APPROVAL_TIMEOUT_MINUTES`；两个 status 都是 0；没有进行中的构建、队列空（有就等；定时器每 10 分钟一发，扫完立刻做第二节，被打断的那次会自行恢复、记 FAILURE，无害）。

## 二、控制器重启（装新引导）

```bash
make -C infrastructure jenkins-agent-stop; echo "agent stop exit=$?"
make -C infrastructure jenkins-stop; echo "stop exit=$?"
systemctl show sunmoon-jenkins.service --property=ActiveState,Result | cat
make -C infrastructure jenkins-deploy; echo "deploy exit=$?"
make -C infrastructure jenkins-agent-start; echo "agent start exit=$?"
make -C infrastructure jenkins-status; echo "status exit=$?"
make -C infrastructure jenkins-agent-status; echo "agent status exit=$?"
sudo -n bash <<'SH'
ls /opt/sunmoon/jenkins/init.groovy.d/
grep -c 'APPROVAL_TIMEOUT_MINUTES' /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml
grep -c 'body.main' /mnt/sunmoon-data/jenkins/home/jobs/release/config.xml
journalctl -u sunmoon-jenkins.service --since '5 min ago' | grep -i -E 'SEVERE|Exception|04-release' | head -5
SH
```

要看到：四个 make 都是 0；停完 `ActiveState=inactive`、`Result=success`；`/opt` 下只剩四个 `*.groovy.override`（旧的四个这次该删掉了）；两个计数都 ≥ 1（任务定义已更新成三段引导）；journal 没有 SEVERE/Exception。

## 三、第一次跑：失败路径（迁移头写旧，停在第 2 阶段）

临时分支 `fable-b4-test`：k8s 从 fable 分出来改一行，tpl-app 同名分支指向 fable 同一提交（流水线 BRANCH 对 k8s 和应用仓都生效）。用临时工作树，不动您的工位。

```bash
bash <<'SH'
set -e
cd ~/worktrees/fable/k8s
git worktree add -q ~/sunmoon-probe-runs/b4test -b fable-b4-test origin/fable
sed -i "s/^  expected_schema_revision: .*/  expected_schema_revision: '20260101_0000'/" ~/sunmoon-probe-runs/b4test/gitops/components/app-platform/tpl-app/tpl-backend/config.yaml
git -C ~/sunmoon-probe-runs/b4test diff --stat
git -C ~/sunmoon-probe-runs/b4test commit -qam "b4 失败路径测试：tpl 迁移头故意写旧（测试分支，用完删）"
git -C ~/sunmoon-probe-runs/b4test push -q origin fable-b4-test
git -C ~/worktrees/fable/tpl-app push -q origin origin/fable:refs/heads/fable-b4-test
echo branches-pushed
SH
make -C infrastructure jenkins-release-run RELEASE_BRANCH=fable-b4-test APPS="tpl" PIN=keep NOTE="B4 失败路径" ; echo "run1 exit=$? (预期 2)"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1); echo "$log"
grep -n "^\[Pipeline\] { (\|Expected schema differs\|Finished:" "$log" | tail -8
git -C /mnt/sunmoon-data/jenkins/repos/k8s status --short --untracked-files=no | head -3; echo clean-check-done
git -C /mnt/sunmoon-data/jenkins/repos/k8s branch --list 'abandoned/*'
SH
```

要看到：`run1 exit=2`，结果 FAILURE；日志里进了 `1 核对`、`2 改钉`、`前半段收尾`，有 `Expected schema differs`，没有 `3 构建`；代理仓干净；`abandoned/*` 没有新的（第 6 阶段之前停）。

跑完就清掉测试分支（两个仓的远端分支和本地工作树）：

```bash
bash <<'SH'
cd ~/worktrees/fable/k8s && git worktree remove --force ~/sunmoon-probe-runs/b4test && git branch -D fable-b4-test
git push -q origin --delete fable-b4-test && git -C ~/worktrees/fable/tpl-app push -q origin --delete fable-b4-test
git ls-remote --heads origin fable-b4-test; git -C ~/worktrees/fable/tpl-app ls-remote --heads origin fable-b4-test; echo branches-deleted
SH
```

要看到：`branches-deleted` 前两行为空。

## 四、第二次跑：超时路径（2 分钟没人批，中止）

```bash
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B4 超时路径" APPROVAL_TIMEOUT_MINUTES=2; echo "run2 exit=$? (预期 2)"
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1); echo "$log"
grep -n "^\[Pipeline\] { (\|Finished:\|total=\|未获批准" "$log" | tail -14
cd /mnt/sunmoon-data/jenkins/repos/k8s
git branch --list 'abandoned/*'
git diff --stat origin/fable -- infrastructure/environments/kind/flux-source.yaml; echo pointer-diff-done
git log --oneline -1 "$(git branch --list 'abandoned/*' | tail -1 | tr -d ' *')" | cat
SH
```

要看到：`run2 exit=2`，结果 ABORTED；日志进了 1 到 7、`前半段收尾`、`8 人批`，然后 `Finished: ABORTED`（两分钟后）；`abandoned/release-<n>` 指着一个 `deploy(tpl): B4 超时路径（release #n）` 提交；`pointer-diff-done` 前为空（指针没变）；集群没动（不用验，第 9 阶段没进）。候选留在 Harbor，无害。

## 五、第三次跑：真发布 tpl 的 /api/internal（所有者点批）

先对所有者说一声：**这次会在 Jenkins 页面停下等您点「批准发布」**。然后：

```bash
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="tpl ingress 补 /api/internal 收敛规则"; echo "run3 exit=$? (预期 0)"
```

`make` 会一直等（上限 25 小时）。所有者在浏览器开 Jenkins → `release` → 最新一次构建（Stage View 里「8 人批」那列写 Paused for Input）→ 构建页中间的文字块 → 先点产物链接看 `4-workload.diff`（应只有两段 `/api/internal`）→ 点 **批准发布**。

跑完：

```bash
bash <<'SH'
log=$(ls -t infrastructure/.build/jenkins/release-*.log | head -1); echo "$log"
grep -n "^\[Pipeline\] { (\|Finished:\|total=\|批准人\|^tag \|已发布" "$log" | tail -24
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git log --oneline -4 | cat && git tag -l 'release-20261020-*' 'release-20261021-*'
cat infrastructure/environments/kind/flux-source.yaml
ls scripts/results/release-*.md
export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"; K=infrastructure/.tools/bin/kubectl
$K -n flux-system get kustomizations -o name | grep -E '/tpl-' | xargs -r $K -n flux-system get -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,REV:.status.lastAppliedRevision
sudo -n curl -sS -o /dev/null -w "tpl web /api/internal %{http_code}\n" --cacert /etc/sunmoon/registry/tls/ca.crt --resolve tpl.sunmoonai.com:30443:127.0.0.1 https://tpl.sunmoonai.com:30443/api/internal/x
sudo -n curl -sS -o /dev/null -w "tpl admin /api/internal %{http_code}\n" --cacert /etc/sunmoon/registry/tls/ca.crt --resolve tpl-admin.sunmoonai.com:30443:127.0.0.1 https://tpl-admin.sunmoonai.com:30443/api/internal/x
SH
```

要看到：`run3 exit=0`，结果 SUCCESS，十二个阶段加两个收尾都进了；`git pull` 带来三个提交（`deploy(tpl): …`、`release(kind): 晋级到 …`、`release(kind): 回执 #n`）和一个新 tag；`flux-source.yaml` 的 digest/revision 变了；`scripts/results/release-<n>.*.md` 在；tpl 的 kustomization 全 `True`，`lastAppliedRevision` 等于新指针的 digest；两个 curl 都回 **404**（规则生效：内部接口转给前端，前端没有这个页面）。

## 六、所有者走查

浏览器：`release` 的三次构建分别是 FAILURE（失败路径）、ABORTED（超时）、SUCCESS（真发布），第三次的 Build Artifacts 里 `12-push.txt`、回执都在；`https://tpl.sunmoonai.com:30443/api/internal/x` 回 404；tpl 首页照常。

## 七、回执与推回

`scripts/results/fable-b4.<时间>.md`：每节命令与 exit、第二节两个计数、三次跑各自的日志行与核对、第五节 kubectl 与 curl 三行、「就地修了什么」一节（没修就写「没有」）、停在哪（若有）。不拍、不抄口令与 crumb。

```bash
cd ~/worktrees/fable/k8s && git pull --ff-only origin fable && git add scripts/results/fable-b4.*.md && git mv docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b4-release-full.md docs/dev-investment-agent/switch-test/done/ && git commit -m "fable-b4 回执：release 全程（luna）" && git push origin fable; echo "push exit=$?"
```

代码改动（若有）单独提交在回执之前；拉不下来或推不上去就停下告诉所有者，不强推。注意第三次跑之后 `origin/fable` 上多了流水线推的三个提交，先 `pull --ff-only` 再提交回执。
