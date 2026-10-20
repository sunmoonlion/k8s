# fable-b1：Jenkins 控制器已部署，独立 curl 检查退出 77，按卡停下

时间：2026-10-20 17:37–17:43（Asia/Shanghai）。工位 `/home/zymun/worktrees/fable/k8s`，分支 `fable`。

输入卡：[2026-10-20-fable-b1-jenkins-controller.md](../../docs/dev-investment-agent/switch-test/inbox/luna/2026-10-20-fable-b1-jenkins-controller.md)；基线与任务卡提交均为 `efb232d1b29634154859d34b575de638dece8e4b`。按 switch-test 当前分工，本地 fable 工位执行 inbox/luna 的平台线卡；箱子 README 仍写旧 luna 工位，以本卡与上级当前分工表的明确更正为准。

**结论：本卡尚未全部通过。** 控制器已实际启动，第一次账号预设已导入；第三节独立 curl 读 CA 时失败，按卡“任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回”停止。没有重跑 curl、没有改 CA 权限、没有入口 stop/deploy，也没有继续其它卡。

## 命令与原始输出

每份 txt 保留完整 stdout/stderr 和最后一行 exit；没有截断或改写原始文件。下表链接指向本次原件。

| 原始输出 | 命令 / 检查 | exit | 判定 |
| --- | --- | --- | --- |
| [01-preflight](fable-b1.20261020-173741.01-preflight.txt) | `核对 / platform-status` | 0 | pass |
| [02-materials](fable-b1.20261020-173741.02-materials.txt) | `prepare-host-materials` | 0 | pass |
| [03-account-plan](fable-b1.20261020-173741.03-account-plan.txt) | `platform-account-plan OBJECT=jenkins` | 0 | pass |
| [04-account-import](fable-b1.20261020-173741.04-account-import.txt) | `platform-account-import OBJECT=jenkins` | 0 | pass |
| [05-jenkins-plan](fable-b1.20261020-173741.05-jenkins-plan.txt) | `jenkins-plan` | 0 | pass |
| [06-jenkins-deploy](fable-b1.20261020-173741.06-jenkins-deploy.txt) | `jenkins-deploy` | 0 | pass |
| [07-jenkins-status](fable-b1.20261020-173741.07-jenkins-status.txt) | `jenkins-status` | 0 | pass |
| [08-controller-checks](fable-b1.20261020-173741.08-controller-checks.txt) | `独立 ss / curl / systemctl 检查` | 77 | fail（停点） |
| [10-ca-permissions](fable-b1.20261020-173741.10-ca-permissions.txt) | `停下后的只读路径权限诊断` | 0 | pass |

第一节的同步处理：所有者刚运行 human-local 同步，HEAD 正是卡的提交；遵守 switch-test 本地助手“不 pull、不 fetch”的规矩，省略卡里的重复 `git pull --ff-only origin fable`，改为只读核对当前 HEAD、卡的提交、分支与干净状态。没有改变检查标准或基线；这一差异在此明记。Git 只做本次回执的本地提交，未同步或推送。

## 已通过的部分

- `platform-status` 退出 0。开始前无未提交改动，运行后新增的 Git 文件只有本次 results；首份日志创建后其中的 git status 会列出该日志自身。
- 宿主 Docker `29.8.1`；prepare-host-materials 一次执行成功。haproxy、skopeo 的原归档核验通过；Jenkins 固定 manifest 拉取、完整 blob 校验、Docker 导出文件与冻结锁比较均通过，不存在本卡提示的 Docker 导出字节不一致。manifest `sha256:5e70c4e8c97025f7784858bb5c4380912fc17e5fa0f0afa1d4833700a08666eb`；通过锁校验的 tar 为 246174208 字节，SHA256 `916dd7d36e38460b4fe5600e83ea201e79f56f841fa37a3b8e8022654803a87d`。没有修改锁。
- account-plan 显示 Jenkins/admin 的预设导入能力与私有路径；account-import 退出 0，原文 `preset_changed: true`、`live_account_changed: false`、`table_row: "13"`。仅用卡指定的原生导入入口，没有打开或抄录密码表、没有在界面代填。
- jenkins-plan/deploy/status 均退出 0。部署剧本以 become 权限完成证书校验的 TLS 登录页 200、管理员 whoAmI 身份确认、匿名 API 403。首次就绪等待有剧本自带的有限重试，整个 make 退出 0；没有在外层重试部署。

