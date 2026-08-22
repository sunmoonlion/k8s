#!/usr/bin/env node

/**
 * Real browser verification for the V5-P0-005 Admin OIDC boundary.
 *
 * Credentials are read from the operator-only Kubernetes Secret directly into
 * memory. Passwords, cookies, authorization codes, tokens, state, nonce and
 * PKCE material are never printed or written to disk.
 */

import http from "node:http";
import { execFileSync, spawn, spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require(
  "/home/zymun/master/tpl-app/tpl-admin-frontend-react/node_modules/@playwright/test",
);

const kubeconfig =
  process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`;
const namespace = process.env.P0_NAMESPACE || "app-platform-dev";
const operatorSecret = "sunmoonai-p0-005-browser-identity";
const providerUiTimeoutMs = Number(
  process.env.P0_CASDOOR_UI_TIMEOUT_MS || "20000",
);
if (!Number.isInteger(providerUiTimeoutMs) || providerUiTimeoutMs < 10000) {
  throw new Error("P0_CASDOOR_UI_TIMEOUT_MS must be an integer of at least 10000");
}
// KIND's default Traefik certificate is intentionally not trusted. Production
// evidence must set P0_BROWSER_STRICT_TLS=true so this gate cannot mask TLS/SNI
// or certificate failures.
const ignoreHttpsErrors = process.env.P0_BROWSER_STRICT_TLS !== "true";
const browserCaCertificate =
  process.env.P0_BROWSER_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`;
const browserCertutil = process.env.P0_BROWSER_CERTUTIL || "certutil";
const frontendMode = process.env.P0_BROWSER_FRONTEND_MODE || "sink";
const templateFrontendRoot =
  process.env.P0_BROWSER_FRONTEND_ROOT ||
  "/home/zymun/master/tpl-app/tpl-admin-frontend-react";
const templateFrontendPortOverride = process.env.P0_BROWSER_FRONTEND_PORT || "";
if (!["sink", "template"].includes(frontendMode)) {
  throw new Error("P0_BROWSER_FRONTEND_MODE must be sink or template");
}
let currentStage = "module_loaded";

class CallbackDiagnosticError extends Error {}

function progress(stage, app = "all") {
  currentStage = `${stage}:${app}`;
  console.error(`P0_BROWSER_STAGE=${stage} APP=${app}`);
}

function prepareStrictTlsEnvironment() {
  if (ignoreHttpsErrors) return null;
  if (!fs.existsSync(browserCaCertificate)) {
    throw new Error(`strict TLS CA certificate not found: ${browserCaCertificate}`);
  }

  const homeDir = fs.mkdtempSync(path.join(os.tmpdir(), "sunmoonai-p0-browser-"));
  const nssDir = path.join(homeDir, ".pki", "nssdb");
  fs.mkdirSync(nssDir, { recursive: true });
  try {
    execFileSync(
      browserCertutil,
      ["-N", "-d", `sql:${nssDir}`, "--empty-password"],
      { stdio: "ignore" },
    );
    execFileSync(
      browserCertutil,
      [
        "-A",
        "-d",
        `sql:${nssDir}`,
        "-n",
        "SunMoonAI Root CA",
        "-t",
        "C,,",
        "-i",
        browserCaCertificate,
      ],
      { stdio: "ignore" },
    );
    return { homeDir };
  } catch (error) {
    fs.rmSync(homeDir, { recursive: true, force: true });
    throw new Error(
      `strict TLS requires certutil and a valid NSS profile: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

process.once("SIGTERM", () => {
  console.error(`P0_BROWSER_SIGNAL=SIGTERM STAGE=${currentStage}`);
  process.exit(143);
});

const apps = [
  {
    key: "info",
    service: "service/info-admin-backend",
    backendPort: 18082,
    frontendPort: 19082,
    sessionCookie: "sunmoonai_info_admin_sid",
    adminScope: "info:admin",
  },
  {
    key: "knowledge",
    service: "service/knowledge-admin-backend",
    backendPort: 18083,
    frontendPort: 19083,
    sessionCookie: "sunmoonai_knowledge_admin_sid",
    adminScope: "knowledge:admin",
  },
  {
    key: "research",
    service: "service/research-admin-backend",
    backendPort: 18084,
    frontendPort: 19084,
    sessionCookie: "sunmoonai_research_admin_sid",
    adminScope: "research:admin",
  },
];

if (templateFrontendPortOverride) {
  const basePort = Number(templateFrontendPortOverride);
  if (!Number.isInteger(basePort) || basePort < 1024 || basePort > 65532) {
    throw new Error(
      "P0_BROWSER_FRONTEND_PORT must be an integer between 1024 and 65532",
    );
  }
  apps.forEach((app, index) => {
    app.frontendPort = basePort + index;
  });
}

function kubectl(args, options = {}) {
  return execFileSync(
    "kubectl",
    ["--kubeconfig", kubeconfig, ...args],
    {
      encoding: "utf8",
      stdio: options.capture ? ["ignore", "pipe", "pipe"] : "ignore",
    },
  );
}

function assertResearchTrafficClosed() {
  const deployment = JSON.parse(
    kubectl(
      [
        "get",
        "deployment/research-admin-backend",
        "-n",
        namespace,
        "-o",
        "json",
      ],
      { capture: true },
    ),
  );
  const env =
    deployment.spec?.template?.spec?.containers?.[0]?.env || [];
  if (env.some((item) => item.name === "AGENT_V4_TRAFFIC_ENABLED")) {
    throw new Error("Research Deployment has an explicit traffic override");
  }
  const configMap = JSON.parse(
    kubectl(
      [
        "get",
        "configmap/research-admin-backend-config",
        "-n",
        namespace,
        "-o",
        "json",
      ],
      { capture: true },
    ),
  );
  if (configMap.data?.AGENT_V4_TRAFFIC_ENABLED !== "false") {
    throw new Error("Research ConfigMap traffic gate is not closed");
  }
}

function setResearchTraffic(enabled) {
  kubectl([
    "set",
    "env",
    "deployment/research-admin-backend",
    "-n",
    namespace,
    enabled
      ? "AGENT_V4_TRAFFIC_ENABLED=true"
      : "AGENT_V4_TRAFFIC_ENABLED-",
  ]);
  kubectl([
    "rollout",
    "status",
    "deployment/research-admin-backend",
    "-n",
    namespace,
    "--timeout=180s",
  ]);
}

function loadTestIdentities() {
  const raw = kubectl(
    ["get", "secret", operatorSecret, "-n", namespace, "-o", "json"],
    { capture: true },
  );
  const data = JSON.parse(raw).data || {};
  const decode = (key) => {
    if (!data[key]) throw new Error(`operator Secret key missing: ${key}`);
    return Buffer.from(data[key], "base64").toString("utf8");
  };
  const identities = {
    primary: {
      username: decode("PRIMARY_USERNAME"),
      password: decode("PRIMARY_PASSWORD"),
    },
    secondary: {
      username: decode("SECONDARY_USERNAME"),
      password: decode("SECONDARY_PASSWORD"),
    },
  };
  for (const identity of Object.values(identities)) {
    if (!identity.username || !identity.password) {
      throw new Error("operator Secret contains an empty test identity");
    }
  }
  return identities;
}

function startPortForward(app) {
  const child = spawn(
    "kubectl",
    [
      "--kubeconfig",
      kubeconfig,
      "port-forward",
      "-n",
      namespace,
      app.service,
      `${app.backendPort}:8000`,
      "--address=127.0.0.1",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  return child;
}

function waitForPortForward(child, app) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("port-forward timeout")), 30000);
    const onData = (chunk) => {
      const value = String(chunk);
      if (value.includes("Forwarding from 127.0.0.1")) {
        clearTimeout(timeout);
        resolve();
      }
    };
    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.once("exit", (code) => {
      clearTimeout(timeout);
      reject(new Error(`port-forward exited: app=${app.key}, code=${code}`));
    });
  });
}

function startFrontendSink(port) {
  const server = http.createServer((_request, response) => {
    response.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    });
    response.end("<!doctype html><title>P0 OIDC callback complete</title>");
  });
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

function startTemplateFrontend(app) {
  const child = spawn(
    "pnpm",
    ["dev", "--host", "127.0.0.1", "--port", String(app.frontendPort)],
    {
      cwd: templateFrontendRoot,
      env: {
        ...process.env,
        VITE_API_URL: `http://127.0.0.1:${app.backendPort}`,
        VITE_AUTH_MODE: "session",
        VITE_APP_NAME: `V5 ${app.key} React Admin template`,
      },
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  return child;
}

function assertTemplateFrontendPortAvailable(port) {
  return new Promise((resolve, reject) => {
    const probe = http.createServer();
    probe.once("error", (error) => {
      if (error && typeof error === "object" && error.code === "EADDRINUSE") {
        reject(new Error(`template frontend port is already in use: ${port}`));
      } else {
        reject(error);
      }
    });
    probe.listen(port, "127.0.0.1", () => {
      probe.close((error) => (error ? reject(error) : resolve()));
    });
  });
}

function stopTemplateFrontend(child) {
  if (!child?.pid) return;
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch {
    try {
      child.kill("SIGTERM");
    } catch {
      // The process may already have exited.
    }
  }
  child.stdout?.destroy();
  child.stderr?.destroy();
}

function waitForFrontend(child, app) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + 60000;
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearInterval(timer);
      clearTimeout(timeout);
      if (error) reject(error);
      else resolve();
    };
    const probe = () => {
      const request = http.get(
        `http://127.0.0.1:${app.frontendPort}/`,
        (response) => {
          response.resume();
          if (response.statusCode && response.statusCode < 500) finish();
        },
      );
      request.once("error", () => {
        if (Date.now() >= deadline) {
          finish(new Error(`template frontend timeout: app=${app.key}`));
        }
      });
    };
    const timer = setInterval(probe, 250);
    const timeout = setTimeout(
      () => finish(new Error(`template frontend timeout: app=${app.key}`)),
      60000,
    );
    child.once("exit", (code) => {
      finish(new Error(`template frontend exited: app=${app.key}, code=${code}`));
    });
    probe();
  });
}

