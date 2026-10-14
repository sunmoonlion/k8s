# Cursor 发布卡：财务分析与预测上线——投资后端（专家切成可用）+ 知识服务登记 Olist 样例

```text
被测仓：k8s，fable 工作树 `~/worktrees/fable/k8s`，分支 fable
跑：先第一部分（投资后端），application-check 退出 0 后再第二部分（样例）；按编号步骤做
仓与提交：投资父仓 93462322cdec3a2c36c5a5a0177f68f5e9a1dae2；后端 15769d59ec3a6a3442bb3ddf3344348a2aab3e83；网页 309e73d5…（不变）；管理端不动
          知识服务：运行代码不变、镜像不重建、config 不动；样例生成用 knowledge-backend e30525f（fable 头）
预计：第一部分 20–30 分钟（一个镜像、一次现网变更，API 中断约 1 分钟）；第二部分 10 分钟（要联网下载约 55 MB）
看什么：第一部分——只有后端 image.lock 变、计划核到 '20261012_0018'、application-check 0；
        第二部分——样例 data_version = olist-ecommerce-dcca129e2ea0cb56，登记表里有它、security_code 为空
前提：所有者已通知执行；~/worktrees/fable/k8s 在 fable 且干净，含本卡与 gitops/…/knowledge-backend/samples/；
      ~/worktrees/fable/knowledge-app/knowledge-backend 在 e30525f 且干净；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/sunmoonai/scripts/results/fin-forecast-release-cursor.<时间>.md，最后一行 exit=<码>；本地提交，不 push
```

## 这一轮是什么

专家「财务分析与预测」由 Opus 在 qwen 工位做完、fable 合并（设计 `tree-build/SDD/modules/0023-fin-forecast.md`，回执 `scripts/results/fin-forecast-{1,2,3}-remote-20261013.md`）。所有者要演示，要在站点上点得到、用得起来：

- **投资后端 `15769d5`**：`FIN_FORECAST` 五步的方法、工具、验收与失败去向；切成可用、版本 1（原来是「筹备中」，请不了）；评测题与固定数据。后端全量 806 过、0 失败。**没有新迁移**，config 不动。
- **知识服务**：多数据集登记与语义层在 `knowledge-app/knowledge-backend/config.yaml` 里**早已打开**（`KNOWLEDGE_DATASET_REGISTRY_ENABLED`、`KNOWLEDGE_SEMANTIC_ENGINE_ENABLED`，账本待办 4、6 在新体系已落实），运行代码没变，不重建镜像。只差一份数据：在本地机生成 Olist 1/20 样例，放进 `info-originals` 的 `info/samples/` 下，用 info 的服务身份登记（`gitops/components/app-platform/knowledge-app/knowledge-backend/samples/README.md`）。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。

---

# 第一部分：投资后端

## 一、核对（只读）

```bash
cd ~/worktrees/fable/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
ls gitops/components/app-platform/knowledge-app/knowledge-backend/samples/
grep -n "investment:" -A7 infrastructure/applications/sources.yaml
grep -n "expected_schema_revision\|migration_job_revision" gitops/components/app-platform/investment-app/investment-backend/config.yaml
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：`fable`；干净；`samples/` 下有 `README.md`、`register-olist.py`；现在钉的是父仓 `102054b4…`、后端 `e73ffa5e…`、网页 `309e73d5…`；config 是 `v7` / `'20261012_0018'`（本卡不动）；`platform-status` 0。

## 二、改钉（只动父仓与后端三行；网页、管理端、config 不动）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>93462322cdec3a2c36c5a5a0177f68f5e9a1dae2', new, count=1)
new=re.sub(r'(?m)^(    backend_parent_revision: )\w+', r'\g<1>15769d59ec3a6a3442bb3ddf3344348a2aab3e83', new)
new=re.sub(r'(?m)^(    backend_revision: )\w+', r'\g<1>15769d59ec3a6a3442bb3ddf3344348a2aab3e83', new)
assert new!=block; p.write_text(s.replace(block,new,1))
PY2
git diff --stat; git diff infrastructure/applications/sources.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只动这一份文件、三行；`web_*` 两行仍是 `309e73d5…`，`admin_*` 不变。

## 三、构建、暂存、计划

```bash
echo "=== $(date +%T)"; make -C infrastructure platform-build OBJECT=app-platform/investment-app 2>&1 | tail -n 12; echo "exit=${PIPESTATUS[0]}"
git status --short gitops/components/app-platform/investment-app | grep image.lock
for f in $(git diff --name-only gitops/components/app-platform/investment-app | grep image.lock); do echo "$f: $(grep -E 'source_revision' $f | head -1)"; done
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^[-+].*(investment-migrate-|image: )' | head -8
make -C infrastructure application-deployment-plan APP=investment 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
```

要看到：**只有后端的** `image.lock.yaml` 变（`source_revision` = `15769d59…`）；网页锁不变；没有 PEM；迁移 Job 名里镜像摘要那一段随后端镜像变、结尾仍是 `-v7`（**没有新迁移**，跑完库仍在 `20261012_0018`）；计划核到 `20261012_0018`。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 财务分析与预测切成可用、五步方法（待办 44）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 44 投资后端）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get pods | grep -E "investment-(backend|migrate)" | head -12
```

