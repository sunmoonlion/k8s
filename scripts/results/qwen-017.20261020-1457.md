# qwen-017 回执：knowlab 后端——测试通过不再随刷新自动交付（第一次停在 3.2；改卡为 7 行钉后全过并上线）

- 卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-20-qwen-017-knowlab-delivery-guard.md`（95 行）
- 执行者：Qwen（本地机）；开工前所有者原话「已经都好了你直接做发卡」，追加令「工作台那次请专家已经交回了，前提满足，照 qwen-017 做。第二节那条查询照样跑，status='testing' 必须是 0 行才往下走，不是 0 行就停下来告诉我。做完在 k8s 本地提交，不推，然后跟我说「跑完了」」
- 结果：**第一次停在 3.2**（3 行钉），Opus 改卡为 **7 行钉**后重做，**第二次全过并发布上线**（详第七节）。第一至六节保留为第一次的历史记录，不改一字；最终口径以第七节为准。
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
- 一次性产物：`/tmp/q017-sec1.log`、`/tmp/q017-sec2.log`、`/tmp/q017-pin.log`、`/tmp/q017-32.log`、`/tmp/q017-build-knowlab.log`。关键原文已全部抄进本回执，当时暂留构建日志一份供 Opus 复核；**改卡后 Opus 明令不用留，已连同第二次的一起全部删除**（详见 7.6）。仓内无 `scripts/tmp-*`、无一次性脚本文件（命令块直接在 bash 里跑）。
- 本回执在 k8s 本地提交，**不推**（推回是所有者的 human-remote.sh），等 Opus 审。

## 六、第一次的结论（历史，已被第七节取代）

第一节 7 项全对卡、第二节 0 行、3.1 三行钉精确落地（`web_*`/`admin_*` 四行未动）；3.2 应用级构建在 web 组件的源修订断言上 `exit=2`，根因是卡面「两个前端的钉不动」与父仓 `43cd00fc` 已把两个前端 gitlink 推到新号互斥（只读证据见第三节三值对照）。按卡面停住，未重试、未退回、未发布、未部署、未推。当时提的两条候选里，**「只建后端组件」被 Opus 否决**：`build_kind=component` 指的是平台自己的组件镜像（如 postgresql、traefik），不是应用里的后端；就算只建了后端，`sources.yaml` 的钉与父仓 gitlink 还是对不上，以后整应用构建还会卡。故采用第二条：7 行钉全换、两个前端照样重建一次（代码与线上一字不差，摘要会变）。

## 七、第二次（7 行钉，改卡后）——全过，已上线

改卡原文要点（Opus）：钉改成 7 行，网页、管理端也钉到父仓 `43cd00fc` 里记的号；两个前端照样重建一次（代码和线上一字不差，摘要会变）；`knowlab-web`、`knowlab-admin` 的摘要会变，**各自和自己的 `image.lock` 一致就算过**。

### 7.1 退回失败那次留下的两处改动

```text
$ git checkout -- infrastructure/applications/sources.yaml gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml
checkout exit=0
-- git status --short（应为空）--
(空)
-- HEAD 仍是回执提交 --
5227c512 docs(qwen-017): 停在 3.2——…本地提交不推
```

工作区退回后为空 ✓（回执提交 `5227c512` 不受影响 ✓）。

### 7.2 3.1 改钉（7 行）

改卡给的 python 原样跑，输出原文：

```text
pin exit=0
 infrastructure/applications/sources.yaml | 14 +++++++-------
 1 file changed, 7 insertions(+), 7 deletions(-)
