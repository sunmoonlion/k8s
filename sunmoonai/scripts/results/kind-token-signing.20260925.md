# KIND Workbench token signing — 2026-09-25

## Server-side preparation

- Built and pushed relay `v1-r3`, digest `sha256:dfc4d0e08fc83f846ceb1d3024a7f944b688f1283f886a89fb0c8c5b0702b647`, pinned and applied it. Relay is Ready; the existing `demo` agent reconnected.
- Generated a P-256 signing keypair. Private and public PEM files are at `/home/zymun/private/wb-signing.pem` and `/home/zymun/private/wb-public.pem`, both mode 0600. Local OpenSSL validation passed. Key material is not in this report or Git.
- Patched only the private PEM into `app-platform-dev/investment-workbench/WORKBENCH_TOKEN_SIGNING_KEY` and the public PEM into `app-platform-dev/knowledge-mcp-tokens/jwt-public-key.pem`. Both API deployments restarted and are Ready; the private-key env and Knowledge public-key env are present.
- The Workbench `/api/workbench/token-keys` endpoint returns one EC P-256 key (`kid=dazjQBuCmtSO3rCFTWuEA5mOYf8xJ0nlWdt0RiONLpw`) and no private `d` member.
- Investment API can reach provisioner and relay health checks (HTTP 200). Relay logs show v1-r3 listening and the static `demo` agent up. It has not yet logged JWT verification enabled because the settings-page per-user sandbox update has not pushed the public key to relay.

## Browser work pending

The settings-page “更新沙箱”/“换代理令牌” actions and Workbench SMOKE/DATA_QUERY delegations have not been performed. After the 09 browser launch, verify the relay receives the public key; rotate the proxy token, confirm the old agent is rejected, initialize/start the new agent privately, then run SMOKE and DATA_QUERY if 08 remains available. Do not paste JWTs or agent-init commands into chat or Git.
