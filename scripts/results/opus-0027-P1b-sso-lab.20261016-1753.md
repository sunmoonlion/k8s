# 0027 P1b 第一步：单点登录实验（Opus，远程机）

结论：Casdoor 4.12.0 上，sunmoonai 组织的网页端应用要**同时打开「保持登录会话」（`enableSigninSession`）和「自动登录」（`enableAutoSignin`）**，在一个应用登录后跳到另一个才不用再输密码。退出用 OIDC 退出接口 `/api/logout`，**带上登录时的 id_token** 才能结束会话并跳回应用。Casdoor 登录会话默认保持 30 天，由 `app.conf` 的 `sessionCookieLifeTime`（秒）调。边缘放行清单要加 `/api/logout`。全部在远程机隔离容器 `opus65-*` 里实测（只绑 127.0.0.1，已删），没碰现网。

## 做法

同版本 Casdoor（`casbin/casdoor:4.12.0`，锁定摘要）+ 临时 postgres；组织 `sunmoonai`，两个网页端应用（模拟 investment、knowmart，字段照 `common/backend/identity/provision.py.j2`），一个测试用户（随机密码，只在 scratchpad）；前面接用边缘真模板渲染的 Traefik。无头 Chromium：A 登录 → 跳 B → 退出 → 再跳 B。只记路径与状态，不记 code、令牌。

## 结果

| 设置 | A 登录后跳 B | 退出后再跳 B |
| --- | --- | --- |
| 两个都关（现状，正式环境也是） | 登录框，要再输密码 | 登录框 |
| 只开保持登录会话 | 登录框 | 登录框 |
| 只开自动登录 | 登录框 | 登录框 |
| **两个都开** | **授权请求服务端直接 302 回 B 的回调带 code，不显示页面** | **登录框（会话已结束）** |

- 现状下登录后也会下发 `casdoor_session_id`（30 天），只是应用不用它；所以「账号统一」一直是，「登录一次处处免登」现在不是。
- 退出：`GET /api/logout?id_token_hint=<登录时的 id_token>&post_logout_redirect_uri=<登记过的地址>&state=…` → 结束会话并 302 回该地址。不带 id_token 也能结束会话，但停在 Casdoor 的接口页，跳不回应用。模板后端现在退出只删本地会话、不存 id_token（`tpl-backend` `app/interfaces/http/web/auth.py`），要改。
- 会话时长：cookie `Max-Age=2592000`（30 天），勾不勾「下次自动登录」都一样；应用上的 `cookieExpireInHours` 管不到它（设 12 仍是 720 小时）。Casdoor 源码 `main.go` 读 `app.conf` 的 `sessionCookieLifeTime`（秒，默认 30 天）；4.12.0 实测设 `43200` 后 cookie 变 12 小时，单点登录与退出照常。这是全局设置，管理端登录也一起变短。
- 两个开关不开的应用（如 built-in 组织的管理端），即使浏览器里有会话也照样弹登录框——只给 sunmoonai 的网页端开，管理端不受影响。
- 经边缘过滤配置（待办 65 的清单加 `/api/logout`）：单点登录、退出、退出后重新登录都通过，没有被拦的请求；原登录流程照常（第二次授权变成 302 自动回跳）。

## 补记（同日稍后，写模板代码时）

- 改用 `client_id` 代替 `id_token_hint` 也行：`/api/logout?client_id=<本面>&post_logout_redirect_uri=<登记过的地址>&state=…` 同样结束会话并跳回。`client_id` 对但地址没登记、或拿 B 的 `client_id` 配 A 的地址，都不跳回（会话照样结束）。所以**不存任何令牌**：模板原有约束「会话记录里不出现 id_token」保持（Casdoor 的 id_token 与 access_token 同钥签名、内容几乎一样，存它近乎存访问令牌）。下面第 3 条按此改。
- 发现文档有标准的 `end_session_endpoint`（= `/api/logout`），后端按标准从发现文档读、同源校验。

## 对 P1b 实施的输入

1. identity 共用机制：sunmoonai 网页端应用 `enableSigninSession`、`enableAutoSignin` 改 true（显式迁移，不靠漂移放行；`identity_revision` 递增）；管理端不动。
2. `app.conf` 加 `sessionCookieLifeTime`（时长待所有者定）。
3. 模板后端：退出删本地会话后返回 Casdoor 退出地址（带 `client_id`，不存令牌），前端跳过去；落地地址 `/api/auth/<面>/logged-out` 登记进应用的 redirectUris。
4. 边缘 `edge_path_allowlist` 的 casdoor 加 `/api/logout`，部署照待办 65 的做法。

## 脚本

放 scratchpad 跑，不进仓。`sso-provision.py` 建组织、两个应用、用户并切开关；`sso.mjs` 走 A 登录 → 跳 B → 退出 → 再跳 B。

### `sso-provision.py`

