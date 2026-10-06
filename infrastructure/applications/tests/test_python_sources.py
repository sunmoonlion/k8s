"""Regression checks against the actual four application lockfiles."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

APP = Path(__file__).resolve().parents[1]
WORKTREES = APP.parents[2]


class PythonSources(unittest.TestCase):
    def project(self, temporary, app='tpl'):
        context = Path(temporary) / 'context'
        context.mkdir()
        source = WORKTREES / (app+'-app') / (app+'-backend') / 'app'
        for name in ['pyproject.toml','uv.lock']:
            (context/name).write_bytes((source/name).read_bytes())
        return context

    def select(self, context, mode):
        return subprocess.run([sys.executable,str(APP/'select-python-source.py'),'--context',str(context),'--mode',mode],capture_output=True,text=True)

    def test_all_four_locks_roundtrip_without_dependency_changes(self):
        for app in ['tpl','info','knowledge','investment']:
            with self.subTest(app=app), tempfile.TemporaryDirectory(prefix='sunmoon-tpl-build-test-') as temporary:
                context=self.project(temporary,app)
                before={p.name:p.read_bytes() for p in context.iterdir()}
                domestic=self.select(context,'domestic')
                self.assertEqual(domestic.returncode,0,domestic.stderr)
                self.assertFalse(json.loads(domestic.stdout)['changed'])
                official=self.select(context,'official-proxy')
                self.assertEqual(official.returncode,0,official.stderr)
                result=json.loads(official.stdout)
                self.assertTrue(result['changed'])
                self.assertTrue(result['locked_identities_preserved'])
                self.assertGreater(result['artifacts'],0)
                self.assertNotIn(b'pypi.tuna.tsinghua.edu.cn',(context/'uv.lock').read_bytes())
                back=self.select(context,'domestic')
                self.assertEqual(back.returncode,0,back.stderr)
                self.assertEqual(before,{p.name:p.read_bytes() for p in context.iterdir()})

    def test_invalid_hash_rejected_before_any_write(self):
        with tempfile.TemporaryDirectory(prefix='sunmoon-tpl-build-test-') as temporary:
            context=self.project(temporary)
            lock=context/'uv.lock'
            lock.write_text(lock.read_text().replace('sha256:','invalid:',1))
            before={p.name:p.read_bytes() for p in context.iterdir()}
            result=self.select(context,'official-proxy')
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(before,{p.name:p.read_bytes() for p in context.iterdir()})

    def test_unapproved_registry_rejected(self):
        with tempfile.TemporaryDirectory(prefix='sunmoon-tpl-build-test-') as temporary:
            context=self.project(temporary)
            lock=context/'uv.lock'
            lock.write_text(lock.read_text().replace('https://pypi.tuna.tsinghua.edu.cn/simple','https://unapproved.invalid/simple',1))
            self.assertNotEqual(self.select(context,'official-proxy').returncode,0)

    def test_symbolic_link_rejected(self):
        with tempfile.TemporaryDirectory(prefix='sunmoon-tpl-build-test-') as temporary:
            context=self.project(temporary)
            lock=context/'uv.lock'
            content=lock.read_bytes()
            lock.unlink()
            target=Path(temporary)/'outside.lock'
            target.write_bytes(content)
            lock.symlink_to(target)
            self.assertNotEqual(self.select(context,'official-proxy').returncode,0)
            self.assertEqual(content,target.read_bytes())

    def test_non_disposable_context_rejected(self):
        with tempfile.TemporaryDirectory(prefix='not-a-build-') as temporary:
            context=self.project(temporary)
            self.assertNotEqual(self.select(context,'official-proxy').returncode,0)


if __name__=='__main__':
    unittest.main()
