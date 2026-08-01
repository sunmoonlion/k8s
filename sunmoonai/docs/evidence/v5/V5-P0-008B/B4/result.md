# V5-P0-008B/B4 Nest Security / Paired Deploy / Freeze 证据

状态：`ACCEPTED / B5_NEXT`

验收日期：2026-07-26（Asia/Shanghai）

## 1. 固定输入与产物

| 产物 | 固定值 |
|---|---|
| Nest 可选 profile commit | `947021cbbaa5f5e26b891b65c65d47bb27e5a5c5` |
| Nest Git tag | `p0-008b-b4-nest-20260726` |
| Nest 新远端 | `https://gitee.com/sunmoonlion/tpl-web-backend-nest.git` |
| Next commit | `f746255c71eb1a6d6486f284aa1b992ad2417006` |
| Next Git tag | `p0-008b-b4-next-20260726` |
| B4 父仓基线 | `edf11a3` |
| 父仓改名提交 | `ffa3a0b`、`bc4c03f` |
| 父仓改名后 tag | `p0-008b-b4-renamed-20260726` |
| Nest 镜像 tag | `tpl-web-backend-nest:b4-r5-20260726` |
| Nest 镜像 digest | `sha256:78b9929ddf6735341768093ae1093fd0f05420f581189af60913577d6f2f2e3a` |
| Next v1 镜像 tag | `tpl-web-frontend:b4-r2-v1-20260722` |
| Next v1 digest | `sha256:61fc192219488bc315e431580b345d44e5d0f43bc73569db2e4c2b78769121c8` |
| Next v2 镜像 tag | `tpl-web-frontend:b4-v2-20260726` |
| Next v2 digest | `sha256:d07d55798a0c7efc82f2762bc3f87408eb7ed120a5e6d33621dd5340244cc262` |
| interaction contract | `1` |

现有 Gitee `tpl-web-backend` 在改名前已推送 B4 commit/tag，随后通过 Gitee API 改名为
`tpl-web-backend-nest`。父仓只在远端改名成功并复核新远端 master/tag 后修改 gitlink、
path 和 URL；没有复制出两套 Nest 历史。新的 FastAPI `tpl-web-backend` 尚未在 B4
创建，它属于 B5。

## 2. 源码门禁

Nest：

```text
pnpm check
typecheck: passed
lint: passed
unit: 6 suites / 40 tests passed
e2e: 1 suite / 2 tests passed
build: 211 files compiled
```

Next：

```text
pnpm typecheck: passed
pnpm lint: passed
vitest: 7 files / 33 tests passed
next build: Next 16.2.2 Turbopack production build passed
```

Next 的首次本地生产构建在受限沙箱中因 Turbopack 创建内部进程/绑定端口被 OS 拒绝；
同一源码在允许本地构建进程的环境和 Docker clean build 中均通过。这不是源码或网络
回退，证据不把该次沙箱失败记作产品成功。

## 3. 身份与 Provider 兼容结论

隔离 Casdoor application：`sunmoonai-tpl-web-b4`。浏览器使用真实 Authorization Code +
PKCE S256、state、nonce、一次性 Redis transaction、精确 client audience、签名/JWKS、
安全 cookie、CSRF/Origin 和资源授权；验证过程中未打印 credential、token、code、cookie
或 PKCE verifier。

Casdoor `v3.42.0` 有一个必须显式处理的 Provider 兼容约束：

1. 官方 tag 中 `object/wellknown_oidc_discovery.go` 的 application-specific discovery
   宣告 application-scoped issuer。
2. 同一 tag 的 `object/token_jwt.go` 中 `generateJwtToken()` 仍使用基础
   `originBackend` 签发 token。
3. 真实 callback 首次按 application-specific discovery 验证时严格失败为
   `issuer_mismatch`，与源码一致。

B4 没有加入双 issuer allowlist，也没有弱化验签。当前 Casdoor 版本改用标准
`/.well-known/openid-configuration` 的唯一基础 issuer/JWKS；App/Surface 隔离继续由
独立 client、精确 audience/redirect URI、cookie/Redis namespace、PKCE/nonce 和本地
policy 共同保证。ADR-005 已同步修订；未来 Provider 升级只有证明
`metadata.issuer == token.iss` 后才允许切换 discovery 模式。

内网 backchannel 仍保留 canonical public Host。实现先严格校验公开 discovery 的所有 URL，
再以 Node 原生 HTTP transport 访问内部 Service 并保持外部 Host；不接受内部 HTTP issuer，
不关闭 TLS/issuer/audience 验证。

## 4. KIND 严格 TLS 与配对门禁

隔离拓扑：

```text
Traefik strict TLS
  /api/* -> 2 x Nest B4
  /*     -> 2 x Next B4
Redis    -> B4 独立 ACL user + 独立 key namespace
Casdoor  -> B4 独立 confidential client
```

