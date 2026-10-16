# 待办 65：边缘只放行 Casdoor 登录路径（Opus，远程机）

结论：边缘 Traefik 对 `casdoor.sunmoonai.com` 只放行 OAuth 登录要用的路径，其余 403；investment、relay 不变。远程机隔离实验全部通过。2026-10-16 所有者批准后已部署到边缘（见文末「部署」），所有者用手机走公网登录 investment 成功，完成。

## 改了什么

- `infrastructure/edge/config.yaml`：新增 `edge_path_allowlist`（按域名；`paths` 精确、`prefixes` 前缀）。casdoor：`/login/oauth/authorize`、`/signup/oauth/authorize`、`/api/get-account`、`/api/get-app-login`、`/api/login`，前缀 `/assets/`。
- `templates/dynamic.yml.j2`：列了清单的域名生成放行 router（priority 200）+ 拒绝 router（priority 100，`deny-all` = `ipAllowList 0.0.0.0/32` → 403，服务 `noop@internal`）；没列的域名照旧。纯 Jinja，不用 Ansible 专有过滤器。
- `service.yaml`：断言清单域名都在 `edge_domains` 里、只有 `paths`/`prefixes` 两个键、路径只含 `/A-Za-z0-9._-` 且以 `/` 开头、每个域名至少一条。
- `smoke/run.sh`：casdoor 改测放行路径回显 Host + 管理路径 403（13 → 14 项）；`sunmoon-edge.service` 在跑就拒绝运行——冒烟和现网同一个单元名，清理时会停掉它，上线后在边缘机上跑会替换并停掉现网边缘（原来就有的隐患，这次发现）。没在边缘机上跑冒烟，原因同上。

## 清单怎么来的

不靠读前端代码猜：在远程机起一套同版本 Casdoor（`casbin/casdoor:4.12.0`，锁定摘要），临时 postgres，按 `common/backend/identity/provision.py.j2` 的字段建组织 `sunmoonai` 和应用（授权码 + PKCE、关注册、只用密码），一个测试用户（随机密码，只在 scratchpad；管理员用全新实例的出厂口令，从 `admin.pw` 读，不写进脚本）；用边缘真模板渲染 Traefik 配置（smoke 证书，后端改指临时 Casdoor），无头 Chromium 走：首次进入授权页 → 错密码 → 对密码拿到回跳 → 再次授权 → 注册页。录下发往 casdoor 域的每个请求（方法、路径、状态；不记查询串与 code）。

录到的全部路径：页面 `/login/oauth/authorize`、`/signup/oauth/authorize`；静态 `/assets/*`（JS/CSS/字体）；接口只有 `GET /api/get-account`、`GET /api/get-app-login`、`POST /api/login`。换令牌、JWKS 由后端经 `*_BACKCHANNEL_ENDPOINT` 走集群内部（SDD 0013 第 88 行核实过），不经边缘，所以 `/.well-known/`、`/api/login/oauth/access_token` 不放行。图标走 `cdn.casbin.org`。

## 验证（全在远程机隔离容器 `opus65-*`，只绑 127.0.0.1，未碰现网边缘，验完已删）

| 项 | 结果 |
| --- | --- |
| 改前配置走全流程 | 拿到回跳 `has_code=true`；路径如上 |
| 改后配置走全流程 | 路径集合与改前**完全一致**，全部 200，拿到回跳 |
| Ansible `template` 渲染 vs 实验渲染 | 逐字一致（后端地址替换后） |
| `edge-plan`（真 config） | exit 0；5 种坏清单（域名不在列表、注入反引号、错键、空列表、不以 / 开头）都被断言拦下 exit 2 |
| 管理页面 `/`、`/organizations`、`/users`、`/applications`、`/forget`、`/swagger/` | 403 |
| 管理接口 `get-users`、`get-organizations`、`get-applications`、`get-user`、`add-user`、`signup`、`login/oauth/access_token`、`.well-known` | 403 |
| 绕过写法：`/assets/../`、`%2e%2e`、`/api/login/../`、`%2F`、`//`、大小写、尾斜杠、反斜杠、`/login/oauth/authorize/../../..` | 403 |
| `/assets/..%2Fapi%2Fget-users`、`/assets/%2E%2E%2F…`、`/assets/..;/…`、`..%2Fconf%2Fapp.conf`、`..%2Fetc%2Fpasswd` | 200，但内容都是前端入口页（与登录页同一份 `index.html`，sha 一致）：Casdoor 对不存在的静态文件一律回这页，没有一条到达接口或真实文件；这页里要调的管理接口全是 403 |
| `POST /api/login`（放行） | 到达 Casdoor（回「用户不存在」） |
| investment、relay 任意路径 | 不受影响（200） |

