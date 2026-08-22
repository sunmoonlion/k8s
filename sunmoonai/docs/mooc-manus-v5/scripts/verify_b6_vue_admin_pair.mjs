#!/usr/bin/env node

/**
 * Strict-TLS, real-Casdoor verification for the Vue Admin reference profile
 * paired with the canonical FastAPI Admin backend. Secrets remain in memory;
 * output contains statuses and immutable tuple identifiers only.
 */

import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const require = createRequire(import.meta.url)
const { chromium } = require(
  '/home/zymun/master/tpl-app/tpl-admin-frontend/app/node_modules/@playwright/test',
)

const kubeconfig = process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const namespace = process.env.B6_VUE_NAMESPACE || 'app-platform-dev'
const origin =
  process.env.B6_VUE_ORIGIN || 'https://tpl-admin-p0-007e.sunmoonai.com:30443'
const applicationHost = new URL(origin).hostname
const providerHost = 'casdoor.sunmoonai.com'
const identitySecret = 'sunmoonai-p0-005-browser-identity'
const caCertificate =
  process.env.B6_VUE_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`

let browser
let strictTlsHome

function stage(value) {
  process.stderr.write(`B6_VUE_BROWSER_STAGE=${value}\n`)
}

function kubectl(args) {
  const environment = { ...process.env }
  delete environment.DEBUG
  return execFileSync('kubectl', ['--kubeconfig', kubeconfig, ...args], {
    encoding: 'utf8',
    env: environment,
  })
}

function decodeSecret(key) {
  const encoded = kubectl([
    'get',
    'secret',
    identitySecret,
    '-n',
    namespace,
    '-o',
    `jsonpath={.data.${key}}`,
  ]).trim()
  if (!encoded) throw new Error(`required browser identity key is absent: ${key}`)
  return Buffer.from(encoded, 'base64').toString('utf8')
}

function deployment(name, expectedPort, expectedProfile) {
  const value = JSON.parse(
    kubectl(['get', `deployment/${name}`, '-n', namespace, '-o', 'json']),
  )
  const pod = value.spec.template.spec
  const container = pod.containers[0]
  if (value.spec.replicas !== 2 || value.status.readyReplicas !== 2) {
    throw new Error(`${name} is not ready at 2/2`)
  }
  if (!container.image.includes('@sha256:')) {
    throw new Error(`${name} is not pinned by immutable digest`)
  }
  if (pod.automountServiceAccountToken !== false) {
    throw new Error(`${name} mounts a ServiceAccount token`)
  }
  if (!container.ports?.some((entry) => entry.containerPort === expectedPort)) {
    throw new Error(`${name} exposes an unexpected port`)
  }
  if (
    expectedProfile &&
    value.spec.template.metadata.labels?.['sunmoonai.com/profile'] !==
      expectedProfile
  ) {
    throw new Error(`${name} has an unexpected profile label`)
  }
  if (
    container.securityContext?.readOnlyRootFilesystem !== true ||
    container.securityContext?.runAsNonRoot !== true ||
    container.securityContext?.allowPrivilegeEscalation !== false
  ) {
    throw new Error(`${name} runtime hardening is incomplete`)
  }
  return {
    image: container.image,
    deployment_id:
      value.spec.template.metadata.annotations?.['sunmoonai.com/deployment-id'],
  }
}

function prepareStrictTlsHome() {
  if (!fs.existsSync(caCertificate)) {
    throw new Error(`strict TLS CA certificate not found: ${caCertificate}`)
  }
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'sunmoonai-b6-vue-'))
  const nssDir = path.join(home, '.pki', 'nssdb')
  fs.mkdirSync(nssDir, { recursive: true })
  execFileSync('certutil', ['-N', '-d', `sql:${nssDir}`, '--empty-password'], {
    stdio: 'ignore',
  })
  execFileSync(
    'certutil',
    [
      '-A',
      '-d',
      `sql:${nssDir}`,
      '-n',
      'SunMoonAI Root CA',
      '-t',
      'C,,',
      '-i',
      caCertificate,
    ],
    { stdio: 'ignore' },
  )
  return home
}

async function submitCasdoorLogin(page, identity) {
  const username = page
    .locator(
      'input[name="username"], input[autocomplete="username"], input[type="text"]',
    )
    .first()
  await username.waitFor({ state: 'visible', timeout: 30000 })
  await username.fill(identity.username)
  await username.press('Enter')
  const password = page
    .locator(
      'input[name="password"], input[autocomplete="current-password"], input[type="password"]',
    )
    .first()
  await password.waitFor({ state: 'visible', timeout: 30000 })
  await password.fill(identity.password)
  await password.press('Enter')
}

function assertCsp(headers) {
  const csp = headers['content-security-policy'] || ''
  if (
    !csp.includes("default-src 'self'") ||
    !csp.includes("object-src 'none'") ||
    !csp.includes("frame-ancestors 'none'") ||
    csp.includes("'unsafe-eval'")
  ) {
    throw new Error('Vue Admin CSP contract is incomplete')
  }
}

async function browserFetch(page, pathName, init = {}) {
  return page.evaluate(
    async ({ target, requestInit }) => {
      const response = await fetch(target, {
        credentials: 'include',
        ...requestInit,
      })
      const text = await response.text()
      let body = null
      if (text) {
        try {
          body = JSON.parse(text)
        } catch {
          body = text
        }
      }
      return { status: response.status, body }
    },
    { target: pathName, requestInit: init },
  )
}

async function waitForAuthenticatedSession(page) {
  let last = null
  for (let attempt = 0; attempt < 60; attempt += 1) {
    last = await browserFetch(page, '/api/auth/me')
    if (last.status === 200) return last
    await page.waitForTimeout(500)
  }
  throw new Error(`authenticated auth/me expected 200, got ${last?.status || 0}`)
}

async function main() {
  stage('deployment_preflight')
  const frontend = deployment(
    'tpl-admin-frontend-p0-007e',
    8080,
    'vue-reference',
  )
  const backend = deployment('tpl-admin-backend-p0-007e', 8000)
  const identity = {
    username: decodeSecret('PRIMARY_USERNAME'),
    password: decodeSecret('PRIMARY_PASSWORD'),
  }

  stage('strict_tls_browser_start')
  strictTlsHome = prepareStrictTlsHome()
  browser = await chromium.launch({
    headless: true,
    executablePath: chromium.executablePath(),
    env: { ...process.env, HOME: strictTlsHome },
    args: [
      `--host-resolver-rules=MAP ${applicationHost} 127.0.0.1, MAP ${providerHost} 127.0.0.1`,
    ],
  })
  const context = await browser.newContext({ ignoreHTTPSErrors: false })
  const page = await context.newPage()
  const remoteRuntimeHosts = new Set()
  page.on('request', (request) => {
    const host = new URL(request.url()).hostname
    const localBrowserHost =
      host === '127.0.0.1' || host === 'localhost' || host === '::1'
    if (host && host !== applicationHost && host !== providerHost && !localBrowserHost) {
      remoteRuntimeHosts.add(host)
    }
  })

  stage('casdoor_strict_tls_preflight')
  const provider = await page.goto(`https://${providerHost}:30443/`, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  })
  if (!provider || provider.status() !== 200) {
    throw new Error(`Casdoor strict-TLS preflight failed: ${provider?.status() || 0}`)
  }

  stage('anonymous_csp_and_route_guard')
  const initial = await page.goto(`${origin}/#/login`, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  })
  if (!initial || initial.status() !== 200) {
    throw new Error('Vue Admin login shell did not load')
  }
  assertCsp(initial.headers())
  await page
    .getByRole('button', { name: '使用 Casdoor 登录' })
    .waitFor({ state: 'visible', timeout: 30000 })
  const anonymous = await browserFetch(page, '/api/auth/me')
  if (anonymous.status !== 401) {
    throw new Error(`anonymous auth/me expected 401, got ${anonymous.status}`)
  }

  const isolated = await browser.newContext({ ignoreHTTPSErrors: false })
  const isolatedPage = await isolated.newPage()
  await isolatedPage.goto(`${origin}/#/about`, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  })
  await isolatedPage.waitForURL(/#\/login$/, { timeout: 30000 })
  await isolated.close()

  stage('real_casdoor_login')
  await page.getByRole('button', { name: '使用 Casdoor 登录' }).click()
  await submitCasdoorLogin(page, identity)
  await page.waitForURL(new RegExp(`^${origin.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`), {
    timeout: 45000,
  })
  const me = await waitForAuthenticatedSession(page)
  const payload = me.body
  if (
    payload.contract_version !== 1 ||
    payload.authenticated !== true ||
    payload.user?.surface !== 'admin' ||
    payload.user?.app !== 'tpl' ||
    typeof payload.csrf_token !== 'string'
  ) {
    throw new Error('auth/me contract or Admin identity boundary is invalid')
  }

  stage('csrf_mutation_and_role_boundary')
  if (payload.user.roles.includes('admin')) {
    throw new Error('gate identity cannot prove the non-admin role boundary')
  }
  const rejected = await browserFetch(page, '/api/internal/tasks/ping', {
    method: 'POST',
    headers: { 'X-CSRF-Token': 'invalid' },
  })
  if (rejected.status !== 403) {
    throw new Error(`invalid CSRF expected 403, got ${rejected.status}`)
  }
  const scoped = await browserFetch(page, '/api/internal/tasks/ping', {
    method: 'POST',
    headers: { 'X-CSRF-Token': payload.csrf_token },
  })
  if (scoped.status !== 503) {
    throw new Error(`authorized mutation expected 503, got ${scoped.status}`)
  }

  stage('logout_and_runtime')
  const logout = await browserFetch(page, '/api/auth/logout', {
    method: 'POST',
    headers: { 'X-CSRF-Token': payload.csrf_token },
  })
  if (logout.status !== 204) {
    throw new Error(`logout expected 204, got ${logout.status}`)
  }
  const afterLogout = await browserFetch(page, '/api/auth/me')
  if (afterLogout.status !== 401) {
    throw new Error(`post-logout auth/me expected 401, got ${afterLogout.status}`)
  }
  if (remoteRuntimeHosts.size > 0) {
    throw new Error(
      `Vue runtime loaded unexpected remote hosts: ${[...remoteRuntimeHosts].join(',')}`,
    )
  }

  execFileSync(
    'kubectl',
    [
      '--kubeconfig',
      kubeconfig,
      'exec',
      '-n',
      namespace,
      'deployment/tpl-admin-frontend-p0-007e',
      '--',
      'sh',
      '-lc',
      'test "$(id -u)" = 101 && ! command -v node && nginx -t && ! touch /usr/share/nginx/html/.b6-write-probe',
    ],
    { stdio: 'ignore' },
  )
  const auditLogs = kubectl([
    'logs',
    '-n',
    namespace,
    '-l',
    'app=tpl-admin-backend-p0-007e',
    '--tail=300',
  ])
  if (
    !auditLogs.includes(
      'audit_mutation method=POST path=/api/auth/logout status=204',
    )
  ) {
    throw new Error('successful logout mutation is absent from audit logs')
  }

  console.log(
    JSON.stringify({
      task: 'V5-P0-008B-B6.2-vue-admin-pair',
      result: 'passed',
      anonymous: anonymous.status,
      authenticated: me.status,
      invalid_csrf: rejected.status,
      scoped_mutation: scoped.status,
      logout: logout.status,
      post_logout: afterLogout.status,
      frontend_image: frontend.image,
      backend_image: backend.image,
      deployment_id: frontend.deployment_id,
      contract_version: payload.contract_version,
      strict_tls: true,
      csp_checked: true,
      real_role_negative: true,
      remote_runtime_hosts: 0,
      credentials_printed: false,
      tokens_printed: false,
    }),
  )
  stage('complete')
}

try {
  await main()
} finally {
  if (browser) await browser.close()
  if (strictTlsHome) fs.rmSync(strictTlsHome, { recursive: true, force: true })
}