Pod 均满足：

- immutable digest；
- `runAsNonRoot`，UID/GID 1001；
- `readOnlyRootFilesystem`；
- drop `ALL` capabilities；
- 不挂载 ServiceAccount token；
- requests/limits、readiness/liveness、PDB；
- `maxUnavailable=0`、`maxSurge=1`；
- `minReadySeconds=5`；
- `preStop sleep 10` 与 30 秒 termination grace。

真实 B4 verifier 在 v1、v2 和回滚后的 v1 均通过：

```json
{
  "strict_tls": true,
  "redis_cross_replica_statuses": [200, 200],
  "http": {
    "home": 200,
    "anonymous_me": 401,
    "authenticated_me": 200,
    "action": 201,
    "logout_me": 401
  },
  "sse": {
    "initial_sequences": [2, 3, 4],
    "resumed_sequences": [3, 4],
    "invalid_cursor": 400,
    "conflicting_cursor": 400
  },
  "resource_authorization": {
    "forbidden_run": 403,
    "forbidden_citation": 403,
    "authorized_source": 200
  },
  "business_deployments_unchanged": true
}
```

该验证使用完整 Chromium、隔离 NSS DB 导入平台 Root CA，`ignoreHTTPSErrors=false`；
真实登录、callback、SSR workspace、浏览器 action、Citation 和 logout 全部经过相同来源
的 Next + Nest 配对。B4 verification adapter 由独立入口
`dist/b4-verification-main.js` 启动，不进入生产 `AppModule`，也不冒充 LangGraph Runtime
或真实 Retrieval。

## 5. 滚动升级、version skew 与回滚

首轮滚动门禁实际捕获到一个 Next asset `502`：旧 Pod 收到终止信号后退出过快，而
Traefik/Endpoint 摘流存在传播窗口。没有把它归为偶发网络问题。部署契约补入 preStop
排空、termination grace 和 minReadySeconds 后，从 v1 重新开始验收。

最终结果：

```json
{
  "upgrade_continuity": {
    "probes": 72,
    "deploymentIds": ["b4-v1", "b4-v2"]
  },
  "rollback_continuity": {
    "probes": 87,
    "deploymentIds": ["b4-v1", "b4-v2"]
  },
  "old_pod_deployment_ids": ["b4-v1", "b4-v1"],
  "new_pod_deployment_ids": ["b4-v2", "b4-v2"],
  "rollback_pod_deployment_ids": ["b4-v1", "b4-v1"],
  "cross_version_assets": {
    "old_assets_on_v2": 16,
    "new_assets_on_v1": 16
  },
  "full_verifications": ["v2", "rollback_v1"],
  "business_deployments_unchanged": true,
  "final_state": "b4-v1"
}
```

连续探测每次都严格验证页面、HSTS 和页面引用的全部 Next static assets。稳定点还通过
逐 Pod port-forward 校验 build-time `data-dpl-id`，不能由 Service 偶然只命中一个 Pod
蒙混过关。门禁脚本在任何失败时自动恢复 v1 immutable image。

## 6. 脚本稳健性修复

- 验收固定 `KUBECTL_BIN`，并 fail-fast 拒绝 client/server minor 差超过 1；本次使用
  KIND 自带的 `kubectl v1.27.3` 对接 server `v1.27.3`。
- 主机全局 `DEBUG=release` 会让 client-go SPDY 输出内部 stream 日志；所有 B4 kubectl
  子进程显式移除该环境变量。
- Redis Job heredoc 的普通注释曾包含反引号形式的 `kubectl wait` 文本。未加引号的
  heredoc 会执行反引号命令替换，因而产生误导性的
  `unrecognized condition: []`。注释已改为普通文本，幂等部署复验输出干净。
- Secret 只在 Kubernetes/进程内传递；脚本和证据只输出状态、计数、commit、tag 和 digest。

## 7. 结论与下一游标

B4 的源码、安全、真实身份、双副本、严格 TLS、滚动/version-skew、回滚、不可变镜像、
Git tag、远端改名和父仓 gitlink 已闭环，状态为 `ACCEPTED`。

唯一下一任务是 B5：

1. 从三套已通过 P0-005 的 FastAPI Admin Backend 反向收敛通用安全/基础设施能力；
2. 修复并验收 canonical `tpl-admin-backend`，不得复制其旧认证原型；
3. 创建新的空 Gitee `tpl-web-backend`；
4. 只从固定 FastAPI 母版初始化默认 Web BFF，并替换 Web surface/audience/cookie/Redis
   namespace/API allowlist/downstream；
5. B5 未完成前不修改 Info/Knowledge/Research，B6 后必须立即执行 P0-009。
