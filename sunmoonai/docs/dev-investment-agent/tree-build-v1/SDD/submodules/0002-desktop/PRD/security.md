# 安全与登录

> 窗口的能力边界见 [窗口组成与能力边界](windows.md)。

**安全**（必须）：

- 界面随应用打包，不从后端加载主界面（不用 `loadURL` 指向后端网址）；
- 开启 `contextIsolation`、`sandbox`，关闭 `nodeIntegration`；禁止窗口导航到外部网址；设置 CSP；
- preload 只经 `contextBridge` 暴露具体函数（如 `approve(id, ok)`、`saveKey(provider, key)`），不暴露通用执行接口；
- 本机能力分窗口授予：只有本地窗口挂能调用 runtime 的 preload；主窗口只挂只读能力与结果解密所需的具体函数；审查窗口只挂解密所需的具体函数，不挂任何写本机或调用执行的能力；
- 页面与 runtime 的交互集中在 `runtimeClient` 模块；
- 代码签名（Windows 优先 EV 证书）、macOS 公证、自动更新，更新包校验完整性。

**登录与会话**：

- 系统浏览器打开认证服务（Casdoor）的登录页，走 OAuth PKCE，经自定义协议回到应用；
- token 存系统钥匙串，刷新由应用负责；后端持有会话与投影；
- 设备配对复用同一登录态（[`0003-runtime/PRD/device.md`](../../0003-runtime/PRD/device.md)）。

