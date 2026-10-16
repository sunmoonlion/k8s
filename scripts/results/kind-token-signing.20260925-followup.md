# D10 token rotation follow-up — 2026-09-25

- The Workbench settings flow pushed the public key to relay. Relay logged `admin set public key` and token revocation (`admin revoke jti count=2`).
- The prior agent went down; relay rejected its next connection attempt. No previous proxy token was retained or copied into this result.
- The first replacement command was superseded before browser DATA_QUERY work. After the owner rotated again, the updated private command was used without printing its contents. Relay rejected the stale agent, then logged one `agent up` for `u-a63d03b16693` at 2026-09-25 15:50:54 UTC.
- Exactly one kind2 agent process is running. Its status is `connected`, with the relay URL set to the local NodePort and the allowed root `/home/zymun/research`. The existing 07 demo agent remains separate.
- No credential values are recorded here.
- D10 browser DATA_QUERY delegation remains pending. The 08 server-side MCP `run_sql` probe passed earlier, but that does not verify Workbench delegation.

## Browser verification after token rotation

- For release item 12, the owner reported the second token-rotation flow passed its confirmation and copy feedback checks. The old token was revoked (`closed_agents=1`), and a replacement token was initialized privately; the agent reconnected once. No token value or command was recorded.
- Owner reported the browser Workbench DATA_QUERY delegation passed earlier; this is the owner-reported result, distinct from the server-side MCP probes above.
- Owner also reported release step 9 SMOKE passed without refreshing: the delegation card, `委托 … → SUCCEEDED` rows, expert plan, and answer appeared automatically (2 steps, 0.5256 yuan).
