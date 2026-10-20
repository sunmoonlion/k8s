# fable-b1 第二次接续：第三、四节通过，入口已恢复

时间：2026-10-20，Asia/Shanghai。被测仓 k8s，本地 fable 工位，分支 fable。

输入提交 `b2b1b47c1ed22809a41bee2ec226c0c3064d7687`；任务卡为 [2026-10-20-fable-b1-jenkins-controller.md](../../docs/dev-investment-agent/switch-test/done/2026-10-20-fable-b1-jenkins-controller.md) 的“第二次接续”。按卡从第三节 bash 块继续，TLS curl 用 sudo -n 读取 root 0700 目录下的 CA；没有重复物料准备、口令导入或 Jenkins deploy。

**结论：第三、四节 pass，所有本轮执行命令退出 0；第五节所有者走查未验。** 控制器仅回环，TLS/HTTP login 均 200、匿名 API 403；入口新增 Jenkins 路由后 Jenkins login 200、Harbor health 200，最终 platform-status 退出 0 并显示 Jenkins active/enabled。

## 原始输出索引

全部 stdout/stderr 原样保留，每份 txt 最后一行 exit=0。未改第一次的日志或回执。

| 日志 | 命令 / 范围 | exit |
| --- | --- | --- |
| [01-controller-checks](fable-b1.20261020-175616.01-controller-checks.txt) | `第三节独立 ss、三个 curl、systemctl` | 0 |
| [02-entry-preview](fable-b1.20261020-175616.02-entry-preview.txt) | `make -C infrastructure entry-preview` | 0 |
| [03-entry-idle](fable-b1.20261020-175616.03-entry-idle.txt) | `30443 活跃连接计数（只读）` | 0 |
| [04-entry-stop](fable-b1.20261020-175616.04-entry-stop.txt) | `make -C infrastructure entry-stop` | 0 |
| [05-entry-deploy](fable-b1.20261020-175616.05-entry-deploy.txt) | `make -C infrastructure entry-deploy` | 0 |
| [06-entry-checks](fable-b1.20261020-175616.06-entry-checks.txt) | `经入口 Jenkins login 与 Harbor health 的 sudo curl` | 0 |
| [07-platform-status](fable-b1.20261020-175616.07-platform-status.txt) | `make -C infrastructure platform-status` | 0 |

## 第三节独立核对（完整原文）

```text
2026-10-20T17:56:16+08:00
$ git rev-parse HEAD
b2b1b47c1ed22809a41bee2ec226c0c3064d7687
Second continuation: resume section 3 bash block; do not redeploy or re-import.
$ bash -o pipefail -c sudo\ -n\ ss\ -ltnp\ \|\ grep\ -E\ \':18443\|:18080\|:50000\'
LISTEN 0      4096        127.0.0.1:50000      0.0.0.0:*    users:(("docker-proxy",pid=3132619,fd=8))
LISTEN 0      4096        127.0.0.1:18443      0.0.0.0:*    users:(("docker-proxy",pid=3133399,fd=8))
LISTEN 0      4096        127.0.0.1:18080      0.0.0.0:*    users:(("docker-proxy",pid=3132590,fd=8))
command exit=0
ports listed above must all be 127.0.0.1
$ sudo -n curl -sS -o /dev/null -w tls\ login\ %\{http_code\}\\n --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/login
tls login 200
command exit=0
$ curl -sS -o /dev/null -w http\ login\ %\{http_code\}\\n http://127.0.0.1:18080/login
http login 200
command exit=0
$ sudo -n curl -sS -o /dev/null -w anonymous\ api\ %\{http_code\}\\n --cacert /etc/sunmoon/registry/tls/ca.crt https://127.0.0.1:18443/api/json
anonymous api 403
command exit=0
$ bash -o pipefail -c systemctl\ show\ sunmoon-jenkins.service\ --property=ActiveState\,UnitFileState\,WantedBy\ \|\ cat
WantedBy=sunmoon-platform.target
ActiveState=active
UnitFileState=enabled
command exit=0

checks exit=0
exit=0
```

