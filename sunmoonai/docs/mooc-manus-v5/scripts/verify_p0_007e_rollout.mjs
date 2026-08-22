#!/usr/bin/env node

/**
 * P0-007E Next Node rolling rollback gate.
 *
 * Keeps strict-TLS traffic and referenced static assets healthy while the
 * two-replica frontend rolls from the accepted candidate to the previous
 * candidate and forward again. The real-Casdoor browser verifier runs at both
 * stable points. A failure always attempts to restore the accepted candidate.
 */

import { execFile, execFileSync } from 'node:child_process'
import fs from 'node:fs'
import https from 'node:https'

const kubeconfig =
  process.env.KUBECONFIG || `${process.env.HOME}/.kube/kind-config`
const kubectlBinary = process.env.KUBECTL_BIN || 'kubectl'
const namespace = process.env.P0_007E_NAMESPACE || 'app-platform-dev'
const origin =
  process.env.P0_007E_ORIGIN ||
  'https://tpl-admin-p0-007e.sunmoonai.com:30443'
const caCertificate =
  process.env.P0_007E_CA_CERT ||
  `${process.env.HOME}/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt`
const fullVerifier =
  process.env.P0_007E_FULL_VERIFIER ||
  '/home/zymun/master/k8s/sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_007e_browser.mjs'
const deploymentName = 'tpl-admin-frontend-p0-007e'
const options = parseArguments(process.argv.slice(2))
const kubectlEnvironment = { ...process.env }
delete kubectlEnvironment.DEBUG

function parseArguments(argv) {
  const value = {
    acceptedImage: '',
    rollbackImage: '',
    backendImage: '',
    acceptedDeploymentId: 'p0-007e-v2',
    rollbackDeploymentId: 'p0-007e-v1',
  }
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index]
    const next = argv[index + 1]
    if (argument === '--accepted-image') value.acceptedImage = next
    else if (argument === '--rollback-image') value.rollbackImage = next
    else if (argument === '--backend-image') value.backendImage = next
    else if (argument === '--accepted-deployment-id') {
      value.acceptedDeploymentId = next
    } else if (argument === '--rollback-deployment-id') {
      value.rollbackDeploymentId = next
    } else if (argument === '--help' || argument === '-h') {
      process.stdout.write(
        'Usage: verify_p0_007e_rollout.mjs ' +
          '--accepted-image IMAGE@sha256:DIGEST ' +
          '--rollback-image IMAGE@sha256:DIGEST ' +
          '--backend-image IMAGE@sha256:DIGEST\n',
      )
      process.exit(0)
    } else {
      throw new Error(`unknown or incomplete argument: ${argument}`)
    }
    index += 1
  }
  for (const [name, image] of [
    ['accepted', value.acceptedImage],
    ['rollback', value.rollbackImage],
    ['backend', value.backendImage],
  ]) {
    if (!/@sha256:[a-f0-9]{64}$/.test(image)) {
      throw new Error(`${name} image must be an immutable digest reference`)
    }
  }
  if (value.acceptedImage === value.rollbackImage) {
    throw new Error('accepted and rollback images must differ')
  }
  return value
}

function stage(value) {
  process.stderr.write(`P0_007E_ROLLOUT_STAGE=${value}\n`)
}

function kubectl(args, capture = true) {
  return execFileSync(
    kubectlBinary,
    ['--kubeconfig', kubeconfig, ...args],
    {
      encoding: 'utf8',
      env: kubectlEnvironment,
      stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    },
  )
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
  return JSON.parse(
    kubectl(['get', `deployment/${name}`, '-n', namespace, '-o', 'json']),
  )
}

function deploymentIdentity(name) {
  const value = deployment(name)
  return {
    image: value.spec.template.spec.containers[0].image,
    deploymentId:
      value.spec.template.metadata.annotations?.[
        'sunmoonai.com/deployment-id'
      ] || '',
    ready: value.status.readyReplicas || 0,
    replicas: value.spec.replicas || 0,
  }
}

function unaffectedDeploymentSnapshot() {
  const value = JSON.parse(
    kubectl(['get', 'deployments', '-n', namespace, '-o', 'json']),
  )
  return Object.fromEntries(
    value.items
      .filter((item) => item.metadata.name !== deploymentName)
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

function strictRequest(target, timeoutMs = 10000) {
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
    request.setTimeout(timeoutMs, () =>
      request.destroy(new Error('strict TLS request timeout')),
    )
    request.once('error', reject)
    request.end()
  })
}

function staticAssets(html) {
  const assets = new Set()
  for (const match of html.matchAll(/(?:src|href)="([^"]*\/_next\/static\/[^"]+)"/g)) {
    assets.add(match[1].replaceAll('&amp;', '&'))
  }
  if (!assets.size) throw new Error('rendered Admin page has no static assets')
  return [...assets].sort()
}

async function assertAssets(assets) {
  for (const asset of assets) {
    const response = await strictRequest(asset)
    if (response.status !== 200) {
      throw new Error(`static asset returned ${response.status}`)
    }
  }
}