+行数: 7
== 实际改了哪几行 ==
-    parent_revision: aa51ed9eb8ca1decf6124b0a1c93c1a68b6cf515
-    backend_parent_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
-    backend_revision: 7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e
-    web_parent_revision: 6da5cef54da34d616146530a09cbf8ae73c21acd
-    web_revision: 6da5cef54da34d616146530a09cbf8ae73c21acd
-    admin_parent_revision: d46b6bd5ad03c3675f165f573713c82e4cafb5bf
-    admin_revision: d46b6bd5ad03c3675f165f573713c82e4cafb5bf
+    parent_revision: 43cd00fc7c930419474a86cee0317dfe54dad2f4
+    backend_parent_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
+    backend_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
+    web_parent_revision: d7589583436d7d42d90e390f91508acb6ed76a39
+    web_revision: d7589583436d7d42d90e390f91508acb6ed76a39
+    admin_parent_revision: 2d5c1124c0b3f76ec0efda2371fadbd5f13787b0
+    admin_revision: 2d5c1124c0b3f76ec0efda2371fadbd5f13787b0
```

逐项对卡：`pin exit=0` ✓；只动 `sources.yaml` ✓；最后一行 **7** ✓。改后 knowlab 段七个钉与第一节量到的父仓/子仓号逐一相等（后端 `e3287024…`、网页 `d7589583…`、管理端 `2d5c1124…`，父 `43cd00fc…`）。

### 7.3 3.2 构建、暂存、计划（qwen-014 一段 2.2 原命令，日志名 `q017-*`）

```text
build knowlab exit=0
== 变了的镜像锁 ==
gitops/…/knowlab-admin-frontend/image.lock.yaml: digest: sha256:57422c78f2f4701ca14b1aab5f2ddc0c8cc798157f76637bb3c59189eced5f1e source_revision: 2d5c1124c0b3f76ec0efda2371fadbd5f13787b0
gitops/…/knowlab-backend/image.lock.yaml:       digest: sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5 source_revision: e3287024050aef46b6d6954e5e8ab6f59294eaad
gitops/…/knowlab-web-frontend/image.lock.yaml:  digest: sha256:5c43b733dbdfc22da11770620062697263afb27cb14f05c40a2ab591abeb9cc0 source_revision: d7589583436d7d42d90e390f91508acb6ed76a39
stage knowlab exit=0
key-check-done            （前面没有任何文件名，即无私钥/公钥泄入 gitops）
== 暂存产物归属统计 ==
      2 components/app-platform/knowlab-app/knowlab-admin-frontend
      8 components/app-platform/knowlab-app/knowlab-backend
      2 components/app-platform/knowlab-app/knowlab-web-frontend
== 越界闸门：gitops 里非 knowlab 的改动（应为空）==
(空)
== 运行时 workload diff（除镜像与摘要）==
-- knowlab-app/knowlab-backend/runtime/workload.yaml
-  DEPLOYMENT_ID: "knowlab-backend-afca9881f01d4a94"
+  DEPLOYMENT_ID: "knowlab-backend-57ac0aeb69b53a21"
-- knowlab-app/knowlab-web-frontend/workload.yaml
-            - {name: DEPLOYMENT_ID, value: "knowlab-web-frontend-a89b38ec326bd87a"}
+            - {name: DEPLOYMENT_ID, value: "knowlab-web-frontend-5c43b733dbdfc22d"}
-- knowlab-app/knowlab-admin-frontend/workload.yaml
-            - {name: DEPLOYMENT_ID, value: "knowlab-admin-frontend-8f83032359d5566b"}
+            - {name: DEPLOYMENT_ID, value: "knowlab-admin-frontend-57422c78f2f4701c"}
== 迁移 workload diff（除镜像与摘要）==
-            - {name: DEPLOYMENT_ID, value: '7c9731cdbe79f8be7f00bf6c73ebcf7a70dffd8e'}
+            - {name: DEPLOYMENT_ID, value: 'e3287024050aef46b6d6954e5e8ab6f59294eaad'}
== 迁移头 ==
9:  expected_schema_revision: '20261019_0010'
plan knowlab exit=0
TASK [Require the configured schema to match the immutable source chain] *******
        "schema": "20261019_0010",