要看到：候选 `revision` = 提交后 HEAD；三次退出 0；后端各角色 Pod 换新、迁移 Job 完成；网页 Pod 不重启。

---

# 第二部分：Olist 样例进集群（只有第一部分 application-check 退出 0 才开始）

## 五、在本地机生成样例

```bash
cd ~/worktrees/fable/knowledge-app/knowledge-backend && git rev-parse --short HEAD && git status --short | head -3
cd app && uv sync --frozen
mkdir -p ~/.cache/sunmoon-olist
uv run python -m scripts.build_olist_dataset --cache ~/.cache/sunmoon-olist/parquet --out ~/.cache/sunmoon-olist/olist-ecommerce.sqlite | tee ~/.cache/sunmoon-olist/build.json; echo "exit=${PIPESTATUS[0]}"
cat ~/.cache/sunmoon-olist/build.json
```

要看到：`e30525f`、干净；退出 0；JSON 里 `"data_version": "olist-ecommerce-dcca129e2ea0cb56"`、`"security_code"` 不出现、`size_bytes` 约 3858432。**`data_version` 不是这个就停**（评测题冻结在这个版本）。文件 sha256 和远程机上不同（SQLite 或 DuckDB 版本差异）照实记下，不算失败。parquet 与生成的文件留在 `~/.cache/sunmoon-olist`，不进任何仓。

## 六、在 info 后端容器里上传并登记

```bash
cd ~/worktrees/fable/k8s
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get deploy info-api
$K -n app-platform-dev exec -i deploy/info-api -c api -- \
  python -c "$(cat gitops/components/app-platform/knowledge-app/knowledge-backend/samples/register-olist.py)" \
  "$(cat ~/.cache/sunmoon-olist/build.json)" < ~/.cache/sunmoon-olist/olist-ecommerce.sqlite; echo "exit=$?"
```

要看到：一行 JSON，`"result": "registered"`（`http_status` 201）或 `"already_registered"`（重跑时）；`registered` 里 `dataset_id` = `olist-ecommerce`、`data_version` = `olist-ecommerce-dcca129e2ea0cb56`、`security_code` 为 `null`、`status` 为现行、`registered_by` 是 info 的服务身份；`object` 在 `s3://info-originals/info/samples/olist-ecommerce/…`。脚本不打印令牌；万一输出里出现 `Bearer` 或 `sk-` 开头的串，回传前删掉并注明。

`"result": "refused"` 时把 `http_status` 与 `detail` 原样贴回并停下（422 多半是桶或前缀不被允许，409 是同版本内容不同）。

## 七、看知识服务认出了它（只读）

```bash
sleep 35   # 登记表每 30 秒重读一次
$K -n app-platform-dev logs deploy/knowledge-api --since=5m 2>/dev/null | grep -iE "dataset|semantic|olist" | grep -v -i "bearer\|sk-" | tail -10
```

要看到：没有 `olist` 相关的报错（取文件失败、sha 对不上、语义模型建不出）。日志里没有相关行也照实写。

---

## 验收

- 第一部分：钉 = 父仓 `93462322…`、后端 `15769d59…`，网页不变；只换后端镜像；`application-check` 0。
- 第二部分：样例 `data_version` = `olist-ecommerce-dcca129e2ea0cb56`；登记结果 `registered` 或 `already_registered`；知识服务日志无相关报错。
- **真人验收由所有者做，不在本卡**：投资网页请专家页「财务分析与预测」不再带「筹备中」、点得动；在一个项目里请它，问「近两年按月收入怎么走？预测下两个季度。」，第一步「定范围」认出「巴西电商 Olist 样例（1/20 抽样…）」，往下走到成稿，项目里出现 `底稿/财务分析与预测-成稿.md` 与 `交回.md`。PPT 第 9、11 页的数（三季度约 15.1 万、四季度约 17.2 万）是这套方法在这份样例上的结果。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选。第一部分需恢复时把 `sources.yaml` 三行改回 `102054b4…` / `e73ffa5e…`，重走构建到晋级。第二部分没有要回退的现网配置：登记的样例只是登记表里多一行，不影响别的数据集；要撤下由 Opus 另写卡。报告写 `k8s/sunmoonai/scripts/results/fin-forecast-release-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