function assertProviderMaterialAbsent(payload) {
  const serialized = JSON.stringify(payload).toLowerCase();
  for (const forbidden of [
    "access_token",
    "id_token",
    "refresh_token",
    "client_secret",
    "code_verifier",
  ]) {
    if (serialized.includes(forbidden)) {
      throw new Error(`provider material exposed: ${forbidden}`);
    }
  }
}

function diagnoseCallbackInPod(app, callbackUrl, transactionId) {
  const callback = new URL(callbackUrl);
  const payload = JSON.stringify({
    code: callback.searchParams.get("code") || "",
    state: callback.searchParams.get("state") || "",
    transaction_id: transactionId,
  });
  const program = String.raw`
import asyncio
import base64
import hmac
import json
import sys
import time

from joserfc import jwt
from joserfc.jwt import JWTClaimsRegistry

from app.application.services.auth_service import TRANSACTION_PREFIX
from app.infrastructure.security.oidc import OidcProviderClient
from app.infrastructure.storage.redis import get_redis
from core.config import get_settings


def decode_segment(value):
    padding = "=" * (-len(value) % 4)
    return json.loads(base64.urlsafe_b64decode(value + padding))

async def main():
    payload = json.load(sys.stdin)
    await get_redis().init()
    result = {"outcome": "diagnosed"}
    try:
        raw = await get_redis().client.getdel(
            f'{TRANSACTION_PREFIX}{payload["transaction_id"]}'
        )
        result["transaction_found"] = bool(raw)
        if not raw:
            print(json.dumps(result, sort_keys=True))
            return
        transaction = json.loads(raw)
        expected_state = transaction.get("state")
        result["state_matches"] = isinstance(expected_state, str) and hmac.compare_digest(
            expected_state, payload["state"]
        )
        if not result["state_matches"]:
            print(json.dumps(result, sort_keys=True))
            return

        nonce = transaction.get("nonce")
        code_verifier = transaction.get("code_verifier")
        settings = get_settings()
        oidc = OidcProviderClient(settings)
        metadata = await oidc.get_metadata()
        token_url, routing_headers = oidc._backchannel_target(
            metadata.token_endpoint, "token_endpoint"
        )
        async with oidc._client() as client:
            response = await client.post(
                token_url,
                data={
                    "grant_type": "authorization_code",
                    "client_id": settings.casdoor_client_id,
                    "client_secret": settings.casdoor_client_secret,
                    "code": payload["code"],
                    "redirect_uri": settings.casdoor_redirect_uri,
                    "code_verifier": code_verifier,
                },
                headers={"Accept": "application/json", **routing_headers},
            )
        result["token_http_status"] = response.status_code
        token_response = response.json() if response.status_code == 200 else {}
        encoded = token_response.get("id_token") if isinstance(token_response, dict) else None
        result["id_token_present"] = isinstance(encoded, str) and bool(encoded)
        if not result["id_token_present"]:
            print(json.dumps(result, sort_keys=True))
            return

        segments = encoded.split(".")
        result["compact_jws"] = len(segments) == 3
        if len(segments) != 3:
            print(json.dumps(result, sort_keys=True))
            return
        header = decode_segment(segments[0])
        claims = decode_segment(segments[1])
        configured_algorithms = settings.auth_allowed_algorithm_list
        result.update(
            {
                "header_json": isinstance(header, dict),
                "claims_json": isinstance(claims, dict),
                "algorithm_allowed": isinstance(header, dict)
                and header.get("alg") in configured_algorithms,
                "kid_present": isinstance(header, dict)
                and isinstance(header.get("kid"), str)
                and bool(header.get("kid")),
            }
        )
        if not isinstance(claims, dict):
            print(json.dumps(result, sort_keys=True))
            return
        audience = claims.get("aud")
        now = int(time.time())
        result.update(
            {
                "issuer_present": isinstance(claims.get("iss"), str),
                "issuer_matches": claims.get("iss") == metadata.issuer,
                "issuer_matches_public_endpoint": claims.get("iss")
                == settings.casdoor_endpoint.rstrip("/"),
                "subject_valid": isinstance(claims.get("sub"), str)
                and bool(claims.get("sub", "").strip()),
                "audience_present": "aud" in claims,
                "audience_matches": audience == settings.casdoor_client_id
                or audience == [settings.casdoor_client_id],
                "expiration_is_integer": isinstance(claims.get("exp"), int),
                "expiration_current": isinstance(claims.get("exp"), int)
                and claims["exp"] + settings.auth_clock_skew_seconds >= now,
                "issued_at_is_integer": isinstance(claims.get("iat"), int),
                "nonce_present": isinstance(claims.get("nonce"), str),
                "nonce_matches": isinstance(nonce, str)
                and claims.get("nonce") == nonce,
            }
        )
        try:
            key_set = await oidc._get_key_set(metadata, force_refresh=True)
            verified = jwt.decode(
                encoded,
                key_set,
                algorithms=configured_algorithms,
            )
            result["signature_valid"] = True
            registry = JWTClaimsRegistry(
                leeway=settings.auth_clock_skew_seconds,
                iss={"essential": True, "value": metadata.issuer},
                sub={"essential": True},
                aud={"essential": True},
                exp={"essential": True},
                iat={"essential": True},
                nonce={"essential": True, "value": nonce},
            )
            try:
                registry.validate(verified.claims)
                result["claims_registry_valid"] = True
            except Exception as exc:
                result["claims_registry_valid"] = False
                result["claims_error_type"] = type(exc).__name__
        except Exception as exc:
            result["signature_valid"] = False
            result["signature_error_type"] = type(exc).__name__
    except Exception as exc:
        result = {"outcome": "error", "error_type": type(exc).__name__}
    finally:
        await get_redis().shutdown()
    print(json.dumps(result, sort_keys=True))

asyncio.run(main())
`;
  const child = spawnSync(
    "kubectl",
    [
      "--kubeconfig",
      kubeconfig,
      "exec",
      "-i",
      "-n",
      namespace,
      `deploy/${app.key}-admin-backend`,
      "--",
      ".venv/bin/python",
      "-c",
      program,
    ],
    { input: payload, encoding: "utf8", maxBuffer: 1024 * 1024 },
  );
  if (child.status !== 0) {
    throw new Error(`callback diagnostic process failed: app=${app.key}`);
  }
  const lines = (child.stdout || "").trim().split("\n").filter(Boolean);
  if (!lines.length) throw new Error("callback diagnostic returned no result");
  return JSON.parse(lines.at(-1));
}

