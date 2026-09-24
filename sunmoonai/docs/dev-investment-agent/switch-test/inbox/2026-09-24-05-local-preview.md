# 本地预览栈：一台机上把页面跑起来（本地机 WSL，要 Docker）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要并列的 runtime、investment-app、knowledge-app 三个仓）
跑：cd sunmoonai/scripts/local-preview && bash preview.sh init && bash preview.sh up   （之后按下面的编号步骤做）
仓与提交：k8s fable 同步后的头提交（本条待办与脚本同一提交）；runtime 51b7a85；investment-app 92d3021（子仓 investment-backend 4f79ef1、investment-web-frontend f11cb56）；knowledge-app 08437e9（子仓 knowledge-backend d267bc0）
预计：第一次 20 到 30 分钟（拉基础镜像、建三个镜像、前端 pnpm install）；要联网；要 Docker；要 Kimi key 在 ~/.codex-probe-kimi/auth.json；要 runtime/agent 已 pnpm build
看什么：编号步骤里每步"应该看到"；做到哪一步和预期不一样就停，写下屏幕上实际是什么
前提：03、04 号先 pass（代理与沙箱镜像在 WSL 上各自成立）；knowledge-backend/app/datasets/ 里放好 lesson23 sqlite（见该目录 README）；所有者定好白名单目录（默认 ~/research，init 时用 PREVIEW_ROOTS=/mnt/c/... 覆盖）
回传：k8s/sunmoonai/scripts/local-preview/results/local-preview.<时间>.md（写下即可，提交与推回由所有者做）
```

## 步骤

1. `bash preview.sh init`：应该看到「已生成 .env 与 secrets/」和一行演示账号密码。把账号密码抄进回传文件，密码不要贴到别处。
2. `bash preview.sh up`：结束时打印各服务状态；应该看到 postgres、redis、casdoor、backend-api、backend-runner、edge、knowledge-mcp、relay、sandbox、frontend 全是 Up，casdoor-seed 与 migration 是 Exited (0)。`status` 里 casdoor 200、backend 200、login 是 302 且跳转地址以 `http://localhost:8100/login/oauth/authorize` 开头、mcp 401。
3. 浏览器开 `http://localhost:3000`：应该到中文登录页；点登录跳到 Casdoor（地址栏 localhost:8100），用演示账号登录；回来后落在 `/zh-CN/workbench`「工作台」页，上面有「新建会话」和「我的会话」两块，机器下拉是空的。
4. `bash preview.sh seed`：应该打印一行 JSON，含 user、roots、sandbox。刷新页面：机器下拉出现 this-pc，沙箱下拉出现 ws://sandbox:47800。
5. 另开终端 `bash preview.sh agent`：应该看到代理日志里有 "relay connected"。
6. 页面上新建会话：机器 this-pc、沙箱唯一那个、项目目录填白名单下的一个真实子目录（先在 WSL 里 mkdir）。应该跳到会话页；几秒内时间线出现「Codex 会话已建立」。
7. 输入框发一句：`在当前目录写一个 hello.txt，内容 hello，然后 cat 它`。应该看到时间线依次出现「你」「命令」「Codex」条目，WSL 里该目录出现 hello.txt。
8. 右侧「问专家」：专家包 SMOKE，问题随便写一句，预算 5，交出方向盘。应该看到：输入框变灰并显示「专家正在驾驶」；右侧出现委托卡，状态从 RECEIVED 走到 RUNNING，步骤 0 → 1 → 2；一两分钟后状态 SUCCEEDED，输入框恢复。
9. 委托卡点「打开底稿」：应该看到结果、证据、交回物三块和一个「结论（用户草稿）」编辑框；填一句保存，显示「草稿第 1 版」。
10. 首页顶栏「设置」：提交一个假 key（任意 8 位以上字符串），列表出现一行末四位；点撤销，状态变已撤销。页面上任何地方不应出现你输入的整串 key。
11. `bash preview.sh down`。

## 回传里要有

每步的「做到了 / 没做到，屏幕上是什么」；`docker compose ps` 的输出；`docker compose logs backend-runner | tail -30` 与 `docker compose logs sandbox | tail -20`（都过滤掉含 sk- 的行）。
