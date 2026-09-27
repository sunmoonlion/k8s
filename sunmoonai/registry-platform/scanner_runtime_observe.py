"""Read-only /proc sampling of an admitted scanner process and descendants.

Reads executable paths and mapped library paths only: no argv, environment,
file contents, credentials or ptrace. Sampling does not prove absence of every
short-lived helper. Docker health probes are separate execs, outside this tree.
"""
import os
from pathlib import Path
import re
import threading
import time


class Observation:
    def __init__(self, pid):
        self.pid = int(pid)
        if self.pid <= 1:
            raise ValueError('Live scanner host PID required')
        self.identity = self.start_time(self.pid)
        self.rows = {}
        self.errors = set()
        self.samples = 0
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self.collect, daemon=True)
        self.started = time.monotonic()
        self.thread.start()

    @staticmethod
    def start_time(pid):
        return (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()[19]

    def snapshot(self):
        if self.start_time(self.pid) != self.identity:
            raise ValueError('Scanner PID reused')
        pending = [self.pid]; visited = set()
        while pending:
            pid = pending.pop()
            if pid in visited:
                continue
            visited.add(pid)
            base = Path('/proc') / str(pid)
            try:
                executable = os.readlink(base / 'exe')
                libraries = set()
                for line in (base / 'maps').read_text().splitlines():
                    fields = line.split(None, 5)
                    if len(fields) == 6 and re.search(r'\.so(?:\.|$)', fields[-1]):
                        libraries.add(fields[-1])
                self.rows.setdefault(executable, set()).update(libraries)
                # Go may launch children from any OS thread.
                for task in (base / 'task').iterdir():
                    try:
                        pending.extend(int(v) for v in (task / 'children').read_text().split())
                    except FileNotFoundError:
                        pass
            except (FileNotFoundError, ProcessLookupError):
                pass
        self.samples += 1

    def collect(self):
        while not self.stop_event.is_set():
            try:
                self.snapshot()
            except (FileNotFoundError, ProcessLookupError):
                self.errors.add('root-process-disappeared')
                break
            except Exception as error:
                self.errors.add(type(error).__name__)
                break
            self.stop_event.wait(0.05)

    def finish(self):
        self.stop_event.set(); self.thread.join(timeout=5)
        if self.thread.is_alive():
            raise ValueError('Runtime observer did not stop')
        return {'schema': 1, 'method': '50ms /proc executable and mapped-library sampling',
                'elapsed_seconds': round(time.monotonic() - self.started, 2),
                'samples': self.samples, 'errors': sorted(self.errors),
                'executables': [{'path': p, 'mapped_shared_libraries': sorted(libs)}
                                for p, libs in sorted(self.rows.items())],
                'scope': 'Scanner adapter and descendants during this fixed private-image scan',
                'all_helper_execution_excluded': False,
                'docker_healthcheck_observed': False,
                'limitations': ['Short-lived processes may be missed',
                               'Docker healthcheck executes outside the sampled process tree',
                               'Does not cover other scan modes or all input formats']}