async function submitCasdoorLogin(page, identity) {
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const username = page.locator(
        'input[name="username"], input[autocomplete="username"], input[type="text"]',
      ).first();
      await username.waitFor({ state: "visible", timeout: providerUiTimeoutMs });
      await username.fill(identity.username);
      await username.press("Enter");

      const password = page.locator(
        'input[name="password"], input[autocomplete="current-password"], input[type="password"]',
      ).first();
      await password.waitFor({ state: "visible", timeout: providerUiTimeoutMs });
      await password.fill(identity.password);
      await password.press("Enter");
      return attempt;
    } catch (error) {
      if (
        attempt === 2 ||
        !error ||
        typeof error !== "object" ||
        !("name" in error) ||
        error.name !== "TimeoutError"
      ) {
        throw error;
      }
      await page.reload({ waitUntil: "commit", timeout: providerUiTimeoutMs });
    }
  }
  throw new Error("Casdoor login controls unavailable after bounded retry");
}

async function safePageShape(page, network) {
  const current = new URL(page.url());
  const inputs = await page.locator("input").evaluateAll((elements) =>
    elements.slice(0, 12).map((element) => ({
      id: element.getAttribute("id") || "",
      name: element.getAttribute("name") || "",
      type: element.getAttribute("type") || "",
      placeholder: element.getAttribute("placeholder") || "",
      autocomplete: element.getAttribute("autocomplete") || "",
      visible: Boolean(element.offsetWidth || element.offsetHeight),
    })),
  );
  const buttons = await page.locator("button").evaluateAll((elements) =>
    elements.slice(0, 12).map((element) => ({
      type: element.getAttribute("type") || "",
      text: (element.textContent || "").trim().slice(0, 80),
      visible: Boolean(element.offsetWidth || element.offsetHeight),
    })),
  );
  const documentShape = await page.evaluate(() => ({
    readyState: document.readyState,
    bodyChildCount: document.body?.childElementCount || 0,
    bodyTextLength: document.body?.innerText?.length || 0,
    htmlLength: document.documentElement?.outerHTML?.length || 0,
    scriptCount: document.scripts.length,
    stylesheetCount: document.styleSheets.length,
    roots: Array.from(document.body?.children || []).slice(0, 8).map((element) => ({
      tag: element.tagName,
      id: element.id || "",
      childCount: element.childElementCount,
    })),
    scripts: Array.from(document.scripts).slice(0, 8).map((element) => {
      const source = element.src ? new URL(element.src) : null;
      return {
        type: element.type || "classic",
        defer: element.defer,
        async: element.async,
        hostname: source?.hostname || "",
        pathname: source?.pathname || "",
      };
    }),
  }));
  return {
    origin: current.origin,
    pathname: current.pathname,
    document: documentShape,
    inputs,
    buttons,
    network,
  };
}

