# Cursor 回执：0.2.5 放行后的第二段

时间：2026-10-11（UTC+8）。runtime `3541410b883188c824a6ff251094edec8314502c`，k8s 候选 `3ac0def8ead094e1387d68ab9dd819ba66b8a6aa`，晋级 `0e10b7fcb75abc00174c33269cf02917b3acfd3f`。没有推远程，没有改 `luna-feedback.md`，没有做 U4，没有建 sunmoonai 用户。

## 小改

`openDesktop` 的就绪判断改成 `desktopWindowReady`：读 `tray.json` 抛错时返回未就绪，轮询不会把异常抛出定时器。测试见 `agent/test/desktopLaunch.test.ts`。`pnpm test` 213 通过、32 跳过；`tsc --noEmit` 通过；`bundle.test.mjs` 32 通过。版本仍是 0.2.5。

## 安装目录

恢复前，安装目录自带清单是 `513d34eb8cbbec977150caf2e26e489e29d461faf8246d212075084d809d18f8`（源码 `cf13310`，0.2.5，96 个文件）。`verifyBundle` 按这份清单核验失败：`Incomplete or oversized bundle`。放开布局要求后再核，是 `Bundle content mismatch`：多出 `app/native/open-desktop.vbs`，`app/dist/cli.js`、`app/dist/resident.js`、`app/native/desktop.ps1` 与清单不一致。

先停掉正在跑的托盘和常驻（`tray stop` 回 `{"closed":true}`，`stop` 回 `{"stopped":true}`），再从正式包 `sunmoon-agent-c0c185f` 按清单把不一致的文件放回，包括清单本身。放回的是 `app/dist/cli.js`、`app/dist/resident.js`、`installer/bundle.mjs`、`bundle-manifest.json`。没有删目录外的文件，没有动用户配置。

恢复后再核验通过：清单 `df9b659fef058d3b5f016e02846b6895af27e56ce604c8309db724df3e5c9615`，源码 `c0c185fae905ea249012046b0e0316ee95660d59`，97 个内容文件。用户配置仍是 984 字节，令牌长度 386，令牌 SHA256 `f3255049f2cb743745f61891b22bcdbf064bf2a842fef5a999f1ab0c6267e585`。新包没有覆盖进安装目录。

## 0.2.5 包

目录 `sunmoon-agent-3541410`。清单 `9b5cf6cf5358328c8c36501abdbe10ee1c1a77b188946269f730beee02e4a852`，源码 `3541410b883188c824a6ff251094edec8314502c`，98 个条目，501009828 字节。ZIP `sunmoon-agent-0.2.5-3541410-windows-x64.zip`，deflate、正斜杠、无外层目录，SHA256 `e94df6797d670f42ca0d0a10af61b9ade2cfa332d72474155bdadbf798967697`，175306953 字节。包内 Node 跑 `windows-candidate.mjs` 通过：0.2.5 / Codex 0.155.1 / Node 24.19.0，没有启动代理，隔离目录已删。

`agent-release-verify` 本地校验通过。`agent-release-upload` 读回通过：`uploaded: true`，`readback_verified: true`，`reader_write_denied: true`，`writer_read_denied: true`，`existing_preserved: false`，对象 `windows-x64/0.2.5/sunmoon-agent-0.2.5-3541410-windows-x64.zip`。校验要对照 `config.yaml`，所以这五项是在 verify 之前写入的。安装模板两份都是 `491035b68ea3f4bbe63ef848f51f7d292d07c9224334a5d261b527c00d066cfe`，六个占位符各一次。解密后的安装脚本里对象键、两个摘要、大小、0.2.5、Codex 0.155.1 各出现一次，占位符已经替换完。

## 投资 stage

相对当时的 `10f5a92a`，stage 只改了三份：`agent-releases/config.yaml`、`runtime/agent-releases.sops.yaml`、`runtime/workload.yaml`。负载 diff 只有四处 `sunmoonai.com/config-sha256`，从 `350848b9c36eed84f4042cbff6426346c0e57c4e783b14ac007a2f8ae8caa8ed` 换成 `381a0bcb1857225bb49023df0e68ab80404abc58c4b6d326685617ed7bfe2dd2`。

相对 `df1aa4d7`，除此之外还有审读提交里已有的 `luna-feedback.md` 和 `agent-release-025-tray-stderr.20261010.md`，以及第二段晋级写上的 `infrastructure/environments/kind/flux-source.yaml`。stage 本身没有再改别的对象。

## 发布与检查

发布摘要 `sha256:2d69dd36c285bfd0210f63256bf2ca6ad105fa5426f93d388442205a46065b41`，修订 `3ac0def8ead094e1387d68ab9dd819ba66b8a6aa`。晋级前的现网源是摘要 `sha256:45b1c6549660df4685a036d322a76b3cdd09ad05825b43c685a6560be102ae25`、修订 `36db18c4a74c01dc0d59d985954e5bdb558e42db`。`flux-source-apply` 与 `flux-source-status` 都通过，现网源已是这次的摘要。

identity Job 都成功。投资新建了组织，另外三个组织已经在，四处 `migrated` 都是 `["web"]`：

| Job | 完成 | 结果 |
| --- | --- | --- |
| `investment-identity-09405580a3d6-v3` | 00:07:56Z–00:07:59Z | `created: ["user_organization"]`，`migrated: ["web"]`，`user_organization: sunmoonai` |
| `info-identity-b470e2fd4f17-v3` | 00:08:24Z–00:08:27Z | `created: []`，`migrated: ["web"]`，`user_organization: sunmoonai` |
| `knowledge-identity-d88fee857408-v3` | 00:08:42Z–00:08:45Z | `created: []`，`migrated: ["web"]`，`user_organization: sunmoonai` |
| `tpl-identity-b4b94f049f84-v3` | 00:08:23Z–00:08:27Z | `created: []`，`migrated: ["web"]`，`user_organization: sunmoonai` |

`application-check` 四个应用都通过。四处都是 `web_member_organization: sunmoonai`，admin 的 `user_organization_denied: true`。检查结束后 sunmoonai 组织里用户数 0，名称以 `verify-` 开头的成员 0。

## 停在所有者

E 全程还没走。现装目录对得上 `c0c185f` 的清单，可以 `--remove-config` 卸载；网页上的安装命令会装这次上传的 `3541410` 包。托盘和常驻已经停掉。sunmoonai 账号要所有者自己建，建好后用这个账号走 E。U4 等这份回执审过再做。