localhost                  : ok=16   changed=0    unreachable=0    failed=0    skipped=7    rescued=0    ignored=0
```

逐项对卡：构建/暂存/计划 都是 0 ✓；变了的镜像锁 **3 个**，且 `source_revision` 正是后端 `e3287024…`、网页 `d7589583…`、管理端 `2d5c1124…` ✓；暂存产物只有 knowlab 三件（2+8+2=12 文件）✓；越界闸门空（别的应用零变化）✓；三个运行时 diff 除镜像与摘要外**各只有 `DEPLOYMENT_ID`** ✓；迁移 workload diff 只有 `DEPLOYMENT_ID`（`EXPECTED_SCHEMA_REVISION` 未出现在 diff 里，即仍是 `20261019_0010`）✓；计划核到 `20261019_0010`、`failed=0` ✓。`key-check-done` 前无文件名 ✓。

### 7.4 3.3 提交、发布、晋级、检查（qwen-013 的 2.3，**末尾 `git push` 按本卡明令跳过**）

```text
commit exit=0
33024551 deploy(knowlab): 测试通过不再随刷新自动交付（qwen-017）
release exit=0
localhost                  : ok=30   changed=8    unreachable=0    failed=0    skipped=22   rescued=0    ignored=0
promote-file exit=0
chown exit=0
1:digest: sha256:7812a0d1f2d5a066c16a8caa38b0ecce2b672b4e6606be76927e12e450007ac0
2:path: ./clusters/kind
3:repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
5:revision: 33024551cddc44ada0b2e16980a019d018d1f4f6
release-commit exit=0
061d2bbd release(kind): 晋级到 33024551（qwen-017）
apply exit=0
localhost                  : ok=38   changed=3    unreachable=0    failed=0    skipped=28   rescued=0    ignored=0
kustomization …/knowlab-admin condition met
kustomization …/knowlab-database condition met
kustomization …/knowlab-identity condition met
kustomization …/knowlab-knowbench-testrun-identity condition met
kustomization …/knowlab-knowmart-deliver-identity condition met
kustomization …/knowlab-migration condition met
kustomization …/knowlab-rabbitmq condition met
kustomization …/knowlab-redis condition met
kustomization …/knowlab-runtime condition met
kustomization …/knowlab-storage condition met
kustomization …/knowlab-web condition met
wait exit=0            （11 个 knowlab kustomization 全 Ready）
check knowlab exit=0
                "admin_list_read": true,
