// R5.3 第 1 步：在 Windows 上用组好的包核 PowerShell → 外部程序的管道是 UTF-8（sunmoon-link 1d8e838）。
// 用法（Windows，包内 node）：node r53_encoding_probe.mjs <包目录>\app
// 照代理执行命令时的样子：先按代理的规则改写命令与环境，再让 PowerShell 把一段带中文的 Python 经管道交给 python。
// 要看到最后一行 `probe ok`；中文变成问号时打出 `probe FAILED` 并退出 1。只在临时目录里建一个文件并删掉。
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const app = process.argv[2];
if (!app) { console.error("usage: node r53_encoding_probe.mjs <package>\\app"); process.exit(2); }
const m = await import(pathToFileURL(path.join(app, "dist", "windowsEncoding.js")).href);
const script = [
  "@'",
  "import os",
  "name = '探针_中文.txt'",
  "open(name, 'w', encoding='utf-8').write('中文')",
  "print('seen', name, os.path.exists(name))",
  "os.remove(name)",
  "'@ | python -",
].join("\n");
const argv = m.windowsUtf8Argv(["powershell.exe", "-NoProfile", "-Command", script]);
const r = spawnSync(argv[0], argv.slice(1), { env: m.windowsUtf8Environment(process.env), encoding: "utf8", cwd: os.tmpdir() });
const out = `${r.stdout ?? ""}${r.stderr ?? ""}`.trim();
console.log(out);
const ok = r.status === 0 && out.includes("seen 探针_中文.txt True");
console.log(ok ? "probe ok" : "probe FAILED");
process.exit(ok ? 0 : 1);