async function verifyLogin(browser, app, identityLabel, identity) {
  const context = await browser.newContext({ ignoreHTTPSErrors: ignoreHttpsErrors });
  const page = await context.newPage();
  const backendOrigin = `http://127.0.0.1:${app.backendPort}`;
  const frontendOrigin = `http://127.0.0.1:${app.frontendPort}`;
  let callbackUrl = "";
  let stage = "start";
  let providerUiAttempts = 0;
  const network = {
    responses: [],
    finished: [],
    failures: [],
    external_hosts: [],
    page_errors: 0,
    console_types: {},
  };
  const callbackDiagnostic =
    process.env.P0_BROWSER_CALLBACK_DIAGNOSTIC === "true";

  page.on("response", (response) => {
    if (network.responses.length >= 30) return;
    const request = response.request();
    const url = new URL(response.url());
    if (url.hostname !== "casdoor.sunmoonai.com") return;
    network.responses.push({
      type: request.resourceType(),
      status: response.status(),
      pathname: url.pathname,
      content_type: (response.headers()["content-type"] || "").split(";", 1)[0],
    });
  });
  page.on("requestfailed", (request) => {
    if (network.failures.length >= 20) return;
    const url = new URL(request.url());
    const rawFailure = request.failure()?.errorText || "other";
    network.failures.push({
      type: request.resourceType(),
      hostname: url.hostname,
      pathname: url.pathname,
      failure: rawFailure.startsWith("net::") ? rawFailure : "other",
    });
  });
  page.on("requestfinished", (request) => {
    if (network.finished.length >= 30) return;
    const url = new URL(request.url());
    if (url.hostname !== "casdoor.sunmoonai.com") return;
    network.finished.push({
      type: request.resourceType(),
      pathname: url.pathname,
    });
  });
  page.on("pageerror", () => {
    network.page_errors += 1;
  });
  page.on("console", (message) => {
    const type = message.type();
    network.console_types[type] = (network.console_types[type] || 0) + 1;
  });

  page.on("request", (request) => {
    const url = new URL(request.url());
    if (
      !["casdoor.sunmoonai.com", "127.0.0.1", "localhost"].includes(
        url.hostname,
      ) &&
      !network.external_hosts.includes(url.hostname) &&
      network.external_hosts.length < 20
    ) {
      network.external_hosts.push(url.hostname);
    }
    if (
      url.origin === backendOrigin &&
      url.pathname === "/api/auth/callback"
    ) {
      callbackUrl = request.url();
    }
  });

  if (callbackDiagnostic) {
    await page.route(`${backendOrigin}/api/auth/callback**`, async (route) => {
      callbackUrl = route.request().url();
      await route.abort("aborted");
    });
  }

  try {
    stage = "authorization_redirect";
    await page.goto(`${backendOrigin}/api/auth/login?return_to=/p0-complete`, {
      // Casdoor is an SPA. Waiting for DOMContentLoaded across the complete
      // redirect chain is brittle when optional frontend assets are slow; the
      // explicit, visible login-control wait below is the readiness boundary.
      waitUntil: "commit",
      timeout: 30000,
    });
    if (new URL(page.url()).hostname !== "casdoor.sunmoonai.com") {
      throw new Error("browser did not reach canonical Casdoor host");
    }

    stage = "provider_login";
    const providerUiStartedAt = Date.now();
    providerUiAttempts = await submitCasdoorLogin(page, identity);
    const providerUiMs = Date.now() - providerUiStartedAt;
    const providerFailures = network.failures.filter(
      (failure) => failure.hostname === "casdoor.sunmoonai.com",
    );
    const providerServerErrors = network.responses.filter(
      (response) => response.status >= 500,
    );
    if (network.page_errors > 0) {
      throw new Error(`Casdoor pageerror count=${network.page_errors}`);
    }
    if (providerFailures.length > 0) {
      throw new Error(`Casdoor request failures=${providerFailures.length}`);
    }
    if (providerServerErrors.length > 0) {
      throw new Error(`Casdoor server error responses=${providerServerErrors.length}`);
    }
    if (network.external_hosts.length > 0) {
      throw new Error(
        `unexpected external browser requests=${network.external_hosts.join(",")}`,
      );
    }

    if (callbackDiagnostic) {
      stage = "callback_diagnostic";
      const deadline = Date.now() + 30000;
      while (!callbackUrl && Date.now() < deadline) {
        await page.waitForTimeout(100);
      }
      if (!callbackUrl) throw new Error("OIDC callback was not observed");
      const transactionCookieName = app.sessionCookie.replace("_sid", "_oidc_tx");
      const cookies = await context.cookies();
      const transactionCookie = cookies.find(
        (cookie) => cookie.name === transactionCookieName,
      );
      if (!transactionCookie) throw new Error("OIDC transaction cookie is missing");
      const diagnostic = diagnoseCallbackInPod(
        app,
        callbackUrl,
        transactionCookie.value,
      );
      throw new CallbackDiagnosticError(
        `callback diagnostic result=${JSON.stringify(diagnostic)}`,
      );
    }

    stage = "callback_redirect";
    await page.waitForURL(`${frontendOrigin}/p0-complete`, {
      waitUntil: "domcontentloaded",
      timeout: 45000,
    });
    if (!callbackUrl) throw new Error("OIDC callback was not observed");

    if (frontendMode === "template") {
      stage = "template_session_route";
      await page.goto(`${frontendOrigin}/`, {
        waitUntil: "domcontentloaded",
        timeout: 30000,
      });
      await page.getByRole("heading", { name: "管理首页" }).waitFor({
        state: "visible",
        timeout: 30000,
      });
    }

    let browserCorsStatus = "not_applicable";
    if (frontendMode === "template") {
      stage = "cors_matrix";
      const browserCors = await page.evaluate(async (url) => {
        const response = await fetch(url, { credentials: "include" });
        return response.status;
      }, `${backendOrigin}/api/auth/me`);
      if (browserCors !== 200) {
        throw new Error(`browser credential CORS returned ${browserCors}`);
      }
      const allowedCors = await context.request.get(`${backendOrigin}/api/auth/me`, {
        headers: { Origin: frontendOrigin },
      });
      const deniedCors = await context.request.get(`${backendOrigin}/api/auth/me`, {
        headers: { Origin: "https://attacker.example.test" },
      });
      if (
        allowedCors.status() !== 200 ||
        allowedCors.headers()["access-control-allow-origin"] !== frontendOrigin ||
        allowedCors.headers()["access-control-allow-credentials"] !== "true" ||
        deniedCors.headers()["access-control-allow-origin"]
      ) {
        throw new Error("credential CORS allow/deny matrix is invalid");
      }
      browserCorsStatus = 200;
    }

    stage = "session_me";
    const meResponse = await context.request.get(`${backendOrigin}/api/auth/me`);
    if (meResponse.status() !== 200) {
      throw new Error(`authenticated /me returned ${meResponse.status()}`);
    }
    const me = await meResponse.json();
    if (!me.authenticated || !me.user?.actor_id || !me.csrf_token) {
      throw new Error("authenticated /me contract is incomplete");
    }
    if (
      !Array.isArray(me.user.roles) ||
      !me.user.roles.includes("admin") ||
      !Array.isArray(me.user.scopes) ||
      !me.user.scopes.includes(app.adminScope)
    ) {
      throw new Error("authenticated /me is missing the provisioned Admin policy");
    }
    assertProviderMaterialAbsent(me);

    stage = "callback_replay";
    const replay = await context.request.get(callbackUrl, {
      maxRedirects: 0,
    });
    if (replay.status() !== 302) {
      throw new Error(`callback replay returned ${replay.status()}`);
    }
    const replayLocation = replay.headers().location || "";
    if (replayLocation !== `${frontendOrigin}/login?error=auth_failed`) {
      throw new Error("callback replay was not rejected safely");
    }

    stage = "cookie_contract";
    const cookies = await context.cookies();
    const sessionCookie = cookies.find((cookie) => cookie.name === app.sessionCookie);
    const transactionCookie = cookies.find((cookie) => cookie.name.endsWith("_oidc_tx"));
    if (!sessionCookie || !sessionCookie.httpOnly || transactionCookie) {
      throw new Error("session/transaction cookie lifecycle is invalid");
    }

    stage = "csrf_negative_matrix";
    const csrfCases = [
      { headers: {}, expected: 403 },
      {
        headers: {
          Origin: "https://attacker.example.test",
          "X-CSRF-Token": me.csrf_token,
        },
        expected: 403,
      },
      { headers: { Origin: frontendOrigin }, expected: 403 },
      {
        headers: {
          Origin: frontendOrigin,
          "X-CSRF-Token": "invalid-csrf-token-value-000000000000",
        },
        expected: 403,
      },
    ];
    for (const csrfCase of csrfCases) {
      const response = await context.request.post(`${backendOrigin}/api/auth/logout`, {
        headers: csrfCase.headers,
      });
      if (response.status() !== csrfCase.expected) {
        throw new Error(`CSRF negative case returned ${response.status()}`);
      }
    }

    let browserSessionInternalRoute = "not_applicable";
    if (app.key === "knowledge") {
      stage = "browser_session_internal_route";
      const internalRoute = await context.request.post(
        `${backendOrigin}/api/internal/v1/knowledge/ingestions`,
        {
          headers: {
            Origin: frontendOrigin,
            "X-CSRF-Token": me.csrf_token,
          },
          data: {},
        },
      );
      if (internalRoute.status() !== 401) {
        throw new Error(
          `browser session reached service-only route with ${internalRoute.status()}`,
        );
      }
      browserSessionInternalRoute = 401;
    }

    stage = "csrf_positive_logout";
    const logout = await context.request.post(`${backendOrigin}/api/auth/logout`, {
      headers: {
        Origin: frontendOrigin,
        "X-CSRF-Token": me.csrf_token,
      },
    });
    if (logout.status() !== 204) {
      throw new Error(`valid CSRF logout returned ${logout.status()}`);
    }
    const afterLogout = await context.request.get(`${backendOrigin}/api/auth/me`);
    const cookiesAfterLogout = await context.cookies();
    if (
      afterLogout.status() !== 401 ||
      cookiesAfterLogout.some((cookie) => cookie.name === app.sessionCookie)
    ) {
      throw new Error("logout did not revoke the browser session and cookie");
    }

    return {
      identity: identityLabel,
      authenticated_me: 200,
      stable_actor_binding: true,
      callback_one_time: true,
      session_cookie_httponly: true,
      transaction_cookie_consumed: true,
      provider_material_exposed: false,
      admin_role_and_scope: true,
      csrf_negative_cases: csrfCases.length,
      browser_session_internal_route: browserSessionInternalRoute,
      csrf_positive_logout: true,
      session_revoked_on_logout: true,
      browser_cors_status: browserCorsStatus,
      provider_ui_attempts: providerUiAttempts,
      provider_ui_ms: providerUiMs,
    };
  } catch (error) {
    if (error instanceof CallbackDiagnosticError) throw error;
    let pageShape = {};
    if (process.env.P0_BROWSER_SAFE_DIAGNOSTICS === "true") {
      try {
        pageShape = await safePageShape(page, network);
        pageShape.failure_type =
          error && typeof error === "object" && "name" in error
            ? String(error.name)
            : "unknown";
      } catch {
        pageShape = { unavailable: true };
      }
    }
    throw new Error(
      `browser verification failed: app=${app.key}, stage=${stage}, page_shape=${JSON.stringify(pageShape)}`,
    );
  } finally {
    await context.close();
  }
}

