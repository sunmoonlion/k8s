#!/usr/bin/env node

/**
 * Strict-TLS and real-Casdoor gate for both Architecture v2 Next.js surfaces.
 * Provider credentials, browser cookies and OIDC values never leave memory.
 */

import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const require = createRequire(import.meta.url)
const { chromium } = require(
  '/home/zymun/tpl-app/tpl-admin-frontend/app/node_modules/@playwright/test',
)

const kubeconfig = process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const namespace = process.env.R3_NAMESPACE || 'tpl-architecture-v2-r3'
const providerNamespace = process.env.R3_PROVIDER_NAMESPACE || 'app-platform-dev'
const app = process.env.R3_APP || 'tpl'
const task = process.env.R3_BROWSER_TASK || 'architecture-v2-r3-browser'
const adminOrigin = process.env.R3_ADMIN_ORIGIN || 'https://tpl-admin-r3.sunmoonai.com:30443'
const webOrigin = process.env.R3_WEB_ORIGIN || 'https://tpl-web-r3.sunmoonai.com:30443'
const providerOrigin = process.env.R3_CASDOOR_ORIGIN || 'https://casdoor.sunmoonai.com:30443'
const operatorSecret = process.env.R3_OPERATOR_SECRET || 'sunmoonai-p0-005-browser-identity'
const caCertificate =
  process.env.R3_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`

const hosts = [new URL(adminOrigin).hostname, new URL(webOrigin).hostname, new URL(providerOrigin).hostname]
let browser
let strictTlsHome

function stage(value) {
  process.stderr.write(`ARCH_V2_BROWSER_STAGE=${value}\n`)
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
    operatorSecret,
    '-n',
    providerNamespace,
    '-o',
    `jsonpath={.data.${key}}`,
  ]).trim()
  if (!encoded) throw new Error(`required gate identity key is absent: ${key}`)
  return Buffer.from(encoded, 'base64').toString('utf8')
}

function prepareStrictTlsHome() {
  if (!fs.existsSync(caCertificate)) {
    throw new Error(`strict TLS CA certificate not found: ${caCertificate}`)
  }
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'sunmoonai-arch-v2-r3-browser-'))
  const nssDir = path.join(home, '.pki', 'nssdb')
  fs.mkdirSync(nssDir, { recursive: true })
  execFileSync('certutil', ['-N', '-d', `sql:${nssDir}`, '--empty-password'], {
    stdio: 'ignore',
  })
  execFileSync(
    'certutil',
    ['-A', '-d', `sql:${nssDir}`, '-n', 'SunMoonAI Root CA', '-t', 'C,,', '-i', caCertificate],
    { stdio: 'ignore' },
  )
  return home
}

function casdoorPodSnapshot() {
  const workload = JSON.parse(
    kubectl(['get', 'deployment/casdoor-sunmoonai', '-n', providerNamespace, '-o', 'json']),
  )
  if (
    workload.spec.replicas !== 1 ||
    workload.status.readyReplicas !== 1 ||
    workload.status.availableReplicas !== 1
  ) {
    throw new Error('Casdoor deployment is not stable at 1/1')
  }
  const selector = Object.entries(workload.spec.selector?.matchLabels || {})
    .map(([key, value]) => `${key}=${value}`)
    .join(',')
  const pods = JSON.parse(
    kubectl(['get', 'pods', '-n', providerNamespace, '-l', selector, '-o', 'json']),
  ).items.filter((pod) => pod.metadata.deletionTimestamp === undefined)
  if (pods.length !== 1) throw new Error(`Casdoor expected one active Pod, got ${pods.length}`)
  const status = pods[0].status.containerStatuses?.find(
    (entry) => entry.name === 'casdoor-sunmoonai',
  )
  if (!status?.ready || !status.state?.running?.startedAt) {
    throw new Error('Casdoor container is not ready and running')
  }
  return {
    uid: pods[0].metadata.uid,
    restartCount: status.restartCount,
    startedAt: status.state.running.startedAt,
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
}

function assertSecurityHeaders(headers) {
  const csp = headers['content-security-policy'] || ''
  if (
    !csp.includes("default-src 'self'") ||
    !csp.includes("object-src 'none'") ||
    !csp.includes("frame-ancestors 'none'") ||
    !csp.includes("'strict-dynamic'") ||
    csp.includes("'unsafe-eval'")
  ) {
    throw new Error('production CSP contract is incomplete')
  }
  if (
    headers['strict-transport-security'] !== 'max-age=31536000; includeSubDomains' ||
    headers['x-content-type-options'] !== 'nosniff' ||
    headers['x-frame-options'] !== 'DENY'
  ) {
    throw new Error('browser security header contract is incomplete')
  }
}

async function submitCasdoorLogin(page, identity, surface) {
  const username = page
    .locator('input[name="username"], input[autocomplete="username"], input[type="text"]')
    .first()
  try {
    await username.waitFor({ state: 'visible', timeout: 30000 })
  } catch (error) {
    let location = 'not-written'
    try {
      location = `/tmp/architecture-v2-${app}-${surface}-casdoor.png`
      await page.screenshot({ path: location, fullPage: true, timeout: 5000 })
    } catch {
      location = 'failed'
    }
    throw new Error(
      `Casdoor form absent for ${surface} url=${page.url()} screenshot=${location}`,
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

async function browserFetch(page, pathName, init = {}) {
  return page.evaluate(
    async ({ target, requestInit }) => {
      const response = await fetch(target, { credentials: 'include', ...requestInit })
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

async function verifySurface({ surface, origin, loginLabel, heading, identity }) {
  stage(`${surface}_anonymous`)
  const context = await browser.newContext({ ignoreHTTPSErrors: false })
  const page = await context.newPage()
  let navigationFailure = null
  page.on('requestfailed', (request) => {
    if (request.isNavigationRequest()) {
      navigationFailure = request.failure()?.errorText || 'unknown'
    }
  })
  const loginPage = await page.goto(`${origin}/zh-CN/login`, {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  })
  if (!loginPage || loginPage.status() !== 200) {
    throw new Error(`${surface} login page failed status=${loginPage?.status() || 0}`)
  }
  assertSecurityHeaders(loginPage.headers())
  const anonymous = await browserFetch(page, `/api/auth/${surface}/me`)
  if (anonymous.status !== 401) {
    throw new Error(`${surface} anonymous me expected 401, got ${anonymous.status}`)
  }

  stage(`${surface}_real_casdoor_login`)
  await page.getByRole('link', { name: loginLabel, exact: true }).click()
  await submitCasdoorLogin(page, identity, surface)
  try {
    await page.waitForURL(`${origin}/zh-CN/dashboard`, { timeout: 45000 })
  } catch (error) {
    throw new Error(
      `${surface} callback did not reach dashboard url=${page.url()} network=${navigationFailure || 'none'}`,
      { cause: error },
    )
  }
  await page.getByRole('heading', { name: heading, exact: true }).waitFor({
    state: 'visible',
    timeout: 30000,
  })
  const me = await browserFetch(page, `/api/auth/${surface}/me`)
  if (
    me.status !== 200 ||
    me.body?.contract_version !== 1 ||
    me.body?.authenticated !== true ||
    me.body?.user?.app !== app ||
    me.body?.user?.surface !== surface ||
    typeof me.body?.csrf_token !== 'string'
  ) {
    throw new Error(`${surface} authenticated identity contract is invalid`)
  }
  const cookies = await context.cookies(origin)
  const expectedCookie = `sunmoonai_${app}_${surface}_sid`
  const otherCookie = `sunmoonai_${app}_${surface === 'admin' ? 'web' : 'admin'}_sid`
  const session = cookies.find((cookie) => cookie.name === expectedCookie)
  if (!session?.httpOnly || !session.secure || session.sameSite !== 'Lax') {
    throw new Error(`${surface} session cookie contract is incomplete`)
  }
  if (cookies.some((cookie) => cookie.name === otherCookie)) {
    throw new Error(`${surface} browser received the other surface cookie`)
  }

  const logout = await browserFetch(page, `/api/auth/${surface}/logout`, {
    method: 'POST',
    headers: { 'X-CSRF-Token': me.body.csrf_token },
  })
  if (logout.status !== 204) throw new Error(`${surface} logout expected 204, got ${logout.status}`)
  const revoked = await browserFetch(page, `/api/auth/${surface}/me`)
  if (revoked.status !== 401) throw new Error(`${surface} session was not revoked`)
  await context.close()
  return {
    anonymous: anonymous.status,
    authenticated: me.status,
    logout: logout.status,
    revoked: revoked.status,
    surface: me.body.user.surface,
  }
}

async function main() {
  stage('deployment_preflight')
  for (const name of [`${app}-backend-api`, `${app}-admin-frontend`, `${app}-web-frontend`]) {
    const deployment = JSON.parse(
      kubectl(['get', `deployment/${name}`, '-n', namespace, '-o', 'json']),
    )
    if (deployment.status.readyReplicas !== deployment.spec.replicas) {
      throw new Error(`${name} is not fully ready`)
    }
  }
  const identity = {
    username: decodeSecret('PRIMARY_USERNAME'),
    password: decodeSecret('PRIMARY_PASSWORD'),
  }
  if (!identity.username || !identity.password) throw new Error('gate identity is empty')

  stage('casdoor_stability_window')
  await assertCasdoorStable()
  strictTlsHome = prepareStrictTlsHome()
  browser = await chromium.launch({
    headless: true,
    executablePath: chromium.executablePath(),
    env: { ...process.env, HOME: strictTlsHome },
    args: [`--host-resolver-rules=${hosts.map((host) => `MAP ${host} 127.0.0.1`).join(', ')}`],
  })

  stage('strict_tls_provider_preflight')
  const preflightContext = await browser.newContext({ ignoreHTTPSErrors: false })
  const preflightPage = await preflightContext.newPage()
  const provider = await preflightPage.goto(`${providerOrigin}/`, {
    waitUntil: 'domcontentloaded',
    timeout: 30000,
  })
  if (!provider || provider.status() !== 200) {
    throw new Error(`Casdoor strict TLS preflight failed status=${provider?.status() || 0}`)
  }
  await preflightContext.close()

  const admin = await verifySurface({
    surface: 'admin',
    origin: adminOrigin,
    loginLabel: '使用 Casdoor 登录',
    heading: '治理控制台',
    identity,
  })
  const web = await verifySurface({
    surface: 'web',
    origin: webOrigin,
    loginLabel: '登录',
    heading: '控制台',
    identity,
  })
  console.log(
    JSON.stringify(
      {
        task,
        result: 'passed',
        strict_tls: true,
        provider_preflight: 200,
        admin,
        web,
        clients_isolated: true,
        credentials_printed: false,
        provider_tokens_printed: false,
      },
      null,
      2,
    ),
  )
}

try {
  await main()
} finally {
  if (browser) await browser.close()
  if (strictTlsHome) fs.rmSync(strictTlsHome, { recursive: true, force: true })
}
