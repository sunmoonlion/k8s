# KIND sandbox provisioning — 2026-09-25

## Server-side preparation

- Runtime `f60e9d395b068909745958e6d16ae88083b2a598` contains required commit `60120a5`; the live Investment API image includes `app.cli.workbench_register`.
- Built and pushed sandbox provisioner `v1-r1`, digest `sha256:d8aa2a3951bae9b64f67cb3845de4a84ecb09a22cac1fc197eb5df1f8fe81b0b`. Built and pushed relay `v1-r2`, digest `sha256:c60d91e707ba57f9863f5e749e2da86cd69d8e654b7e0d3effb4780d0accb975`. The provisioner and relay image builds used a temporary build-context Dockerfile pointing pip at the repository's established Tsinghua mirror after the default package host timed out; repository Dockerfiles were not changed for that workaround.
- Pinned the provisioner and relay manifests to those digests and the sandbox template to the running 07 image digest `sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f`.
- Created the provisioner, relay-admin, and Workbench Secrets with newly generated values; the Workbench credential key and admin tokens were not printed. Existing 07 app-server Secrets were preserved. The Knowledge static token is shared with the provisioner from its private Secret reference.
- Applied relay and provisioner. Relay is Ready and the local `demo` agent reconnected after its restart. The provisioner initially hit Harbor 401 because its new ServiceAccount lacked the namespace pull Secret; added the existing `harbor-registry-secret` reference to the ServiceAccount manifest and restarted it. Provisioner is now Ready.
- Restarted Investment API to load the new settings. It has the expected Workbench provisioner/admin environment names. From an API pod, provisioner `/healthz` and relay `/healthz` both returned HTTP 200.

## Browser work pending

The settings-page model-key submission and per-user sandbox launch have not been performed. Consequently, no `sandbox-u-*` pod or one-time per-user agent-init command has been created. Browser verification still needs to cover “启动中” → “运行中”, copy the command privately, start the local agent through NodePort 30471, run a SMOKE turn, then update and reclaim the sandbox. Do not put the generated relay token or init command in chat or Git.

No credential values are recorded here.
