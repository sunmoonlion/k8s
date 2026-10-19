# qwen-015 回执（本地机 Qwen）

卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-19-qwen-015-draft3-test.md`（K19 第 3 稿：孵分身 1.3、测试、第一次看成稿与各步交回物；不发版）。qwen-012 等前置不做（所有者令）。

## 一、核对（只读）——输出原文，全对卡

```text
$ bash <<'SH'
cd ~/worktrees/qwen/k8s && git pull --ff-only origin qwen; echo "pull exit=$?"
git log --oneline -1
cd docs/dev-investment-agent/tree-build/SDD/modules/0029-sample-fin-forecast
sha256sum manifest-v1-draft3.json; wc -c < manifest-v1-draft3.json
python3 -c "import json;m=json.load(open('manifest-v1-draft3.json'));print(m['version'], len(m['rule_sources']), [r['ref'] for r in m['rule_sources'] if r['ref'].startswith('amendment:')], [s['step_id']+'@'+s.get('step_version','1') for s in m['pack']['workflow']])"
SH
From https://github.com/sunmoonlion/k8s
 * branch              qwen       -> FETCH_HEAD
Already up to date.
pull exit=0
c37afb6c (HEAD -> qwen, origin/qwen) qwen-015 改写：0037 上线后按创意/分身新导航孵出分身 1.3；清单换审读后重出的那份（sha 1f2e5617…，第 6 步加三项结构检查）；新加成稿与各步交回物、web端看成稿、-32010 时查符号链接
1f2e56177d163d7d8f576a44ae83843e652b822dce116a33536b9725c2f71f8d  manifest-v1-draft3.json
53459
1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6'] ['scope@1', 'inventory@1', 'reconcile@1', 'series@1', 'indicators@1', 'official@2', 'forecast@1', 'writeup@2']
```

逐项对卡：sha256 逐字一致、`53459` 字节、`1 14 ['amendment:e6df96db-a92c-43ce-8039-84d7ebcd65b6']`、八步 `official@2` 与 `writeup@2`（其余 @1）——全对，放行第二节。

## 二、孵化与测试

### 第 1–6 行（所有者操作）——待回报

### 第 7 行（Qwen 日志核）——待开跑

### 第 8–12 行——待回报
