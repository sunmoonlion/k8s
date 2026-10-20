# fable-b2：物料与控制器通过，代理克隆任务失败

2026-10-20，Asia/Shanghai；WS=fable，k8s 分支 fable。执行版本 `d549d18bd246beff32efb504053c51154096d0aa`；任务卡 [fable-b2](../../docs/dev-investment-agent/switch-test/done/2026-10-20-fable-b2-agent-render-check.md)。

**本轮未完成 B2。停在第四节 `make -C infrastructure jenkins-agent-deploy`，exit=2。** 失败任务 `Clone missing repos as the agent user`，循环项层级引用错误，尚未执行克隆。停止后只作只读诊断、写回执；没有重试、回退、手动克隆或修改产品代码。

## 各节与完整原始输出

stdout/stderr 完整保留在下列文件，未截断或覆盖；末行均写实际 exit。

| 日志 | 范围 | exit |
| --- | --- | --- |
| [01-preflight](fable-b2.20261020-182305.01-preflight.txt) | HEAD、文件、Make 目标、控制器 status；SSH 的 heredoc 包装执行有误，见下文 | 1 |
| [02-ssh-precondition](fable-b2.20261020-182305.02-ssh-precondition.txt) | 修正 SSH 的 stdin 接法；GitHub 认证成功、全局无 insteadOf | 0 |
| [03-materials](fable-b2.20261020-182305.03-materials.txt) | `make -C infrastructure jenkins-materials`，归档与 77 项文件大小、SHA-256 校验 | 0 |
| [04-material-count](fable-b2.20261020-182305.04-material-count.txt) | 文件总数 77：hpi=76、tar.gz=1 | 0 |
| [05-controller-stop](fable-b2.20261020-182305.05-controller-stop.txt) | `make -C infrastructure jenkins-stop` | 0 |
| [06-controller-deploy](fable-b2.20261020-182305.06-controller-deploy.txt) | `make -C infrastructure jenkins-deploy`，插件、启动脚本、TLS 与管理员身份、匿名拒绝、节点存在检查 | 0 |
| [07-controller-checks](fable-b2.20261020-182305.07-controller-checks.txt) | `jenkins-status` 与第三节四项独立检查 | 0 |
| [08-agent-plan](fable-b2.20261020-182305.08-agent-plan.txt) | `make -C infrastructure jenkins-agent-plan` | 0 |
| [09-agent-deploy](fable-b2.20261020-182305.09-agent-deploy.txt) | `make -C infrastructure jenkins-agent-deploy`，在克隆任务模板求值时失败 | 2 |
| [10-stop-diagnostics](fable-b2.20261020-182305.10-stop-diagnostics.txt) | 停点后的服务状态、完整代理与控制器 journal、空 repos 目录、经入口两项 TLS 检查 | 0 |

第一节初始工作区干净。01 中 `git status` 看到的是执行时刚创建的本轮原始日志，不是产品改动。控制器 status=0、active/enabled。初始执行把 SSH 放进 `bash` heredoc，SSH 继承脚本 stdin，吞掉后续语句，外层 exit=1，捕获的认证输出也没被打印。这是本地命令包装错误。修正为 `ssh -n` 且以 DEVNULL 提供 stdin 的独立检查，没有变更 SSH 认证判据、部署脚本或产品代码。02 的原文：

```text
Hi sunmoonlion! You've successfully authenticated, but GitHub does not provide shell access.
ssh exit=1
no insteadOf (fine: the playbook sets it per command)
exit=0
```

GitHub SSH 的 exit=1 是卡明确认可的正常结果；原始包装失败没有改写成成功或删除，没有重跑控制器状态检查来覆盖 01。

## 第二、三节已通过

物料总数与锁一致。容量守卫保留 10 GiB 底线；本轮没有临时容量例外。控制器 stop/deploy/status 均 exit=0，deploy 的登录页就绪等待由剧本内有限重试后通过，无外层重试。

第三节独立核对原文：

```text
status exit=0
ref-plugins count=76
01-platform.groovy
02-agent-node.groovy
03-render-check.groovy
node secret written
home plugins jpi count=76
```

控制器最终 `ActiveState=active`、`SubState=running`、`UnitFileState=enabled`，`WantedBy=sunmoon-platform.target`。新代理节点密钥由本次节点初始化生成，是 B2 预期的新身份；没有重新生成既有管理员口令、服务密钥或证书。插件数量是文件数量，未把“至少 70 插件”的剧本 API 检查写成独立核实全部 76 插件 active。

另一个事实应由远程评估：`jenkins-stop` 虽然 exit=0，但其最终状态输出为 `ActiveState=failed`。10 的 journal 记录 Compose 主进程正常停止流程后以 143 退出，systemd 标成 exit-code。按卡接续的 deploy 已恢复 active/enabled，没有额外 reset-failed、修单元或掩盖状态。journal 还记录 Built-In Node 被磁盘监视器临时置 offline；该节点原本执行器 0，本轮未改监视器阈值，宿主代理尚未安装，不能把这条记录认成代理上线失败。

## 第四节停点

失败原文节选，完整七项循环输出见 09：

```text
TASK [Clone missing repos as the agent user]
[WARNING]: Failed to template loop_control label: object of type 'str' has no attribute 'item'
Origin: infrastructure/jenkins/tasks/workspace.yaml:36:12
[ERROR]: Task failed: Finalization of task args for 'ansible.builtin.command' failed: Error while resolving value for 'argv': object of type 'str' has no attribute 'stdout'
Origin: infrastructure/jenkins/tasks/workspace.yaml:29:3
make: *** [Makefile:195: jenkins-agent-deploy] Error 2
exit=2
```

源文件第 34 行遍历 `repo_origins.results`；每项 `item.stdout` 才是 URL，`item.item` 已经是仓名字符串。第 33 行却读 `item.item.stdout`、`item.item.item`，第 36 行 label 同样多取一层。这是产品剧本缺陷，交远程修，不在本地改。

已产生的副作用：

- 已创建代理和仓目录，安装并校验锁定 JRE（java、libjvm.so 两个成员），设置 current 链接。
- 已从自己的控制器取得 `agent.jar`，给宿主代理用户写入节点密钥的只读副本（原剧本 no_log，不读取或抄写密钥值）。
- 七个 origin 已读到且通过无嵌入凭据检查；模板失败发生在命令执行前，repos 目录为空。
- 代理 systemd 单元尚未落盘；只读状态为 `LoadState=not-found`、`ActiveState=inactive`，代理 journal `-- No entries --`。仓、子模块、.venv、.tools 安装尚未发生。

第五节 `jenkins-agent-check`、第六节边缘与总状态、第七节所有者走查均未执行；没有成功构建或 diff.txt 证据。render 没有跑，不存在已核实的应用身份生成行为，也不声明 B2 通过。

停点后独立验证入口（CA 与主机名均校验，`--resolve` 仅定位本机入口）：

```text
jenkins login 200
harbor health 200
```

没有重启内网入口、改集群声明、发布应用、写库或操作 Harbor 数据。

## 交回

已另写 `inbox/fable/2026-10-20-fable-b2-clone-loop.md` 请求远程修复并发第四节接续卡；物料和控制器安装不必盲目重做。也提醒第六节原有 `curl -sk` 会关闭证书校验，与现行约束不符，请远程给出保留校验的边缘验证方式；本轮未执行该命令。

原任务卡仅归档到 done，表示本次执行已交回，不代表验收通过。只提交本轮回执、原始日志、卡移动及远程收件页，不改代码或判据。日志做了有限秘密格式扫描，未读真实秘密来比对，不能将此当作全面泄漏审计。

exit=2
