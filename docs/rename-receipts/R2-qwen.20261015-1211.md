# R2-qwen — 远端仓改名（GitHub 8 仓 + gitee 2 仓）

- 执行人：Qwen（本地机）
- 时间：2026-10-15 12:11（本机时间）
- 依据：`k8s/docs/rename.md` R2 节（HEAD `8eb2b90c`）；名字对照表以最新手册为准（采集应用最终名 **knowfeed**）。
- 前置：R0「开工」· 2026-10-14 · Opus；R1「通过」· 2026-10-15 · Opus（回执 `R1-opus.20261015-1200.md`，18 仓改名提交已推到旧名字的仓 qwen 分支）。收到所有者转告「R1 通过，可以开始 R2」后，先 `pull --ff-only` 拿到最新手册再动手。
- 只改名，未新建、未删除任何仓；令牌不进本回执。

## 1. 改名前后地址对照

| 平台 | 旧 | 新 |
| --- | --- | --- |
| GitHub | `sunmoonlion/info-app` | `sunmoonlion/knowfeed-app` |
| GitHub | `sunmoonlion/knowledge-app` | `sunmoonlion/knowbase-app` |
| GitHub | `sunmoonlion/info-backend` | `sunmoonlion/knowfeed-backend` |
| GitHub | `sunmoonlion/info-web-frontend` | `sunmoonlion/knowfeed-web-frontend` |
| GitHub | `sunmoonlion/info-admin-frontend` | `sunmoonlion/knowfeed-admin-frontend` |
| GitHub | `sunmoonlion/knowledge-backend` | `sunmoonlion/knowbase-backend` |
| GitHub | `sunmoonlion/knowledge-web-frontend` | `sunmoonlion/knowbase-web-frontend` |
| GitHub | `sunmoonlion/knowledge-admin-frontend` | `sunmoonlion/knowbase-admin-frontend` |
| gitee | `sunmoonlion/info-app`（name+path） | `sunmoonlion/knowfeed-app` |
| gitee | `sunmoonlion/knowledge-app`（name+path） | `sunmoonlion/knowbase-app` |

- GitHub 地址：`https://github.com/sunmoonlion/<仓>.git`（改名后 GitHub 会把旧地址 301 重定向到新地址）。
- gitee 地址：`https://gitee.com/sunmoonlion/<仓>.git`。gitee 上虽有 6 个同名旧子仓（早期拷贝、只有 `master`/`opus` 分支、提交不在现历史、子仓从不往 gitee 推），按手册 R2 更正（`f38266fa`）**不改**，留删由所有者在 R6 定。gitee 不保证转发旧地址，改完旧地址打不开属正常。

## 2. 改名前基线（默认分支 + qwen + master 提交号）

GitHub 8 仓默认分支均为 `master`。改名前从旧地址取：

```text
info-app                   default=master   qwen=1fd9da0f3d8fa23255eca669abe8d34afce69a3b master=244f724dce91d373bd6dd35362d471c565ebf7a9
knowledge-app              default=master   qwen=ba6c77cdd2e8da59e60fa97ddc72d93d99ff8d21 master=b4e6f66624e91b2dbc720cdcc9615b0c73dbb349
info-backend               default=master   qwen=ecce5c797d69565c1d24b903d4d4d61615e99a63 master=e5156a0bfc0d5ca9118128427dcacb69697a0737
info-web-frontend          default=master   qwen=327c5260af227aed664ae8cfca7a5f9a08a093d4 master=a07af307c63ee16204d82afa0a0b7b2d3d22bb3c
info-admin-frontend        default=master   qwen=3f01f34bb308c2c7d200d2ffa18847386490c3d2 master=90e4ab00fc209323d1670743d83ae1369a7b8d82
knowledge-backend          default=master   qwen=1d8fa105cf4469df507c50664ba4c2ead37cac1a master=4d9804c3d5f4084b83bdb00ba49cbf0f8b5cbb55
knowledge-web-frontend     default=master   qwen=3fd93126052b6519b9a34c4e956b9784852b1499 master=8e8d016b4cea7239ae6a13130036924132c63d75
knowledge-admin-frontend   default=master   qwen=1ae7ed73d576290558a31a0d20ec28eb57125b54 master=6634a4c64e297c0dbbd2d0c8fa82c1195d068f67
```

