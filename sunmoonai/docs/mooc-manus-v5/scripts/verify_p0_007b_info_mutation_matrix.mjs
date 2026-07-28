import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require(
  "/home/zymun/tpl-app/tpl-admin-frontend-react/node_modules/@playwright/test",
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
    const headers = (reason, contentType = true) => ({
      ...(contentType ? { "Content-Type": "application/json" } : {}),
      "X-CSRF-Token": csrf,
      "X-Correlation-ID": crypto.randomUUID(),
      "X-Operation-ID": crypto.randomUUID(),
      "X-Audit-Reason": reason,
    });
    const read = async (path, options = {}) => {
      const response = await fetch(origin + path, { credentials: "include", ...options });
      let body = null;
      try { body = await response.json(); } catch { body = null; }
      return { response, body };
    };
    const meResult = await read("/api/auth/me");
    if (meResult.response.status !== 200 || !meResult.body?.csrf_token) throw new Error("auth contract failed status=" + meResult.response.status);
    csrf = meResult.body.csrf_token;
    checks.auth = { status: meResult.response.status, csrf_present: true };

    const sourceResult = await read("/api/admin/sources", {
      method: "POST",
      headers: headers("P0-007B source " + id),
      body: JSON.stringify({
        code: "p0-007b-" + id,
        name: "P0-007B matrix source",
        source_type: "website",
        base_url: "https://example.invalid",
        trust_level: "unknown",
        copyright_status: "unknown",
      }),
    });
    if (sourceResult.response.status !== 201 || !sourceResult.body?.id) throw new Error("source create failed status=" + sourceResult.response.status);
    checks.source_create = { status: sourceResult.response.status, correlation_returned: Boolean(sourceResult.response.headers.get("x-correlation-id")) };

    const collectorResult = await read("/api/admin/collectors", {
      method: "POST",
      headers: headers("P0-007B collector " + id),
      body: JSON.stringify({
        code: "p0-007b-" + id,
        name: "P0-007B matrix collector",
        collector_type: "changedetection",
        source_id: sourceResult.body.id,
        config: { watch_id: "watch-" + id, title: "P0-007B matrix" },
      }),
    });
    if (collectorResult.response.status !== 201 || !collectorResult.body?.id) throw new Error("collector create failed status=" + collectorResult.response.status);
    checks.collector_create = { status: collectorResult.response.status, source_bound: collectorResult.body.source_id === sourceResult.body.id };

    const discoveryResult = await read("/api/admin/collectors/" + collectorResult.body.id + "/discover", {
      method: "POST",
      headers: headers("P0-007B discover " + id),
      body: JSON.stringify({ url: "https://example.invalid/p0-007b" }),
    });
    if (discoveryResult.response.status !== 200 || !Array.isArray(discoveryResult.body) || discoveryResult.body.length !== 1) throw new Error("collector discovery failed status=" + discoveryResult.response.status);
    checks.collector_discover = { status: discoveryResult.response.status, jobs: discoveryResult.body.length, external_fetch: false };

    const file = new File(["P0-007B upload " + id + "\n"], "p0-007b-" + id + ".txt", { type: "text/plain" });
    const form = new FormData();
    form.append("file", file);
    form.append("source_id", sourceResult.body.id);
    form.append("title", "P0-007B upload " + id);
    const uploadResult = await read("/api/admin/uploads", {
      method: "POST",
      headers: headers("P0-007B upload " + id, false),
      body: form,
    });
    if (uploadResult.response.status !== 201 || !uploadResult.body?.document_version_id || !uploadResult.body?.document_id) throw new Error("upload failed status=" + uploadResult.response.status);
    checks.upload = {
      status: uploadResult.response.status,
      document_created: true,
      version_created: true,
      raw_artifact_created: Boolean(uploadResult.body.raw_artifact_id),
      clean_artifact_created: Boolean(uploadResult.body.clean_artifact_id),
      text_artifact_created: Boolean(uploadResult.body.text_artifact_id),
    };

    const distributionCreate = await read("/api/admin/distributions/knowledge", {
      method: "POST",
      headers: headers("P0-007B distribution create " + id),
      body: JSON.stringify({
        document_version_id: uploadResult.body.document_version_id,
        target_dataset: "p0-007b-" + id,
        dispatch: false,
      }),
    });
    if (distributionCreate.response.status !== 201 || !distributionCreate.body?.id || distributionCreate.body.status !== "pending") throw new Error("distribution create failed status=" + distributionCreate.response.status);
    checks.distribution_create = {
      status: distributionCreate.response.status,
      pending: true,
      contract_version: distributionCreate.body.payload?.contract_version,
      audit_present: Boolean(distributionCreate.body.payload?.last_audit),
    };

    const distributionId = distributionCreate.body.id;
    const failedStatus = await read("/api/admin/distributions/" + distributionId + "/status", {
      method: "POST",
      headers: headers("P0-007B distribution failure " + id),
      body: JSON.stringify({ status: "failed", last_error: "p0 matrix synthetic downstream failure", metadata: { p0_matrix: true } }),
    });
    if (failedStatus.response.status !== 200 || failedStatus.body.status !== "failed") throw new Error("distribution failure transition failed status=" + failedStatus.response.status);
    const retryResult = await read("/api/admin/distributions/" + distributionId + "/retry", {
      method: "POST",
      headers: headers("P0-007B distribution retry " + id),
    });
    if (retryResult.response.status !== 200 || retryResult.body.status !== "pending" || !retryResult.body.payload?.last_retry) throw new Error("distribution retry failed status=" + retryResult.response.status);
    checks.distribution_retry = { status: retryResult.response.status, pending_after_retry: true, retry_recorded: true };

    const dispatchResult = await read("/api/admin/distributions/" + distributionId + "/dispatch", {
      method: "POST",
      headers: headers("P0-007B distribution dispatch " + id),
    });
    if (dispatchResult.response.status !== 200 || !["succeeded", "failed", "pending"].includes(dispatchResult.body?.status)) throw new Error("distribution dispatch failed status=" + dispatchResult.response.status);
    checks.distribution_dispatch = { status: dispatchResult.response.status, resulting_status: dispatchResult.body.status };
    return checks;
  }, origin);
  if (externalHosts.size) throw new Error("unexpected external browser requests: " + [...externalHosts].join(","));
  console.log(JSON.stringify({ task: "V5-P0-007B-info-mutation-matrix", result: "passed", checks, external_hosts: [], credentials_printed: false }, null, 2));
} finally {
  await browser.close();
}
