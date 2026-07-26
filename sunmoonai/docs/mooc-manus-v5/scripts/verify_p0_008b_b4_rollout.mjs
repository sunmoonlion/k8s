#!/usr/bin/env node

/**
 * B4 Next rolling-upgrade and rollback gate.
 *
 * The gate keeps strict TLS traffic flowing while the two-replica frontend is
 * moved from an immutable v1 image to an immutable v2 image and back. It also
 * proves that assets referenced by either version remain retrievable from the
 * other version, checks every ready Pod directly, reruns the real-Casdoor B4
 * verifier at both stable points, and rejects changes to non-B4 Deployments.
 */

import { execFile, execFileSync, spawn } from 'node:child_process'
import fs from 'node:fs'
import http from 'node:http'
import https from 'node:https'

const kubeconfig = process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const kubectlBinary = process.env.KUBECTL_BIN || 'kubectl'
const namespace = process.env.B4_NAMESPACE || 'app-platform-dev'
const origin = process.env.B4_ORIGIN || 'https://tpl-web-b4.sunmoonai.com:30443'
const caCertificate =
  process.env.B4_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`
const fullVerifier =
  process.env.B4_FULL_VERIFIER ||
  '/home/zymun/k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b4.mjs'

const options = parseArguments(process.argv.slice(2))
const portForwards = []
const kubectlEnvironment = { ...process.env }
delete kubectlEnvironment.DEBUG

function parseArguments(argv) {
  const value = {
    oldImage: '',
    newImage: '',
    backendImage: '',
    oldDeploymentId: 'b4-v1',
    newDeploymentId: 'b4-v2',
  }
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index]
    const next = argv[index + 1]
    if (argument === '--old-image') value.oldImage = next
    else if (argument === '--new-image') value.newImage = next
    else if (argument === '--backend-image') value.backendImage = next
    else if (argument === '--old-deployment-id') value.oldDeploymentId = next
    else if (argument === '--new-deployment-id') value.newDeploymentId = next
    else if (argument === '--help' || argument === '-h') {
      process.stdout.write(
        'Usage: verify_p0_008b_b4_rollout.mjs --old-image IMAGE@sha256:DIGEST ' +
          '--new-image IMAGE@sha256:DIGEST --backend-image IMAGE@sha256:DIGEST\n',
      )
      process.exit(0)
    } else {
      throw new Error(`unknown or incomplete argument: ${argument}`)
    }
    index += 1
  }
  for (const [name, image] of [
    ['old', value.oldImage],
    ['new', value.newImage],
    ['backend', value.backendImage],
  ]) {
    if (!/@sha256:[a-f0-9]{64}$/.test(image)) {
      throw new Error(`${name} image must be an immutable digest reference`)
    }
  }
  for (const deploymentId of [value.oldDeploymentId, value.newDeploymentId]) {
    if (!/^[a-z0-9][a-z0-9.-]{1,63}$/.test(deploymentId)) {
      throw new Error(`invalid deployment ID: ${deploymentId}`)
    }
  }
  if (value.oldImage === value.newImage) {
    throw new Error('old and new frontend images must differ')
  }
  return value
}

function stage(value) {
  process.stderr.write(`B4_ROLLOUT_STAGE=${value}\n`)
}

function kubectl(args, capture = true) {
  return execFileSync(kubectlBinary, ['--kubeconfig', kubeconfig, ...args], {
    encoding: 'utf8',
    env: kubectlEnvironment,
    stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
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

function kubectlAsync(args) {
  return new Promise((resolve, reject) => {
    execFile(
      kubectlBinary,
      ['--kubeconfig', kubeconfig, ...args],
      { encoding: 'utf8', env: kubectlEnvironment },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message))
          return
        }
        resolve(stdout)
      },
    )
  })
}

function deployment(name) {
  return JSON.parse(kubectl(['get', `deployment/${name}`, '-n', namespace, '-o', 'json']))
}

function deploymentIdentity(name) {
  const value = deployment(name)
  return {
    image: value.spec.template.spec.containers[0].image,
    deploymentId:
      value.spec.template.metadata.annotations?.['sunmoonai.com/deployment-id'] || '',
    ready: value.status.readyReplicas || 0,
    replicas: value.spec.replicas || 0,
  }
}

function businessDeploymentSnapshot() {
  const value = JSON.parse(kubectl(['get', 'deployments', '-n', namespace, '-o', 'json']))
  return Object.fromEntries(
    value.items
      .filter(
        (item) =>
          item.metadata.name !== 'tpl-web-backend-b4' &&
          item.metadata.name !== 'tpl-web-frontend-b4',
      )
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

function strictRequest(target, timeoutMs = 15000) {
  const url = new URL(target, origin)
  return new Promise((resolve, reject) => {
    const request = https.request(
      url,
      {
        ca: fs.readFileSync(caCertificate),
        rejectUnauthorized: true,
        headers: { Accept: 'text/html,*/*' },
        lookup: (_hostname, lookupOptions, callback) => {
          if (typeof lookupOptions === 'object' && lookupOptions.all) {
            callback(null, [{ address: '127.0.0.1', family: 4 }])
            return
          }
          callback(null, '127.0.0.1', 4)
        },
      },
      (response) => {
        const chunks = []
        response.on('data', (chunk) => chunks.push(chunk))
        response.once('end', () =>
          resolve({
            status: response.statusCode || 0,
            headers: response.headers,
            text: Buffer.concat(chunks).toString('utf8'),
          }),
        )
      },
    )
    request.setTimeout(timeoutMs, () => request.destroy(new Error('strict TLS request timeout')))
    request.once('error', reject)
    request.end()
  })
}

function parsePage(html) {
  const deploymentId = html.match(/\bdata-dpl-id="([^"]+)"/)?.[1] || ''
  const assets = new Set()
  for (const match of html.matchAll(/(?:src|href)="([^"]*\/_next\/static\/[^"]+)"/g)) {
    assets.add(match[1].replaceAll('&amp;', '&'))
  }
  if (!deploymentId) throw new Error('rendered page has no Next deployment ID')
  if (!assets.size) throw new Error('rendered page has no Next static assets')
  return { deploymentId, assets: [...assets].sort() }
}

async function assertAssets(assetPaths) {
  for (const assetPath of assetPaths) {
    const response = await strictRequest(assetPath)
    if (response.status !== 200) {
      throw new Error(`Next asset returned ${response.status}`)
    }
  }
}

async function probePublic(allowedDeploymentIds) {
  const response = await strictRequest('/zh-CN')
  if (response.status !== 200) throw new Error(`public frontend returned ${response.status}`)
  if (response.headers['strict-transport-security'] !== 'max-age=31536000; includeSubDomains') {
    throw new Error('strict TLS response lost HSTS')
  }
  const page = parsePage(response.text)
  if (!allowedDeploymentIds.has(page.deploymentId)) {
    throw new Error(`unexpected public deployment ID: ${page.deploymentId}`)
  }
  await assertAssets(page.assets)
  return page
}

function startMonitor(allowedDeploymentIds) {
  let stop = false
  let failure
  const deploymentIds = new Set()
  let probes = 0
  const done = (async () => {
    while (!stop) {
      try {
        const page = await probePublic(allowedDeploymentIds)
        deploymentIds.add(page.deploymentId)
        probes += 1
      } catch (error) {
        failure = error
        stop = true
        break
      }
      await new Promise((resolve) => setTimeout(resolve, 150))
    }
  })()
  return {
    async finish() {
      stop = true
      await done
      if (failure) throw failure
      if (!probes) throw new Error('rollout continuity monitor made no successful probes')
      return { probes, deploymentIds: [...deploymentIds].sort() }
    },
  }
}

function patchFrontend(image, deploymentId) {
  const patch = {
    spec: {
      template: {
        metadata: {
          annotations: {
            'sunmoonai.com/deployment-id': deploymentId,
          },
        },
        spec: {
          containers: [
            {
              name: 'frontend',
              image,
              env: [{ name: 'DEPLOYMENT_ID', value: deploymentId }],
            },
          ],
        },
      },
    },
  }
  kubectl(
    [
      'patch',
      'deployment/tpl-web-frontend-b4',
      '-n',
      namespace,
      '--type=strategic',
      '-p',
      JSON.stringify(patch),
    ],
    false,
  )
}

async function rolloutFrontend(image, deploymentId, allowedDeploymentIds) {
  const monitor = startMonitor(allowedDeploymentIds)
  let rolloutError
  try {
    patchFrontend(image, deploymentId)
    await kubectlAsync([
      'rollout',
      'status',
      'deployment/tpl-web-frontend-b4',
      '-n',
      namespace,
      '--timeout=240s',
    ])
  } catch (error) {
    rolloutError = error
  }
  const continuity = await monitor.finish()
  if (rolloutError) throw rolloutError
  const current = deploymentIdentity('tpl-web-frontend-b4')
  if (
    current.image !== image ||
    current.deploymentId !== deploymentId ||
    current.ready !== 2 ||
    current.replicas !== 2
  ) {
    throw new Error(`frontend did not stabilize at ${deploymentId}`)
  }
  return continuity
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
      `${localPort}:3000`,
      '--address=127.0.0.1',
    ],
    { stdio: ['ignore', 'pipe', 'pipe'], env: kubectlEnvironment },
  )
  portForwards.push(child)
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`frontend port-forward timeout: ${pod}`)),
      30000,
    )
    const ready = (chunk) => {
      if (String(chunk).includes('Forwarding from 127.0.0.1')) {
        clearTimeout(timer)
        resolve()
      }
    }
    child.stdout.on('data', ready)
    child.stderr.on('data', ready)
    child.once('exit', (code) => {
      clearTimeout(timer)
      reject(new Error(`frontend port-forward exited: pod=${pod} code=${code}`))
    })
  })
}

function localRequest(port, target = '/zh-CN') {
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        host: '127.0.0.1',
        port,
        path: target,
        headers: { Accept: 'text/html' },
      },
      (response) => {
        const chunks = []
        response.on('data', (chunk) => chunks.push(chunk))
        response.once('end', () =>
          resolve({
            status: response.statusCode || 0,
            text: Buffer.concat(chunks).toString('utf8'),
          }),
        )
      },
    )
    request.setTimeout(15000, () => request.destroy(new Error('Pod request timeout')))
    request.once('error', reject)
    request.end()
  })
}

async function assertEveryFrontendPod(expectedDeploymentId, portBase) {
  const pods = JSON.parse(
    kubectl([
      'get',
      'pods',
      '-n',
      namespace,
      '-l',
      'app=tpl-web-frontend-b4',
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
    .sort()
  if (pods.length !== 2) throw new Error('expected exactly two healthy frontend Pods')

  const forwards = []
  try {
    for (const [index, pod] of pods.entries()) {
      await startPodForward(pod, portBase + index)
      forwards.push(portForwards.at(-1))
    }
    const deploymentIds = []
    for (const [index] of pods.entries()) {
      const response = await localRequest(portBase + index)
      if (response.status !== 200) throw new Error('direct frontend Pod did not return 200')
      const page = parsePage(response.text)
      if (page.deploymentId !== expectedDeploymentId) {
        throw new Error(`frontend Pod build is ${page.deploymentId}, expected ${expectedDeploymentId}`)
      }
      deploymentIds.push(page.deploymentId)
    }
    return deploymentIds
  } finally {
    for (const child of forwards) {
      child.kill('SIGTERM')
      const index = portForwards.indexOf(child)
      if (index >= 0) portForwards.splice(index, 1)
    }
  }
}

function runFullVerifier(label) {
  stage(`full_verifier_${label}`)
  execFileSync('node', [fullVerifier], {
    env: {
      ...process.env,
      KUBECONFIG: kubeconfig,
      KUBECTL_BIN: kubectlBinary,
      B4_NAMESPACE: namespace,
      B4_ORIGIN: origin,
      B4_CA_CERT: caCertificate,
    },
    stdio: 'inherit',
  })
}

async function main() {
  const summary = {
    task: 'V5-P0-008B/B4-rollout',
    result: 'failed',
    strict_tls: true,
    credentials_printed: false,
    tokens_printed: false,
    cookies_printed: false,
  }
  const businessBefore = businessDeploymentSnapshot()
  try {
    stage('preflight')
    summary.kubectl = assertKubectlCompatibility()
    if (!fs.existsSync(caCertificate)) throw new Error('strict TLS CA certificate is absent')
    const backend = deploymentIdentity('tpl-web-backend-b4')
    const frontend = deploymentIdentity('tpl-web-frontend-b4')
    if (
      backend.image !== options.backendImage ||
      backend.ready !== 2 ||
      backend.replicas !== 2
    ) {
      throw new Error('backend is not the expected immutable 2/2 B4 release')
    }
    if (
      frontend.image !== options.oldImage ||
      frontend.ready !== 2 ||
      frontend.replicas !== 2
    ) {
      throw new Error('frontend is not at the expected immutable v1 baseline')
    }

    const oldPage = await probePublic(new Set([options.oldDeploymentId]))
    summary.old_pod_deployment_ids = await assertEveryFrontendPod(
      options.oldDeploymentId,
      18220,
    )

    stage('rollout_v2')
    summary.upgrade_continuity = await rolloutFrontend(
      options.newImage,
      options.newDeploymentId,
      new Set([options.oldDeploymentId, options.newDeploymentId]),
    )
    const newPage = await probePublic(new Set([options.newDeploymentId]))
    await assertAssets(oldPage.assets)
    summary.new_pod_deployment_ids = await assertEveryFrontendPod(
      options.newDeploymentId,
      18230,
    )
    runFullVerifier('v2')

    stage('rollback_v1')
    summary.rollback_continuity = await rolloutFrontend(
      options.oldImage,
      options.oldDeploymentId,
      new Set([options.oldDeploymentId, options.newDeploymentId]),
    )
    await probePublic(new Set([options.oldDeploymentId]))
    await assertAssets(newPage.assets)
    summary.rollback_pod_deployment_ids = await assertEveryFrontendPod(
      options.oldDeploymentId,
      18240,
    )
    runFullVerifier('rollback_v1')

    if (JSON.stringify(businessBefore) !== JSON.stringify(businessDeploymentSnapshot())) {
      throw new Error('a non-B4 business Deployment changed during rollout verification')
    }
    summary.backend_image = options.backendImage
    summary.old_frontend_image = options.oldImage
    summary.new_frontend_image = options.newImage
    summary.cross_version_assets = {
      old_assets_on_v2: oldPage.assets.length,
      new_assets_on_v1: newPage.assets.length,
    }
    summary.full_verifications = ['v2', 'rollback_v1']
    summary.business_deployments_unchanged = true
    summary.final_state = options.oldDeploymentId
    summary.result = 'passed'
    stage('complete')
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`)
  } catch (error) {
    summary.error = error instanceof Error ? error.message : 'unknown rollout failure'
    try {
      const current = deploymentIdentity('tpl-web-frontend-b4')
      if (
        current.image !== options.oldImage ||
        current.deploymentId !== options.oldDeploymentId
      ) {
        stage('failure_rollback_v1')
        patchFrontend(options.oldImage, options.oldDeploymentId)
        await kubectlAsync([
          'rollout',
          'status',
          'deployment/tpl-web-frontend-b4',
          '-n',
          namespace,
          '--timeout=240s',
        ])
        summary.failure_rollback = 'passed'
      }
    } catch (rollbackError) {
      summary.failure_rollback = 'failed'
      summary.failure_rollback_error =
        rollbackError instanceof Error ? rollbackError.message : 'unknown rollback failure'
    }
    process.stderr.write(`${JSON.stringify(summary, null, 2)}\n`)
    process.exitCode = 1
  } finally {
    for (const child of portForwards) child.kill('SIGTERM')
  }
}

await main()
