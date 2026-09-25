# KIND：Casdoor 登录页、注册页改成中文与我们的品牌；关掉 Casdoor 自带应用的注册（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按下面编号步骤做
仓与提交：k8s 本条待办所在的 fable 头
预计：20 分钟；要 KIND、helm、kubectl
看什么：第 3 步 Casdoor 下发给页面的配置里 defaultLanguage、forceLanguage 都是 zh；第 5 步登录页是中文、顶部是「SunMoon AI 投研」、页脚「© SunMoon AI」
前提：08、09、10 的后台部分已做（不依赖浏览器那几步）；不需要发信服务，也不需要 post-deploy-setup.local.conf
回传：k8s/sunmoonai/scripts/results/kind-casdoor-pages.<时间>.md（写下后在被测仓提交）
```

## 为什么有这一条

远程已在 k8s 改好（设计见 `tree-build/SDD/architecture/security.md`「账号与注册」）：Casdoor 的 Helm 配置 `app.conf` 加了 `defaultLanguage = "zh"` 与 `forceLanguage = "zh"`（镜像自带配置强制英文）；`signup-setup.sh` 管注册页、登录页的文字标题、中文提示、字段顺序、页脚，并关掉 Casdoor 自带应用 `app-built-in` 的注册（它默认开着，任何人能注册进 Casdoor 自己的管理组织）。远程已在本机 Casdoor 3.42 上用无头浏览器截图核过；这一条是让 KIND 也生效。

## 步骤

1. 看现状（只读）：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/auth-app && ./deploy-auth-app-all/deploy-auth-app-all.sh --cluster KIND status`，把输出记下。
2. 重新部署 Casdoor（Helm 升级，带上新的 app.conf）：`cd casdoor/deploy-casdoor && bash deploy-casdoor.sh --cluster KIND upgrade`。它会走数据库 bootstrap、Secret、Helm、Ingress 四步，都是幂等的；若报缺 Secret 文件或配置，**停下**把报错写进回传，不要手工补。完成后 `kubectl --kubeconfig ~/.kube/kind-config -n app-platform-dev rollout status deploy -l app.kubernetes.io/name=casdoor --timeout=180s`（选择器对不上就用 `get deploy | grep -i casdoor` 找名字）。
3. 看 Casdoor 下发给页面的配置（只读）：
   ```bash
   curl -sk -c - https://casdoor.sunmoonai.com:30443/login | grep jsonWebConfig | sed 's/%22/"/g; s/%2C/,/g; s/%3A/:/g'
   ```
   里面应有 `"defaultLanguage":"zh"` 与 `"forceLanguage":"zh"`。不是 zh 就停下，贴出这一行。
4. 注册页、登录页的设置（不需要发信服务；没配发信服务时注册保持关闭，这是设计）：
   ```bash
   cd ~/worktrees/fable/k8s/sunmoonai/app-platform/auth-app/casdoor/deploy-casdoor
   bash kind-apply-signup.sh
   ```
   应看到几行 `[OK]`：「页面品牌：标题「SunMoon AI 投研」，标志=文字，只用中文」「已关闭 Casdoor 自带应用 app-built-in 的注册」，最后一行含「注册=false」。
5. 浏览器（所有者，换一个无痕窗口免得旧的语言设置干扰）：打开投资网页 `https://investment.sunmoonai.com:30443` 点登录，跳到 Casdoor 登录页。应该看到：中文界面（"登 录""忘记密码？"），顶部一行字「SunMoon AI 投研」（没有破图标），页脚「© SunMoon AI」，没有右上角的语言地球图标；此时**没有**"立即注册"链接（注册还关着）。用你的账号登录一次，确认照常能进。
6. 回传：每步输出（第 2 步只要最后 30 行）；第 5 步屏幕上看到了什么（可以附截图文件放 results/）。过滤含 password、token、secret 的行。

以后开注册：开通腾讯云邮件推送后，在 `~/private/casdoor-signup.env`（0600，不进 git）里写 `SIGNUP_SMTP_HOST`、`SIGNUP_SMTP_USER`、`SIGNUP_SMTP_PASSWORD`、`SIGNUP_SMTP_FROM` 和可选的 `SIGNUP_INVITATION_CODE`，再跑 `SIGNUP_ENV=~/private/casdoor-signup.env bash kind-apply-signup.sh`，最后一行变成「注册=true」。那是另一条待办。
