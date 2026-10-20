# fable-b2c：代理部署通过，手动构建提交返回 HTTP 400

2026-10-20，Asia/Shanghai；WS=fable，k8s 分支 fable；执行版本 `a686ce59fe4aa14e7ca3c7053ee1e3431a35afec`。任务卡：[B2c](../../docs/dev-investment-agent/switch-test/done/2026-10-20-fable-b2c-agent-continue.md)。

**第二节代理部署与核对通过；第三节 `jenkins-agent-check` 在提交构建时 HTTP 400、Make exit=2，已停止后续执行。B2 尚未通过。** 未重跑失败目标、未改产品代码、未重新安装物料或启停控制器。第四节边缘与总状态、第五节所有者走查未执行。

## 完整原始输出

| 日志 | 范围 | exit |
| --- | --- | --- |
| [01-preflight](fable-b2c.20261020-191232.01-preflight.txt) | HEAD、insteadOf=5、控制器 status、SSH 真实退出码与成功提示 | 0 |
| [02-agent-plan](fable-b2c.20261020-191232.02-agent-plan.txt) | `jenkins-agent-plan` | 0 |
| [03-agent-deploy](fable-b2c.20261020-191232.03-agent-deploy.txt) | 保留七个父仓、fetch、18 子仓检出、工具安装、代理启用及上线核对 | 0 |
| [04-agent-status-and-checks](fable-b2c.20261020-191232.04-agent-status-and-checks.txt) | status=0、单元/目录/子仓；本地检查误数 @tmp，见下文 | 1 |
| [05-repo-count-correction](fable-b2c.20261020-191232.05-repo-count-correction.txt) | 修正本地计数检查：7 个实际 Git 仓、3 个 knowbench 子仓、alternates=0 | 0 |
| [06-render-check](fable-b2c.20261020-191232.06-render-check.txt) | `jenkins-agent-check`，提交 POST 返回 400 | 2 |
| [07-stop-diagnostics](fable-b2c.20261020-191232.07-stop-diagnostics.txt) | 单元、代理/控制器完整时间窗口 journal、本机日志目录、两项入口探针 | 0 |
| [08-timer-build-state](fable-b2c.20261020-191232.08-timer-build-state.txt) | 只读 Jenkins 持久化构建元数据：已有 #1–#5 均为定时来源，无终态 | 0 |
| [09-timer-progress](fable-b2c.20261020-191232.09-timer-progress.txt) | 只读 #1 当前任务名与日志路径，未触发新构建 | 0 |
| [10-latest-timer-state](fable-b2c.20261020-191232.10-latest-timer-state.txt) | 19:22:22 再次只读核对 #1，仍无 result 终态，日志继续增长 | 0 |

日志保留全部 stdout/stderr、实际 exit 和工具原生行尾空白，没有用格式清理改写原始证据。SSH 用 -n，不以 head 的退出码代替 SSH 的真实退出码；提示 successfully authenticated 且退出 1，符合卡。

## 第二节通过证据

七个既有父仓只 fetch；18 个子仓均按源工位自己的 Git 对象库检出成功。tools、install-binaries、install-secrets-tools 三步成功，代理单元创建、enable、启动成功；节点上线由剧本 API 检查确认（内置一次就绪重试，无外层重试）。status 再次 exit=0。独立输出为：

```text
User=zymun
WantedBy=sunmoon-platform.target
ActiveState=active
UnitFileState=enabled
Git repo count=7
alternates count=0
```

`.venv`、`.tools/bin` 均存在；knowbench 三个子仓前缀均为空格，提交分别为 admin `26964553`、backend `44888e23`、web `4748b94e`，与父仓钉一致。原卡的 find 核对用 sudo -n 以免漏掉 root 所有的渲染目录，find 本身 exit=0，结果无 alternates。

04 的失败是本地额外断言写错：我把 repos 下每个目录都计入仓数，Jenkins 在代理上线后自动产生的七个 `@tmp` 目录也被计入，得到 14。status、服务和子仓检查其实已过。05 改为识别有 `.git` 的七个实际仓，并核对其它目录均为 Jenkins 的 @tmp；保留 04 exit=1，未删缓存、未改产品代码或通过标准，也没有重新部署代理来覆盖这次检查错误。

## 第三节停点

原任务 `Queue a forced render-check build`，`infrastructure/jenkins/agent.yaml:250`：

```text
[ERROR]: Task failed: Module failed: Status code was 400 and not [201]: HTTP Error 400: Bad request
Origin: infrastructure/jenkins/agent.yaml:250:11
fatal: [localhost]: FAILED! => {"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result", "changed": false}
make: *** [Makefile:195: jenkins-agent-check] Error 2
exit=2
```

此前 `Wait for the agent to be connected` 与 `Get a CSRF crumb` 都通过。没有禁用 no_log、打印口令或 crumb/cookie、手工重发 POST 或代点页面。第 252 行当前通过查询参数传 BRANCH/APPS/FORCE，没有表单 body；这仅是供远程定位的源事实，尚未确认 400 的服务端原因，不能把猜测记成根因。

本次手动请求没有取得构建编号，尚未走到剧本保存控制台日志的任务；当时调用工位 `infrastructure/.build/jenkins` 不存在，不能虚构该次请求的 render-check-N.log。

## 定时任务的独立事实与副作用边界

代理上线后，控制器原有定时任务已自动执行。19:19 的只读元数据中 #1–#5 均有 TimerTriggerCause，result 仍无终态；#1 显示 `#1 fable@a686ce59fe`，日志增长，正在渲染候选；其它定时构建也没有完成结果。这些不是本次返回 400 的手动提交，不能拿来改写手动检查结果或宣称 SUCCESS。

现有自动渲染会按模块约定读写宿主私有输入及 `.build/` 候选；已看到相关 Ansible 和 SOPS 恢复校验记录。本轮没有取得完整终态日志，尚未证明全部既有应用身份均未发生生成或恢复，不能记作“零身份变化”。没有手工改私有文件、触发发布、写库、改集群或操作 Harbor 数据。

自动 #1 的原生实时日志在 `/mnt/sunmoon-data/jenkins/home/jobs/render-check/builds/1/log`。为便于后续本机诊断，19:20:42 留了当时完整的私有快照（0600），不进 Git：

```text
/home/zymun/worktrees/fable/k8s/infrastructure/.build/jenkins/timer-render-check-1.20261020-192026.snapshot.log
```

它是运行中快照，不是完成构建日志；已核对被 Git ignore。19:22:22 再次只读核对 #1，仍无 result 终态，日志已增长至 416801 字节（见 10）。回执交回时保留自动任务原配置及服务运行，不冒充已验收其最终结果。远程接续需分别核对该自动构建的最终结果与修复手动触发。

## 当前运行状态与交回

控制器和代理均 active/enabled，代理 User=zymun、NRestarts=0、WantedBy=sunmoon-platform.target；代理 journal 有 19:16:03 Connected。正常 CA 和主机名校验的入口探针：Jenkins login 200、Harbor health 200。

本轮只提交回执、原始日志、卡归档与 `inbox/fable/2026-10-20-fable-b2c-trigger-400.md` 请求，不改产品代码或判据。原卡归档表示本轮已交回，第三节仍未通过。日志作有限秘密格式检查，不读取实际秘密作比对；本机控制台快照不入 Git。

exit=2