部署与 status 原文状态均为：

```text
NRestarts=0
Id=sunmoon-jenkins.service
ActiveState=active
SubState=running
UnitFileState=enabled
```

## 停点与原文

第三节独立检查原文完整如下（证书内容没有读取或打印）：

```text
2026-10-20T17:42:10+08:00
$ sudo ss -ltnp | grep -E ":18443|:18080|:50000"
LISTEN 0      4096        127.0.0.1:50000      0.0.0.0:*    users:(("docker-proxy",pid=3132619,fd=8))
LISTEN 0      4096        127.0.0.1:18443      0.0.0.0:*    users:(("docker-proxy",pid=3133399,fd=8))
LISTEN 0      4096        127.0.0.1:18080      0.0.0.0:*    users:(("docker-proxy",pid=3132590,fd=8))
ports listed above must all be 127.0.0.1
$ curl: TLS login
curl: (77) error setting certificate file: /etc/sunmoon/registry/tls/ca.crt
tls login 000

checks exit=77
exit=77
```

因此三个端口只绑 127.0.0.1 已查；独立 TLS curl 失败。后面的 HTTP login、anonymous API curl 与 WantedBy 检查均未执行，不能拿剧本内的检查冒充它们的原文。

只读诊断证实 CA 文件存在且自身为 0644，但两个父目录均为 root:root 0700，当前 zymun 用户无法遍历：

```text
2026-10-20T17:42:53+08:00
Read-only diagnosis after curl exit 77; no curl retry, no permission changes.
$ id -un
zymun
$ sudo -n namei -l /etc/sunmoon/registry/tls/ca.crt
f: /etc/sunmoon/registry/tls/ca.crt
drwxr-xr-x root root /
drwxr-xr-x root root etc
drwxr-xr-x root root sunmoon
drwx------ root root registry
drwx------ root root tls
-rw-r--r-- root root ca.crt
$ sudo -n stat -c "%F %a %U:%G %s %n" /etc/sunmoon/registry /etc/sunmoon/registry/tls /etc/sunmoon/registry/tls/ca.crt
directory 700 root:root 4096 /etc/sunmoon/registry
directory 700 root:root 4096 /etc/sunmoon/registry/tls
regular file 644 root:root 1529 /etc/sunmoon/registry/tls/ca.crt

exit=0
```

这解释了同一路径在 become 的部署剧本里能校验证书、普通用户 curl 却退出 77。建议远程更正独立 curl 的执行身份（例如 sudo 执行 curl），继续保留 --cacert 与原 TLS 判据；本次未自行重试、更改权限、复制证书或关闭校验。

## 当前实际状态与剩余范围

- Jenkins 控制器与随附 TLS 容器已启动，服务 enabled；数据、管理员预设/主备凭据与服务证书按原剧本准备在卡指定的宿主私有目录与数据盘。没有回退或停止这个已成功部署的控制器。
- 第四节未进入：entry-preview、entry-stop、entry-deploy、经入口 Jenkins/Harbor curl、最终 platform-status 均未跑。内网入口没有因本次操作被停下或重部署。
- 第五节所有者浏览器登录、空实例/插件/执行器走查与边缘 404 未验，没有代替所有者登录。
- 未发布、未变更集群声明或应用，未写业务库、未修改 Harbor 数据；物料拉取/缓存与新控制器数据是本卡指定的副作用。Git 中没有产品、配置、锁或任务卡变动，只有本次原始日志与回执。

| 规则 | 对照 |
| --- | --- |
| C-R3 / C-R14 物料锁与单一来源 | 原生入口按既有锁校验；未改摘要或锁 |
| C-R12 秘密与身份 | 只走原生预设导入与部署，保留 no_log；不读私有凭据到对话/回执 |
| C-R13 / C-R18 维护入口与停点 | 只用卡指定 Make 入口；独立 curl 77 后停下，未改脚本或判据 |

后续：所有者用 `WS=fable bash ~/switch-test/human-remote.sh` 回传；远程 Fable 审读本回执并更正卡的检查执行身份。建议新卡从第三节未完成的独立检查接续，复核已有控制器，随后再安排第四节入口维护与第五节所有者走查。不要将本次记为整卡 pass。

exit=77