已知影响：登录页「忘记密码？」跳 `/forget`，公网 403——现在没配邮件服务，这功能本来也用不了；开找回密码时把它和相关接口重录加入清单。

## 部署后要验（所有者）

1. 远程机 `make -C infrastructure edge-deploy`（批准后由 Opus 跑），`edge-status` 两个容器 running。
2. 远程机：`curl -sk -o /dev/null -w '%{http_code}' https://casdoor.sunmoonai.com:30443/api/get-users --resolve casdoor.sunmoonai.com:30443:127.0.0.1` 得 403；`/login/oauth/authorize` 得 200。
3. 所有者用**不改 hosts 的设备**（手机流量）打开 `https://investment.sunmoonai.com:30443` 登录一次，能进工作台；再开 `https://casdoor.sunmoonai.com:30443/` 应是 403。
4. 回退：`git revert` 本提交后再 `edge-deploy`。

## 部署（2026-10-16，所有者批准）

- 部署前把要渲染的 6 个非秘密文件与边缘现行文件逐个比对：只有 `dynamic.yml` 不同（casdoor 两条路由 + `deny-all`），`traefik.yml`、`frps.toml`、`404.html`、`compose.yaml`、单元文件逐字相同。
- 部署前基线（远程机经边缘 `--resolve 127.0.0.1:30443`）：casdoor `/api/get-users` **200**、`/` 200（管理接口确实对公网开着）；investment `/` 307。
- `make edge-deploy`：exit 0，`changed=2`（写 `dynamic.yml`、重启单元）；两个容器重新起来；Traefik 无 error 日志；证书仍是 Let's Encrypt 正式证书（CN=YR1）。
- 部署后：casdoor `/login/oauth/authorize`、`/api/get-app-login`、`/api/get-account` 200，登录页引用的 `/assets/index-*.js`、`.css` 200；`/`、`/organizations`、`/api/get-users`、`/api/get-organizations`、`/api/login/oauth/access_token`、`/.well-known/openid-configuration` **403**；investment `/` 307、relay `/` 426（WebSocket 端点对普通请求的正常回应），与前一致。`/assets/` 目录本身 500（Casdoor 回的空响应，不是边缘拦截；登录不用）。
- 所有者手机（公网）验证：前几次报「密码错误」，电脑（hosts 直连）能登。排查：经公网边缘打开真实登录页，请求全部 200、`/api/login` 到达 Casdoor；同版本实验经部署配置、模拟 iPhone，正确密码登录成功，密码含 `!@#$%^&*()_+-=[]{};:,.<>/?~` 也不受影响；真实组织没开密码混淆。结论是手机端实际输入的密码不同，与边缘无关。实测 Casdoor 默认 5 次机会、任一端成功登录一次清零；所有者先在电脑登录清零后，手机登录成功。
- 附带发现：Casdoor 登录页用户名输入框没设 `autocapitalize="none"`，手机输入法可能自动把首字母改大写，而用户名区分大小写。这次不是这个原因（所有者核过），先记录，不改。

## 以后重录（升级 Casdoor 或开注册 / 找回密码 / MFA）

