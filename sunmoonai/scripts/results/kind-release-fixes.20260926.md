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