gitee 2 仓改名前（与 GitHub 同提交号）：

```text
info-app                   qwen=1fd9da0f3d8fa23255eca669abe8d34afce69a3b master=244f724dce91d373bd6dd35362d471c565ebf7a9
knowledge-app              qwen=ba6c77cdd2e8da59e60fa97ddc72d93d99ff8d21 master=b4e6f66624e91b2dbc720cdcc9615b0c73dbb349
```

## 3. 改名操作与输出

### GitHub（`gh repo rename <新名> --repo sunmoonlion/<旧名> --yes`）

```text
== info-app -> knowfeed-app ==            ✓ Renamed repository sunmoonlion/knowfeed-app
== knowledge-app -> knowbase-app ==       ✓ Renamed repository sunmoonlion/knowbase-app
== info-backend -> knowfeed-backend ==    ✓ Renamed repository sunmoonlion/knowfeed-backend
== info-web-frontend -> knowfeed-web-frontend ==   ✓ Renamed repository sunmoonlion/knowfeed-web-frontend
== info-admin-frontend -> knowfeed-admin-frontend == ✓ Renamed repository sunmoonlion/knowfeed-admin-frontend
== knowledge-backend -> knowbase-backend == ✓ Renamed repository sunmoonlion/knowbase-backend
== knowledge-web-frontend -> knowbase-web-frontend == ✓ Renamed repository sunmoonlion/knowbase-web-frontend
== knowledge-admin-frontend -> knowbase-admin-frontend == ✓ Renamed repository sunmoonlion/knowbase-admin-frontend
```

### gitee（`PATCH /api/v5/repos/sunmoonlion/<旧名>`，同时改 `name` 与 `path`；令牌走 stdin，不进命令行参数）

返回的仓库 JSON（更新后）：

```text
== gitee info-app -> knowfeed-app ==      name=knowfeed-app path=knowfeed-app url=https://gitee.com/sunmoonlion/knowfeed-app.git
== gitee knowledge-app -> knowbase-app == name=knowbase-app path=knowbase-app url=https://gitee.com/sunmoonlion/knowbase-app.git
```

## 4. 改完核对（手册 R2 核对命令原样；前缀从旧检出 `~/master/info-app` 取，协议随本机 = https）

`GH=https://github.com/sunmoonlion/`、`GE=https://gitee.com/sunmoonlion/`

```text
knowfeed-app                 github qwen=1fd9da0f master=244f724d
knowbase-app                 github qwen=ba6c77cd master=b4e6f666
knowfeed-backend             github qwen=ecce5c79 master=e5156a0b
knowfeed-web-frontend        github qwen=327c5260 master=a07af307
knowfeed-admin-frontend      github qwen=3f01f34b master=90e4ab00
knowbase-backend             github qwen=1d8fa105 master=4d9804c3
knowbase-web-frontend        github qwen=3fd93126 master=8e8d016b
knowbase-admin-frontend      github qwen=1ae7ed73 master=6634a4c6
knowfeed-app                 gitee  qwen=1fd9da0f master=244f724d
knowbase-app                 gitee  qwen=ba6c77cd master=b4e6f666
```

## 5. 结论

- 每个新地址都能列出分支（GitHub 8 + gitee 2），无 404、无鉴权失败。
- **qwen 分支提交号逐一等于 `R1-opus` 记下的提交号**：knowfeed-app=1fd9da0f、knowbase-app=ba6c77cd、knowfeed-backend=ecce5c79、knowfeed-web-frontend=327c5260、knowfeed-admin-frontend=3f01f34b、knowbase-backend=1d8fa105、knowbase-web-frontend=3fd93126、knowbase-admin-frontend=1ae7ed73。
- **master 分支与改名前基线逐一相同**（改名不动提交，只动仓名）。
- gitee 两仓 name 与 path 都已换成新名，qwen/master 与 GitHub 一致。
- 无停报项。R2 完成，等 Opus 审过在本节写「通过」后，再做 R3（本地检出换名，远程机 Opus 先做、审过后我做本地机）。改名窗口内不跑同步脚本。

exit=0
