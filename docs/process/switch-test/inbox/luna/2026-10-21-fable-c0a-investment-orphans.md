# luna 卡 fable-c0a：清掉改名遗留的 10 个 `investment-*` Flux 条目和它们的工作负载

> 状态：**可执行**（远程 Fable 2026-10-21 写；**所有者 2026-10-21 已批准删除**：「对，按这两条发卡」）。这 10 个 Kustomization 是 10-15 改名（investment → knowbench）时没带清理留下的孤儿：`gitops/` 里早没有 investment 的声明，集群里的条目指着不存在的目录，永远不 Ready，现在卡住了开机守卫（`platform-start` 要求全部 Flux 对象 Ready，你 c0 维护回执里的失败就是它）。
>
> **范围**：删 flux-system 里这 10 个 Kustomization；删它们当初建出来的 investment 工作负载（Deployment、Service、Ingress/IngressRoute、Job、ConfigMap、Secret、ServiceAccount、Role/RoleBinding、NetworkPolicy，三个命名空间）。**不删**：PVC、共享 PostgreSQL 里的 `investment` 库、对象存储里的桶、Harbor 里的镜像——留到 kind 存档时一起处理。knowbench 的任何东西不碰。
>
> 临时就地修授权：本卡的命令可以改「怎么执行」；范围（删什么、不删什么）不改；删之前先列、列出来和预期不符就停。

```text
工位 WS=fable：~/worktrees/fable/sunmoonun；KUBECONFIG=~/.kube/sunmoon-kind.config；K=infrastructure/.tools/bin/kubectl
不碰：knowbench-*、六个应用、Harbor、gitops 声明、PVC、数据库、桶
```

## 一、先列（只读）

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"; K=infrastructure/.tools/bin/kubectl
$K -n flux-system get kustomization -o name | grep '/investment-' | tee /tmp/c0a-kusts.txt | wc -l
grep -rc "investment" gitops/clusters/kind/stages.yaml
for k in $(sed 's#.*/##' /tmp/c0a-kusts.txt); do
  echo "== $k"; $K get deploy,sts,svc,ingress,job,cronjob,cm,secret,sa,role,rolebinding,networkpolicy,pvc -A -l "kustomize.toolkit.fluxcd.io/name=$k,kustomize.toolkit.fluxcd.io/namespace=flux-system" --no-headers 2>/dev/null | awk '{print $1, $2}'
  $K get ingressroutes.traefik.io -A -l "kustomize.toolkit.fluxcd.io/name=$k" --no-headers 2>/dev/null | awk '{print $1, "ingressroute/"$2}'
done | tee /tmp/c0a-resources.txt
grep -c "knowbench" /tmp/c0a-resources.txt; grep "pvc" /tmp/c0a-resources.txt
```

要看到：10 个 Kustomization；`stages.yaml` 里 investment 计数 0（声明早没了）；列出的资源名全带 `investment`，`knowbench` 计数 **0**（有就停）；有没有 PVC 照实记（有也不删）。整份清单贴进回执。

## 二、删

```bash
export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"; K=infrastructure/.tools/bin/kubectl
for k in $(sed 's#.*/##' /tmp/c0a-kusts.txt); do
  $K get deploy,sts,svc,ingress,job,cronjob,cm,secret,sa,role,rolebinding,networkpolicy -A -l "kustomize.toolkit.fluxcd.io/name=$k,kustomize.toolkit.fluxcd.io/namespace=flux-system" -o name --no-headers 2>/dev/null | while read -r r; do ns=$($K get "$r" -A --no-headers 2>/dev/null | awk '{print $1}' | head -1); echo "delete $ns $r"; done
done | tee /tmp/c0a-plan.txt | wc -l
# 真删（PVC 不在上面的种类里）
while read -r _ ns r; do $K -n "$ns" delete "$r" --ignore-not-found --wait=false; done < /tmp/c0a-plan.txt
$K get ingressroutes.traefik.io -A -l "kustomize.toolkit.fluxcd.io/namespace=flux-system" --no-headers 2>/dev/null | awk '$2 ~ /^investment/ {print $1, $2}' | while read -r ns n; do $K -n "$ns" delete ingressroute "$n" --ignore-not-found; done
$K -n flux-system delete $(cat /tmp/c0a-kusts.txt) --wait=true --timeout=120s; echo "kust delete exit=$?"
```

要看到：删除清单的行数和第一节列出的一致；Kustomization 删除 exit 0（Flux 的 prune 关着，删条目不会连带删别的东西，所以上面先删工作负载再删条目）。

## 三、核

```bash
export KUBECONFIG="$HOME/.kube/sunmoon-kind.config"; K=infrastructure/.tools/bin/kubectl
$K -n flux-system get kustomization --no-headers | grep -c investment
$K -n flux-system get kustomization -o json | python3 -c 'import json,sys; ks=json.load(sys.stdin)["items"]; bad=[k["metadata"]["name"] for k in ks if not any(c["type"]=="Ready" and c["status"]=="True" for c in k.get("status",{}).get("conditions",[]))]; print("total",len(ks),"not-ready",bad)'
$K get pods -A --no-headers | grep -c investment
$K get all -A --no-headers 2>/dev/null | grep -c investment
make -C infrastructure platform-status; echo "status exit=$?"
make -C infrastructure platform-start; echo "start exit=$? (开机守卫这次该过)"
```

要看到：investment 计数 0；`total 95 not-ready []`；pod 与 all 里 investment 计数 0（Succeeded 的旧 Job Pod 会随 Job 删掉）；`platform-status` 0；`platform-start` 0。

## 四、回执与推回

`scripts/results/fable-c0a.<时间>.md`：第一节清单原文、第二节删除清单与 exit、第三节六行、「就地修了什么」。

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git add scripts/results/fable-c0a.*.md && git mv docs/process/switch-test/inbox/luna/2026-10-21-fable-c0a-investment-orphans.md docs/process/switch-test/done/ && git commit -m "fable-c0a 回执：investment 孤儿清理（luna）" && git push origin fable; echo "push exit=$?"
```
