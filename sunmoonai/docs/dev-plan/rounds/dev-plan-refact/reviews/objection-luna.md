# ④ 异议 · dev-plan-refact · luna

**无异议。**本结论限于本环节允许 luna 提出的 Q3 处置异议，以及验收方计算；不代表整份裁决稿验收通过。

## 取件与范围

按主线 `call-④.md` 读取 `~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/`，
三份文件均逐字节比对提交 `1f2d0651`，不是本人工作区的①候选。

| 文件（相对上述检视面） | 行数 | SHA-256 |
| --- | --- | --- |
| pipeline.md | 270 | c4b315911cbf7a60e379273724015a44ae34bc5edc2dd7b9ef638c61615958cc |
| dev-plan-architecture.md | 778 | 7139e7b9a94e6b21874948cc843573d77a432f1b087cccea3166aa35b849c985 |
| rounds/dev-plan-refact/disposition.md | 179 | 3bcfcaa4265a1055c30eaa2eaf411ca949dda38115d06c5d7b195e8f4dbdac16 |

## Q3 的处置

条目：**luna｜Q3：protocol 是 SDP 引用的执行附件｜部分接受**。

原主张是调用与版本引用：具体任务、依赖和进度归计划，规程不因任务表完成而过期。
本人②进一步说明，逻辑附件关系与物理独立文件可以同时成立。
裁决稿保留上述关系，并将类型明确为横切常驻；这没有改变我要求保留的执行关系。
「不写成实施计划的一章」可作为组织边界的澄清，我不要求改判为全部接受。

证据：

- 原①：`~/worktrees/luna/k8s/sunmoonai/docs/dev-plan/pipeline.md:162`（提交 `9a2b999c`）。
- 原②：`~/worktrees/luna/k8s/sunmoonai/docs/dev-plan/rounds/dev-plan-refact/reviews/review-luna.md:232`（提交 `40f5fceb`）。
- 裁决正文：`~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/pipeline.md:149`。
- 裁决直接回答：`~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:252`。

## 验收方计算

按处置表重新计数，排除裁决兼整合方 cursor 与基座作者 luna 后：

| 家 | 接受 | 部分接受 | 计入合计 |
| --- | --- | --- | --- |
| opus | 5 | 1 | 6 |
| kimi | 5 | 3 | 8 |
| qwen | 2 | 2 | 4 |

因此验收方为 **qwen**，与通知及处置记录一致，无计算异议。

## 通知要求的 RUNNER 复跑回执

**裁决稿 RUNNER 的 `verify` 失败。**同一 luna 仓根、同一索引与源文件下，
本人①的 RUNNER 通过；裁决稿在表格与 CONFIG 比对的断言失败。
比对全部 260 行，阶段/落点不一致的条目只有 `I08-009`：

| 面 | 阶段 | 落点 |
| --- | --- | --- |
| 裁决稿第八节表格 | S3 | implementation-plan.md / 计划责任和产品工作单元 |
| 裁决稿 CONFIG、show、render | S0/S3 | handoff.md / 未决及开工输入 |

实跑 `render implementation-plan.md` 不含 `来源单元 I08-009；`，
`render handoff.md` 仍含该单元。失败不是源摘要变化，而是文字落点更新后机器清单未同步。

证据：`~/review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan/dev-plan-architecture.md:580`
是新落点；同文件 `:596` 为 CONFIG，`:722` 为失败断言。

本项按通知「请重点看的三处」第 3 项留证，**不列为正式异议**：
相关 L2、render/verify 主张已被接受，通知明确不属于本次可异议条目。
建议整合方同步 CONFIG 中的 unit 与两侧 group 成员，重跑 verify 和两个 render；
验收方核对后再判断该项是否闭合。本回执不修改裁决稿，也不代替⑤验收结论。

### 可复跑命令

在 luna 仓根执行。只读取检视面及 Git，禁写 Python 字节码；
基座校验须通过，裁决稿的预期失败捕获后继续报告具体差异。

```bash
cd ~/worktrees/luna/k8s
python3 -B - <<'PY'
from pathlib import Path
import hashlib, json, re, subprocess, sys, traceback

root = Path.home() / 'review/dev-plan-refact-③裁决稿/sunmoonai/docs/dev-plan'
prefix = 'sunmoonai/docs/dev-plan/'
for name in ('pipeline.md', 'dev-plan-architecture.md', 'rounds/dev-plan-refact/disposition.md'):
    raw = (root / name).read_bytes()
    assert raw == subprocess.check_output(['git', 'show', '1f2d0651:' + prefix + name])
    print(name, len(raw.splitlines()), hashlib.sha256(raw).hexdigest())

for label, commit in [('baseline', '9a2b999c'), ('decision', '1f2d0651')]:
    s = subprocess.check_output(['git', 'show', commit + ':' + prefix + 'dev-plan-architecture.md']).decode()
    code = s.split('<!-- RUNNER -->\n```python\n', 1)[1].split('\n```\n<!-- END RUNNER -->', 1)[0]
    ns = {'s': s}
    sys.argv = ['runner', 'verify']
    print('VERIFY', label, flush=True)
    try:
        exec(compile(code, commit + '::RUNNER', 'exec'), ns)
    except AssertionError:
        if label == 'baseline':
            raise
        traceback.print_exc()
    table = s.split('## 八、260 节安置表', 1)[1].split('## 九、复现清单', 1)[0]
    rows = re.findall(r'^\| (I\d+-\d+) \| (.*?) \| (.*?) \| (.*?) \| (.*?) \|$', table, re.M)
    assert len(rows) == 260
    for uid, src, title, stage, dest in rows:
        x = ns['units'][uid]
        expected = (x['stage'], x['target'] + ' / ' + x['group'])
        if (stage, dest) != expected:
            print('MISMATCH', uid, (stage, dest), expected)
    render = ns['render']
    for target in ('implementation-plan.md', 'handoff.md'):
        print(label, target, 'contains I08-009:', '来源单元 I08-009；' in render(target))

s = (root / 'rounds/dev-plan-refact/disposition.md').read_text()
table = s.split('## 二、', 1)[1].split('### 部分接受', 1)[0]
counts = {}
for who, item, verdict in re.findall(r'^\| (luna|opus|kimi|cursor|qwen) \| (.*?) \| (.*?) \|$', table, re.M):
    counts.setdefault(who, {'接受': 0, '部分接受': 0, '拒绝': 0})[verdict.split('（')[0]] += 1
print(json.dumps(counts, ensure_ascii=False))
eligible = {w: c['接受'] + c['部分接受'] for w, c in counts.items() if w not in {'cursor', 'luna'}}
assert eligible == {'opus': 6, 'kimi': 8, 'qwen': 4}
print('acceptor:', min(eligible, key=eligible.get))
PY
```

## 覆盖与盲区

已核 Q3 原主张与处置正文、三份裁决物的冻结字节、验收方计数，以及通知点名的
RUNNER verify 和 I08-009 两侧 render。未从 inputs 照抄框架。

⚠ 未独立验收整稿的全部语义、未逐条重审其他家的处置、未复跑 opus 的全套计数、
未运行产品仓测试或部署。本次 verify 失败后尚未执行到的后续断言不能记为通过；
本人基座通过不能外推为裁决稿通过。以上结论仅是本次规定范围的检视结果。