照上面「清单怎么来的」重做；三个脚本附在下面（放 scratchpad 跑，不进仓）。改前改后两份录制 `diff` 一致、绕过写法全 403 或只回入口页，才改清单。

### `provision.py`

```python
# 在一次性 Casdoor 里建组织、应用、测试用户。参数：目录（含 admin.pw = 全新实例的出厂管理员口令、user.pw = 测试用户随机口令）
import json, sys, urllib.request, http.cookiejar, datetime, secrets
B='http://127.0.0.1:38000'; L=sys.argv[1]
cj=http.cookiejar.CookieJar(); op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
def api(m,p,body=None):
    r=urllib.request.Request(B+p,method=m,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json','Origin':'https://casdoor.sunmoonai.com:39443'})
    d=json.load(op.open(r)); 
    if d.get('status')!='ok': raise SystemExit(f'{p}: {d.get("msg")}')
    return d.get('data')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
api('POST','/api/login',{'application':'app-built-in','organization':'built-in','username':'admin','password':open(L+'/admin.pw').read().strip(),'type':'login'})
base=api('GET','/api/get-application?id=admin/app-built-in')
api('POST','/api/add-organization',{'owner':'admin','name':'sunmoonai','displayName':'SunMoonAI','passwordType':'bcrypt','passwordOptions':['AtLeast8'],'enableSoftDeletion':False,'createdTime':now})
app={'owner':'admin','name':'sunmoonai-investment-web','organization':'sunmoonai','description':'lab65','displayName':'SunMoon template web','category':'Default','type':'Web',
 'clientId':'lab65-web-client','clientSecret':secrets.token_hex(16),'redirectUris':['https://investment.sunmoonai.com:39443/api/auth/web/callback'],
 'homepageUrl':'https://investment.sunmoonai.com:39443','cert':base['cert'],'grantTypes':['authorization_code'],'tokenFormat':'JWT','tokenSigningMethod':'RS256',
 'expireInHours':1,'refreshExpireInHours':0,'enablePassword':True,'enableSignUp':False,'enableGuestSignin':False,'enableSigninSession':False,'isShared':False,
 'signinMethods':[{'name':'Password','displayName':'Password','rule':'All'}],'createdTime':now}
print('app',api('POST','/api/add-application',app))
pw=open(L+'/user.pw').read().strip()
print('user',api('POST','/api/add-user',{'owner':'sunmoonai','name':'labuser','displayName':'Lab User','type':'normal-user','password':pw,'createdTime':now,'signupApplication':'sunmoonai-investment-web'}))
```

### `render.py`

```python
# 用边缘真模板渲染实验用 Traefik 配置：smoke 证书、后端改指临时 Casdoor。参数：模板目录 输出目录
import sys, yaml, jinja2, os
tdir, out = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(open(os.path.join(tdir, '..', 'config.yaml')))
cfg['edge_tls_mode'] = 'smoke'; cfg['edge_health_port'] = 8082
env = jinja2.Environment(loader=jinja2.FileSystemLoader(tdir), undefined=jinja2.StrictUndefined, keep_trailing_newline=True, trim_blocks=True)
os.makedirs(out, exist_ok=True)
for name in ('traefik.yml', 'dynamic.yml'):
    text = env.get_template(name + '.j2').render(**cfg)
    if name == 'dynamic.yml':
        text = text.replace(f'http://127.0.0.1:{cfg["edge_vhost_port"]}', 'http://opus65-casdoor:8000')
        assert 'opus65-casdoor' in text
    if name == 'traefik.yml':
        text = text.replace('address: "127.0.0.1:8082"', 'address: ":8082"')
    open(os.path.join(out, name), 'w').write(text)
print('rendered', out)
```

### `record.mjs`

