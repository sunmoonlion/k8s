# KIND 诊断：沙箱线程 rollout 有没有写到持久卷 — 2026-09-26

被测仓 k8s `2fc32bd1`（fable）。投资后端仍是 14 的 `4f639f78…`，没有建镜像、没有发版、没有改产品代码。

结论：**B**。发话之后 rollout 写在 `/data/codex/sessions` 下，第二句还让同一个文件变大。回收再拉起后这个文件没了，持久卷的名字和卷名没变。同一会话再发话报 `no rollout found`。没有 `thread resumed`，没有 `thread not found`，没有 `gone on sandbox`。

第 1 步的 `df -h/data` 少了一个空格，改成 `df -h /data` 再跑。通过标准没改。

## 1. 发话前的沙箱

- PID 1 是 `/sbin/tini`，不是 `codex`。Codex 是它的子进程：`codex app-server --listen ws://0.0.0.0:47800`，`codex-cli 0.155.1`。
- `CODEX_HOME=/data/codex`，`HOME=/home/codex`，用户 `codex`（uid 10001）。
- `/data/codex/sessions`、`archived_sessions`、`thread-writer-locks` 当时都不存在。
- `/data` 挂的是 PVC `sandbox-u-a63d03b16693-codex-home`，卷 `pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c`。容器里 `df` 显示 `/dev/sdd`，ext4，可写。
- 分界时间：`2026-09-26T03:26:48Z`。当时的 Pod 是 `sandbox-u-a63d03b16693-65476d4dc9-bg8gp`。

## 3–4. 发话之后文件在盘上

所有者新建会话后先发「在吗」，Codex 回答「在的！有什么可以帮你的吗？」。再发「谢谢！」，Codex 回答「不客气！需要帮忙的时候随时叫我。」

同一路径，属主 `codex`，模式 `600`：

```text
/data/codex/sessions/2026/09/26/rollout-2026-09-26T03-28-32-01a0dbc1-e34d-7ed1-964a-172d1c030222.jsonl
「在吗」之后   41030 字节   Sep 26 03:28
「谢谢」之后   47924 字节   Sep 26 03:30
```

`/data/codex` 下比 `config.toml` 新的非 sqlite 文件只有这一条。`find / -xdev -name 'rollout-*.jsonl'` 没有输出，因为 `/data` 是另一块文件系统，`-xdev` 不跨进去。沙箱近 10 分钟日志里没有 `materialize`、`rollout`、`persist`、`permission`、`denied`、`read-only`、`no space`。

## 5. 回收再拉起之后文件没了

新 Pod `sandbox-u-a63d03b16693-56c87f6b5-gq6fh`，1/1 Running。PVC 名与卷名和回收前一致：

```text
sandbox-u-a63d03b16693-codex-home   Bound   pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c   2Gi
```

volume 与 volumeMounts：

```text
volumes: codex-home -> persistentVolumeClaim claimName=sandbox-u-a63d03b16693-codex-home
         app-server-token -> secret sandbox-u-a63d03b16693 key app-server-token
         kube-api-access（投影，只读）
mounts:  /data <- codex-home
         /secrets/app-server <- app-server-token  readOnly
         /var/run/secrets/kubernetes.io/serviceaccount <- kube-api-access  readOnly
```

`/data/codex/sessions` 不存在，`thread-writer-locks` 也不存在。`/data` 目录本身仍是 Sep 25 14:57 那份。`/data/codex` 整目录的时间变成新 Pod 启动的 `03:31`：`config.toml`、sqlite、`auth.json` 都是这一刻新建的，不是回收前 `03:09`/`03:28` 的那些文件。`logs_2.sqlite` 从回收前的 487424 字节变成 49152 字节。

## 6. 同一会话再发「你好」

时间线「#96 · 命令失败」：

```text
AppServerError: thread/resume: no rollout found for thread id 01a0dbc1-e34d-7ed1-964a-172d1c030222
```

线程号就是第 3 步那个文件名里的 id。runner 近 15 分钟日志里与待办那条 grep 相符的只有这一行，没有 `thread resumed`，没有 `thread not found`，没有 `gone on sandbox`。runner 仍是 `investment-backend-runner-77596b8695-4l7l6`，RESTARTS 0。本地助手没有重启它。

停在这里。