async function openOwnerIsolationSession(browser, app, identity) {
  const context = await browser.newContext({ ignoreHTTPSErrors: ignoreHttpsErrors });
  const page = await context.newPage();
  const backendOrigin = `http://127.0.0.1:${app.backendPort}`;
  const frontendOrigin = `http://127.0.0.1:${app.frontendPort}`;
  try {
    await page.goto(`${backendOrigin}/api/auth/login?return_to=/p0-owner`, {
      waitUntil: "commit",
      timeout: 30000,
    });
    if (new URL(page.url()).hostname !== "casdoor.sunmoonai.com") {
      throw new Error("canonical Casdoor host was not reached");
    }
    const providerUiAttempts = await submitCasdoorLogin(page, identity);
    await page.waitForURL(`${frontendOrigin}/p0-owner`, {
      waitUntil: "domcontentloaded",
      timeout: 45000,
    });
    if (frontendMode === "template") {
      await page.goto(`${frontendOrigin}/`, {
        waitUntil: "domcontentloaded",
        timeout: 30000,
      });
      await page.getByRole("heading", { name: "管理首页" }).waitFor({
        state: "visible",
        timeout: 30000,
      });
    }
    const response = await context.request.get(`${backendOrigin}/api/auth/me`);
    if (response.status() !== 200) {
      throw new Error("owner-isolation /me did not authenticate");
    }
    const me = await response.json();
    if (
      !me.user?.actor_id ||
      !me.csrf_token ||
      !Array.isArray(me.user.roles) ||
      !me.user.roles.includes("admin") ||
      !Array.isArray(me.user.scopes) ||
      !me.user.scopes.includes(app.adminScope)
    ) {
      throw new Error("owner-isolation principal policy is incomplete");
    }
    assertProviderMaterialAbsent(me);
    return { context, page, me, providerUiAttempts };
  } catch (error) {
    await context.close();
    throw new Error("owner-isolation browser login failed");
  }
}

