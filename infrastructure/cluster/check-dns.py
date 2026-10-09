#!/usr/bin/env python3
"""Read-only host and in-cluster DNS health check for the owned KIND cluster."""

from __future__ import annotations

import argparse
import ipaddress
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import yaml

DNS_LABEL = re.compile(r"^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$")
MAX_DNS_MS = 200.0
SAMPLE_COUNT = 10


def parse_resolv_conf(contents: str) -> dict[str, list[str]]:
    """Parse nameserver/search entries and reject malformed search suffixes."""
    nameservers: list[str] = []
    search_domains: list[str] = []
    for raw_line in contents.splitlines():
        fields = raw_line.split("#", 1)[0].split()
        if not fields:
            continue
        if fields[0] == "nameserver":
            if len(fields) != 2:
                raise ValueError(f"invalid nameserver entry: {raw_line.strip()}")
            try:
                nameservers.append(str(ipaddress.ip_address(fields[1])))
            except ValueError as exc:
                raise ValueError(f"invalid nameserver IP: {fields[1]}") from exc
        elif fields[0] == "search":
            if len(fields) < 2:
                raise ValueError("empty search directive")
            search_domains.extend(fields[1:])
    if not nameservers:
        raise ValueError("no valid nameserver configured")
    for domain in search_domains:
        if "/" in domain:
            raise ValueError(f"search suffix is not a DNS domain (contains '/'): {domain}")
        try:
            ipaddress.ip_network(domain, strict=False)
        except ValueError:
            pass
        else:
            raise ValueError(f"search suffix is an IP/CIDR, not a DNS domain: {domain}")
        normalized = domain[:-1] if domain.endswith(".") else domain
        if len(normalized) > 253 or not normalized or any(
            not DNS_LABEL.fullmatch(label) for label in normalized.split(".")
        ):
            raise ValueError(f"invalid DNS search suffix: {domain}")
    return {"nameservers": nameservers, "search": search_domains}


def validate_latency(samples_ms: list[float], threshold_ms: float = MAX_DNS_MS) -> None:
    if not samples_ms:
        raise ValueError("DNS probe returned no timing samples")
    slow = [sample for sample in samples_ms if sample > threshold_ms]
    if slow:
        raise ValueError(
            f"DNS lookup exceeded {threshold_ms:g} ms (max {max(samples_ms):.1f} ms); "
            "check the host DNS suffix and WSL DNS tunnel"
        )


def run_json(command: list[str]) -> Any:
    result = subprocess.run(command, text=True, capture_output=True, timeout=30)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit={result.returncode}"
        raise RuntimeError(f"command failed ({' '.join(command)}): {detail}")
    return json.loads(result.stdout)


def check(site_path: Path, cluster_config_path: Path) -> dict[str, Any]:
    site = yaml.safe_load(site_path.read_text(encoding="utf-8"))
    cluster = yaml.safe_load(cluster_config_path.read_text(encoding="utf-8"))
    cluster_name = site["cluster_name"]
    kubeconfig = cluster["cluster_kubeconfig"]
    app_namespace = site["app_namespace"]
    data_namespace = site["data_namespace"]
    kubectl = str(Path(__file__).resolve().parents[1] / ".tools/bin/kubectl")
    context = f"kind-{cluster_name}"

    nodes = run_json([kubectl, f"--kubeconfig={kubeconfig}", f"--context={context}", "get", "nodes", "-o", "json"])["items"]
    node_dns: dict[str, dict[str, list[str]]] = {}
    for node in nodes:
        name = node["metadata"]["name"]
        if not name.startswith(cluster_name + "-"):
            continue
        raw = subprocess.run(
            ["docker", "exec", name, "cat", "/etc/resolv.conf"],
            text=True,
            capture_output=True,
            timeout=10,
        )
        if raw.returncode:
            raise RuntimeError(f"cannot inspect node resolver on {name}: {raw.stderr.strip()}")
        raw = raw.stdout
        node_dns[name] = parse_resolv_conf(raw)
    if len(node_dns) != 3:
        raise ValueError(f"expected 3 owned KIND nodes, inspected {len(node_dns)}")

    pod_list = run_json([
        kubectl,
        f"--kubeconfig={kubeconfig}",
        f"--context={context}",
        "-n",
        app_namespace,
        "get",
        "pods",
        "-o",
        "json",
    ])["items"]
    candidates = [
        pod
        for pod in pod_list
        if pod.get("status", {}).get("phase") == "Running"
        and pod.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/name", "").endswith("-api")
        and any(
            condition.get("type") == "Ready" and condition.get("status") == "True"
            for condition in pod.get("status", {}).get("conditions", [])
        )
    ]
    if not candidates:
        raise ValueError(f"no Ready application API Pod found in {app_namespace} for DNS probe")
    pod = sorted(candidates, key=lambda item: item["metadata"]["name"])[0]
    pod_name = pod["metadata"]["name"]
    fqdn = f"postgresql.{data_namespace}.svc.cluster.local"
    probe = (
        "import json,socket,sys,time\n"
        "name=sys.argv[1]\n"
        "out=[]\n"
        f"for _ in range({SAMPLE_COUNT}):\n"
        " start=time.perf_counter()\n"
        " socket.getaddrinfo(name,5432,type=socket.SOCK_STREAM)\n"
        " out.append(round((time.perf_counter()-start)*1000,1))\n"
        "print(json.dumps(out))\n"
    )
    result = subprocess.run(
        [kubectl, f"--kubeconfig={kubeconfig}", f"--context={context}", "-n", app_namespace,
         "exec", pod_name, "--", "python", "-c", probe, fqdn],
        text=True,
        capture_output=True,
        timeout=30,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit={result.returncode}"
        raise RuntimeError(f"Pod DNS probe failed on {pod_name}: {detail}")
    samples_ms = [float(value) for value in json.loads(result.stdout.strip().splitlines()[-1])]
    validate_latency(samples_ms)
    return {
        "cluster": cluster_name,
        "node_dns": node_dns,
        "pod": pod_name,
        "service_fqdn": fqdn,
        "samples_ms": samples_ms,
        "max_ms": max(samples_ms),
        "threshold_ms": MAX_DNS_MS,
        "passed": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", type=Path, required=True)
    parser.add_argument("--cluster-config", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.site, args.cluster_config), indent=2))
    except (OSError, KeyError, ValueError, RuntimeError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"DNS health check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
