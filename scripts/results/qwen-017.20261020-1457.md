# qwen-017 回执：knowlab 后端——测试通过不再随刷新自动交付（停在 3.2 构建）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-20-qwen-017-knowlab-delivery-guard.md`（95 行）
- 执行者：Qwen（本地机）；开工前所有者原话「已经都好了你直接做发卡」，追加令「工作台那次请专家已经交回了，前提满足，照 qwen-017 做。第二节那条查询照样跑，status='testing' 必须是 0 行才往下走，不是 0 行就停下来告诉我。做完在 k8s 本地提交，不推，然后跟我说「跑完了」」
- 结果：**停在 3.2**。第一节、第二节、3.1 全对卡；3.2 `platform-build OBJECT=app-platform/knowlab-app` 在 **web 组件**上 `exit=2`。按卡面「任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回」停住，未发布、未晋级、未部署、未推。
- 纪律边界：全程只读 + 卡面明令的改钉与构建；**没有** `rollout restart`、没有写库、没有碰 knowbench/knowmart/测试电脑/沙箱；`web_*`/`admin_*` 四行钉一字未动；一次性脚本无（命令块直接跑），`/tmp` 日志用完即删（见第五节）。

## 一、第一节核对（只读）——全对卡

卡面命令原样跑（包在 `bash <<'SH'` 里，`KUBECONFIG=~/.kube/sunmoon-kind.config`）。输出原文（`platform-status` 的 ansible 全文 13667 行落在 `/tmp/q017-sec1.log`，这里取关键行，行号为该日志行号）：

```text
1: 1ab7d471 新账 147：工作台对话里新建文件显示「+0 −38」，增删数像是反了（qwen-012 看到）
   （git status --short | head -3 → 空，工作区干净）
2: pull/submodule exit=0
3: == knowlab-app 43cd00fc7c930419474a86cee0317dfe54dad2f4
4:  2d5c1124c0b3f76ec0efda2371fadbd5f13787b0 knowlab-admin-frontend (heads/qwen)
5:  e3287024050aef46b6d6954e5e8ab6f59294eaad knowlab-backend (heads/qwen)
6:  d7589583436d7d42d90e390f91508acb6ed76a39 knowlab-web-frontend (heads/qwen)
7: knowlab-web-frontend 与线上差异: []
8: knowlab-admin-frontend 与线上差异: []
9: 9:  expected_schema_revision: '20261019_0010'
13663: localhost                  : ok=7    changed=0    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0
13666: status exit=0
```

逐项对卡：父仓 `43cd00fc7c930419474a86cee0317dfe54dad2f4` ✓；后端 `e3287024050aef46b6d6954e5e8ab6f59294eaad` ✓；网页 `d7589583436d7d42d90e390f91508acb6ed76a39` ✓；管理端 `2d5c1124c0b3f76ec0efda2371fadbd5f13787b0` ✓；两个前端「与线上差异」都是空的 `[]` ✓；config 是 `'20261019_0010'` ✓；`status exit=0` ✓。

**这里就埋着 3.2 的雷**：卡面要求「网页、管理端的钉不动（仍是线上 `6da5cef5…`、`d46b6bd5…`）」，而父仓 `43cd00fc` 的两个前端 gitlink 已经是新号（网页 `d7589583…`、管理端 `2d5c1124…`）；「与线上差异 `[]`」只说明**树内容一字不差**，号是不同的。详见第三节定位。

## 二、第二节部署前只看一眼（只读）——0 行，前提满足

`data-platform-dev/postgresql-0` 里 `psql -U postgres -d knowlab`，卡面查询原样：

```text
select id, status, run_id, updated_at from knowbot_draft where status = 'testing';
 id | status | run_id | updated_at
----+--------+--------+------------
(0 rows)

query exit=0
```

**0 行** ✓（没有在测的分身）。所有者已确认「工作台那次请专家已经交回了」，故卡面「另确认工作台里那次请专家已交回」这一条也满足。往下走。

## 三、3.1 改钉（3 行）——全对卡；3.2 构建 exit=2，停

### 3.1 改钉

卡面 python 原样跑。改钉前 knowlab 段原文：

```text
  knowlab:
    parent_revision: aa51ed9eb8ca1decf6124b0a1c93c1a68b6cf515
    backend_parent_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
    backend_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
    web_parent_revision: 6da5cef54da34d616146530a09cbf8ae73c21acd
    web_revision: 6da5cef54da34d616146530a09cbf8ae73c21acd
    admin_parent_revision: d46b6bd5ad03c3675f165f573713c82e4cafb5bf
    admin_revision: d46b6bd5ad03c3675f165f573713c82e4cafb5bf
```

输出原文：

