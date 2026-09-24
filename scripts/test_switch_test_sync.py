"""Regression checks for local result publishing, using disposable Git repos."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "sunmoonai/docs/dev-investment-agent/switch-test/human-remote.sh"
PARENTS = ("k8s", "info-app", "investment-app", "knowledge-app", "tpl-app")
CHILDREN = ("investment-app/investment-backend", "knowledge-app/knowledge-backend")


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs)


def git(repo, *args):
    return run("git", "-C", str(repo), *args).stdout.strip()


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="switch-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.worktrees = self.root / "worktrees"
        self.origins = {}
        for name in (*PARENTS, "runtime", *CHILDREN):
            origin = self.root / (name.replace("/", "-") + ".git")
            run("git", "init", "--bare", str(origin))
            self.origins[name] = origin
            repo = self.worktrees / name
            repo.parent.mkdir(parents=True, exist_ok=True)
            run("git", "clone", str(origin), str(repo))
            git(repo, "config", "user.name", "Sync Test")
            git(repo, "config", "user.email", "sync-test@example.invalid")
            git(repo, "config", "commit.gpgsign", "false")
            git(repo, "config", "core.hooksPath", "/dev/null")
            branch = "master" if name in CHILDREN else "fable"
            git(repo, "checkout", "-b", branch)
            git(repo, "commit", "--allow-empty", "-m", "base")
            git(repo, "push", "origin", branch)
            if name in CHILDREN:
                git(repo, "checkout", "--detach")
        for child in CHILDREN:
            parent, name = child.split("/")
            repo = self.worktrees / parent
            (repo / ".gitmodules").write_text(
                f'[submodule "{name}"]\n\tpath = {name}\n'
                f'\turl = {self.origins[child]}\n'
            )
            git(repo, "add", ".gitmodules", name)
            git(repo, "commit", "-m", "record submodule")
            git(repo, "push", "origin", "fable")
        self.env = dict(
            os.environ,
            WORKTREE_ROOT=str(self.worktrees),
            SYNC_SCRIPT=str(self.root / "no-sync-script"),
            WS="fable",
        )

    def publish(self, success=True):
        result = subprocess.run(
            ["bash", str(SCRIPT)], env=self.env, text=True, capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("本地回来了", result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("本地回来了", result.stdout)
        return result

    def test_detached_children_without_local_fable(self):
        self.publish()
        for child in CHILDREN:
            repo = self.worktrees / child
            self.assertEqual(git(repo, "branch", "--show-current"), "")
            self.assertEqual(
                git(self.origins[child], "rev-parse", "fable"),
                git(repo, "rev-parse", "HEAD"),
            )

    def test_new_child_commit_is_pushed_before_parent_gitlink(self):
        child = CHILDREN[0]
        repo = self.worktrees / child
        (repo / "results.txt").write_text("test evidence\n")
        # Reject a parent push if its gitlink has not already reached the child remote.
        hook = self.origins["investment-app"] / "hooks/pre-receive"
        hook.write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'while read -r old new ref; do\n'
            '  expected=$(git rev-parse "$new:investment-backend")\n'
            f'  actual=$(env -u GIT_DIR -u GIT_WORK_TREE git --git-dir="{self.origins[child]}" rev-parse fable)\n'
            '  test "$expected" = "$actual"\ndone\n'
        )
        hook.chmod(0o755)
        self.publish()
        child_head = git(repo, "rev-parse", "HEAD")
        self.assertEqual(git(self.origins[child], "rev-parse", "fable"), child_head)
        self.assertEqual(
            git(self.origins["investment-app"], "rev-parse", "fable:investment-backend"),
            child_head,
        )

    def test_child_push_failure_stops_before_parent_commit(self):
        hook = self.origins[CHILDREN[0]] / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        parent = self.worktrees / "k8s"
        before = git(parent, "rev-parse", "HEAD")
        (parent / "local.txt").write_text("still uncommitted\n")
        self.publish(success=False)
        self.assertEqual(git(parent, "rev-parse", "HEAD"), before)
        self.assertEqual(git(self.origins["k8s"], "rev-parse", "fable"), before)

    def test_wrong_named_child_branch_stops_before_commits(self):
        repo = self.worktrees / CHILDREN[0]
        git(repo, "checkout", "master")
        (repo / "local.txt").write_text("do not commit on master\n")
        before = git(repo, "rev-parse", "HEAD")
        self.publish(success=False)
        self.assertEqual(git(repo, "rev-parse", "HEAD"), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
