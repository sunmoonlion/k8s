# KIND Casdoor pages — 2026-09-26

## Step 1 — current status

- `deploy-auth-app-all.sh --cluster KIND status` passed. Casdoor Helm Release exists, Deployment `casdoor-sunmoonai` completed rollout, and the HTTP/DB/static readiness gate passed.

## Step 2 — upgrade

- Ran `bash deploy-casdoor.sh --cluster KIND upgrade`. It stopped during the Casdoor database provision phase because the operator environment did not provide `PG_ADMIN_PASSWORD` (`set PG_ADMIN_PASSWORD in the operator environment`).
- Per the task instructions, stopped here. Did not manually supply or modify the missing configuration and did not continue to Helm upgrade, page-config checks, or signup setup.
- Steps 3–6 remain unverified.

## Follow-up after the 2026-09-26 inbox correction

- The corrected inbox says to skip steps 1–3 and start at step 4. The earlier upgrade attempt had stopped at the missing operator database password; it was not manually repaired.
- Step 4 read-only query confirmed `sunmoonai-investment-r5-web` exists in organization `sunmoonai` and registration was disabled.
- `SIGNUP_APP=sunmoonai-investment-r5-web bash kind-apply-signup.sh` passed. It reported the page title `SunMoon AI 投研`, text-only logo, Chinese-only organization language, Casdoor built-in app registration disabled, and `sunmoonai-investment-r5-web` registration=false because SMTP is not configured.
- Step 5 visual browser check and login confirmation remain pending owner verification; no browser control is available in this session.
