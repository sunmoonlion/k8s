# 跨应用跳转：一个应用把用户带到另一个应用

> 产品层面的约定在 [`PRD/apps/README.md`](../../PRD/apps/README.md) 4.1。这一份写的是它落在代码里的样子。
> 对应 [先后顺序](../../PRD/apps/README.md) 的第 5 步，2026-09-29 做完：先进模板，再同步到 info、knowledge、investment。
> 页面还没有用到它。第 7、8、9 步做页面时直接用。

## 一、约定

| 项 | 约定 |
| --- | --- |
| 形式 | 普通链接，在新标签页打开 |
| 链接里带 | 业务参数（例如证券代码）、`from`（从哪个应用来）、`ref`（来处的引用） |
| 链接里不带 | 身份、令牌、回去的地址 |
| 用户是谁 | 由用户在目标应用的登录决定 |
| 回去的地址 | 目标应用按 `from` 在自己的配置里查，把 `ref` 填进去。从不从链接里取 |
| `ref` | 不透明的字符串，最长 128，只许字母数字与 `._:-`。目标应用只存、只原样显示 |
| 链接带来的参数 | 不可信。不认识的应用、不合规则的引用当作没带，不报错：用户只是点了一个链接，不该因为链接不对就看到错误页 |
| 拼链接的代码 | 每个应用的网页端只在一处拼。后端不拼去别的应用的链接 |

## 二、后端

四个仓库里逐字相同（模板与三个应用），只有配置的默认值不同。

| 项 | 位置 |
| --- | --- |
| 规则 | `app/domain/cross_app.py` |
| 配置 | `core/config.py` 的 `cross_app_sources_json`、`cross_app_targets_json` |
| 接口 | `app/interfaces/http/web/cross_app.py` |
| 测试 | `tests/test_cross_app.py`，54 项 |

| 配置 | 含义 | 例 |
| --- | --- | --- |
| `CROSS_APP_SOURCES_JSON` | 哪些应用可以把用户带到这里，各自的回跳地址。没写回跳地址的，页面上不显示「回到原处」 | `{"investment": {"return_url": "https://…/zh-CN/workbench?ref={ref}"}, "knowledge": {}}` |
| `CROSS_APP_TARGETS_JSON` | 这个应用会把用户带去哪些应用，各自网页端的地址。没配的，页面上不显示去那里的链接 | `{"info": {"web_base_url": "https://info.example"}}` |

| 应用 | 默认认谁带来的用户 | 默认带用户去哪 |
| --- | --- | --- |
| 模板 | 谁都不认 | 哪都不去 |
| info | investment、knowledge，都没有回跳地址 | 哪都不去 |
| knowledge | investment、info，都没有回跳地址 | 哪都不去 |
| investment | 谁都不认 | 哪都不去 |

| 配置写错了 | 后果 |
| --- | --- |
| 不是 JSON、应用名不合规则、多了别的项 | 启动时就报错 |
| 回跳地址不是完整的 http(s) 地址、带账号口令、带 `#`、`{ref}` 出现两次、`{ref}` 在主机名里、有别的花括号 | 启动时就报错 |

| 接口 | 作用 | 谁能调 |
| --- | --- | --- |
| `GET /api/web/v1/cross-app/links` | 这个应用自己的名字；会带用户去哪些应用、各自网页端的地址 | 登录的用户 |
| `GET /api/web/v1/cross-app/origin?from=&ref=` | 链接带来的「从哪来」：认得就返回应用名、引用、回跳地址；认不得返回空 | 登录的用户 |

都是只读的。

## 三、网页端

四个仓库里逐字相同，只有 `destinations.ts` 各填各的。

| 文件 | 作用 |
| --- | --- |
| `contracts/cross-app.ts` | 两个接口的返回长什么样。地址不是完整的 http(s) 地址就不认 |
| `lib/cross-app/links.ts` | 拼链接。整个网页端只有这一处 |
| `lib/cross-app/destinations.ts` | 这个应用要去的页面，逐个登记 |
| `lib/cross-app/client.ts`、`use-cross-app.ts` | 向后端取地址、认「从哪来」 |
| `components/common/cross-app-link.tsx` | 去别的应用的链接。新标签页；不把来处的地址与窗口的引用交给对方 |
| `components/common/return-to-origin.tsx` | 「回到原处」。地址只用后端给的 |

