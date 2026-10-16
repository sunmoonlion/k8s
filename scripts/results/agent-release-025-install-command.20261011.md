# Cursor 回执：复制安装命令的 500，以及修后的检查

时间：2026-10-11（UTC+8）。Redis 运行身份的命令白名单没有改。

## 500 原文

所有者点「复制安装命令」时，投资 API 日志只有这一行，没有堆栈：

```
2026-10-11 01:05:13 - app.bootstrap.api - INFO - agent_onboarding_result request_id=f83749df-b4b2-4717-adfe-6f7fcfd12e4d status=500
```

在当时的 API 镜像里把签发步骤重放了一遍，下载描述符可读，凭据表可以写入，限速这一步失败：

```
download_ready 0.2.5 object-storage
redis_allow_error NoPermissionError User investment_runtime has no permissions to run the 'eval' command
credential_write ok
```

网页把这次 500 显示成「下载信息暂时读取失败；不会创建沙箱或更换令牌」。

## 修法

`consume_window` 不再用 EVAL。窗口键里已经有窗口编号，改成 `pipeline(transaction=True)` 里的 `INCR` 和 `EXPIRE(seconds, nx=True)`。投资后端 `982b216`，父仓 `3803444`。全量 pytest：960 passed，5 skipped。ruff 与 lint-imports 通过。

镜像 `harbor.sunmoonai.com:30443/platform/investment-backend@sha256:b09a366f3d71ff175c48a0259f1a7f20793be8bd746e26ca876af04c49f7a379`。只构建了这个后端。stage `a0fcdce6`，发布摘要 `sha256:7884dbc6cd55de1df38c1a44f7cf70251f3a9c2bda021acf1b5e969dcb25bd3f`，晋级 `00a4732d`。回退点仍是上一包：摘要 `sha256:2d69dd36c285bfd0210f63256bf2ca6ad105fa5426f93d388442205a46065b41`，修订 `3ac0def8`。

`investment-api` 已是新镜像，就绪 1/1。

## 修后检查

`make application-check APP=investment` 退出码 0。浏览器断言原文：

```
{
  "browser_ui_clicks_verified": false,
  "business_provider_configured": false,
  "entry_port": 29443,
  "install_command_issued": true,
  "protocol_checks": {
    "admin": {
      "authenticated_ssr": true,
      "cross_surface_denied": true,
      "csrf_required": true,
      "logout_revoked": true,
      "pkce_callback": true,
      "secure_cookie": true,
      "unprivileged_admin_diagnostic_denied": true,
      "user_organization_denied": true
    },
    "web": {
      "authenticated_ssr": true,
      "cross_surface_denied": true,
      "csrf_required": true,
      "logout_revoked": true,
      "pkce_callback": true,
      "secure_cookie": true,
      "unprivileged_admin_diagnostic_denied": null,
      "user_organization_denied": null
    }
  },
  "web_member_organization": "sunmoonai"
}
```

这次检查用临时成员签发了一次命令，成员随后删除。命令正文没有记在这里。

## 还没做

所有者还没从「复制安装命令」继续 E。Traefik 来源和后端 `source_ip` 仍没有可看的配对请求。U4 没做。
