"""Bounded fixture DNS convergence gate, not a retry of policy assertions."""

import json
import socket
import sys
import time


def wait_for_records(
    records,
    *,
    resolve=socket.gethostbyname,
    now=time.monotonic,
    sleep=time.sleep,
    emit=print,
    budget=30,
):
    deadline = now() + budget
    attempt = 0
    while now() < deadline:
        attempt += 1
        ready = True
        for name, expected in records.items():
            try:
                address = resolve(name)
            except OSError:
                address = None
            matches = address == expected
            ready = ready and matches
            emit(
                json.dumps(
                    {
                        "attempt": attempt,
                        "name": name,
                        "expected": expected,
                        "address": address,
                        "ready": matches,
                    }
                )
            )
        if ready:
            return 0 if now() < deadline else 2
        sleep(min(1, max(0, deadline - now())))
    return 2


if __name__ == "__main__":
    expected_records = dict(item.split("=", 1) for item in sys.argv[1:])
    if not expected_records:
        raise SystemExit(2)
    raise SystemExit(wait_for_records(expected_records))
