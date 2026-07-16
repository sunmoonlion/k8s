#!/usr/bin/env python3
"""Run the V5-P0-001 candidate-A process recovery spike in KIND.

The Job reuses only the Research worker's environment references and service
account. It never prints resolved Secret values and removes itself after the
result is collected.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
import time
from typing import Any


def kubectl(
    args: list[str],
    *,
    kubeconfig: str,
    input_text: str | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    command = ["kubectl", "--kubeconfig", kubeconfig, *args]
    return subprocess.run(
        command,
        input=input_text,
        text=True,
        capture_output=True,
        check=check,
    )


def build_job(
    *,
    source_deployment: dict[str, Any],
    namespace: str,
    job_name: str,
    image: str,
) -> dict[str, Any]:
    pod_spec = source_deployment["spec"]["template"]["spec"]
    source_container = pod_spec["containers"][0]
    container: dict[str, Any] = {
        "name": "runtime-spike",
        "image": image,
        "imagePullPolicy": "Always",
        "command": [
            "/app/.venv/bin/python",
            "scripts/run_runtime_selection_sigkill_spike.py",
        ],
    }
    for field in ("env", "envFrom"):
        if source_container.get(field):
            container[field] = copy.deepcopy(source_container[field])

    job_pod_spec: dict[str, Any] = {
        "restartPolicy": "Never",
        "automountServiceAccountToken": False,
        "containers": [container],
    }
    for field in ("serviceAccountName", "imagePullSecrets"):
        if pod_spec.get(field):
            job_pod_spec[field] = copy.deepcopy(pod_spec[field])

    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "name": job_name,
            "namespace": namespace,
            "labels": {
                "app": job_name,
                "sunmoonai.com/task": "V5-P0-001",
            },
        },
        "spec": {
            "backoffLimit": 0,
            "ttlSecondsAfterFinished": 600,
            "template": {
                "metadata": {"labels": {"app": job_name}},
                "spec": job_pod_spec,
            },
        },
    }


def validate_result(payload: dict[str, Any]) -> None:
    if payload.get("candidate") != "A-custom-runtime":
        raise AssertionError(f"unexpected candidate: {payload.get('candidate')}")
    if payload.get("result") != "passed":
        raise AssertionError(f"runtime spike did not pass: {payload}")
    if payload.get("checkpoint") != "postgres":
        raise AssertionError("runtime spike did not use PostgreSQL checkpointing")
    if payload.get("process_death") != "SIGKILL":
        raise AssertionError("runtime spike did not exercise SIGKILL")

    kill_cases = payload.get("kill_cases")
    if not isinstance(kill_cases, list) or len(kill_cases) != 2:
        raise AssertionError("before/after commit kill cases are incomplete")
    by_kill_point = {case["kill_point"]: case for case in kill_cases}
    if set(by_kill_point) != {"before_commit", "after_commit"}:
        raise AssertionError(f"unexpected kill cases: {sorted(by_kill_point)}")
    for kill_point, case in by_kill_point.items():
        if case.get("worker_exitcode") != -9:
            raise AssertionError(f"{kill_point} worker was not SIGKILLed")
        if case.get("replacement_completed") is not True:
            raise AssertionError(f"{kill_point} replacement did not complete")
        if case.get("durable_side_effect_count") != 1:
            raise AssertionError(f"{kill_point} duplicated or lost the side effect")

    cancel = payload.get("cancel", {})
    if cancel != {
        "durable_side_effect_count": 0,
        "running_cancel_observed": True,
        "terminal_status": "cancelled",
    }:
        raise AssertionError(f"running cancel contract failed: {cancel}")

    parallel = payload.get("parallel_workers", {})
    if parallel.get("worker_processes") != 2:
        raise AssertionError("two-worker execution was not exercised")
    if parallel.get("worker_exitcodes") != [0, 0]:
        raise AssertionError(f"parallel worker failure: {parallel}")
    if parallel.get("terminal_statuses") != ["completed", "completed"]:
        raise AssertionError(f"parallel terminal states failed: {parallel}")
    if parallel.get("durable_side_effect_counts") != [1, 1]:
        raise AssertionError(f"parallel side-effect counts failed: {parallel}")

    postgres_outage = payload.get("postgres_outage", {})
    if postgres_outage != {
        "outage_observed": True,
        "fail_closed_side_effect_count": 0,
        "replacement_completed": True,
        "recovered_side_effect_count": 1,
    }:
        raise AssertionError(
            f"PostgreSQL fail-closed/recovery contract failed: {postgres_outage}"
        )


def wait_for_job(
    *,
    kubeconfig: str,
    namespace: str,
    job_name: str,
    timeout_seconds: int,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        result = kubectl(
            ["get", "job", job_name, "-n", namespace, "-o", "json"],
            kubeconfig=kubeconfig,
        )
        job = json.loads(result.stdout)
        status = job.get("status", {})
        if status.get("succeeded") == 1:
            return
        if status.get("failed"):
            raise AssertionError(f"runtime spike Job failed: {status}")
        time.sleep(1)
    raise TimeoutError(f"timed out waiting for Job {namespace}/{job_name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument(
        "--kubeconfig",
        default=os.path.expanduser("~/.kube/kind-config"),
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument(
        "--source-deployment",
        default="celeryworker-research-admin-backend",
    )
    parser.add_argument("--job-name", default="p0-001-runtime-candidate-a")
    parser.add_argument("--timeout", type=int, default=240)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = kubectl(
        [
            "get",
            "deployment",
            args.source_deployment,
            "-n",
            args.namespace,
            "-o",
            "json",
        ],
        kubeconfig=args.kubeconfig,
    )
    deployment = json.loads(source.stdout)
    job = build_job(
        source_deployment=deployment,
        namespace=args.namespace,
        job_name=args.job_name,
        image=args.image,
    )

    kubectl(
        [
            "delete",
            "job",
            args.job_name,
            "-n",
            args.namespace,
            "--ignore-not-found=true",
        ],
        kubeconfig=args.kubeconfig,
    )
    try:
        kubectl(
            ["apply", "-f", "-"],
            kubeconfig=args.kubeconfig,
            input_text=json.dumps(job),
        )
        wait_for_job(
            kubeconfig=args.kubeconfig,
            namespace=args.namespace,
            job_name=args.job_name,
            timeout_seconds=args.timeout,
        )
        logs = kubectl(
            ["logs", f"job/{args.job_name}", "-n", args.namespace],
            kubeconfig=args.kubeconfig,
        ).stdout
        lines = [line for line in logs.splitlines() if line.strip()]
        if not lines:
            raise AssertionError("runtime spike Job produced no output")
        payload = json.loads(lines[-1])
        validate_result(payload)
        print(
            json.dumps(
                {
                    "task": "V5-P0-001",
                    "candidate": "A-custom-runtime",
                    "result": "passed",
                    "image": args.image,
                    "evidence": payload,
                    "secret_values_printed": False,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    finally:
        kubectl(
            [
                "delete",
                "job",
                args.job_name,
                "-n",
                args.namespace,
                "--ignore-not-found=true",
            ],
            kubeconfig=args.kubeconfig,
            check=False,
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(
            json.dumps(
                {
                    "task": "V5-P0-001",
                    "result": "failed",
                    "error": str(exc),
                },
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        raise
