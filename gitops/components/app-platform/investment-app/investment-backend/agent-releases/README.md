# Windows 代理安装包

投资后端负责已登录用户的安装包下载。包放在私有桶 `agent-releases`；不开放匿名下载。
本目录的 `config.yaml` 是版本、ZIP/清单摘要、对象名和托管模式的唯一输入，
桶/身份沿用组件渲染、SOPS、Flux；上传入口在 `infrastructure/Makefile`。

## 状态与凭据

本提交是**未发布候选**，`enabled` 与 `download_available` 均为 false。
代码/本地包检查通过不等于线上下载或真实权限已经通过。由所有者安排 Cursor 发布后实测。

| 对象 | 位置 / 权限 |
| --- | --- |
| 公开发行输入 | 本目录 `config.yaml`；固定 Agent / Codex /源码及摘要 |
| reader / writer 私有输入 | `/etc/sunmoon/services/sunmoon-kind/investment-agent-releases.yaml`，root 0600 |
| 独立恢复副本 | `/mnt/sunmoon-data/backups/services/sunmoon-kind/investment-agent-releases.yaml` |
| API 身份 | `investment_release_reader`，仅 `s3:GetObject`，包括对象 HEAD；无列桶/写/删除/管理权限 |
| 上传身份 | `investment_release_writer`，仅 `s3:PutObject`；无读/列/删除/管理权限 |
| SOPS | `agent-releases/provision.sops.yaml` 在 data namespace；`runtime/agent-releases.sops.yaml` 只给 API |
| 读回回执 | `/etc/sunmoon/services/sunmoon-kind/investment-agent-release-published.json`；无秘密，root 0600 |

初始化任务使用平台管理员建桶、关闭匿名访问、开启版本记录和绑定两个最小权限策略。
API Pod 没有管理员或上传密码，Worker/Scheduler/Runner 不挂读取密码。凭据主备都丢失时停止，不能自动重建新密码。
修改凭据或 Job 内容需独立轮换并提升 `job_revision`；不要手改已完成 Job 的不可变字段。

## 查看与上传

从 k8s 根目录运行；`AGENT_ZIP` 支持含空格的绝对路径。上传前须已通过现有部署链建桶和身份。

```bash
AGENT_ZIP=/绝对路径/windows-x64.zip make -C infrastructure agent-release-verify
AGENT_ZIP=/绝对路径/windows-x64.zip make -C infrastructure agent-release-upload
```

`verify` 只读：核 ZIP 大小/SHA256、清单摘要与版本/源码、包内每个文件的大小/摘要；拒绝越界路径、重复条目、链接和超限包。
`upload` 先重复上述校验，执行正常容量检查，再只监听回环的 kubectl port-forward；
curl 使用 SigV4、专用 CA 和域名校验，代理与 curl 用户配置不参与，不跟随跳转。
上传用已校验文件描述符和 `If-None-Match: *`，同名不覆盖。412 时只读回核对原对象，
409/其它失败停止，不自动覆盖重试。

读回使用独立 reader，逐块重算完整 SHA256；再验证 writer 读被拒、reader 写被拒。
写权限反例使用已存在对象与 `If-None-Match: *`，不覆盖包。任何核验失败不给发布回执，
不删除已传对象：维护者应先查原因，不能自动清桶。摘要与当前发行不符时停止。
输出的回执不含凭据；临时 curl 配置仅在 root 私有临时目录，正常结束清除。

## 发布顺序（本轮由 Cursor 执行）

1. 固定后端、网页提交，按原构建入口构建并按摘要发布；准备原 Flux 源和镜像摘要作为回退点。
   不从尚未合并的 fable 发投资后端/relay。
2. `enabled: true`，`download_available: false`。按原生入口
   `make -C infrastructure platform-stage OBJECT=app-platform/investment-app/investment-backend`
   生成候选，检查 diff/SOPS/拓扑；本地提交后通过现有 `flux-release` 与显式晋级流程部署。
   `investment-agent-releases` 先于 investment-runtime；此时网页仍显示暂不可下载。
3. 执行上面的 upload 命令；核回执完整摘要、两个拒绝结果、私有桶无匿名读取、外桶不可读写。
   必须用实机 AIStor 确认条件写、权限、重复上传不增加同名版本。失败停在此，不开放下载。
4. `download_available: true` 后重新 stage、提交、发布与晋级。渲染会要求回执与版本摘要完全对应。
   用登录浏览器核 metadata、完整下载/HEAD、206 续传、416、未登录拒绝；校验下载文件两个摘要。
5. 按「我的电脑」完成下载→安装→领令牌→目录→在线真人闭环。GUI 允许、重启、UAC、干净机仍按原待验补齐。

包锁定 Agent 0.2.1、Codex 0.155.1、源码 `6de6002`；使用已组好的 ZIP，不因本轮改网页而重组代理。
各验证结果需与当时实际镜像和 Flux 摘要一起记录。步骤 2 会增加新包支持，不改现有数据库 schema。

## 切换边缘与回退

- 边缘可用后，改 `mode: external`、`external_url: https://...`，保留已校验版本/摘要；
  stage/晋级后网页获得外部地址，UI 与代理不改。旧桶暂留，无删除授权。
- 临时关下载：`download_available: false` 后按原链发布，metadata 返回 null。
- 回退代码：恢复记录的原 Flux 源/镜像版本。保留桶、对象、私有输入和备份；不把回退当删除授权。
- 上传与服务失败排查：先核配置/回执对应，再查桶初始化 Job、SOPS、NetworkPolicy、TLS CA、
  reader/writer 权限与条件请求。不要关闭 TLS 或给 API 管理员权限绕过错误。

本地维护检查：`python3 <本目录>/test_upload.py`；后端契约在 investment-backend
`app/contracts/agent-onboarding.md`。开发原始输出与待验清单在 runtime 本轮交回中。
