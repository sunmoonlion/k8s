# KIND sandbox provisioning follow-up — 2026-09-25

## Process check

- Ran the requested `pgrep -f '[a]gent/dist/cli.js start'` inventory with each matching process's `SUNMOON_AGENT_HOME`; it returned no live agent processes, so there was no non-demo PID to kill. The `status.json` files under the default agent home and `~/.sunmoon-agent-kind2` remained, but no matching CLI process was running.

## CrashLoop diagnosis and provisioner refresh

- Previous sandbox container log, filtered with `grep -viE 'sk-|token|password'`: `chmod: /data/codex: Operation not permitted`.
- Verified fable k8s HEAD `f6914102652ecbe8a6fe92d72aa65ef3b330405b` contains fix `d1a2f202`.
- Rebuilt and pushed `harbor.sunmoonai.com:30443/app-images/sandbox-provisioner:v1-r2` from the fable provisioner source. New image digest: `sha256:9df0db43168977ac389f311c30e20cb43c3790059efa537d3b64da06b51677ec`.
- Updated `sunmoonai/sandbox-platform/resources/provisioner.yaml` to pin that digest, applied the manifest, and confirmed the `sandbox-provisioner` Deployment rollout succeeded.
- Pending owner action: in Workbench settings, click “更新沙箱” once. After that, verify `sandbox-u-a63d03b16693` reaches Running and its log reports `listening`; continue agent and registration steps only then.

No token, password, or agent-init command is recorded here.
- A prior attempt initialized `~/.sunmoon-agent-kind2` and briefly reported `relay=connected`, but the requested process inventory now finds no live CLI process. Step 7 is therefore not counted complete; repeat init/start and verify the live process after the sandbox has been refreshed and is Running.

## Owner refreshed sandbox; agent and machine registration

- Owner clicked “更新沙箱”. The replacement `sandbox-u-a63d03b16693` pod reached `Running` 1/1. Filtered pod logs report `server listening` and the app-server listening on port 47800.
- Fast-forwarded the clean fable runtime checkout to `d6d9d7c` and rebuilt `agent/dist` with the already-installed TypeScript compiler. The requested `start --help` fix is present in this build.
- Read `~/private/agent-init.txt` without printing it. Initialized the `kind2` agent with relay `ws://172.18.0.3:30471` and root `/home/zymun/research`; no credential value was recorded.
- Duplicate agents initially caused repeated close-4000 replacements. Stopped the non-demo processes by exact PID, preserving `~/.sunmoon-agent-kind`. Started one detached kind2 agent. After 30 seconds: exactly one live kind2 process; its status is `connected`; its private log has one `relay connected`; relay logs since the restart show one `agent up` for this user and no subsequent `agent down` or `agent replaced`.
- Ran `workbench_register` in the Investment API for the user-provided email, environment `this-pc`, root `/home/zymun/research`, and the refreshed sandbox service URL. The environment was newly registered; the already provisioned sandbox record was reused. No token was written to this report.
- Browser step 8 (create session and run SMOKE) remains pending. Once the owner confirms it passed, perform step 9's update/reclaim verification; do not reclaim before SMOKE.

## Browser report and final UI cleanup pending

- Owner reports that the 09 browser SMOKE passed.
- The post-SMOKE settings-page “更新沙箱” and “回收沙箱” actions have not yet been performed from this session; no browser process or browser-control endpoint is available here. Verify the final reclaim state only after those UI actions: Deployment absent, PVC retained.

## Browser SMOKE and final lifecycle actions

- Owner reported the browser SMOKE passed: delegation card, `委托 … → SUCCEEDED` rows, expert plan, and answer appeared without refreshing; 2 steps, reported cost 0.5256 yuan.
- Final settings-page “更新沙箱” and “回收沙箱” actions remain unverified. This session has no controllable browser process/debug endpoint. Do not substitute a direct Deployment deletion for the product reclaim flow; after the owner completes the UI actions, verify the sandbox Deployment is absent and its PVC remains.

## Post-SMOKE update/reclaim verification

- Owner reports completing both settings-page actions, “更新沙箱” and “回收沙箱”.
- Read-only cluster verification does not yet satisfy the documented reclaim postcondition: `sandbox-u-a63d03b16693` Deployment is still present and 1/1 Ready (creation timestamp `2026-09-25T14:45:36Z`); PVC `sandbox-u-a63d03b16693-codex-home` remains Bound (2 GiB). Recent events show pod replacements, but no Deployment deletion. Therefore update/reclaim is not counted complete until the Deployment is absent and PVC remains Bound.
