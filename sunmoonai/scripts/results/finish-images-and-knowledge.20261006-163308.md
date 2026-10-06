# 待办 26 回传续：finish-images-and-knowledge

时间：2026-10-06 16:33。重跑前 HEAD `cd229248`（在 `86d8f6de` 之后）。工作区干净。`download-modes.json` 国内模式的 `debian_mirror` 是 `http://mirrors.tuna.tsinghua.edu.cn`。

## 一、上一份日志仍是证书问题

`infrastructure/.build/applications/sandbox-build-domestic.log`（被这次构建覆盖前）里，清华镜像走的是 `https://mirrors.tuna.tsinghua.edu.cn`。摘录：

```text
33: SSL connection failed: error:0A000086:SSL routines::certificate verify failed / Success [IP: 101.6.15.130 443]
39: W: Failed to fetch https://mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie/InRelease  SSL connection failed
40: W: Failed to fetch https://mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie-updates/InRelease  SSL connection failed
41: W: Failed to fetch https://mirrors.tuna.tsinghua.edu.cn/debian-security/dists/trixie-security/InRelease  SSL connection failed
52: E: Package 'ca-certificates' has no installation candidate
```

## 二、沙箱重建

`platform-build OBJECT=sandbox-platform/sandbox` 退出 0，用时 76 秒（16:28:58–16:30:14）。日志：`infrastructure/.build/applications/sandbox-build-domestic.log`（16:29，34078 字节）。没有 `official-proxy` 那份。

锁 diff：去掉 `harbor_project: app-images`，digest 从 `sha256:ba14b8d3f69e…` 换成 `sha256:e758ccb23d40e07f53c4e26b9473bb26d5425ef80848e15d5a7ca4eb88a75c3b`，`source_revision` 从 `kind-sandbox-0155-r2` 换成 `e3ce871f96d160aa2017960e98d176c102b991e4`。

## 三、会合点、供给器再暂存

会合点暂存退出 0，用时 25 秒。`git diff gitops/components/relay-platform` 为空。

供给器暂存退出 0，用时 16 秒。`SANDBOX_IMAGE`：

- 旧：`harbor.sunmoonai.com:30443/app-images/sandbox@sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f`
- 新：`harbor.sunmoonai.com:30443/platform/sandbox@sha256:e758ccb23d40e07f53c4e26b9473bb26d5425ef80848e15d5a7ca4eb88a75c3b`

## 四、knowledge 暂存

退出 2，用时 33 秒（16:31:27–16:32:00）。失败任务：`Preserve non-overwritten domain input backup`（`common/backend/domain/prepare.yaml:119`）。原话：`Source /etc/sunmoon/applications/sunmoon-kind/knowledge/domain.yaml not found`。

私有目录和备份里都没有 `domain.yaml`。同目录已有 identity、redis、rabbitmq、credentials、provider、tls，没有这份。knowledge 的 `domain_secrets` 只有 `KNOWLEDGE_MCP_JWT_PUBLIC_KEY`，来源是 `workbench-signing` 的 `public_key_pem`，不是 `random`，所以「第一次生成随机值」被跳过，随后无条件复制备份时源文件不存在。`workbench-signing` 的读取在这个复制备份之后。没有改配置，没有新建 `domain.yaml`。knowledge 的 gitops 没有新改动，因此没有密文计数，两段 workload diff 为空。`gitops/` 里没有 `BEGIN PRIVATE KEY` / `BEGIN PUBLIC KEY`。

## 五、部署计划

| 计划 | 退出码 | 用时 | 结论 |
| --- | --- | --- | --- |
| tpl | 0 | 4s | schema `20260911_0003` |
| info | 0 | 4s | schema `20260929_0013` |
| knowledge | 0 | 4s | schema `20260927_0007` |
| investment | 0 | 4s | schema `20260929_0012` |
| platform-plan OBJECT=all | 0 | 1s | 退出 0 |

## 六、提交

`602a6791 test(local): 待办 26 沙箱锁、会合点与供给器再暂存、knowledge 候选`。2 个文件：沙箱锁、供给器 `workload.yaml`。knowledge 不在其中。

## 结论

不通过。沙箱镜像、供给器的 `SANDBOX_IMAGE`、会合点再暂存、五个计划都过了。knowledge 暂存退出 2，`domain.yaml` 不存在。
