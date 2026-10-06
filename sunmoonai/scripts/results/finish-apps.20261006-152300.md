# 待办 23b：同步锁、构建 knowledge、暂存

- 工位：`~/worktrees/fable/k8s`
- 开始时 HEAD：`c8a9dc68`
- 结论：**不通过**。第四节的过滤命令有输出，按待办停下。第五、六、七节没有做。待办 24 没有做。没有 flux-release、没有晋级、没有部署。

## 一、核对

`application-lock-backend` 的 `make -n` 退出 0。investment 后端配置里能看到 `enabled: true`。`.build/applications/` 里有 tpl、info、investment 各三个 `*-deployment-image.yaml`，共 9 个。

## 二、同步 9 个锁

九次 `application-lock-*` 都退出 0。`git status` 里 `image.lock` 是 9 个。tpl backend 的 `source_revision` 已是 `834dff5a8e0cbbc399d61f5f26c211f1283d4d1d`。九个新 digest 前 12 位：

| 锁 | digest 前 12 位 | source |
| --- | --- | --- |
| tpl-backend | `e92a7bb62f06` | `834dff5` |
| tpl-web | `39650d73027c` | `a398a63` |
| tpl-admin | `0efb051259f2` | `3a0c88f` |
| info-backend | `9e536b0ad5e4` | `89d6598` |
| info-web | `a2749a27479d` | `58f01b6` |
| info-admin | `c7c096d48d0a` | `27bc4c9` |
| investment-backend | `86a20079c309` | `a49577a` |
| investment-web | `64d475b29ea0` | `c7c955d` |
| investment-admin | `7060113659a0` | `469cadc` |

## 三、构建 knowledge

`platform-build OBJECT=app-platform/knowledge-app` 退出 **0**，用时 **151 秒**（15:18:56–15:21:27）。之后 `image.lock` 共 **12** 个。三个新 digest 前 12 位：

| 锁 | digest 前 12 位 | source |
| --- | --- | --- |
| knowledge-backend | `be3c4269ce1a` | `f75996b` |
| knowledge-web | `a35fd8c0c7f1` | `e61eff3` |
| knowledge-admin | `b4c23cdcd7e0` | `ee6b897` |

## 四、tpl 暂存

`platform-stage OBJECT=app-platform/tpl-app` 退出 **0**。过滤镜像行之后仍有 **179** 行。不是新字段，是这些：

- 三个 `image.lock.yaml` 的说明注释换了措辞
- 多份 `*.sops.yaml` 里已有口令、`DATABASE_URL`、`clients.json` 的密文被重写，附带的 age 块、`mac`、`lastmodified` 一起变了（`2026-10-03` → `2026-10-06T07:22`）

密文正文没有贴进这份回传。涉及文件：`tpl-backend` 的 database、identity、migration、rabbitmq、redis、runtime 下的 sops，以及三个组件的 workload 和 image.lock。

## 五至七

没有做。工作树里还留着这 12 个锁和 tpl 暂存的改动，这一份回传没有把它们提交进去。
