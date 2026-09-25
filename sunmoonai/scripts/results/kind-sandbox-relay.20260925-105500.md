# KIND sandbox relay 07 — partial result (2026-09-25)

## Completed

- Built and pushed sandbox image digest: `harbor.sunmoonai.com:30443/app-images/sandbox@sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f`.
- Built and pushed relay image digest: `harbor.sunmoonai.com:30443/app-images/relay@sha256:9a155338849e57d0e4e3b9ba075783de71fe4d19053d9f2602b695da85476806`.
- Updated the resource manifests to use these digests. Relay Secret permissions use mode 0440 and fsGroup 10002. Sandbox mounts its home PVC at /data and its app-server token with mode 0440/fsGroup 10001; this lets the non-root entrypoint initialize /data/codex.
- Relay and sandbox pods are Running and Ready. Sandbox logs report app-server listening at ws://0.0.0.0:47800 and a paired connection.
- Registered the existing Workbench user `admin@sunmoonai.local` without sending email. Environment `this-pc`: `3c306437-b499-4830-b85f-3209f78700f7`; sandbox: `ce3fe8da-f055-4bf3-acaf-2c7aaa2331ff`.
- Initialized and started the local agent under `/home/zymun/.sunmoon-agent-kind`; startup log reports `relay connected` to edge-1. Agent remains running for follow-up.

## Stopped at browser smoke test

Step 8 onward is not verified: this session has no interactive browser control, and no local Chromium/Firefox or Playwright/Puppeteer installation was found. No Workbench session or SMOKE delegation was created, and no UI success is claimed. Continue by opening the Workbench in an authenticated browser, selecting `this-pc` and the registered sandbox, then completing the hello.txt and SMOKE checks in inbox item 07.