```python
# 一次性 Casdoor：组织 sunmoonai、两个网页端应用（照正式字段）、测试用户。参数：目录 [session auto]（0/1，改两个应用的开关）
import json, sys, urllib.request, http.cookiejar, datetime, secrets
L=sys.argv[1]; B='http://127.0.0.1:38000'
cj=http.cookiejar.CookieJar(); op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
def api(m,p,b=None):
    d=json.load(op.open(urllib.request.Request(B+p,data=json.dumps(b).encode() if b is not None else None,headers={'Content-Type':'application/json'},method=m)))
    if d.get('status')!='ok': raise SystemExit(f'{p}: {d.get("msg")}')
    return d.get('data')
api('POST','/api/login',{'application':'app-built-in','organization':'built-in','username':'admin','password':open(L+'/admin.pw').read().strip(),'type':'login'})
apps={'inv':('sunmoonai-investment-web','https://investment.sunmoonai.com:39443'),'km':('sunmoonai-knowmart-web','https://knowmart.sunmoonai.com:39443')}
if len(sys.argv)==2:
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    base=api('GET','/api/get-application?id=admin/app-built-in')
    api('POST','/api/add-organization',{'owner':'admin','name':'sunmoonai','displayName':'SunMoonAI','passwordType':'bcrypt','passwordOptions':['AtLeast8'],'enableSoftDeletion':False,'createdTime':now})
    secrets_out={}
    for key,(name,origin) in apps.items():
        sec=secrets.token_hex(16); secrets_out[key]=sec
        api('POST','/api/add-application',{'owner':'admin','name':name,'organization':'sunmoonai','description':'lab','displayName':name,'category':'Default','type':'Web',
          'clientId':'lab-'+key,'clientSecret':sec,'redirectUris':[origin+'/api/auth/web/callback',origin+'/'],'homepageUrl':origin,'cert':base['cert'],
          'grantTypes':['authorization_code'],'tokenFormat':'JWT','tokenSigningMethod':'RS256','expireInHours':1,'refreshExpireInHours':0,
          'enablePassword':True,'enableSignUp':False,'enableGuestSignin':False,'enableSigninSession':False,'isShared':False,
          'signinMethods':[{'name':'Password','displayName':'Password','rule':'All'}],'createdTime':now})
    json.dump(secrets_out,open(L+'/client-secrets.json','w'))
    api('POST','/api/add-user',{'owner':'sunmoonai','name':'labuser','displayName':'Lab','type':'normal-user','password':open(L+'/user.pw').read().strip(),'createdTime':now})
    print('provisioned')
else:
    session,auto=bool(int(sys.argv[2])),bool(int(sys.argv[3]))
    for key,(name,_) in apps.items():
        a=api('GET','/api/get-application?id=admin/'+name); a['enableSigninSession']=session; a['enableAutoSignin']=auto
        api('POST','/api/update-application?id=admin/'+name,a)
        b=api('GET','/api/get-application?id=admin/'+name); print(name,'session',b['enableSigninSession'],'auto',b['enableAutoSignin'])
```

### `sso.mjs`