async function closeOwnerIsolationSession(handle, app) {
  if (!handle) return;
  const backendOrigin = `http://127.0.0.1:${app.backendPort}`;
  const frontendOrigin = `http://127.0.0.1:${app.frontendPort}`;
  try {
    await handle.context.request.post(`${backendOrigin}/api/auth/logout`, {
      headers: {
        Origin: frontendOrigin,
        "X-CSRF-Token": handle.me.csrf_token,
      },
    });
  } finally {
    await handle.context.close();
  }
}

function expireBrowserSession(app, sessionId) {
  const prefixes = {
    info: "info:auth:admin:session:",
    knowledge: "knowledge:auth:admin:session:",
    research: "research:auth:admin:session:",
  };
  const prefix = prefixes[app.key];
  if (!prefix) throw new Error(`unknown browser session prefix: ${app.key}`);
  const payload = JSON.stringify({ session_id: sessionId });
  const program = String.raw`
import asyncio
import json
import sys

from app.infrastructure.storage.redis import get_redis

async def main():
    payload = json.load(sys.stdin)
    await get_redis().init()
    try:
        key = ${JSON.stringify(prefix)} + payload["session_id"]
        expired = await get_redis().client.expire(key, 0)
        print(json.dumps({"expired": bool(expired)}, sort_keys=True))
    finally:
        await get_redis().shutdown()

asyncio.run(main())
`;
  const child = spawnSync(
    "kubectl",
    [
      "--kubeconfig",
      kubeconfig,
      "exec",
      "-i",
      "-n",
      namespace,
      `deploy/${app.key}-admin-backend`,
      "--",
      ".venv/bin/python",
      "-c",
      program,
    ],
    { input: payload, encoding: "utf8", maxBuffer: 1024 * 1024 },
  );
  if (child.status !== 0) {
    throw new Error(`browser session expiry process failed: app=${app.key}`);
  }
  const lines = (child.stdout || "").trim().split("\n").filter(Boolean);
  const outcome = lines.length ? JSON.parse(lines.at(-1)) : {};
  if (outcome.expired !== true) {
    throw new Error(`browser session was not expired: app=${app.key}`);
  }
}