async function probe() {
  const health = await strictRequest('/healthz')
  if (
    health.status !== 200 ||
    JSON.parse(health.text).surface !== 'admin'
  ) {
    throw new Error(`frontend health returned ${health.status}`)
  }
  const page = await strictRequest('/zh-CN/login')
  if (page.status !== 200) {
    throw new Error(`frontend login returned ${page.status}`)
  }
  const csp = page.headers['content-security-policy'] || ''
  if (!csp.includes("default-src 'self'") || csp.includes("'unsafe-eval'")) {
    throw new Error('frontend CSP changed during rollout')
  }
  const assets = staticAssets(page.text)
  await assertAssets(assets)
  return assets
}

function startContinuityMonitor() {
  let stop = false
  let failure
  let probes = 0
  const done = (async () => {
    while (!stop) {
      try {
        await probe()
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
      if (!probes) throw new Error('continuity monitor made no successful probe')
      return { probes }
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
          containers: [{ name: 'frontend', image }],
        },
      },
    },
  }
  kubectl(
    [
      'patch',
      `deployment/${deploymentName}`,
      '-n',
      namespace,
      '--type=strategic',
      '-p',
      JSON.stringify(patch),
    ],
    false,
  )
}

async function rollout(image, deploymentId) {
  const monitor = startContinuityMonitor()
  let rolloutError
  try {
    patchFrontend(image, deploymentId)
    await kubectlAsync([
      'rollout',
      'status',
      `deployment/${deploymentName}`,
      '-n',
      namespace,
      '--timeout=240s',
    ])
  } catch (error) {
    rolloutError = error
  }
  const continuity = await monitor.finish()
  if (rolloutError) throw rolloutError
  const current = deploymentIdentity(deploymentName)
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

function runFullVerifier(stageName) {
  stage(`full_pair_${stageName}`)
  execFileSync('node', [fullVerifier], {
    env: {
      ...process.env,
      KUBECONFIG: kubeconfig,
      KUBECTL_BIN: kubectlBinary,
      P0_007E_NAMESPACE: namespace,
      P0_007E_ORIGIN: origin,
      P0_007E_CA_CERT: caCertificate,
      P0_007E_ALLOW_LEGACY_FORBIDDEN_EN:
        stageName === 'rollback_v1' ? '1' : '0',
    },
    stdio: 'inherit',
  })
}

async function main() {
  const summary = {
    task: 'V5-P0-007E-rollout',
    result: 'failed',
    strict_tls: true,
    credentials_printed: false,
    tokens_printed: false,
  }
  const unaffectedBefore = unaffectedDeploymentSnapshot()
  try {
    stage('preflight')
    if (!fs.existsSync(caCertificate)) {
      throw new Error('strict TLS CA certificate is absent')
    }
    const frontend = deploymentIdentity(deploymentName)
    const backend = deploymentIdentity('tpl-admin-backend-p0-007e')
    if (
      frontend.image !== options.acceptedImage ||
      frontend.ready !== 2 ||
      frontend.replicas !== 2
    ) {
      throw new Error('frontend is not at the expected accepted baseline')
    }
    if (
      backend.image !== options.backendImage ||
      backend.ready !== 2 ||
      backend.replicas !== 2
    ) {
      throw new Error('backend is not the expected immutable 2/2 release')
    }
    const acceptedAssets = await probe()

    stage('rollback_v1')
    summary.rollback_continuity = await rollout(
      options.rollbackImage,
      options.rollbackDeploymentId,
    )
    const rollbackAssets = await probe()
    await assertAssets(acceptedAssets)
    runFullVerifier('rollback_v1')

    stage('forward_v2')
    summary.forward_continuity = await rollout(
      options.acceptedImage,
      options.acceptedDeploymentId,
    )
    await probe()
    await assertAssets(rollbackAssets)
    runFullVerifier('accepted_v2')

    if (
      JSON.stringify(unaffectedBefore) !==
      JSON.stringify(unaffectedDeploymentSnapshot())
    ) {
      throw new Error('a non-frontend Deployment changed during rollout')
    }
    summary.accepted_image = options.acceptedImage
    summary.rollback_image = options.rollbackImage
    summary.backend_image = options.backendImage
    summary.cross_version_assets = {
      accepted_on_rollback: acceptedAssets.length,
      rollback_on_accepted: rollbackAssets.length,
    }
    summary.full_verifications = ['rollback_v1', 'accepted_v2']
    summary.unaffected_deployments_unchanged = true
    summary.final_state = options.acceptedDeploymentId
    summary.result = 'passed'
    stage('complete')
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`)
  } catch (error) {
    summary.error =
      error instanceof Error ? error.message : 'unknown rollout failure'
    try {
      const current = deploymentIdentity(deploymentName)
      if (
        current.image !== options.acceptedImage ||
        current.deploymentId !== options.acceptedDeploymentId
      ) {
        stage('failure_restore_accepted')
        patchFrontend(options.acceptedImage, options.acceptedDeploymentId)
        await kubectlAsync([
          'rollout',
          'status',
          `deployment/${deploymentName}`,
          '-n',
          namespace,
          '--timeout=240s',
        ])
      }
      summary.failure_restore = 'passed'
    } catch (restoreError) {
      summary.failure_restore = 'failed'
      summary.failure_restore_error =
        restoreError instanceof Error
          ? restoreError.message
          : 'unknown restore failure'
    }
    process.stderr.write(`${JSON.stringify(summary, null, 2)}\n`)
    process.exitCode = 1
  }
}

await main()
