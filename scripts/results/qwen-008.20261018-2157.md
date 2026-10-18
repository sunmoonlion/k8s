# qwen-008 回执：测试先不隔离、聊天与项目页加右栏

时间：2026-10-18 21:57（本地）／执行者：Qwen（本地机）
卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-008-test-folders.md`
提交链：拉取到 `ecded738` → 部署提交 `4b298f4a` → 晋级提交 `4e2b9cfe`（HEAD=origin/qwen，双远程已推）

## 一、第一节 核对（全 exit=0）

- `git pull --ff-only origin qwen`：`ecded738`，exit=0。
- 父仓与子仓指针对卡：父仓 `2c504efe`、后端 `51b72eb5`、网页 `4748b94e`、管理端 `26964553`，逐字一致。
- `make -C infrastructure platform-status`：exit=0。

## 二、第二节 改钉（exit=0）

- 卡内 python 改钉脚本 exit=0；`git diff --stat` 只动 `infrastructure/applications/sources.yaml`，5 行（knowbench 块：parent 1 + backend 2 + web 2）；脚本末行打印 `5`。
- 管理端与其它应用字段未动。

## 三、第三节 构建/暂存/计划（日志 /tmp/q008-s3.log，已随回执固化后删除）

- build：exit=0（knowlab-admin 打印「已是这一份 sha256:8d87f3e4937c」，未重编）。
- 镜像锁两行（`source_revision`）：
  - knowbench-backend：`51b72eb5…`
  - knowbench-web-frontend：`4748b94e…`
- stage：exit=0；key-check：`key-check-done` 之前无任何文件名输出。
- `uniq -c` 暂存产物：`9 knowbench-backend`、`2 knowbench-web-frontend`，无其它应用。
- backend runtime workload diff（排除 sha256/digest/image: 行后）只有一行：
  - `- DEPLOYMENT_ID: "knowbench-backend-ff76d83e7e29d27f"`
  - `+ DEPLOYMENT_ID: "knowbench-backend-a93d38dd53e44a24"`
- plan：exit=0；迁移头 `20261017_0020` 不变，`ok=16 failed=0`；无新迁移。

## 四、第四节 提交/发布/晋级/apply/wait/精删/check（全 exit=0）

- deploy 提交 `4b298f4a`（12 files, 33+/33-）；flux-release exit=0。
- 晋级提交 `4e2b9cfe`；flux-source-apply exit=0（ok=38 changed=3 failed=0；容量读数 13:35:54Z c_free=132512006144、remaining=66111979520、passes:true）。
- wait：exit=0，13 个 knowbench kustomization 全 condition met。
- 精删（O3 闭环）：删前 `investment-sandboxes-in` 与 `knowbench-sandboxes-in` 并存；
  `delete networkpolicy investment-sandboxes-in` 打印 `networkpolicy.networking.k8s.io "investment-sandboxes-in" deleted`；
  删后 `get networkpolicy` 只剩 `knowbench-sandboxes-in`。
- application-check knowbench：exit=0，输出含 `"admin_list_read": true`。
- 测试电脑：`knowbench-test-computer-58bdd469cf-zdrt9 1/1 Running 4h54m`。
- `git push origin qwen`：`ecded738..4e2b9cfe` 双远程推送成功。

## 五、第五节 走查（所有者操作，我核截图与日志）

| 行 | 内容 | 判词 | 证据 |
|---|---|---|---|
| 1 | 修订 4 草稿发起测试并刷新结果 | 通过 | 截图：管理端专家草稿卡「走查用：读我的表回答营收 · 第 2 版 · 第 4 稿」，运行方 knowbench、已交付、已发起 1 次；规则出处 3 条「已由 d1c8037c-b552-4015-8f54-4abf3fd56095 逐条核对」；`c1 · 通过 · 期望满足 1/1`；并写明「本次测试没有隔离： 测试电脑的本地代理还不支持建、删目录，在共用的工作区里跑」 |
| 2 | runner 结束行与 /workspace/runs | 通过 | 13:48:45Z runner 日志：`knowbot test run finished run=knowlab-3fdfc0fa-24de-4392-9694-3e8730ed7437-1 status=passed error=`；测试电脑 `ls /workspace/runs` exit=2（不存在，隔离关着本不建） |
| 3 | 「待回答的问题」条件行 | 本轮未触发 | 所有者：没冒（测试一路通过到交付） |
| 4 | 项目页右栏只文件/终端 | 通过 | 所有者确认、免截图：展开后只有「文件」「终端」、无「改动」；文件栏见项目文件树 |
| 5 | 项目内聊天有右栏、项目外无 | 通过 | 所有者确认、免截图：项目内聊天右栏只「文件」「终端」；项目外聊天无右栏 |
| 6 | 窗口 <1024 窄轨与浮层 | 通过 | 所有者确认、免截图：窄轨照留，展开浮在上层不挤中间 |

走查插曲（已排除，非缺陷）：所有者第一张行 5 截图右轨为四栏（工作底稿/文件/改动/终端）。
核实：集群 knowbench-web Pod `knowbench-web-84c8f56fd5-f99m8` 自 13:39:38Z 起即跑新镜像
`sha256:6e1b4307eac329c1a281e103cded91cef4a3639e98c2cf47c2bc91d999811065`（与 image.lock 一致）；源码 4748b94 中项目页与项目内聊天
均只传 `only={['files','terminal']}`（project-screen.tsx、chat-screen.tsx）。判定为浏览器旧缓存包，
硬刷新后所有者确认四/五/六行全对。

## 六、exit 汇总

| 步 | exit |
|---|---|
| 一节 pull/指针/status | 0 |
| 二节 改钉脚本 | 0 |
| 三节 build/stage/key-check/plan | 0 |
| 四节 deploy/release/promote/apply/wait/delete-np/check | 0 |
| 五节 走查六行 | 5 过 + 1 未触发 |

无重试、无退回；密码/key/令牌未进对话、回执与日志。
