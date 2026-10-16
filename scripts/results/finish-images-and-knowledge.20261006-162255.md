# 待办 26 回传：finish-images-and-knowledge

时间：2026-10-06 16:22。HEAD `da32ee05`（在 `0559d44d` 之后）。工作区干净。`git stash list` 为空。`component-images.yaml` 有 `revision: e3ce871f96d160aa2017960e98d176c102b991e4`（第 27 行）和 `timeout_seconds: 3600`（第 35 行）。`knowledge-backend/config.yaml` 第 82 行是 `job_revision: v2`。

## 二、沙箱构建

`platform-build OBJECT=sandbox-platform/sandbox` 退出 2，用时 18 秒（16:22:16–16:22:34）。

失败任务：`Build using the committed recipe and locked base images`（`build-attempt.yaml:65`，命令非零退出）。随后 `Refuse source switching for trust, build or an already official failure`，原话是「证书、身份、签名或完整性校验失败，不切换源、不关闭校验」。

日志只有一份：`infrastructure/.build/applications/sandbox-build-domestic.log`。没有 `official-proxy` 那份。尾部：

```text
#6 8.184 Err:3 https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security InRelease
#6 8.184   SSL connection failed: error:0A000086:SSL routines::certificate verify failed / Success [IP: 101.6.15.130 443]
#6 8.255 Err:2 https://mirrors.tuna.tsinghua.edu.cn/debian trixie-updates InRelease
#6 8.255   SSL connection failed: error:0A000086:SSL routines::certificate verify failed / Success [IP: 101.6.15.130 443]
#6 8.334 Err:1 https://mirrors.tuna.tsinghua.edu.cn/debian trixie InRelease
#6 8.334   SSL connection failed: error:0A000086:SSL routines::certificate verify failed / Success [IP: 101.6.15.130 443]
#6 8.352 E: Unable to locate package python3
#6 8.352 E: Unable to locate package python3-pip
#6 8.352 E: Package 'ca-certificates' has no installation candidate
#6 8.352 E: Unable to locate package git
#6 8.352 E: Unable to locate package ripgrep
#6 8.352 E: Unable to locate package tini
#6 8.352 E: Unable to locate package curl
ERROR: process ... did not complete successfully: exit code: 100
Dockerfile:17 RUN apt-get update && apt-get install ...
```

`DEBIAN_MIRROR` 已换成 `https://mirrors.tuna.tsinghua.edu.cn`。apt 在校验清华镜像证书时失败，随后找不到要装的包。沙箱锁没有改动。

## 三至六

按待办，构建失败后停下。会合点与供给器再暂存、knowledge 暂存、五个计划、第六节提交都没有做。

## 结论

不通过。沙箱构建退出 2，锁仍是旧的 `app-images`。
