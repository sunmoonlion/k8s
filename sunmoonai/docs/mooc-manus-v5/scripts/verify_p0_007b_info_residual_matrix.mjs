import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require(
  "/home/zymun/tpl-app/tpl-admin-frontend/node_modules/@playwright/test",
);
const kubeconfig = process.env.KUBECONFIG || (process.env.HOME + "/.kube/kind-config");
const namespace = process.env.P0_NAMESPACE || "app-platform-dev";
const origin = process.env.P0_ORIGIN || "http://127.0.0.1:19082";
const secret = JSON.parse(execFileSync(
  "kubectl",
  ["--kubeconfig", kubeconfig, "get", "secret", "sunmoonai-p0-005-browser-identity", "-n", namespace, "-o", "json"],
  { encoding: "utf8" },
));
const decode = (key) => Buffer.from(secret.data[key], "base64").toString("utf8");
const identity = { username: decode("PRIMARY_USERNAME"), password: decode("PRIMARY_PASSWORD") };
const host = new URL(origin).hostname;
const browser = await chromium.launch({
  headless: true,
  ignoreHTTPSErrors: true,
  args: ["--host-resolver-rules=MAP " + host + " 127.0.0.1,MAP casdoor.sunmoonai.com 127.0.0.1"],
});
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();
const externalHosts = new Set();
page.on("request", (request) => {
  const requestHost = new URL(request.url()).hostname;
  if (!["127.0.0.1", "localhost", host, "casdoor.sunmoonai.com"].includes(requestHost)) externalHosts.add(requestHost);
});