| 规则 | 怎么守 |
| --- | --- |
| 身份、令牌、回去的地址不进链接 | 登记要去的页面时，参数名在禁用的名单里就报错（`token`、`session`、`return_to`、`return_url`、`redirect` 等） |
| 没登记的参数不许带 | 拼链接时报错 |
| 引用不合规则 | 当作没带，链接照给 |
| 目标应用没有配置 | 不给链接。页面不显示一个点不动的 |
| 后端的返回不合约定 | 不给链接 |
| 地址栏里带了回去的地址 | 不看。测试里专门带一个假的核对 |

### 各应用登记的页面

| 应用 | 键 | 去哪 | 路径 | 业务参数 |
| --- | --- | --- | --- | --- |
| investment | `info.request` | info | `requests/new` | `code` |
| investment | `knowledge.catalog` | knowledge | `catalog` | — |
| investment | `knowledge.dataset` | knowledge | `catalog/<数据集>` | — |
| knowledge | `info.request` | info | `requests/new` | `code` |
| info | `knowledge.dataset` | knowledge | `catalog/<数据集>` | — |
| info | `knowledge.catalog` | knowledge | `catalog` | — |

用法：

```tsx
<CrossAppLink to="info.request" values={{ code: '600519' }} refValue={taskId}>
  申请入库
</CrossAppLink>
<ReturnToOrigin>回到原处</ReturnToOrigin>
```

拼出来的链接：`https://<info 网页端>/zh-CN/requests/new?code=600519&from=investment&ref=<委托编号>`

## 四、info 原来那一份

info 做采集申请时先写过一份专用的（2026-09-29，`3b5d037`）。这次换成共用的，三处变了。都还没有部署过，没有页面在用。

| 项 | 原来 | 现在 |
| --- | --- | --- |
| 配置 | `SECURITY_REQUEST_SOURCES_JSON`、`KNOWLEDGE_WEB_BASE_URL` | `CROSS_APP_SOURCES_JSON`、`CROSS_APP_TARGETS_JSON` |
| 接口 | `GET /api/web/v1/security-request-origin` | `GET /api/web/v1/cross-app/origin` |
| 申请的返回里去 knowledge 的地址模板 | 有（`catalog_url_template`） | 没有，只给数据集的编号。链接由网页端拼 |

## 五、提交

| 仓库 | 后端 | 网页端 | 上级仓库 |
| --- | --- | --- | --- |
| 模板 | `742fc11` | `0030678` | `f2546d7` |
| info | `c55b2a8` | `9127094` | `64df53d` |
| knowledge | `966d6d5` | `4af70ec` | `470b1b9` |
| investment | `f99c398` | `f4be400` | `8618343` |

都在 `fable` 分支。四个网页端的仓库原来没有 `fable` 分支，这次建了。

## 六、验证

| 检查 | 模板 | info | knowledge | investment |
| --- | --- | --- | --- | --- |
| 后端全部测试 | 316 过，5 跳过 | 1131 过，13 跳过 | 908 过，5 跳过 | 752 过，5 跳过 |
| 后端代码检查、类型检查、分层四条规则 | 过 | 过 | 过 | 过 |
| 网页端测试 | 63 过，2 跳过 | 66 过，2 跳过 | 65 过，2 跳过 | 90 过，2 跳过 |
| 网页端类型检查、代码检查、文案检查、构建 | 过 | 过 | 过 | 过 |

info 换掉原来那一份之后，用本机联调把「申请 → 批准 → 采集 → 建库 → 可用」真跑了一遍（`run.sh requested 600276`）：280 秒走到可用；专家的位置上经工具核对 30 项，全过。

## 七、没有验证的

| 项 | 为什么 |
| --- | --- |
| 在浏览器里从一个应用点到另一个应用 | 页面还没有做 |
| 登录过一个应用的用户到另一个应用不用再输密码 | 要三个应用连同身份服务一起跑。等集群 |
| 真的配置 | 各应用网页端的地址要等集群上定下来才有 |

## 八、管理端

管理端（`*-admin-frontend`）没有同步。现在没有哪个管理页面要把人带去别的应用。要用的时候按同样的做法加。