localhost                  : ok=50   changed=0    unreachable=0    failed=0    skipped=24   rescued=0    ignored=0
```

迁移 Job（卡面 `get jobs | grep knowlab-migrate | tail -2` 取到的是字母序旧 Job——qwen-014 擞过同一个坑，故改按新 digest 名直查）：

```text
NAME                              STATUS     COMPLETIONS   DURATION   AGE     IMAGES
knowlab-migrate-57ac0aeb69b5-v1   Complete   1/1           8s         6m31s   harbor.sunmoonai.com:30443/platform/knowlab-backend@sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5
job-query exit=0
```

各 deploy 镜像摘要与锁对齐（改卡口径：前端摘要会变，各自和自己的 `image.lock` 一致就算过）：

```text
knowlab-api       = …/knowlab-backend@sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5
knowlab-worker    = …/knowlab-backend@sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5
knowlab-scheduler = …/knowlab-backend@sha256:57ac0aeb69b53a21c117413d4651511631be49fc7929bc7ef7d258e807951fe5
knowlab-web       = …/knowlab-web-frontend@sha256:5c43b733dbdfc22da11770620062697263afb27cb14f05c40a2ab591abeb9cc0
knowlab-admin     = …/knowlab-admin-frontend@sha256:57422c78f2f4701ca14b1aab5f2ddc0c8cc798157f76637bb3c59189eced5f1e
image.lock 对照：backend 57ac0aeb69b5… / web 5c43b733dbdf… / admin 57422c78f2f4…  → 五者逐一对上 ✓
knowlab-admin-5894d8bcd7-xksvm    1/1 Running 0 4m33s
knowlab-api-79477dcf8d-mzrrq      1/1 Running 0 4m56s
knowlab-scheduler-66865f4f9f-xxtx6 1/1 Running 0 4m55s
knowlab-web-79979c7c9d-72jz5      1/1 Running 0 4m26s
knowlab-worker-5786f55bcd-scfnd   1/1 Running 0 4m56s
```

五个 Pod 均 1/1 Running、0 重启；无新迁移（Job 照样跑一次、`Complete 1/1`、8s）。

### 7.5 第四节上线后核

第 1 行（Qwen）原文：

```text
$K -n app-platform-dev logs deploy/knowlab-api --since=10m | grep -E "Traceback|ERROR"
grep exit=1 (1=无命中)
== api 启动尾（只取最后 4 行，均为 WARNING/INFO 级）==
2026-10-20 07:16:32 - app.interfaces.errors.exception_handlers - WARNING - application_error status=403 code=forbidden path=/api/auth/admin/logout
2026-10-20 07:16:32 - app.bootstrap.api - INFO - audit_mutation method=POST path=/api/auth/admin/logout status=403 actor_id=- …
2026-10-20 07:16:32 - app.bootstrap.api - INFO - audit_mutation method=POST path=/api/auth/admin/logout status=200 actor_id=- …
2026-10-20 07:16:32 - app.interfaces.errors.exception_handlers - WARNING - application_error status=401 code=auth_required path=/api/auth/admin/me
```

**零命中** ✓（无 `Traceback`、无 `ERROR`）。那几条 403/401 WARNING 是 `application-check` 自己跑真实登录/登出探测留下的审计行，属检查过程正常输出，不是新后端报错。

第 2–4 行：**所有者 2026-10-20 夜裁定「不要了」，三行取消，不再核**。下表原样留着作记录（判据一字未改），「所有者所见」一列由「待填」改记取消；Qwen 没有替所有者去点页面，也没有拿别的东西冒充这三行的结果。

| # | 做什么 | 要看到 | 所有者所见 |
| --- | --- | --- | --- |
| 2 | 管理端 `/zh-CN/avatars`，admin 登录、硬刷新、点分身 1.3 | 页面正常、**不出现「读取失败」**；分身 1.3 仍写「已交付 knowmart，专家编号 084acc72…」 | 不要了（所有者取消，未核） |
| 3 | web端 `/zh-CN/avatars`，sig-am 登录 | 页面正常、不出现「读取失败」；看得到分身 1.3 | 不要了（所有者取消，未核） |
| 4 | 管理端「专家」`/zh-CN/experts` | 「财务分析与预测」第 1 版仍在 | 不要了（所有者取消，未核） |

按卡面「不做的」：没去点「刷新结果」「交付」来试（现在没有通过而未交付的分身，点了也看不出什么；新行为由后端测试保证）。

**这三行取消意味着什么，如实写清**：第 1 行（Qwen 侧 api 日志零命中）与 3.3 的 `application-check`（`ok=50 failed=0`、`admin_list_read: true`）、五个 deploy 摘要对齐仍是既得证据，但**页面层的三项人眼确认从此没有证据**——「读取失败」不再出现、分身 1.3 仍写已交付、「财务分析与预测」第 1 版仍在，都只到命令行能证的那一层为止。后面若有人在页面上看到不符，不能拿本回执当「已核过」。

### 7.6 第二次的纪律与清理

- 未推：Qwen 一次 `git push` 都没跑。第二次做完时本地 ahead 4（`5227c512` 第一次停点回执、`33024551` 换钉与 gitops、`061d2bbd` 晋级、`6bbf88e9` 第七节），**这 4 个已由所有者的 human-remote.sh 推上远端**——2026-10-20 夜只读核验：`HEAD == origin/qwen == 7e9619db`、`ahead/behind = 0/0`，且 4 个提交都被 `origin/master`、`origin/qwen`、`origin/fable`、`origin/luna`、`origin/kimi`、`origin/cursor` 包含。7.5 这三行取消的补写（本笔）是先本地提交，随后**所有者 2026-10-20 夜授权 Qwen 直接 `git push origin qwen`**（README 第 99 行的例外之外的单次授权，非长期改规；推前 fetch 确认能快进、不强推）。
- 未写库；本轮只读 SELECT 共一条（第二节 `testing` 0 行）；未 `rollout restart`（受 flux 管的部署全靠 flux reconcile）；未碰 knowbench/knowmart/测试电脑/沙箱。
- 一次性产物：`/tmp/q017-run32.sh`、`/tmp/q017-run33.sh` 两个临时脚本，与 `/tmp/q017-build-knowlab.log`（改卡明令不用留）、`q017-stage-knowlab.log`、`q017-plan-knowlab.log`、`q017-release.log`、`q017-apply.log`、`q017-check.log`、`q017-pin2.log`、`q017-32b.log`、`q017-33.log`、`q017-sec4.log`——关键原文已全抄进本回执，**全部删除**；仓内无 `scripts/tmp-*`、无残留脚本。

### 7.7 第二次的结论

7 行钉全换后应用级构建、暂存、计划、提交、发布、晋级、flux wait、`application-check` 全部 exit=0；三个镜像锁对应三个源修订，五个 deploy 的摘要与各自 `image.lock` 逐一对上；迁移头仍 `20261019_0010`（无新迁移，Job `Complete 1/1`）；api 日志无 `Traceback`/`ERROR`；越界闸门空（别的应用零变化）。「测试通过不再随刷新自动交付」与「用户没要的交付回 409」已随 knowlab 后端 `e3287024…` 上线；两个前端按改卡重建，代码与线上一字不差、摘要已变。**本卡到此结案**：第四节第 2–4 行原是唯一悬着的项，所有者 2026-10-20 夜裁定不要了（见 7.5，含「页面层三项从此没有证据」的如实交代），Qwen 侧再无待办。