```js
// 用无头浏览器走 Casdoor OAuth 登录，记录发往 casdoor 域的每个请求（方法 路径 状态），不记查询串与 code。
// 参数：输出文件 用户密码文件 [expect=ok|blocked]
import { createRequire } from 'node:module';
import fs from 'node:fs';
import crypto from 'node:crypto';
const require = createRequire(process.env.PW_DIR + '/');
const { chromium } = require('playwright');
const [out, pwFile] = process.argv.slice(2);
const pw = fs.readFileSync(pwFile, 'utf8').trim();
const C = 'https://casdoor.sunmoonai.com:39443';
const log = []; const other = new Set();
const b64 = (b) => b.toString('base64url');
function authUrl(kind = 'login') {
  const verifier = b64(crypto.randomBytes(32));
  const q = new URLSearchParams({ response_type: 'code', client_id: 'lab65-web-client',
    redirect_uri: 'https://investment.sunmoonai.com:39443/api/auth/web/callback', scope: 'openid profile email',
    state: b64(crypto.randomBytes(16)), nonce: b64(crypto.randomBytes(16)),
    code_challenge: b64(crypto.createHash('sha256').update(verifier).digest()), code_challenge_method: 'S256' });
  return `${C}/${kind}/oauth/authorize?${q}`;
}
const browser = await chromium.launch({ args: ['--host-resolver-rules=MAP casdoor.sunmoonai.com 127.0.0.1, MAP investment.sunmoonai.com 127.0.0.1'] });
const ctx = await browser.newContext({ ignoreHTTPSErrors: true, locale: 'zh-CN' });
let step = '';
let callbacks = 0;
await ctx.route('https://investment.sunmoonai.com:39443/**', (r) => { callbacks++; log.push(`${step}\tCALLBACK\t${new URL(r.request().url()).pathname}\thas_code=${new URL(r.request().url()).searchParams.has('code')}`); r.fulfill({ status: 200, body: 'callback-ok' }); });
ctx.on('requestfinished', async (req) => {
  const u = new URL(req.url());
  if (u.hostname === 'casdoor.sunmoonai.com') { const res = await req.response(); log.push(`${step}\t${req.method()}\t${u.pathname}\t${res ? res.status() : '-'}`); }
  else if (u.hostname !== 'investment.sunmoonai.com') other.add(u.hostname);
});
ctx.on('requestfailed', (req) => { const u = new URL(req.url()); if (u.hostname === 'casdoor.sunmoonai.com') log.push(`${step}\t${req.method()}\t${u.pathname}\tFAILED`); else other.add(u.hostname + '(failed)'); });
const page = await ctx.newPage();
const shot = (n) => page.screenshot({ path: out.replace(/\.txt$/, '') + `-${n}.png` });
async function fill(password) {
  await page.waitForSelector('input[type=password]', { timeout: 20000 });
  const user = page.locator('input:not([type=password]):not([type=hidden]):not([type=checkbox])').first();
  await user.fill('labuser');
  await page.locator('input[type=password]').fill(password);
  await page.locator('button[type=submit], button:has-text("登录"), button:has-text("Sign In")').first().click();
}
try {
  step = '1-open'; await page.goto(authUrl()); await page.waitForLoadState('networkidle'); await shot('1-open');
  step = '2-wrong'; await fill('wrong-password-123'); await page.waitForTimeout(3000); await shot('2-wrong');
  step = '3-right'; await page.reload(); await page.waitForLoadState('networkidle'); await fill(pw);
  await page.waitForURL(/investment\.sunmoonai\.com/, { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(1500); await shot('3-right');
  step = '4-again'; await page.goto(authUrl()); await page.waitForTimeout(5000); await shot('4-again');
  step = '5-signup'; await page.goto(authUrl('signup')); await page.waitForLoadState('networkidle'); await page.waitForTimeout(1500); await shot('5-signup');
} catch (e) { log.push(`${step}\tERROR\t${String(e.message).split('\n')[0]}`); await shot('error').catch(() => {}); }
log.push(`callbacks=${callbacks}`); log.push(`other_hosts=${[...other].join(',')}`);
fs.writeFileSync(out, log.join('\n') + '\n');
await browser.close();
```

