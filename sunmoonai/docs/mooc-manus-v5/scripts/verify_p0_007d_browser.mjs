#!/usr/bin/env node

/**
 * Strict-TLS, real-Casdoor pairing verification for P0-007D.
 * Credentials, cookies, OIDC codes/state/nonces and CSRF values remain in
 * memory. Output contains statuses and immutable deployment identifiers only.
 */

import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const require = createRequire(import.meta.url)
const { chromium } = require(
  '/home/zymun/tpl-app/tpl-admin-frontend-react/node_modules/@playwright/test',
)

const kubeconfig = process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const namespace = process.env.P0_007D_NAMESPACE || 'app-platform-dev'
const origin =
  process.env.P0_007D_ORIGIN ||
  'https://tpl-admin-p0-007d.sunmoonai.com:30443'
const applicationHost = new URL(origin).hostname
const providerHost = 'casdoor.sunmoonai.com'
const identitySecret = 'sunmoonai-p0-005-browser-identity'
const caCertificate =
  process.env.P0_007D_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`

let browser
let strictTlsHome

function stage(value) {
  process.stderr.write(`P0_007D_BROWSER_STAGE=${value}\n`)
}

function kubectl(args) {
  const environment = { ...process.env }
  delete environment.DEBUG
  return execFileSync(
    'kubectl',
    ['--kubeconfig', kubeconfig, ...args],
    { encoding: 'utf8', env: environment },
  )
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
  if (!encoded) throw new Error(`required test identity key is absent: ${key}`)
  return Buffer.from(encoded, 'base64').toString('utf8')
}

function deployment(name, expectedPort) {
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
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'sunmoonai-p0-007d-'))
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
  try {
    await username.waitFor({ state: 'visible', timeout: 30000 })
  } catch (error) {
    const diagnosticPath = '/tmp/p0-007d-casdoor-login.png'
    let screenshot = 'not-written'
    try {
      await page.screenshot({
        path: diagnosticPath,
        fullPage: true,
        timeout: 5000,
      })
      screenshot = diagnosticPath
    } catch {
      screenshot = 'failed'
    }
    let title = ''
    try {
      title = await page.title()
    } catch {
      title = '<unavailable>'
    }
    throw new Error(
      `Casdoor form absent url=${page.url()} title=${JSON.stringify(title)} screenshot=${screenshot}`,
      { cause: error },
    )
  }
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

function casdoorPodSnapshot() {
  const workload = JSON.parse(
    kubectl([
      'get',
      'deployment/casdoor-sunmoonai',
      '-n',
      namespace,
      '-o',
      'json',
    ]),
  )
  if (
    workload.spec.replicas !== 1 ||
    workload.status.readyReplicas !== 1 ||
    workload.status.availableReplicas !== 1
  ) {
    throw new Error('Casdoor deployment is not stable at 1/1')
  }
  const matchLabels = workload.spec.selector?.matchLabels || {}
  const selector = Object.entries(matchLabels)
    .map(([key, value]) => `${key}=${value}`)
    .join(',')
  if (!selector) throw new Error('Casdoor deployment selector is empty')
  const pods = JSON.parse(
    kubectl(['get', 'pods', '-n', namespace, '-l', selector, '-o', 'json']),
  ).items.filter((pod) => pod.metadata.deletionTimestamp === undefined)
  if (pods.length !== 1) {
    throw new Error(`Casdoor expected one active Pod, got ${pods.length}`)
  }
  const pod = pods[0]
  const container = pod.status.containerStatuses?.find(
    (entry) => entry.name === 'casdoor-sunmoonai',
  )
  if (!container?.ready || !container.state?.running?.startedAt) {
    throw new Error('Casdoor container is not ready and running')
  }
  return {
    uid: pod.metadata.uid,
    restartCount: container.restartCount,
    startedAt: container.state.running.startedAt,
  }
}

async function assertCasdoorStable() {
  const before = casdoorPodSnapshot()
  await new Promise((resolve) => setTimeout(resolve, 15000))
  const after = casdoorPodSnapshot()
  if (
    before.uid !== after.uid ||
    before.restartCount !== after.restartCount ||
    before.startedAt !== after.startedAt
  ) {
    throw new Error('Casdoor changed during the 15-second stability window')
  }
  return true
}

function assertCsp(headers) {
  const csp = headers['content-security-policy'] || ''
  if (
    !csp.includes("default-src 'self'") ||
    !csp.includes("object-src 'none'") ||
    !csp.includes("frame-ancestors 'none'") ||
    csp.includes("'unsafe-eval'")
  ) {
    throw new Error('legacy Admin CSP contract is incomplete')
  }
  return true
}

async function browserFetch(page, pathName, init = {}) {
  return page.evaluate(
    async ({ pathName: target, init: requestInit }) => {
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
    { pathName, init },
  )
}

async function main() {
  stage('deployment_preflight')
  const frontend = deployment('tpl-admin-frontend-p0-007d', 80)
  const backend = deployment('tpl-admin-backend-p0-007d', 8000)
  const identity = {
    username: decodeSecret('PRIMARY_USERNAME'),
    password: decodeSecret('PRIMARY_PASSWORD'),
  }
  stage('casdoor_stability_window')
  await assertCasdoorStable()
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
  let lastNavigationFailure = null
  page.on('requestfailed', (request) => {
    if (request.isNavigationRequest()) {
      lastNavigationFailure = request.failure()?.errorText || 'unknown'
    }
  })

  stage('casdoor_strict_tls_preflight')
  let providerPreflight
  try {
    providerPreflight = await page.goto(`https://${providerHost}:30443/`, {
      waitUntil: 'domcontentloaded',
      timeout: 30000,
    })
  } catch (error) {
    throw new Error(
      `Casdoor strict-TLS navigation failed url=${page.url()} network=${lastNavigationFailure || 'none'} cause=${error instanceof Error ? error.message : 'unknown'}`,
      { cause: error },
    )
  }
  if (!providerPreflight || providerPreflight.status() !== 200) {
    throw new Error(
      `Casdoor strict-TLS preflight failed status=${providerPreflight?.status() || 0} network=${lastNavigationFailure || 'none'}`,
    )
  }

  stage('anonymous_and_csp')
  const initial = await page.goto(`${origin}/login`, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  })
  if (!initial || initial.status() !== 200) {
    throw new Error('legacy Admin login page did not load')
  }
  assertCsp(initial.headers())
  const anonymous = await browserFetch(page, '/api/auth/me')
  if (anonymous.status !== 401) {
    throw new Error(`anonymous auth/me expected 401, got ${anonymous.status}`)
  }
  stage('real_casdoor_login')
  await page.getByRole('link', { name: '使用 Casdoor 登录' }).click()
  try {
    await submitCasdoorLogin(page, identity)
  } catch (error) {
    throw new Error(
      `${error.message} network=${lastNavigationFailure || 'none'}`,
      { cause: error },
    )
  }
  await page.waitForURL(`${origin}/`, { timeout: 45000 })
  await page.getByRole('heading', { name: '管理首页' }).waitFor({
    state: 'visible',
    timeout: 30000,
  })

  const me = await browserFetch(page, '/api/auth/me')
  if (me.status !== 200) {
    throw new Error(`authenticated auth/me expected 200, got ${me.status}`)
  }
  const payload = me.body
  if (
    payload.contract_version !== 1 ||
    payload.authenticated !== true ||
    payload.user?.surface !== 'admin' ||
    payload.user?.app !== 'tpl-p0-007d' ||
    typeof payload.csrf_token !== 'string'
  ) {
    throw new Error('auth/me contract or Admin identity boundary is invalid')
  }

  stage('csrf_and_mutation_boundary')
  const rejected = await browserFetch(page, '/api/internal/tasks/ping', {
    method: 'POST',
    headers: {
      'X-CSRF-Token': 'invalid',
    },
  })
  if (rejected.status !== 403) {
    throw new Error(`invalid CSRF expected 403, got ${rejected.status}`)
  }

  const scoped = await browserFetch(page, '/api/internal/tasks/ping', {
    method: 'POST',
    headers: {
      'X-CSRF-Token': payload.csrf_token,
    },
  })
  if (![403, 503].includes(scoped.status)) {
    throw new Error(`authorized mutation boundary returned ${scoped.status}`)
  }

  stage('logout_and_audit')
  const logout = await browserFetch(page, '/api/auth/logout', {
    method: 'POST',
    headers: {
      'X-CSRF-Token': payload.csrf_token,
    },
  })
  if (logout.status !== 204) {
    throw new Error(`logout expected 204, got ${logout.status}`)
  }
  const afterLogout = await browserFetch(page, '/api/auth/me')
  if (afterLogout.status !== 401) {
    throw new Error(`post-logout auth/me expected 401, got ${afterLogout.status}`)
  }

  execFileSync(
    'kubectl',
    [
      '--kubeconfig',
      kubeconfig,
      'exec',
      '-n',
      namespace,
      'deployment/tpl-admin-frontend-p0-007d',
      '--',
      'sh',
      '-lc',
      '! command -v node && nginx -t',
    ],
    { stdio: 'ignore' },
  )
  const auditLogs = kubectl([
    'logs',
    '-n',
    namespace,
    '-l',
    'app=tpl-admin-backend-p0-007d',
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
      task: 'V5-P0-007D-browser-pair',
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
      csp_checked: true,
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
