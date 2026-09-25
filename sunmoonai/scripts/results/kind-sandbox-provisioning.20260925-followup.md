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