本轮修正只涉及卡给出的执行身份：用 sudo -n curl，--cacert 与地址及 HTTP 判据保留，没有降低 CA 目录权限、复制证书或关闭 TLS 校验。

## 第四节入口维护

entry-preview 计划中原文为：

```json
{"backend":"127.0.0.1:18443","hostnames":["jenkins.sunmoonai.com"],"name":"jenkins"}
```

维护前只读统计 30443 为 6 条活跃 TCP 连接，因此先按卡的“选个没人在用的时候做”询问所有者。所有者在本会话明确回答 **“现在可以切换”** 后，才依次 entry-stop、entry-deploy。均退出 0，没有外层重试或回退。deploy 内置的 Harbor 就绪等待出现一次有限重试，最后成功。

两次 Make 的完整记录见上面的 04、05；时间以各自原始首行为准，没有把命令总耗时当成精确停机秒数。经入口的两项检查完整原文：

```text
2026-10-20T17:59:19+08:00
Section 4 certificate-verified SNI checks
$ sudo -n curl -sS -o /dev/null -w via\ entry\ %\{http_code\}\\n --cacert /etc/sunmoon/registry/tls/ca.crt --resolve jenkins.sunmoonai.com:30443:127.0.0.1 https://jenkins.sunmoonai.com:30443/login
via entry 200
command exit=0
$ sudo -n curl -sS -o /dev/null -w harbor\ still\ %\{http_code\}\\n --cacert /etc/sunmoon/registry/tls/ca.crt --resolve harbor.sunmoonai.com:30443:127.0.0.1 https://harbor.sunmoonai.com:30443/api/v2.0/health
harbor still 200
command exit=0

checks exit=0
exit=0
```

最后 platform-status 的服务清单原文节选（完整输出见 07）：

```text
Id=sunmoon-entry.service
ActiveState=active
UnitFileState=disabled

Id=sunmoon-jenkins.service
ActiveState=active
UnitFileState=enabled
```

Jenkins 的 WantedBy=sunmoon-platform.target 已在第三节独立核对。entry 的 disabled 与原启动策略一致，本卡没有启用它的开机管理。平台状态命令整体 exit=0；只读查集群状态，没有发布、apply、改应用或操作 Harbor 数据。

## 同步与交接说明

第一次回执已发布在 `76475d0f2b8219b9dae3d9e18c5abfadff2e2e8c`，对应 [第一次停点回执](fable-b1.20261020-173741.md)。读新 inbox 之前，远端尚未更新，本地多提交了一页交接说明并移动旧卡（未推提交 34939cec）。随后远程接续卡 b2b1b47c 抵达，--ff-only 报分叉，按规则没有合并、变基或强推。

经核对该本地提交只有自己未推送的交接文档后，已留本地备份引用 `backup/fable-b1-handoff-34939cec`，用 git reset --keep 撤回到已发布的 76475d0f，再正常 --ff-only 快进到 b2b1b47c。第一次回执与原始输出保留；本地备份引用不推送。本次按更新卡实际完成接续。封装前再次快进到 `c55fbfaf6df0027f07a811996c98c2de36eb36fa`，新增变化仅是协作规矩按 WS 参数化及本卡工位说明，部署真源与检查判据未变，本卡仍为 WS=fable。随后只提交新回执、原始输出及卡的归档，不提交产品代码、锁或配置改动。

## 尚未验的部分

- 第五节浏览器登录：需所有者自行打开 https://jenkins.sunmoonai.com:30443/ ，按密码表第 13 项亲自登录，核对空实例、没有任务、没有插件与执行器 0。本轮没有代填或代点，也没有把剧本内身份检查冒充浏览器走查。
- 同域名从边缘访问的 404 尚未实测。
- 0033 下一步宿主 agent、插件、render-check/release 流水线不在本卡范围，未执行。

本轮日志已做有限秘密格式检查，未读密码或私钥来比对；部署中的私有输入仍由原剧本管理，回执没有凭据值。`exit=0` 表示本轮命令与第三、四节判据通过，不表示第五节已由所有者验收。原卡按平台线新流程归档到 done；第一次失败证据不删不改。

exit=0
