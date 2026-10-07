# 新体系：对象存储控制台放行回连自己（账 51），发布晋级应用，platform-check 跑到底（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：暂存对象存储控制台 → 提交 → 发布晋级应用 → platform-check
预计：15 分钟；只加一条网络策略，对象存储 Pod 不重启
看什么：platform-check 退出 0；不是 0 就贴失败任务名和 fail_msg（后面几项从没在现网跑过）
回传：k8s/sunmoonai/scripts/results/object-storage-console.<时间>.md
```

## 一、核对与暂存

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -3
make -C infrastructure platform-stage OBJECT=data-platform/object-storage/ui; echo "exit=$?"
git diff gitops/components/data-platform/object-storage | grep -E '^\+.*(object-storage-console-self|policyTypes|port: )' | head
git add gitops && git -c core.editor=true commit -m "deploy(object-storage): 控制台放行回连自己的 API 端口（待办 31）"
```

要看到：差异只是 `ui/workload.yaml` 多了 `object-storage-console-self` 这条策略。

## 二、发布、晋级、应用

照待办 29 第四节的命令，提交消息写「待办 31」。

## 三、检查

```bash
curl -sk --noproxy '*' --resolve aistor.sunmoonai.com:30443:127.0.0.1 -X POST -H 'Content-Type: application/json' -d '{"accessKey":"nobody","secretKey":"invalid-ui-acceptance-password"}' -o /dev/null -w '%{http_code}\n' https://aistor.sunmoonai.com:30443/api/v1/login
make -C infrastructure platform-check OBJECT=all 2>&1 | tail -n 30; echo "exit=${PIPESTATUS[0]}"
```

要看到：第一条是 401 或 403；platform-check 退出 0。不是 0：贴失败任务名、fail_msg，以及它前面 `Report only …` 任务里最后一个通过项的名字，让我知道走到了哪。

## 四、回传并本地提交
