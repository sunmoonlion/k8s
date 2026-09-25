# KIND Casdoor pages — 2026-09-26

## Step 1 — current status

- `deploy-auth-app-all.sh --cluster KIND status` passed. Casdoor Helm Release exists, Deployment `casdoor-sunmoonai` completed rollout, and the HTTP/DB/static readiness gate passed.

## Step 2 — upgrade

- Ran `bash deploy-casdoor.sh --cluster KIND upgrade`. It stopped during the Casdoor database provision phase because the operator environment did not provide `PG_ADMIN_PASSWORD` (`set PG_ADMIN_PASSWORD in the operator environment`).
- Per the task instructions, stopped here. Did not manually supply or modify the missing configuration and did not continue to Helm upgrade, page-config checks, or signup setup.
- Steps 3–6 remain unverified.
