#!/usr/bin/env node

/**
 * Strict-TLS, real-Casdoor verification for V5-P0-009D Research Web.
 *
 * Credentials, session cookies, OIDC codes/state/nonces and CSRF tokens remain
 * in memory. The emitted evidence contains only statuses, counts and immutable
 * image/deployment identifiers.
 */

import { execFileSync, spawn } from 'node:child_process'
import { createRequire } from 'node:module'
import fs from 'node:fs'
import http from 'node:http'
import https from 'node:https'
import os from 'node:os'
import path from 'node:path'

const require = createRequire(import.meta.url)
const { chromium } = require(
  '/home/zymun/tpl-app/tpl-web-frontend/app/node_modules/@playwright/test',
)

const kubeconfig = process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const kubectlBinary = process.env.KUBECTL_BIN || 'kubectl'
const taskId = 'V5-P0-009D-web-pair'
const namespace = process.env.P0_009D_NAMESPACE || 'app-platform-dev'
const origin =
  process.env.P0_009D_ORIGIN || 'https://research-web-p0-009d.sunmoonai.com:30443'
const providerHost = 'casdoor.sunmoonai.com'
const identitySecret = 'sunmoonai-p0-005-browser-identity'
const caCertificate =
  process.env.P0_009D_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`
const runId = '00000000-0000-5000-8000-000000000001'
const actionId = '00000000-0000-5000-8000-000000000020'
const evidenceId = '00000000-0000-5000-8000-000000000030'
const event2 = '00000000-0000-5000-8000-000000000011'
const event3 = '00000000-0000-5000-8000-000000000012'

let browser
let strictTlsHome
const portForwards = []
const kubectlEnvironment = { ...process.env }
delete kubectlEnvironment.DEBUG

function stage(value) {
  console.error(`P0_009D_WEB_STAGE=${value}`)
}

function kubectl(args, capture = true) {
  return execFileSync(kubectlBinary, ['--kubeconfig', kubeconfig, ...args], {
    encoding: 'utf8',
    env: kubectlEnvironment,
    stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'ignore',
  })
}

function assertKubectlCompatibility() {
  const value = JSON.parse(kubectl(['version', '-o', 'json']))
  const clientMinor = Number.parseInt(value.clientVersion?.minor, 10)
  const serverMinor = Number.parseInt(value.serverVersion?.minor, 10)
  if (
    !Number.isInteger(clientMinor) ||
    !Number.isInteger(serverMinor) ||
    Math.abs(clientMinor - serverMinor) > 1
  ) {
    throw new Error(
      `unsupported kubectl skew: client_minor=${clientMinor} server_minor=${serverMinor}`,
    )
  }
  return { client_minor: clientMinor, server_minor: serverMinor }
}

function decodeSecret(secretName, key) {
  const encoded = kubectl([
    'get',
    'secret',
    secretName,
    '-n',
    namespace,
    '-o',
    `jsonpath={.data.${key}}`,
  ]).trim()
  if (!encoded) throw new Error(`required operator Secret key is absent: ${key}`)
  return Buffer.from(encoded, 'base64').toString('utf8')
}

function loadIdentity() {
  const identity = {
    username: decodeSecret(identitySecret, 'PRIMARY_USERNAME'),
    password: decodeSecret(identitySecret, 'PRIMARY_PASSWORD'),
  }
  if (!identity.username || !identity.password) throw new Error('test identity is empty')
  return identity
}

function deployment(name) {
  return JSON.parse(
    kubectl(['get', `deployment/${name}`, '-n', namespace, '-o', 'json']),
  )
}

function assertDeployment(name, expectedPort) {
  const value = deployment(name)
  const pod = value.spec.template.spec
  const container = pod.containers[0]
  const context = container.securityContext || {}
  const podContext = pod.securityContext || {}
  if (value.spec.replicas !== 2 || value.status.readyReplicas !== 2) {
    throw new Error(`${name} is not ready at 2/2`)
  }
  if (!container.image.includes('@sha256:')) {
    throw new Error(`${name} is not pinned by immutable digest`)
  }
  if (
    pod.automountServiceAccountToken !== false ||
    podContext.runAsNonRoot !== true ||
    podContext.runAsUser !== 1001 ||
    podContext.runAsGroup !== 1001 ||
    context.readOnlyRootFilesystem !== true ||
    context.allowPrivilegeEscalation !== false ||
    !context.capabilities?.drop?.includes('ALL')
  ) {
    throw new Error(`${name} pod hardening contract is incomplete`)
  }
  if (!container.ports?.some((entry) => entry.containerPort === expectedPort)) {
    throw new Error(`${name} does not expose the expected internal port`)
  }
  return {
    image: container.image,
    deployment_id: value.spec.template.metadata.annotations?.['sunmoonai.com/deployment-id'],
  }
}

function businessDeploymentSnapshot() {
  const value = JSON.parse(kubectl(['get', 'deployments', '-n', namespace, '-o', 'json']))
  return Object.fromEntries(
    value.items
      .filter((item) => !item.metadata.name.endsWith('-p0-009d'))
      .map((item) => [
        item.metadata.name,
        {
          generation: item.metadata.generation,
          image: item.spec.template.spec.containers[0]?.image || '',
        },
      ])
      .sort(([left], [right]) => left.localeCompare(right)),
  )
}

function prepareStrictTlsHome() {
  if (!fs.existsSync(caCertificate)) {
    throw new Error(`strict TLS CA certificate not found: ${caCertificate}`)
  }
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'sunmoonai-b63f-browser-'))
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
    .locator('input[name="username"], input[autocomplete="username"], input[type="text"]')
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

function assertSecurityHeaders(headers) {
  const csp = headers['content-security-policy'] || ''
  if (
    !csp.includes("default-src 'self'") ||
    !csp.includes("object-src 'none'") ||
    !csp.includes("frame-ancestors 'none'") ||
    !csp.includes("'strict-dynamic'") ||
    csp.includes("'unsafe-inline'") ||
    csp.includes("'unsafe-eval'")
  ) {
    throw new Error('production CSP is missing strict nonce policy')
  }
  if (
    headers['strict-transport-security'] !== 'max-age=31536000; includeSubDomains' ||
    headers['x-content-type-options'] !== 'nosniff' ||
    headers['x-frame-options'] !== 'DENY' ||
    !headers['permissions-policy']
  ) {
    throw new Error('browser security header contract is incomplete')
  }
  const nonce = csp.match(/'nonce-([^']+)'/)?.[1]
  if (!nonce) throw new Error('CSP nonce is absent')
  return nonce
}

function strictRequest(
  method,
  target,
  { headers = {}, body = undefined, timeoutMs = 30000 } = {},
) {
  const url = new URL(target, origin)
  const payload = body === undefined ? undefined : JSON.stringify(body)
  return new Promise((resolve, reject) => {
    const request = https.request(
      url,
      {
        method,
        ca: fs.readFileSync(caCertificate),
        rejectUnauthorized: true,
        lookup: (_hostname, options, callback) => {
          if (typeof options === 'object' && options.all) {
            callback(null, [{ address: '127.0.0.1', family: 4 }])
            return
          }
          callback(null, '127.0.0.1', 4)
        },
        headers: {
          Accept: 'application/json',
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
          ...headers,
        },
      },
      (response) => {
        const chunks = []
        response.on('data', (chunk) => chunks.push(chunk))
        response.once('end', () => {
          const text = Buffer.concat(chunks).toString('utf8')
          resolve({
            status: response.statusCode || 0,
            headers: response.headers,
            text,
            json() {
              return JSON.parse(text)
            },
          })
        })
      },
    )
    request.setTimeout(timeoutMs, () => request.destroy(new Error('strict TLS request timeout')))
    request.once('error', reject)
    if (payload) request.write(payload)
    request.end()
  })
}

function parseSse(body) {
  const events = []
  for (const block of body.split(/\r?\n\r?\n/)) {
    const id = block.match(/^id:\s*(.+)$/m)?.[1]?.trim()
    const data = block.match(/^data:\s*(.+)$/m)?.[1]?.trim()
    if (id && data) events.push({ id, data: JSON.parse(data) })
  }
  return events
}

function startPodForward(pod, localPort) {
  const child = spawn(
    kubectlBinary,
    [
      '--kubeconfig',
      kubeconfig,
      'port-forward',
      '-n',
      namespace,
      `pod/${pod}`,
      `${localPort}:8000`,
      '--address=127.0.0.1',
    ],
    { stdio: ['ignore', 'pipe', 'pipe'], env: kubectlEnvironment },
  )
  portForwards.push(child)
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`port-forward timeout: ${pod}`)), 30000)
    const onData = (chunk) => {
      if (String(chunk).includes('Forwarding from 127.0.0.1')) {
        clearTimeout(timeout)
        resolve()
      }
    }
    child.stdout.on('data', onData)
    child.stderr.on('data', onData)
    child.once('exit', (code) => {
      clearTimeout(timeout)
      reject(new Error(`port-forward exited: pod=${pod} code=${code}`))
    })
  })
}

function requestPod(port, cookieHeader) {
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        host: '127.0.0.1',
        port,
        path: '/api/auth/me',
        headers: {
          Cookie: cookieHeader,
          Accept: 'application/json',
          // TrustedHostMiddleware rejects Host=127.0.0.1; use the Service DNS
          // name that the isolated ConfigMap already allows.
          Host: 'research-web-backend-p0-009d',
        },
      },
      (response) => {
        response.resume()
        response.once('end', () => resolve(response.statusCode))
      },
    )
    request.once('error', reject)
    request.end()
  })
}

async function verifySessionOnEveryBackendPod(cookieHeader) {
  const pods = JSON.parse(
    kubectl([
      'get',
      'pods',
      '-n',
      namespace,
      '-l',
      'app=research-web-backend-p0-009d',
      '-o',
      'json',
    ]),
  ).items
    .filter(
      (item) =>
        !item.metadata.deletionTimestamp &&
        item.status.phase === 'Running' &&
        item.status.conditions?.some(
          (condition) => condition.type === 'Ready' && condition.status === 'True',
        ),
    )
    .map((item) => item.metadata.name)
  if (pods.length !== 2) throw new Error('expected exactly two P0-009D backend pods')
  await Promise.all(pods.map((pod, index) => startPodForward(pod, 18120 + index)))
  const statuses = await Promise.all(
    pods.map((_pod, index) => requestPod(18120 + index, cookieHeader)),
  )
  if (statuses.some((status) => status !== 200)) {
    throw new Error(`Redis session was not readable on every backend pod: ${statuses.join(',')}`)
  }
  return statuses
}

async function main() {
  const summary = {
    task: taskId,
    result: 'failed',
    strict_tls: true,
    credentials_printed: false,
    tokens_printed: false,
    cookies_printed: false,
  }
  const businessBefore = businessDeploymentSnapshot()
  try {
    stage('infrastructure_preflight')
    summary.kubectl = assertKubectlCompatibility()
    summary.backend = assertDeployment('research-web-backend-p0-009d', 8000)
    summary.frontend = assertDeployment('research-web-frontend-p0-009d', 3000)
    const identity = loadIdentity()

    stage('strict_tls_browser_start')
    strictTlsHome = prepareStrictTlsHome()
    browser = await chromium.launch({
      headless: true,
      args: [
        `--host-resolver-rules=MAP research-web-p0-009d.sunmoonai.com 127.0.0.1, MAP ${providerHost} 127.0.0.1`,
      ],
      executablePath: chromium.executablePath(),
      env: { ...process.env, HOME: strictTlsHome },
    })
    const context = await browser.newContext({ ignoreHTTPSErrors: false })
    const page = await context.newPage()
    const pageErrors = []
    page.on('pageerror', (error) => pageErrors.push(error.name))

    stage('anonymous_and_csp')
    const home = await strictRequest('GET', '/zh-CN')
    if (home.status !== 200) throw new Error(`strict TLS home returned ${home.status}`)
    const nonce = assertSecurityHeaders(home.headers)
    const html = home.text
    if (!html.includes(`nonce="${nonce}"`)) {
      throw new Error('CSP header nonce is not attached to rendered scripts')
    }
    const anonymous = await strictRequest('GET', '/api/auth/me')
    if (anonymous.status !== 401) {
      throw new Error(`anonymous /api/auth/me returned ${anonymous.status}`)
    }

    stage('real_casdoor_login')
    await page.goto(`${origin}/api/auth/login?return_to=/zh-CN/dashboard`, {
      waitUntil: 'commit',
      timeout: 30000,
    })
    if (new URL(page.url()).hostname !== providerHost) {
      throw new Error('OIDC authorization did not reach the canonical Casdoor host')
    }
    await submitCasdoorLogin(page, identity)
    await page.waitForURL(`${origin}/zh-CN/dashboard`, {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    })
    await page.getByRole('heading', { name: '控制台' }).waitFor({ timeout: 30000 })
    await page.getByText('FastAPI reference interaction').waitFor({ timeout: 30000 })
    if (pageErrors.length) throw new Error(`browser page errors=${pageErrors.length}`)

    stage('session_and_cookie')
    const cookies = await context.cookies(origin)
    const sessionCookie = cookies.find((cookie) => cookie.name === 'sunmoonai_research_web_sid')
    if (
      !sessionCookie ||
      !sessionCookie.httpOnly ||
      !sessionCookie.secure ||
      sessionCookie.sameSite !== 'Lax'
    ) {
      throw new Error('secure session cookie contract is incomplete')
    }
    const cookieHeader = `${sessionCookie.name}=${sessionCookie.value}`
    const meResponse = await strictRequest('GET', '/api/auth/me', {
      headers: { Cookie: cookieHeader },
    })
    if (meResponse.status !== 200) {
      throw new Error(`authenticated /api/auth/me returned ${meResponse.status}`)
    }
    const me = meResponse.json()
    if (!me.authenticated || !me.user?.actor_id || !me.csrf_token) {
      throw new Error('browser session contract is incomplete')
    }
    summary.redis_cross_replica_statuses = await verifySessionOnEveryBackendPod(cookieHeader)

    stage('sse_cursor_contract')
    const firstStream = await strictRequest('GET', `/api/runs/${runId}/events`, {
      headers: { Cookie: cookieHeader, Accept: 'text/event-stream' },
    })
    if (firstStream.status !== 200) {
      throw new Error(`initial SSE returned ${firstStream.status}`)
    }
    const firstEvents = parseSse(firstStream.text)
    if (firstEvents.map((event) => event.data.sequence_no).join(',') !== '2,3,4') {
      throw new Error('initial SSE sequence is not 2,3,4')
    }
    if (new Set(firstEvents.map((event) => event.id)).size !== firstEvents.length) {
      throw new Error('initial SSE contains duplicate event identifiers')
    }
    const resumed = await strictRequest('GET', `/api/runs/${runId}/events`, {
      headers: { Cookie: cookieHeader, Accept: 'text/event-stream', 'Last-Event-ID': event2 },
    })
    const resumedEvents = parseSse(resumed.text)
    if (resumedEvents.map((event) => event.data.sequence_no).join(',') !== '3,4') {
      throw new Error('SSE resume sequence is not 3,4')
    }
    const invalidCursor = await strictRequest(
      'GET',
      `/api/runs/${runId}/events?last_event_id=not-a-uuid`,
      { headers: { Cookie: cookieHeader, Accept: 'text/event-stream' } },
    )
    const conflictingCursor = await strictRequest(
      'GET',
      `/api/runs/${runId}/events?last_event_id=${event3}`,
      {
        headers: {
          Cookie: cookieHeader,
          Accept: 'text/event-stream',
          'Last-Event-ID': event2,
        },
      },
    )
    if (invalidCursor.status !== 400 || conflictingCursor.status !== 400) {
      throw new Error('SSE invalid/conflicting cursor matrix is incomplete')
    }

    stage('authorization_and_csrf')
    const forbiddenRun = await strictRequest(
      'GET',
      '/api/runs/00000000-0000-5000-8000-000000000099',
      { headers: { Cookie: cookieHeader } },
    )
    const forbiddenCitation = await strictRequest(
      'GET',
      '/api/citations/00000000-0000-5000-8000-000000000099/source',
      { headers: { Cookie: cookieHeader } },
    )
    if (forbiddenRun.status !== 403 || forbiddenCitation.status !== 403) {
      throw new Error('resource authorization negative matrix is incomplete')
    }
    const command = { contract_version: 1, action_id: actionId, value: 'confirm' }
    const csrfCases = [
      {},
      { Origin: 'https://attacker.example.test', 'X-CSRF-Token': me.csrf_token },
      { Origin: origin },
      { Origin: origin, 'X-CSRF-Token': 'invalid-csrf-token-value-000000000000' },
    ]
    for (const headers of csrfCases) {
      const response = await strictRequest('POST', `/api/runs/${runId}/actions`, {
        headers: { Cookie: cookieHeader, ...headers },
        body: command,
      })
      if (response.status !== 403) {
        throw new Error(`CSRF negative case returned ${response.status}`)
      }
    }
    const accepted = await strictRequest('POST', `/api/runs/${runId}/actions`, {
      headers: {
        Cookie: cookieHeader,
        Origin: origin,
        'X-CSRF-Token': me.csrf_token,
      },
      body: command,
    })
    if (accepted.status !== 200 || accepted.json().status !== 'succeeded') {
      throw new Error(`authorized action returned ${accepted.status}`)
    }

    stage('citation_and_paired_ui')
    const citation = await strictRequest('GET', `/api/citations/${evidenceId}/source`, {
      headers: { Cookie: cookieHeader },
    })
    const citationLocation = citation.headers.location
    if (
      citation.status !== 302 ||
      citationLocation !== `/api/reference/sources/${evidenceId}`
    ) {
      throw new Error('citation redirect contract is invalid')
    }
    const source = await strictRequest('GET', citationLocation, {
      headers: { Cookie: cookieHeader },
    })
    const sourceBody = source.json()
    if (
      source.status !== 200 ||
      !(
        sourceBody.evidence_id === evidenceId ||
        sourceBody.source === 'authorized-reference-fixture'
      )
    ) {
      throw new Error('authorized citation source contract is invalid')
    }
    await page.getByTestId('required-action').waitFor({ timeout: 30000 })
    await page.getByRole('button', { name: '确认并继续' }).click()
    await page.getByTestId('run-status').getByText('已完成').waitFor({ timeout: 30000 })

    stage('logout')
    await page.getByRole('button', { name: '退出登录' }).click()
    await page.waitForURL(`${origin}/zh-CN/login`, { timeout: 30000 })
    const afterLogout = await strictRequest('GET', '/api/auth/me', {
      headers: { Cookie: cookieHeader },
    })
    if (afterLogout.status !== 401) throw new Error('logout did not revoke the Redis session')

    if (JSON.stringify(businessBefore) !== JSON.stringify(businessDeploymentSnapshot())) {
      throw new Error('a business deployment changed during isolated P0-009D verification')
    }
    summary.http = {
      home: home.status,
      anonymous_me: anonymous.status,
      authenticated_me: meResponse.status,
      action: accepted.status,
      logout_me: afterLogout.status,
    }
    summary.sse = {
      initial_sequences: firstEvents.map((event) => event.data.sequence_no),
      resumed_sequences: resumedEvents.map((event) => event.data.sequence_no),
      invalid_cursor: invalidCursor.status,
      conflicting_cursor: conflictingCursor.status,
    }
    summary.resource_authorization = {
      forbidden_run: forbiddenRun.status,
      forbidden_citation: forbiddenCitation.status,
      authorized_source: source.status,
    }
    summary.business_deployments_unchanged = true
    summary.result = 'passed'
    stage('complete')
    console.log(JSON.stringify(summary, null, 2))
  } catch (error) {
    summary.error =
      error instanceof Error ? error.message : 'unknown P0-009D Web verification failure'
    console.error(JSON.stringify(summary, null, 2))
    process.exitCode = 1
  } finally {
    for (const child of portForwards) child.kill('SIGTERM')
    if (browser) await browser.close()
    if (strictTlsHome) fs.rmSync(strictTlsHome, { recursive: true, force: true })
  }
}

await main()
