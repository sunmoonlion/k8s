# B3：控制器重启通过，但首启脚本的新版 03 没进 jenkins_home，render-check 并发闸仍缺

WS=fable，执行 6cfd59c8。一节全过（三文件在、`SuccessExitStatus=130 143`、两个 status=0、无构建在跑）。二节四个 make 全 0（deploy `ok=69 changed=3 failed=0`），停控制器那行是 `ActiveState=failed`/`Result=exit-code`，按卡面属旧单元、照实记不算失败；`init.groovy.d/` 四份齐、`release job: present`。**卡在并发闸判据**：要「两份 config.xml 计数都是 1」，实际 `render-check:0`、`release:2`。已停止，三节（tpl/`PIN=keep`/构建三镜像）未跑，四、五节未做；没重跑、没改代码、没手改现场任何文件。所有者裁定：等你们修好再跑第三节。

`release:2` 是判据写法：那两行是同一 property 的开标签（37）与闭标签（39），实际**一条**，实质满足。建议判据改成只数开标签，或直接数元素。

`render-check:0` 是真缺。`jobs/render-check/config.xml` 里 `concurrent` 零命中，properties 只有 `ParametersDefinitionProperty` 与 `PipelineTriggersJobProperty`；mtime 停在 **18:32:51**，这次 21:58 重启没重写它（对照 `release/config.xml` 是 21:58:05 新建）。

**根因（只读确证，三层）**：① `docker inspect` 显示 `/opt/sunmoon/jenkins/init.groovy.d` 挂到容器的是 **`/usr/share/jenkins/ref/init.groovy.d`**（镜像 ref 目录），不是 `/var/jenkins_home/init.groovy.d`；② 入口把 ref 拷进 home 时**只拷目标不存在的文件**，故 `04-release.groovy`（新文件，21:57:57）进去了、release job 建成并带闸，而 `03-render-check.groovy` 在 home 里已有 18:32:41 旧版（**1890 字节 / sha `ae317404…`**）未被覆盖——`/opt` 的新版是 **2680 字节 / sha `d4cc9ff9…`**，含 `eca20738` 加的 else 补属性分支；③ journal 里 21:58:05 四份都 `Executing /var/jenkins_home/init.groovy.d/0X-….groovy`、无 SEVERE/Exception，即跑的确实是 home 里那份旧 03，旧版只有 `if (getItem == null)`，任务已存在就什么都不做，所以既没 `addProperty` 也没 `save()`。`01`/`02` 两边 sha 相同（未改过内容），所以只有 `03` 露出这个坑；**以后改 01/02/03 任何一份，重启后同样不会生效**。

时间线：`addProperty` 与 else 分支是 `eca20738` 才加的（提交说明写「控制器重启后生效」），而 18:32 那次部署时工位上还是 `d549d18b` 版；这次是新版第一次部署，第一次撞上 ref→home 的语义。

我没确证的部分（不猜）：运行时 render-check 有没有这条属性只能问 API/CLI，要 crumb 与凭据，卡面明令不读不抄，**没查**；「旧版 03 是否曾以别的方式加过这条」从 `eca20738` 才引入看应是「从没加过」，这句是推断不是实测。

**请修落盘方式，三条候选（选哪条你们定，Qwen 不改实现）**：① 把 `/opt/sunmoon/jenkins/init.groovy.d` 直接挂到 `/var/jenkins_home/init.groovy.d`（最直白；顾虑：home 里那份会被宿主 root 拥有的文件替换，需确认容器内 jenkins 用户读权限与 SELinux/权限位，且首启脚本从此每次都跑新版，等于取消「只建一次不覆盖人改过的」保护）；② 部署时先把 home 里的同名旧份删掉再让入口重拷（保留 ref 语义；顾虑：删的动作要有幂等与备份，别让部署失败时 home 里空着）；③ 文件名带版本（如 `03-render-check-v2.groovy`）绕过「同名不覆盖」（改动最小；顾虑：会攒下历史版本、旧版仍在跑，得同时删旧）。修好后请把 **B3 第三节起**重发一张接续卡（或在本卡注明从第三节续跑），并顺带把二节那条计数判据改成数元素。

现场净变化只有二节授权的那些：代理与控制器各停一次、`jenkins-deploy`（`changed=3`）、代理起一次；副作用是多了 `release` job（带闸、**零构建**）。Harbor 没多任何镜像，`gitops/`、`sources.yaml` 一字未动（`git status --short` 全程空），控制器与代理 active/running/enabled。**卡留在 `inbox/qwen/` 没移 `done/`**（未做完）。完整原文见[回执 fable-b3.20261020-221234](../../../../../scripts/results/fable-b3.20261020-221234.md)（含挂载表、四份 sha256 对照、journal 四行、`git log -S` 证据）；`/tmp/b3-*` 十个日志已删，`infrastructure/.build/jenkins/` 下这轮没产生新构建日志。
