"""A DNS error, OOM or Pending pod is not evidence of NetworkPolicy denial."""

import json
import sys
from pathlib import Path


def matches_expected(pod, log, expected):
    status = pod.get("status", {})
    containers = status.get("containerStatuses", [])
    if status.get("phase") != expected or len(containers) != 1:
        return False
    terminated = containers[0].get("state", {}).get("terminated", {})
    if expected == "Succeeded":
        return (
            terminated.get("exitCode") == 0 and terminated.get("reason") == "Completed"
        )
    if expected == "Failed":
        # This gate pins a BusyBox wget probe against a known-live HTTP fixture.
        # Refusal, DNS failure, command errors and the outer timeout are not a pass.
        return (
            terminated.get("exitCode") == 1
            and terminated.get("reason") == "Error"
            and log.strip() == "wget: download timed out"
        )
    return False


if __name__ == "__main__":
    try:
        accepted = matches_expected(
            json.loads(Path(sys.argv[1]).read_text()),
            Path(sys.argv[2]).read_text(),
            sys.argv[3],
        )
    except (OSError, ValueError, IndexError, TypeError, AttributeError):
        accepted = False
    raise SystemExit(0 if accepted else 1)
