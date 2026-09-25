# KIND release fixes — 2026-09-26

## Preflight / step 2 stop

- Step 1 identity preparation directory exists at `/home/zymun/private/investment-identity-recovered-20260926`; private files are mode 0600. The configured preparation record was left unchanged.
- Step 2 requires investment-app commit `d1ee4e0`, investment-backend `a14b070`, and investment-web-frontend `a480433`. Those commit objects are not present in the corresponding local Git object databases. Current checked-out heads are parent `f1be39c`, backend `1745da1`, and web `e096732`.
- Per owner instruction, no fetch/pull was run for those repositories. No images were built or pushed from the older checkouts, and no bundle, deployment, or relay changes were made for this release.
- Runtime is at the requested `d6d9d7c`; the accidental untracked `agent/pnpm-workspace.yaml` was shown to the owner and removed as requested. Runtime worktree is clean.
- Release work is stopped at step 2 pending the owner to sync the required investment-app sources with `human-local.sh`.

## Follow-up after owner synced source commits

- Required checkouts are now present locally: investment-app `d1ee4e0`, backend `a14b070`, web frontend `a480433`, runtime `d6d9d7c`. No fetch/pull/rebase was run in this follow-up.
- Built and pushed backend image digest `sha256:ab1288a41a90bd85069eed2e07ccba00616942f549f9f9c36d93aa98e29fd75b` and web image digest `sha256:3be96b51f2503de4ea5d742ea0ce062b13f86d06c57d577c487bb64a8fdea97b`.
- Updated the source lock, development input, `.conf`, and rendered bundle for release `kind-wb-20260926-fixes`. Diff was limited to the requested backend/web images, their source lock and annotations, derived hashes, and release-derived resource identifiers. Admin image, migration head `20260925_0011`, runtime identity upgrade and other configuration stayed unchanged.
- Declarative bundle gate passed. The specified 18-test suite had 17 passing tests and one known unrelated Knowledge candidate-render error: `source checkout does not match the development lock`; Investment and Info candidate subchecks passed. The read-only Investment plan passed.
- Scaled API, worker, scheduler and runner to zero; waited until their Pods disappeared. The private database rehearsal ran twice, both restore catalogs and rows matched, the live DB remained unchanged, and a mode-0600 cutover receipt was generated for this release. Server dry-run passed.
- Deployed once. Migration Job completed and was cleaned up; all six Deployments rolled out successfully. Identity upgrade record `database-upgrade-kind-wb-20260926-fixes/complete.json` reports `grants_only=true`.
- Built and pushed relay v1-r4 digest `sha256:5ccedf04bcd3ad124f22c346ea89b8af4e89c550bf48b109292cd0c1110fb184`; applied the manifest and relay rollout succeeded.
- **Stopped at step 6:** after the relay restart, the kind2 agent did not reconnect. Its status is `rejected`; the relay logged `reject: agent offline` and only the `demo` user came back up. Exactly one kind2 process remains, but it is not connected. Steps 7–10 were not run. No tokens or passwords are recorded here.

## Step 6b recovery attempt from the updated inbox

- Applied `edge/relay-jwt` from the existing local public-key file without printing its contents; the Secret exposes only the expected `public.pem` key name.
- Applied the synchronized manifest with the unchanged v1-r4 digest. Relay rollout succeeded and PVC `relay-state` is Bound (64 MiB, RWO).
- The required startup log `jwt verification enabled` was absent. Sanitized logs repeatedly showed `reject: agent offline`; kind2 remains one running process with relay status `rejected`.
- Stopped at step 6b as instructed. Did not kill/restart the agent or proceed to steps 7–10. No credential values are recorded.

## Step 6b corrected verification and step 7

- The inbox command used `kubectl ... logs deploy/relay --tail=10 | grep -iE "jwt verification enabled|listening"`. This was inadequate because relay emits a health-check line every 10 seconds, so the startup line can fall outside the last 10 lines.
- Corrected command, preserving the same pass criteria:
  `KUBECONFIG=~/.kube/kind-config kubectl -n edge logs deploy/relay | grep -iE "jwt verification enabled|listening" | head -5`
  It returned `jwt verification enabled issuer=sunmoon-workbench`, `server listening...`, and `listening ws...`.
- Corrected environment-name check:
  `KUBECONFIG=~/.kube/kind-config kubectl -n edge exec deploy/relay -- sh -c 'env | cut -d= -f1 | grep ^RELAY_JWT'`
  It returned `RELAY_JWT_PUBLIC_KEY` and `RELAY_JWT_ISSUER`, meeting the stated criteria.
- Restarted the existing kind2 agent without re-initializing. The first check found an old rejected PID (3212994) as well as the newly connected PID (3569964); stopped only the stale PID. Thereafter exactly one kind2 agent remained, and its log showed `relay connected`; relay showed one `agent up` and no replacement/down event.
- Step 7 TypeScript compile passed: `node node_modules/typescript/bin/tsc -p tsconfig.json`.
- Restarted the single kind2 agent for step 7. After 30 seconds exactly one process remained (PID 3582175), and its log showed `relay connected`. No credential values were written here.
- Paused at step 8 for the owner’s browser verification and token-rotation confirmation.

## Step 8 token rotation and agent re-enrollment

- The owner confirmed the browser key list, sandbox refresh feedback, token-rotation confirmation, and copied replacement command. The replacement command is stored in `/home/zymun/private/agent-init.txt` (0600); its contents and token were not recorded.
- Verified the previous kind2 agent log contained `token revoked`; relay logged `admin revoke jti count=2 closed_agents=1`.
- The old process inventory command pattern `pgrep -f '[a]gent/dist/cli.js start'` did not match this checkout’s actual argv, `node dist/cli.js start`. Corrected the inventory by enumerating `pgrep -f 'node dist/cli.js start'` matches and reading each `/proc/<PID>/environ` `SUNMOON_AGENT_HOME`. This found stale kind2 PID 3582175 alongside new PID 3606403; both were explicitly confirmed to use `/home/zymun/.sunmoon-agent-kind2`. Stopped only stale PID 3582175; demo PID 450664 (`/home/zymun/.sunmoon-agent-kind`) was preserved.
- Reinitialized kind2 from the private replacement command, adapting the relay endpoint to the already-used local NodePort `ws://172.18.0.3:30471` and project root `/home/zymun/research`; token was passed directly from the private file without printing it.
- Started one background kind2 agent. Final status reports PID 3606403, relay `connected`, root `/home/zymun/research`; process inventory shows one kind2 agent and the separate demo agent. Relay logged one `agent up` for `u-a63d03b16693` after the rotation.
- Step 9 is ready for browser verification: create a session with `this-pc` and `sandbox-u-a63d03b16693`, send a message and run SMOKE; verify the event timeline and delegation status appear without refreshing.

## Step 9 browser verification

- Owner reported the Workbench browser check passed without refreshing: the delegation card, each `委托 … → SUCCEEDED` timeline row, the expert plan, and the expert answer appeared automatically. SMOKE completed in 2 steps at a reported cost of 0.5256 yuan.
- This verifies the event-stream behavior in step 9. The separate 09 settings-page sandbox update/reclaim flow is still pending browser interaction; its required postcondition is Deployment absent with the PVC retained.

- Owner reports that the post-SMOKE settings-page sandbox update and reclaim actions were completed. The immediate read-only cluster check still finds `sandbox-u-a63d03b16693` Deployment 1/1 Ready and its home PVC Bound; recent events show pod recreation but no Deployment deletion. The release browser test passed, but the separate 09 reclaim criterion remains unverified/not met until the Deployment is absent while the PVC remains Bound.