```text
pin exit=0
 infrastructure/applications/sources.yaml | 6 +++---
 1 file changed, 3 insertions(+), 3 deletions(-)
+行数: 3
== 实际改了哪几行 ==
-    parent_revision: aa51ed9eb8ca1decf6124b0a1c93c1a68b6cf515
-    backend_parent_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
-    backend_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
+    parent_revision: 43cd00fc7c930419474a86cee0317dfe54dad2f4
+    backend_parent_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
+    backend_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
```

逐项对卡：`pin exit=0` ✓；只动 `sources.yaml` ✓；最后一行是 `3` ✓；`web_*`、`admin_*` 四行没动 ✓（diff 里根本没有这四行）。

### 3.2 构建、暂存、计划——**构建 exit=2，停在这里**

卡面照 qwen-014 一段 2.2（日志名换 `q017-*-knowlab`）。第一条命令 `make -C infrastructure platform-build OBJECT=app-platform/knowlab-app` 就非 0，脚本按卡面 `[ "$rc" = 0 ] || exit 1` 当场停，**暂存、计划、越界闸门、运行时/迁移 diff 都没跑**。输出原文（终端）：

```text
make[2]: Leaving directory '/home/zymun/worktrees/qwen/k8s/infrastructure'
make[1]: *** [Makefile:503: platform-build-selected] Error 2
make[1]: Leaving directory '/home/zymun/worktrees/qwen/k8s/infrastructure'
make: *** [Makefile:487: platform-build] Error 2
make: Leaving directory '/home/zymun/worktrees/qwen/k8s/infrastructure'
build knowlab exit=2
```

构建日志 `/tmp/q017-build-knowlab.log`（467 行）关键原文：

```text
424: make application-lock-backend APP=knowlab
426: /home/zymun/worktrees/qwen/k8s/infrastructure/../gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml: digest sha256:57ac0aeb69b5 source e3287024050a
429: make application-build-web application-publish-web APP=knowlab
431: .venv/bin/ansible-playbook -i host/inventory.yaml applications/build.yaml … --extra-vars 'application_name=knowlab build_component=web'
433: PLAY [Build one pinned application component from a clean Git object] ****
435: TASK [Require the reviewed source and build budget] ****  ok: [localhost]
441: TASK [Inspect source revision and local modifications] ****
442: ok: [localhost] => (item=['git', '-C', '/home/zymun/worktrees/qwen/knowlab-app/knowlab-web-frontend', 'rev-parse', 'HEAD'])
445: TASK [Read the pinned parent Git object and its component gitlink] ****  ok: [localhost]
448: TASK [Refuse unreviewed source revisions or dirty checkout] ****
449: [ERROR]: Task failed: Action failed: Assertion failed
450: Origin: /home/zymun/worktrees/qwen/k8s/infrastructure/applications/build.yaml:114:7
457: fatal: [localhost]: FAILED! => {"assertion": "build_kind == 'component' or source_state.results[0].stdout == component_revision", "changed": false, "evaluated_to": false, "msg": "Assertion failed"}
460: localhost                  : ok=4    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
462: make[2]: *** [Makefile:343: application-build-web] Error 2
```

即：**后端建完并写了锁**（`e3287024…` → `sha256:57ac0aeb69b5…`），随后 **web 组件**在「拒绝未经评审的源修订」这一步被断言挡下。

### 只读定位（不改任何文件、不重跑）

断言口径 `infrastructure/applications/build.yaml`：

```text
12:    build_kind: application
31:    component_revision: '{{ source_lock[build_component + "_revision"] if build_kind == "application" else (…) }}'
32:    parent_gitlink_revision: '{{ (source_lock[build_component + "_parent_revision"] | default(component_revision)) if build_kind == "application" else component_revision }}'
64:    source_checkout: '{{ ((playbook_dir + "/../../../" + application_name + "-app/" + component.repository) …) | realpath }}'
118:          - build_kind == 'component' or source_state.results[0].stdout == component_revision
120:          - build_kind == 'component' or parent_link.stdout.split() == ['160000', 'commit', parent_gitlink_revision, component.repository]
```

三个值实测对照（只读命令取得）：

```text
web 子仓 HEAD（source_checkout 的 rev-parse HEAD）: d7589583436d7d42d90e390f91508acb6ed76a39
sources.yaml web_revision（= component_revision）:  6da5cef54da34d616146530a09cbf8ae73c21acd
父仓 43cd00fc 的 web gitlink（ls-tree 原文）:       160000 commit d7589583436d7d42d90e390f91508acb6ed76a39    knowlab-web-frontend
sources.yaml web_parent_revision:                   6da5cef54da34d616146530a09cbf8ae73c21acd
```