```js
// 单点登录实测：A 登录 → 跳 B → OIDC 退出 → 再跳 B。记录发往 casdoor 的请求（方法 路径 状态）与每步结论；不记 code、令牌。
// 参数：输出文件 用户密码文件 客户端秘密文件 端口
import { createRequire } from 'node:module';
import fs from 'node:fs';
import crypto from 'node:crypto';
const require = createRequire(process.env.PW_DIR + '/');
const { chromium } = require('playwright');
const [out, pwFile, secFile, port] = process.argv.slice(2);
const pw = fs.readFileSync(pwFile, 'utf8').trim(); const secrets = JSON.parse(fs.readFileSync(secFile, 'utf8'));
const C = `https://casdoor.sunmoonai.com:${port}`;
const origin = { inv: `https://investment.sunmoonai.com:${port}`, km: `https://knowmart.sunmoonai.com:${port}` };
const b64 = (b) => b.toString('base64url');
const pending = {};
function authUrl(key) {
  const verifier = b64(crypto.randomBytes(32)); const state = b64(crypto.randomBytes(12));
  pending[state] = { key, verifier };
  const q = new URLSearchParams({ response_type: 'code', client_id: 'lab-' + key, redirect_uri: origin[key] + '/api/auth/web/callback',
    scope: 'openid profile email', state, nonce: b64(crypto.randomBytes(12)),
    code_challenge: b64(crypto.createHash('sha256').update(verifier).digest()), code_challenge_method: 'S256' });
  return `${C}/login/oauth/authorize?${q}`;
}
const log = []; let step = ''; const got = {};
const browser = await chromium.launch({ args: ['--host-resolver-rules=MAP casdoor.sunmoonai.com 127.0.0.1, MAP investment.sunmoonai.com 127.0.0.1, MAP knowmart.sunmoonai.com 127.0.0.1'] });
const ctx = await browser.newContext({ ignoreHTTPSErrors: true, locale: 'zh-CN' });
for (const k of ['inv', 'km']) await ctx.route(origin[k] + '/**', (r) => {
  const u = new URL(r.request().url());
  if (u.pathname === '/api/auth/web/callback') { const st = pending[u.searchParams.get('state')]; got[step] = { key: k, code: u.searchParams.get('code'), verifier: st?.verifier }; log.push(`${step}\tCALLBACK\t${k}\thas_code=${u.searchParams.has('code')}`); }
  else log.push(`${step}\tLANDED\t${k}${u.pathname}\tparams=${[...u.searchParams.keys()].join(',')}`);
  r.fulfill({ status: 200, body: 'ok' });
});
ctx.on('requestfinished', async (req) => { const u = new URL(req.url()); if (u.hostname === 'casdoor.sunmoonai.com' && !u.pathname.startsWith('/assets/')) { const r = await req.response(); log.push(`${step}\t${req.method()}\t${u.pathname}\t${r ? r.status() : '-'}`); } });
ctx.on('response', (r) => { const s = r.status(); if (s >= 300 && s < 400) { const loc = r.headers()['location'] || ''; let where = loc; try { const u = new URL(loc, r.url()); where = `${u.protocol}//${u.host}${u.pathname} params=${[...u.searchParams.keys()].join(',')}`; } catch {} log.push(`${step}\tREDIRECT\t${new URL(r.url()).pathname} -> ${where}`); try { const u = new URL(loc, r.url()); if (u.pathname === '/api/auth/web/callback' && u.searchParams.has('code') && !got[step]) got[step] = { key: u.hostname.split('.')[0], code: u.searchParams.get('code'), verifier: pending[u.searchParams.get('state')]?.verifier, via: 'redirect' }; } catch {} } });
const page = await ctx.newPage();
async function waitOutcome(ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { if (got[step]) return 'auto-callback'; if (await page.locator('input[type=password]').count()) return 'login-form'; await page.waitForTimeout(250); }
  return got[step] ? 'auto-callback' : 'neither';
}
try {
  step = '1-loginA'; await page.goto(authUrl('inv'));
  await page.waitForSelector('input[type=password]', { timeout: 20000 });
  await page.locator('input:not([type=password]):not([type=hidden]):not([type=checkbox])').first().fill('labuser');
  await page.locator('input[type=password]').fill(pw);
  await page.locator('button[type=submit]').first().click();
  await page.waitForTimeout(3000); log.push(`${step}\tRESULT\t${got[step] ? 'logged-in' : 'FAILED'}`);
  const cookies = (await ctx.cookies(C)).map((c) => `${c.name}(${c.expires > 0 ? Math.round((c.expires - Date.now() / 1000) / 3600) + "h" : "session"})`); log.push(`${step}\tCOOKIES\t${cookies.join(',')}`);
  step = '2-jumpB'; await page.goto(authUrl('km')); log.push(`${step}\tRESULT\t${await waitOutcome(8000)}`); await page.screenshot({ path: out.replace(/\.txt$/, '-jumpB.png') }); log.push(`${step}\tTEXT\t${(await page.locator('body').innerText()).replace(/\s+/g, ' ').slice(0, 200)}`);
  // 用 A 的 code 换 id_token（后端那条路，直连 Casdoor，不经边缘）
  const a = got['1-loginA']; let idt = '';
  if (a) { const body = new URLSearchParams({ grant_type: 'authorization_code', client_id: 'lab-inv', client_secret: secrets.inv, code: a.code, redirect_uri: origin.inv + '/api/auth/web/callback', code_verifier: a.verifier });
    const tr = await fetch('http://127.0.0.1:38000/api/login/oauth/access_token', { method: 'POST', body }); const tj = await tr.json(); idt = tj.id_token || ''; log.push(`token\tEXCHANGE\t${tr.status}\thas_id_token=${!!idt}`); }
  step = '3-logout'; await page.goto(`${C}/api/logout?` + new URLSearchParams({ id_token_hint: idt, post_logout_redirect_uri: origin.inv + '/', state: 'bye' }));
  await page.waitForTimeout(3000); log.push(`${step}\tFINAL_URL\t${new URL(page.url()).hostname}${new URL(page.url()).pathname}`);
  log.push(`${step}\tCOOKIES\t${(await ctx.cookies(C)).map((c) => c.name).join(',')}`);
  step = '4-jumpB-after-logout'; await page.goto(authUrl('km')); log.push(`${step}\tRESULT\t${await waitOutcome(8000)}`);
} catch (e) { log.push(`${step}\tERROR\t${String(e.message).split('\n')[0]}`); }
fs.writeFileSync(out, log.join('\n') + '\n'); await browser.close();
```

