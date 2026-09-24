# KIND：知识 MCP 进 knowledge 开发包（本地机，要 KIND、Harbor、Docker）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 knowledge-app 含子仓 knowledge-backend）
跑：按下面编号步骤做
仓与提交：k8s 本条待办所在的 fable 头；knowledge-app e18a56e（子仓 knowledge-backend 76765a2）
预计：60 分钟（建 knowledge-backend 镜像 10 分钟、准备记录重建 5 分钟、回执与部署 20 分钟）；要联网；要 Docker、KIND、Harbor
看什么：第 3 步对象在桶里且 sha256 一致；第 9 步 rollout 全 ok；第 10 步用令牌调 MCP 三个工具都返回带 data_version 的结果
前提：07 已过（沙箱 pod 在跑，它的 KNOWLEDGE_MCP_TOKEN Secret 在这一步才建）；kind_identity_recover 对 knowledge 也要跑一次（B7 的 knowledge 准备目录同样丢了）
回传：k8s/sunmoonai/scripts/results/kind-knowledge-mcp.<时间>.md
```

## 步骤

1. 桶与访问权（声明已加 `development-knowledge-datasets` 只读）：`cd ~/worktrees/fable/k8s && ./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh --cluster KIND provision ~/worktrees/fable/knowledge-app/knowledge-backend/storage-access-bootstrap/config/access.json`。应看到桶创建、Policy 更新、Secret `knowledge-backend-s3` 复用当前凭据。
2. 上传数据集（对象存储控制台或 mc；数据集文件在本地 `~/worktrees/fable/knowledge-app/knowledge-backend/app/datasets/lesson23_business_analysis.sqlite`，先 `sha256sum` 确认是 `a1764f1d…04cf5`）：用 `./sunmoonai/data-platform/object-storage/deploy-object-storage/deploy-object-storage.sh --cluster KIND console sunmoonai data-platform-dev development` 开临时隧道，浏览器上传到桶 `development-knowledge-datasets` 路径 `lesson23/lesson23_business_analysis.sqlite`；或用 mc 通过同一隧道 `mc cp`。
3. 核对：控制台里对象大小 21,364,736 字节；如能算 sha256（mc 有 `mc cat | sha256sum`），应等于上面的值。
4. MCP 令牌 Secret（不进 git 不回传）：
   ```bash
   export KUBECONFIG=~/.kube/kind-config
   MCP_TOKEN="kmcp-$(head -c 24 /dev/urandom | base64 | tr -d '=+/')"
   kubectl -n app-platform-dev create secret generic knowledge-mcp-tokens --from-literal=tokens.json="{\"$MCP_TOKEN\":{\"user\":\"demo\",\"sandbox\":\"sandbox-demo\"}}"
   kubectl -n sandbox-pool create secret generic sandbox-demo-knowledge --from-literal=token="$MCP_TOKEN"
   echo "$MCP_TOKEN" > ~/private/demo-mcp-token && chmod 600 ~/private/demo-mcp-token; unset MCP_TOKEN
   kubectl -n sandbox-pool rollout restart deploy/sandbox-demo     # 沙箱重启后才带上令牌
   ```
5. knowledge 的准备记录重建：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && python3 kind_identity_recover.py --app knowledge --kubeconfig ~/.kube/kind-config --cluster-uid $(kubectl get ns kube-system -o jsonpath='{.metadata.uid}') --prepared-release-id kind-b7-20260919 --output ~/private/knowledge-identity-recovered-20260925`。记下 `plan_sha256`。
6. 镜像：`CLUSTER=KIND APPS=knowledge COMPONENTS=backend SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`；取 digest。
7. 锁与输入：`~/worktrees/fable/knowledge-app/development-source-lock.json` 三个组件 commit/tree 改成本地检出实际值（task 改 `knowledge-mcp-kind-20260925`）；`knowledge-app/deployment/development-input.json` 的 `images.backend` 换新 digest，`migration_head` 不变（`20260911_0006`，本次没有迁移），加 `"runtime_identity_upgrade": {"prepared_release_id": "kind-b7-20260919", "preparation_plan_sha256": "<第 5 步>"}`，`development_source_lock` 与锁文件一致。
8. 渲染、门禁、conf、单测、plan（同 06 的 A5 到 A9，换成 knowledge：`cd ../knowledge-app && python3 -B deployment/render.py --output-dir /tmp/knowledge-dev --release-id kind-mcp-20260925 --development-input deployment/development-input.json --ingestion-dataset-bindings-file deployment/ingestion-dataset-bindings.kind.json`；diff 只应有：backend digest、ConfigMap 里 KNOWLEDGE_DATASET_*/KNOWLEDGE_MCP_RATE_PER_MINUTE 五个键、api 容器的 KNOWLEDGE_MCP_TOKENS_JSON 可选引用、api 出站策略多了 80、release.json 的锁与哈希与 runtime_identity_upgrade；conf 里 RELEASE_ID 与 BACKEND_IMAGE 跟着换）。
9. 停写、回执、部署（同 06 B 段第 4 到 7 步，App 换 knowledge，head `20260911_0006`，`--identity-preparation ~/private/knowledge-identity-recovered-20260925`）。
10. 验：`kubectl -n app-platform-dev exec deploy/knowledge-backend-api -- python - <<'PY'` 里用 urllib 对 `http://127.0.0.1:8000/api/mcp/knowledge` 发 `tools/list`（Authorization: Bearer 用第 4 步的令牌，从 `~/private/demo-mcp-token` 读，不要贴出来）与 `tools/call describe_schema`：应返回三个工具、表清单与 `citation.data_version = lesson23-analysis-b7ad59fddab30331`。第一次调用会从桶里取数据集，最多几秒。
11. 沙箱侧：`kubectl -n sandbox-pool exec deploy/sandbox-demo -- grep -A3 sunmoon_knowledge /data/codex/config.toml` 应有 url 与 bearer_token_env_var。然后网页里对 Codex 说「用 sunmoon_knowledge 的 describe_schema 列出表」，时间线应出现数据查询条目。

## 回传里要有

第 1、3、5、8（diff 摘要）、9（部署输出）、10、11 步的结果；日志过滤含 sk-、kmcp- 的行。
