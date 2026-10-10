# Cursor 回执：卡 E 与 U 合发，第一段重做

时间：2026-10-10 18:25（UTC+8）。停点 1。镜像已构建并写入 Harbor 与镜像锁，四个应用已 stage。没有 flux-release，没有晋级，没有 `application-check`。

## U2 摘进 luna

四个后端都在本地 `luna` 分支上 `git cherry-pick`，没有冲突。tpl、info、knowledge 原先没有本地 `luna` 分支，从父仓 luna 正指着的提交建了本地分支再摘。摘进来的提交树：tpl、info、knowledge 与 fable 那一笔逐树相同；investment 的 `auth_service.py` 与 `tests/test_auth_service.py` 与 fable `7a28123` 相同，`core/config.py` 在自动合并后还留着 luna 上已有的配置。

| 应用 | fable | luna 后端 | 父仓 |
| --- | --- | --- | --- |
| tpl | `375b38e` | `6ff511cdc094560e8980f59e4b3ce44c775c93bf` | `a72ada70b618660468d2c9635a64a3b5348434da` |
| info | `5bdd4b2` | `87062b7a673a1fbc21b34122013f5cdebede08a6` | `38c6d0a90f432f7584644d080c9ae0694a79b154` |
| knowledge | `77c643b` | `85409177b85bfc51bb710a68f5be3740c7dbd3e4` | `ee6ad50db3076b73de733c98691eda2580b66c48` |
| investment | `7a28123` | `1c9f99f56fa9c4b6789c6a9ab1afb759f26980ac` | `0e494527b6ec79880cd4c1543c1dc93714798775` |

投资网页仍是 `18e4268b25d1eb4e7fc70f285d517f762309b932`，父仓指针已经指着它。

全量用本机一次性 Postgres（`agent_tests` / `delivery_tests`），跑完已停掉容器。ruff 只查了三个改到的文件，lint-imports 四个仓都是 4 kept、0 broken。

| 仓 | pytest |
| --- | --- |
| tpl | 340 通过，5 跳过 |
| info | 1158 通过，13 跳过 |
| knowledge | 967 通过，6 跳过 |
| investment | 958 通过，5 跳过 |

## 候选里的镜像

`platform-build` 只做了这五个，镜像锁和候选负载里的摘要一致。其余网页、管理端没有重建。

| 候选 | 摘要 | 源码 |
| --- | --- | --- |
| tpl-backend | `sha256:b4b94f049f8414e970e3e5d82057ae0bca2982ef41db5fc7744ffdf8866b7dee` | `6ff511cdc094560e8980f59e4b3ce44c775c93bf` |
| info-backend | `sha256:b470e2fd4f17a65c038bd9547626dc6a822675c3d2ad47e1fbbad62f3268546c` | `87062b7a673a1fbc21b34122013f5cdebede08a6` |
| knowledge-backend | `sha256:d88fee857408281a6d5188bd48e58d42f6662f6a5bf50a10b84703613a4b69a3` | `85409177b85bfc51bb710a68f5be3740c7dbd3e4` |
| investment-backend | `sha256:09405580a3d61058b0693b741c93ccf68fce29b9d6089f3e990f0a3e0472e615` | `1c9f99f56fa9c4b6789c6a9ab1afb759f26980ac` |
| investment-web-frontend | `sha256:d88900e23d29c60afb4b4539c0e17a98f797b55b6c24cbd7d4812794ce3c4884` | `18e4268b25d1eb4e7fc70f285d517f762309b932` |

投资后端的迁移头是 `20261009_0014`（电脑接入）。配置里的 `expected_schema_revision` 从 `20261007_0013` 改成这个头，否则 stage 拒绝渲染。info / knowledge / tpl 的迁移头没变。

## identity 与投资接线

四个应用的候选都有 identity v3：`*-identity-provision-v3`，`CASDOOR_USER_ORGANIZATION=sunmoonai`，网页 ConfigMap `WEB_CASDOOR_ORGANIZATIONS=sunmoonai`。Job 名：

| 应用 | Job |
| --- | --- |
| investment | `investment-identity-09405580a3d6-v3` |
| info | `info-identity-b470e2fd4f17-v3` |
| knowledge | `knowledge-identity-d88fee857408-v3` |
| tpl | `tpl-identity-b4b94f049f84-v3` |

投资接线还在：代理包 `0.2.4`，对象 `windows-x64/0.2.4/sunmoon-agent-0.2.4-a878d14-windows-x64.zip`，安装模板 `lookup('file', …, rstrip=False)`，`WORKBENCH_AGENT_PAIRING_HMAC_KEY: {source: random}`，明文 `WORKBENCH_TRUSTED_PROXY_CIDRS=127.0.0.1/32,10.247.0.0/16`。

stage 还给 info、knowledge、tpl 的网页和管理端补上了 `dnsConfig.ndots: 2`。这来自已提交的长期负载模板，这四个前端镜像没有换。

## 未做

没有发布，没有晋级，没有 `application-check`，没有建 sunmoonai 账号，没有在 Windows 上配对。第二段等「可以发」。
