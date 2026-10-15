# R4-opus — 远程机同步配置

- 执行人：Opus（远程机）
- 时间：2026-10-15 14:25（远程机时间）
- 依据：`k8s/docs/rename.md` R4 节；R3「通过」。

## 1. `~/five-repos-sync/config.sh`

改前备份 `config.sh.bak-rename`。只改 `REPOS` 里两行：

```text
19c19
<   "knowledge-app"
---
>   "knowbase-app"
21c21
<   "info-app"
---
>   "knowfeed-app"
```

`bash -n` 通过。

## 2. `repos.conf`

```text
4:$HOME/master/knowfeed-app
6:$HOME/master/knowbase-app
```

由 R3 脚本改、所有者在远程机提交推送（`toolboxes` `e8f584e`）；本地机已由所有者拉到同一提交。

## 3. 同步脚本

`switch-test/human-local.sh`、`human-remote.sh`（qwen 分支，R1 已改）里的仓表与子仓路径都是新名字（`FIVE="k8s knowfeed-app investment-app knowbase-app tpl-app"`，子仓 `knowfeed-app/knowfeed-backend` 等）；`sync-five-repos.sh` 本身不写仓名，读 `config.sh` 的 `REPOS`。`~/switch-test/human-*.sh` 是转发器，不用改。

远程机这一半完成。本地机 Qwen 改 `config.sh` 并核对 `repos.conf` 后，跑 `WS=qwen bash ~/switch-test/human-local.sh`。

exit=0