try {
  await page.goto(origin + "/api/auth/login?return_to=/info/crawl", { waitUntil: "commit", timeout: 30000 });
  const username = page.locator('input[name="username"], input[autocomplete="username"], input[type="text"]').first();
  await username.fill(identity.username);
  await username.press("Enter");
  const password = page.locator('input[name="password"], input[autocomplete="current-password"], input[type="password"]').first();
  await password.fill(identity.password);
  await password.press("Enter");
  await page.waitForURL(origin + "/info/crawl", { waitUntil: "domcontentloaded", timeout: 45000 });
  await page.getByRole("heading", { name: "资讯采集与治理" }).waitFor({ state: "visible", timeout: 30000 });

  const checks = await page.evaluate(async (origin) => {
    const checks = {};
    const id = crypto.randomUUID();
    let csrf = "";
    const read = async (path, options = {}) => {
      const response = await fetch(origin + path, { credentials: "include", ...options });
      let body = null;
      try { body = await response.json(); } catch { body = null; }
      return { response, body };
    };
    const headers = (reason, operationId = crypto.randomUUID(), contentType = true) => ({
      ...(contentType ? { "Content-Type": "application/json" } : {}),
      "X-CSRF-Token": csrf,
      "X-Correlation-ID": crypto.randomUUID(),
      "X-Operation-ID": operationId,
      "X-Audit-Reason": reason,
    });
    const me = await read("/api/auth/me");
    if (me.response.status !== 200 || !me.body?.csrf_token) throw new Error("auth contract failed");
    csrf = me.body.csrf_token;
    checks.auth = { status: me.response.status, csrf_present: true };

    const dangerous = await read("/api/admin/crawl-jobs", {
      method: "POST",
      headers: headers("P0-007B dangerous URL " + id),
      body: JSON.stringify({ target_url: "javascript:alert(1)", enqueue: false }),
    });
    if (dangerous.response.status !== 422) throw new Error("dangerous URL was not rejected status=" + dangerous.response.status);
    checks.dangerous_url = { status: dangerous.response.status, accepted: false };

    const xssTitle = '<img src=x onerror="window.__p0_xss=1">';
    const form = new FormData();
    form.append("file", new File(["P0-007B XSS text " + id + "\n"], "p0-007b-xss.txt", { type: "text/plain" }));
    form.append("title", xssTitle);
    const upload = await read("/api/admin/uploads", {
      method: "POST",
      headers: headers("P0-007B XSS text " + id, crypto.randomUUID(), false),
      body: form,
    });
    if (upload.response.status !== 201 || !upload.body?.document_id) throw new Error("XSS fixture upload failed status=" + upload.response.status + " body=" + JSON.stringify(upload.body));
    await new Promise((resolve) => setTimeout(resolve, 250));
    const rendered = {
      text_present: document.body.textContent?.includes(xssTitle) === true,
      executable_element_present: document.querySelector('img[src="x"]') !== null,
      marker_executed: Boolean(window.__p0_xss),
    };
    if (!rendered.text_present || rendered.executable_element_present || rendered.marker_executed) throw new Error("XSS rendering contract failed " + JSON.stringify(rendered));
    checks.xss = rendered;

    const documents = await read("/api/documents?limit=1");
    const fixtureDocument = documents.body?.[0];
    if (documents.response.status !== 200 || !fixtureDocument?.id) throw new Error("document fixture unavailable");
    const originalStatus = fixtureDocument.status || "active";
    const replayOperation = crypto.randomUUID();
    const replayBody = JSON.stringify({ status: originalStatus, reason: "P0-007B replay probe", expected_updated_at: fixtureDocument.updated_at });
    const replay1 = await read("/api/documents/" + fixtureDocument.id + "/review", { method: "POST", headers: headers("P0-007B replay probe", replayOperation), body: replayBody });
    const replay2 = await read("/api/documents/" + fixtureDocument.id + "/review", { method: "POST", headers: headers("P0-007B replay probe", replayOperation), body: replayBody });
    if (replay1.response.status !== 200 || replay2.response.status !== 409 || replay1.body?.status !== originalStatus) throw new Error("replay precondition contract failed statuses=" + replay1.response.status + "/" + replay2.response.status);
    const afterReplay = await read("/api/documents/" + fixtureDocument.id);
    const restore = await read("/api/documents/" + fixtureDocument.id + "/review", { method: "POST", headers: headers("P0-007B replay restore"), body: JSON.stringify({ status: originalStatus, reason: "P0-007B replay restore", expected_updated_at: afterReplay.body?.updated_at }) });
    if (restore.response.status !== 200) throw new Error("replay restore failed status=" + restore.response.status);
    checks.replay = { first_status: replay1.response.status, second_status: replay2.response.status, stale_replay_rejected: true, restored: true };

    const concurrentStatuses = ["p0-concurrent-a", "p0-concurrent-b"];
    const concurrencyFixture = await read("/api/documents/" + fixtureDocument.id);
    const concurrent = await Promise.all(concurrentStatuses.map((status) => read("/api/documents/" + fixtureDocument.id + "/review", {
      method: "POST",
      headers: headers("P0-007B concurrency probe"),
      body: JSON.stringify({ status, reason: "P0-007B concurrency probe", expected_updated_at: concurrencyFixture.body?.updated_at }),
    })));
    const afterConcurrency = await read("/api/documents/" + fixtureDocument.id);
    const restoreConcurrent = await read("/api/documents/" + fixtureDocument.id + "/review", { method: "POST", headers: headers("P0-007B concurrency restore"), body: JSON.stringify({ status: originalStatus, reason: "P0-007B concurrency restore", expected_updated_at: afterConcurrency.body?.updated_at }) });
    if (restoreConcurrent.response.status !== 200) throw new Error("concurrency restore failed");
    checks.concurrency_probe = {
      statuses: concurrent.map(({ response }) => response.status),
      conflict_detected: concurrent.some(({ response }) => response.status === 409),
      restored: true,
    };
    return checks;
  }, origin);
  if (externalHosts.size) throw new Error("unexpected external browser requests: " + [...externalHosts].join(","));
  console.log(JSON.stringify({ task: "V5-P0-007B-info-residual-matrix", result: "passed", checks, external_hosts: [], credentials_printed: false }, null, 2));
} finally {
  await browser.close();
}