async function verifyExpiredBrowserSession(browser, app, identity) {
  const handle = await openOwnerIsolationSession(browser, app, identity);
  const backendOrigin = `http://127.0.0.1:${app.backendPort}`;
  const frontendOrigin = `http://127.0.0.1:${app.frontendPort}`;
  try {
    const cookies = await handle.context.cookies();
    const sessionCookie = cookies.find((cookie) => cookie.name === app.sessionCookie);
    if (!sessionCookie?.value) throw new Error("expired-session cookie is missing");
    expireBrowserSession(app, sessionCookie.value);
    const meAfterExpiry = await handle.context.request.get(
      `${backendOrigin}/api/auth/me`,
    );
    if (meAfterExpiry.status() !== 401) {
      throw new Error(`expired session /me returned ${meAfterExpiry.status()}`);
    }
    let templateRedirectLogin = "not_applicable";
    if (frontendMode === "template") {
      await handle.page.goto(`${frontendOrigin}/`, {
        waitUntil: "domcontentloaded",
        timeout: 30000,
      });
      await handle.page.waitForURL(
        (url) =>
          url.origin === frontendOrigin &&
          url.pathname === "/login" &&
          url.searchParams.get("return_to") === "/",
        { timeout: 30000 },
      );
      templateRedirectLogin = true;
    }
    return {
      authenticated_before_expiry: true,
      session_expired: true,
      me_after_expiry: 401,
      template_redirect_login: templateRedirectLogin,
      provider_ui_attempts: handle.providerUiAttempts,
    };
  } finally {
    await handle.context.close();
  }
}

function cleanupResearchAgentSession(sessionId, ownerActorId) {
  const payload = JSON.stringify({ session_id: sessionId, owner_actor_id: ownerActorId });
  const program = String.raw`
import asyncio
import json
import sys

from sqlalchemy import text

from app.infrastructure.storage.postgres import get_postgres

async def main():
    payload = json.load(sys.stdin)
    await get_postgres().init()
    try:
        async with get_postgres().session_factory() as session:
            result = await session.execute(
                text("delete from agent_sessions where id=:session_id and owner_actor_id=:owner_actor_id"),
                payload,
            )
            await session.commit()
        print(json.dumps({"deleted": result.rowcount == 1}, sort_keys=True))
    finally:
        await get_postgres().shutdown()

asyncio.run(main())
`;
  const child = spawnSync(
    "kubectl",
    [
      "--kubeconfig",
      kubeconfig,
      "exec",
      "-i",
      "-n",
      namespace,
      "deploy/research-admin-backend",
      "--",
      ".venv/bin/python",
      "-c",
      program,
    ],
    { input: payload, encoding: "utf8", maxBuffer: 1024 * 1024 },
  );
  if (child.status !== 0) {
    throw new Error("Research owner-isolation cleanup process failed");
  }
  const lines = (child.stdout || "").trim().split("\n").filter(Boolean);
  const outcome = lines.length ? JSON.parse(lines.at(-1)) : {};
  if (outcome.deleted !== true) {
    throw new Error("Research owner-isolation test session was not cleaned");
  }
}

async function verifyResearchOwnerIsolation(browser, app, identities) {
  const backendOrigin = `http://127.0.0.1:${app.backendPort}`;
  const frontendOrigin = `http://127.0.0.1:${app.frontendPort}`;
  let primary;
  let secondary;
  let sessionId = "";
  let ownerActorId = "";
  try {
    primary = await openOwnerIsolationSession(browser, app, identities.primary);
    secondary = await openOwnerIsolationSession(browser, app, identities.secondary);
    ownerActorId = primary.me.user.actor_id;

    const created = await primary.context.request.post(
      `${backendOrigin}/api/agent/sessions`,
      {
        headers: {
          Origin: frontendOrigin,
          "X-CSRF-Token": primary.me.csrf_token,
        },
      },
    );
    if (created.status() !== 200) {
      throw new Error(`owner session creation returned ${created.status()}`);
    }
    const createdPayload = await created.json();
    sessionId = createdPayload.session_id || "";
    if (!sessionId) throw new Error("owner session creation returned no ID");

    const ownerRead = await primary.context.request.get(
      `${backendOrigin}/api/agent/sessions/${sessionId}/events`,
    );
    const otherRead = await secondary.context.request.get(
      `${backendOrigin}/api/agent/sessions/${sessionId}/events`,
    );
    if (ownerRead.status() !== 200 || otherRead.status() !== 403) {
      throw new Error(
        `owner isolation status mismatch: owner=${ownerRead.status()}, other=${otherRead.status()}`,
      );
    }
    return {
      primary_authenticated: true,
      secondary_authenticated: true,
      owner_read: 200,
      cross_owner_read: 403,
      stable_actor_ownership: true,
      primary_provider_ui_attempts: primary.providerUiAttempts,
      secondary_provider_ui_attempts: secondary.providerUiAttempts,
    };
  } finally {
    const cleanupErrors = [];
    if (sessionId && ownerActorId) {
      try {
        cleanupResearchAgentSession(sessionId, ownerActorId);
      } catch (error) {
        cleanupErrors.push(error);
      }
    }
    for (const handle of [secondary, primary]) {
      try {
        await closeOwnerIsolationSession(handle, app);
      } catch (error) {
        cleanupErrors.push(error);
      }
    }
    if (cleanupErrors.length) {
      throw new Error("Research owner-isolation cleanup was incomplete");
    }
  }
}