根因：`build_kind=application` 时，`component_revision` 取的是 **sources.yaml 的 `web_revision`（线上钉 `6da5cef5…`）**，而 `source_checkout` 是父仓 `43cd00fc` 下 `submodule update --init` 出来的 **`d7589583…`**；断言要求两者字符串相等 → 必然失败。第 120 行那条（gitlink 对 `web_parent_revision`）同样会失败，只是没跑到。管理端同理（钉 `d46b6bd5…` vs gitlink `2d5c1124…`）。

也就是说：**卡面「网页、管理端的钉不动、不重建」与「用 `platform-build OBJECT=app-platform/knowlab-app` 构建」这两条，在父仓已把两个前端 gitlink 推到新号的情况下互斥**——应用级构建会连带建三件，而建 web/admin 就要求它们的钉等于父仓 gitlink。qwen-014 那轮之所以过，是因为当时五个钉都与父仓 gitlink 一致。

两条候选口径（**Qwen 不自己选、不擅自改 OBJECT 或改钉**，交所有者/Opus 判）：

1. **只建后端组件**：`infrastructure/Makefile` 第 115 行帮助文本写 `platform-build OBJECT=<业务应用或前后端组件>`，第 342–343 行有 `application-build-backend/web/admin` 单组件目标；组件级路径下 `build_kind == 'component'`，第 118/120 行两条断言按写法被短路跳过。需要卡面把 3.2 的 OBJECT 换成组件级（形如 `app-platform/knowlab-app/knowlab-backend`），并确认暂存/计划/晋级各步在组件级 OBJECT 下的产物口径。
2. **把 `web_parent_revision`/`web_revision`/`admin_parent_revision`/`admin_revision` 四行也换成 `d7589583…`/`2d5c1124…`**：树内容与线上一字不差（第一节 diff `[]`），但会真去重建两个前端、重写它们的镜像锁，与卡面「不重建」和第四节「`knowlab-web`、`knowlab-admin` 的镜像摘要**没变**」直接冲突；同树是否必然产出同摘要要 Opus 判，Qwen 不赌。

### 停在原地的工作区状态（未提交、未退回）

```text
 M gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml
 M infrastructure/applications/sources.yaml

后端锁被写成：
digest: sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5
source_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
deployment_id: knowlab-backend-57ac0aeb69b53a21
```

按卡面「不退回」，这两个改动**留在工作区没有 revert**；本回执只提交回执文件本身（`scripts/results/qwen-017.20261020-1457.md`），**没有**把 `sources.yaml`/`image.lock.yaml` 一起提交（提交它们是 3.3 的事，3.3 没跑到）。所有者若要退回，说一声我再动。

### 集群侧

零写动作。没跑 `platform-stage`、没跑 `flux-release`、没跑 `flux-source-apply`，`knowlab-api / worker / scheduler` 三个 deploy 仍是线上后端 `7c9731cd…`，flux 未被触碰。

## 四、第四节上线后核——未做

第四节四行（Qwen 侧 `knowlab-api` 日志核、所有者三行页面核）**全部未做**：后端没有上线，核了也只是核到旧版本，属假证据。等 3.2 的口径定了、发布真做完再补。

## 五、纪律与一次性产物清理

- 只读 SELECT 一条（第二节），未写库；未替所有者点任何页面；未 `rollout restart`；未推（`git push` 一次没跑，qwen-013 的 2.3 末尾那行 `git push origin qwen` 按本卡「不推」明令**跳过**）。
- key/口令未落任何输出（DB 口令走 Pod 内 `cat /run/auth/password`，未打印）。
- 一次性产物：`/tmp/q017-sec1.log`、`/tmp/q017-sec2.log`、`/tmp/q017-pin.log`、`/tmp/q017-32.log`、`/tmp/q017-build-knowlab.log`。关键原文已全部抄进本回执，**除构建日志 `/tmp/q017-build-knowlab.log` 暂留一份供 Opus 复核外，其余已删**；Opus 说不用了我就删掉它。仓内无 `scripts/tmp-*`、无一次性脚本文件（命令块直接在 bash 里跑）。
- 本回执在 k8s 本地提交，**不推**（推回是所有者的 human-remote.sh），等 Opus 审。

## 六、结论

第一节 7 项全对卡、第二节 0 行、3.1 三行钉精确落地（`web_*`/`admin_*` 四行未动）；3.2 应用级构建在 web 组件的源修订断言上 `exit=2`，根因是卡面「两个前端的钉不动」与父仓 `43cd00fc` 已把两个前端 gitlink 推到新号互斥（只读证据见第三节三值对照）。按卡面停住，未重试、未退回、未发布、未部署、未推。需要所有者/Opus 在两条候选口径里定一条，再往下走 3.2–3.3 与第四节。
