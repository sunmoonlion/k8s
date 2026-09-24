# 本地预览栈

> 在一台机（所有者的本地机 WSL）上把整条链跑起来看页面：Casdoor 登录 → 网页 → 工作台（api + runner）→ 沙箱 → 会合点 → 本地代理 → 本机目录，外加知识 MCP。
> 不是部署形态，只为看页面和前后端联调；正式拓扑见 `docs/dev-investment-agent/tree-build/SDD/architecture/topology.md`。

## 一次性

```bash
cd ~/worktrees/fable/k8s/sunmoonai/scripts/local-preview
bash preview.sh init      # 生成 .env（随机令牌、演示账号）与 secrets/
```

前提：docker compose v2；`~/.codex-probe-kimi/auth.json`（沙箱的模型 key）；`knowledge-backend/app/datasets/lesson23_business_analysis.sqlite`；`runtime/agent` 已 `pnpm install && pnpm build`。

## 每次

```bash
bash preview.sh up            # 构建并起全部（第一次要拉镜像、建三个镜像，10 到 20 分钟）
# 浏览器开 http://localhost:3000 → 登录页 → Casdoor（localhost:8100）→ 用 init 打印的演示账号登录
bash preview.sh seed          # 登录过一次之后：给这个用户登记"这台机"（白名单 PREVIEW_ROOTS）与预览沙箱
bash preview.sh agent         # 另开一个终端：本地代理前台跑，连 localhost:47100
bash preview.sh status
```

之后回到浏览器：新建会话（机器 this-pc、沙箱 ws://sandbox:47800、项目目录填 PREVIEW_ROOTS 下的子目录）→ 对 Codex 说话 → 问专家 → 底稿。

## 改了代码

后端或网页改了：`bash preview.sh up` 会重建镜像再起。只改网页想快一点：`docker compose --profile full up -d --build frontend`。

## 停

```bash
bash preview.sh down          # 停，保留数据库
bash preview.sh down wipe     # 连数据一起删（下次要重新登录、重新 seed）
```

## 端口

| 端口 | 谁 |
| --- | --- |
| 3000 | Caddy：`/api` → 后端，其余 → Next |
| 8100 | Casdoor（浏览器登录用；后端走容器内 `casdoor:8000`） |
| 47100 | 会合点（宿主机上的代理连它） |
| 47900 | 知识 MCP（调试用） |

全部只绑 127.0.0.1。

## 已知限制

- 沙箱到本机文件的路径：代理在宿主机（WSL）上跑，白名单是 WSL 路径；Windows 盘符路径要用 `/mnt/c/...`。
- 凭据登记（设置页的 key）只入库不注入沙箱；沙箱的 key 仍来自 `MODEL_AUTH_JSON`。
- 一个演示用户、一个沙箱容器；不是按需拉起。