async function main() {
  progress("load_test_identity");
  const identities = loadTestIdentities();
  const ownerIsolationMode =
    process.env.P0_BROWSER_OWNER_ISOLATION === "true";
  const sessionExpiryMode =
    process.env.P0_BROWSER_SESSION_EXPIRY === "true";
  const requestedApps = new Set(
    (process.env.P0_BROWSER_APPS ||
      (ownerIsolationMode ? "research" : "info,knowledge,research"))
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
  const selectedApps = apps.filter((app) => requestedApps.has(app.key));
  if (selectedApps.length !== requestedApps.size || selectedApps.length === 0) {
    throw new Error("P0_BROWSER_APPS contains an unknown or empty application set");
  }
  if (
    ownerIsolationMode &&
    (selectedApps.length !== 1 || selectedApps[0].key !== "research")
  ) {
    throw new Error("owner-isolation mode requires only the Research application");
  }
  if (
    sessionExpiryMode &&
    (ownerIsolationMode || selectedApps.length !== 1)
  ) {
    throw new Error("session-expiry mode requires exactly one application");
  }
  const forwards = [];
  const sinks = [];
  const templateFrontends = [];
  let browser;
  let strictTlsEnvironment = null;
  let researchTrafficOverridden = false;
  const summary = {
    task: ownerIsolationMode
      ? "V5-P0-005-browser-owner-isolation"
      : sessionExpiryMode
        ? "V5-P0-005-browser-session-expiry"
      : "V5-P0-005-browser",
    result: "failed",
    credentials_printed: false,
    provider_tokens_printed: false,
  };

  try {
    if (ownerIsolationMode) {
      progress("research_traffic_preflight");
      assertResearchTrafficClosed();
      progress("research_traffic_enable");
      setResearchTraffic(true);
      researchTrafficOverridden = true;
      progress("research_traffic_enabled");
      progress("research_rollout_stabilizing");
      await new Promise((resolve) => setTimeout(resolve, 15000));
      progress("research_rollout_stable");
    }

    progress("start_port_forwards");
    forwards.push(...selectedApps.map(startPortForward));
    await Promise.all(
      selectedApps.map((app, index) => waitForPortForward(forwards[index], app)),
    );
    progress("port_forwards_ready");
    if (frontendMode === "template") {
      await Promise.all(
        selectedApps.map((app) =>
          assertTemplateFrontendPortAvailable(app.frontendPort),
        ),
      );
      for (const app of selectedApps) {
        templateFrontends.push(startTemplateFrontend(app));
      }
      await Promise.all(
        selectedApps.map((app, index) =>
          waitForFrontend(templateFrontends[index], app),
        ),
      );
    } else {
      for (const app of selectedApps) {
        sinks.push(await startFrontendSink(app.frontendPort));
      }
    }

    progress("launch_browser");
    strictTlsEnvironment = prepareStrictTlsEnvironment();
    const browserArgs = [
      "--host-resolver-rules=MAP casdoor.sunmoonai.com 127.0.0.1",
    ];
    browser = await chromium.launch({
      headless: true,
      args: browserArgs,
      ...(strictTlsEnvironment
        ? {
            executablePath: chromium.executablePath(),
            env: { ...process.env, HOME: strictTlsEnvironment.homeDir },
          }
        : {}),
    });
    progress("browser_ready");

    if (ownerIsolationMode) {
      progress("owner_isolation_start", "research");
      summary.owner_isolation = await verifyResearchOwnerIsolation(
        browser,
        selectedApps[0],
        identities,
      );
      progress("owner_isolation_passed", "research");
      progress("research_traffic_restore");
      setResearchTraffic(false);
      researchTrafficOverridden = false;
      assertResearchTrafficClosed();
      summary.research_traffic_restored_closed = true;
      progress("research_traffic_restored");
    } else if (sessionExpiryMode) {
      const app = selectedApps[0];
      progress("session_expiry_start", app.key);
      summary.session_expiry = await verifyExpiredBrowserSession(
        browser,
        app,
        identities.primary,
      );
      progress("session_expiry_passed", app.key);
    } else {
      const results = {};
      for (const app of selectedApps) {
        progress("login_start", app.key);
        results[app.key] = await verifyLogin(
          browser,
          app,
          "primary",
          identities.primary,
        );
        progress("login_passed", app.key);
      }
      const researchApp = selectedApps.find((app) => app.key === "research");
      if (researchApp) {
        progress("login_start", "research_secondary");
        results.research_secondary = await verifyLogin(
          browser,
          researchApp,
          "secondary",
          identities.secondary,
        );
        progress("login_passed", "research_secondary");
      }
      summary.identity = results;
    }

    summary.result = "passed";
    progress("complete");
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    summary.error =
      error instanceof Error
        ? error.message.replace(/[?&](code|state|nonce)=[^&\s]+/gi, "$1=REDACTED")
        : "unknown browser verification failure";
    console.error(JSON.stringify(summary, null, 2));
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
    for (const server of sinks) await new Promise((resolve) => server.close(resolve));
    for (const child of templateFrontends) stopTemplateFrontend(child);
    for (const child of forwards) child.kill("SIGTERM");
    if (strictTlsEnvironment) {
      fs.rmSync(strictTlsEnvironment.homeDir, { recursive: true, force: true });
    }
    if (researchTrafficOverridden) {
      try {
        progress("research_traffic_emergency_restore");
        setResearchTraffic(false);
        assertResearchTrafficClosed();
        progress("research_traffic_emergency_restored");
      } catch {
        console.error("P0_BROWSER_RESTORE_FAILURE=research_traffic");
        process.exitCode = 1;
      }
    }
  }
}

await main();
