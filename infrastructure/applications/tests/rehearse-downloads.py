#!/usr/bin/env python3
"""Exercise the real Ansible/Docker fallback with disposable dependency builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import uuid

import yaml

INFRA = Path(__file__).resolve().parents[2]
APP = INFRA / 'applications'


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['domestic', 'fallback', 'proxy-unset', 'proxy-down', 'exhausted', 'compile', 'integrity', 'python-fallback'])
    opts, config_args = parser.parse_known_args()
    cases = [opts.case] if opts.case else ['domestic', 'fallback', 'proxy-unset', 'proxy-down', 'exhausted', 'compile', 'integrity', 'python-fallback']
    run_id = uuid.uuid4().hex[:12]
    output = INFRA / '.build/applications' / ('rehearsal-' + run_id)
    output.mkdir(mode=0o700)
    profiles = json.loads((APP / 'download-modes.json').read_text())
    config_before = hashlib.sha256((APP / 'config.yaml').read_bytes()).hexdigest()
    images = {x['id']:x for x in json.loads((INFRA / 'artifacts/upstream-images.lock.json').read_text())['images']}
    base = 'harbor.sunmoonai.com:30443/platform/node-build@' + images['node-build']['manifest_digest']
    # Reserve an unused port without listening: connection attempts must fail.
    with socket.socket() as unavailable:
        unavailable.bind(('127.0.0.1', 0))
        dead = 'http://127.0.0.1:' + str(unavailable.getsockname()[1])
        summary = []
        for case in cases:
            case_dir = output / case
            case_dir.mkdir(mode=0o700)
            with tempfile.TemporaryDirectory(prefix='sunmoon-tpl-build-rehearsal-') as temporary:
                staging = Path(temporary)
                context = staging / 'context'
                context.mkdir()
                source_modes = json.loads(json.dumps(profiles))
                if case != 'domestic':
                    source_modes['domestic']['npm_registry'] = dead
                command = 'corepack install --global pnpm@10.24.0 && corepack pnpm --version'
                if case == 'exhausted':
                    command = 'COREPACK_NPM_REGISTRY=' + dead + ' ' + command
                elif case == 'compile':
                    command = "echo 'Injected compile error' >&2; exit 23"
                elif case == 'integrity':
                    command = "echo 'ERR_PNPM_TARBALL_INTEGRITY: injected checksum rejection' >&2; exit 1"
                recipe = ('FROM ' + base + ' AS rehearsal\n'
                          'ARG NPM_CONFIG_REGISTRY\n'
                          'ENV COREPACK_NPM_REGISTRY=${NPM_CONFIG_REGISTRY}\n'
                          'ARG REHEARSAL_ID=' + run_id + '-' + case + '\n'
                          'RUN echo "$REHEARSAL_ID" >/tmp/rehearsal-id && ' + command + '\n')
                if case == 'python-fallback':
                    source = INFRA.parent.parent / 'tpl-app/tpl-backend/app'
                    for name in ['pyproject.toml','uv.lock']:
                        (context/name).write_bytes((source/name).read_bytes())
                    recipe = ('FROM harbor.sunmoonai.com:30443/platform/python@' + images['python']['manifest_digest'] + ' AS rehearsal\n'
                              'ARG PYPI_INDEX_URL\n'
                              'ENV PIP_INDEX_URL=${PYPI_INDEX_URL} UV_DEFAULT_INDEX=${PYPI_INDEX_URL} UV_LINK_MODE=copy\n'
                              'WORKDIR /app\nCOPY pyproject.toml uv.lock ./\n'
                              'ARG REHEARSAL_ID=' + run_id + '\n'
                              'RUN selected="$PYPI_INDEX_URL"; if [ "$selected" = "' + profiles['domestic']['python_index'] + '" ]; then selected="' + dead + '"; fi; '
                              'PIP_INDEX_URL="$selected" pip install --retries 1 --timeout 5 uv==0.11.32\n'
                              'RUN uv sync --frozen --no-dev --no-install-project && .venv/bin/python -c "import fastapi; print(fastapi.__version__)"\n')
                (context / 'Dockerfile').write_text(recipe)
                variables = {
                    'application_directory': str(APP), 'build_component': 'backend' if case == 'python-fallback' else 'admin',
                    'application_download_mode': 'domestic', 'effective_download_mode': 'domestic',
                    'download_modes': source_modes,
                    'download_profile': '{{ download_modes[effective_download_mode] }}',
                    'capacity_operation': 'application-download-rehearsal',
                    'component': {'repository': 'network-rehearsal-' + run_id + '-' + case,
                                  'context': '', 'dockerfile': 'Dockerfile', 'target': 'rehearsal',
                                  'args': [], 'budget': 8388608},
                    'component_revision': hashlib.sha1(recipe.encode()).hexdigest(),
                    'source_lock': {'parent_revision': subprocess.check_output(['git','rev-parse','HEAD'],cwd=INFRA,text=True).strip()},
                    'parent_gitlink_revision': '0' * 40,
                    'recipe': {'stdout': recipe}, 'staging': {'path': temporary},
                    'build_root': str(case_dir),
                }
                play = [{'name': 'Isolated real download fallback rehearsal', 'hosts': 'kind_hosts',
                         'gather_facts': False, 'become': True, 'vars': variables,
                         'tasks': [
                             {'name':'Budget the small isolated rehearsal', 'ansible.builtin.include_tasks':
                              {'file':str(INFRA / 'host/tasks/capacity.yaml'), 'apply':{'become':False}},
                              'vars':{'capacity_planned_bytes':536870912}},
                             {'name':'Prepare private auth directory','ansible.builtin.file':{'path':temporary+'/auth','state':'directory','mode':'0700'}},
                             {'name':'Supply read-only Harbor credentials','ansible.builtin.copy':
                              {'src':'{{ registry_config_dir }}/private/puller-auth.json','dest':temporary+'/auth/config.json','remote_src':True,'mode':'0600'},'no_log':True},
                             {'name':'Exercise production network orchestration',
                              'block':[{'ansible.builtin.include_tasks':str(APP / 'build-network.yaml')}],
                              'always':[{'name':'Record nonsecret outcome', 'ansible.builtin.copy':
                                         {'dest':str(case_dir/'outcome.json'),'mode':'0600',
                                          'content':'{{ {"mode":effective_download_mode,"local_tag":local_tag | default(""),"build_rc":image_build.rc | default(-1),"python_sources":build_input.python_sources | default({}),"probe_rc":proxy_probe.rc | default(-1),"probe_command":proxy_probe.cmd | default([]),"probe_error":proxy_probe.stderr | default("")} | to_json }}'}}]},
                         ]}]
                playbook = staging / 'rehearse.yaml'
                playbook.write_text(yaml.safe_dump(play,sort_keys=False))
                env = os.environ.copy()
                if case == 'proxy-unset':
                    for name in ['HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy','ALL_PROXY','all_proxy']:
                        env.pop(name,None)
                elif case == 'proxy-down':
                    env['HTTPS_PROXY'] = dead
                log = case_dir / 'ansible.log'
                try:
                    with log.open('w') as stream:
                        os.chmod(log,0o600)
                        result = subprocess.run([str(INFRA/'.venv/bin/ansible-playbook'),'-i','host/inventory.yaml',str(playbook),*config_args],cwd=INFRA,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
                    text = log.read_text()
                    subprocess.run(['sudo','-n','chown',str(os.getuid())+':'+str(os.getgid()),str(case_dir/'outcome.json')],check=True)
                    outcome = json.loads((case_dir/'outcome.json').read_text()) if (case_dir/'outcome.json').exists() else {}
                    attempts = text.count('TASK [Build using the committed recipe and locked base images]')
                    expected_attempts = 2 if case in ['fallback','exhausted','python-fallback'] else 1
                    expected_success = case in ['domestic','fallback','python-fallback']
                    success = (result.returncode == 0) == expected_success and attempts == expected_attempts
                    success = success and outcome.get('mode') == ('domestic' if case in ['domestic','compile','integrity'] else 'official-proxy')
                    if expected_success:
                        success = success and outcome.get('build_rc') == 0
                    record = {'case':case,'passed':success,'ansible_rc':result.returncode,'attempts':attempts,'outcome':outcome}
                    summary.append(record)
                    (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
                    print(json.dumps({**record, 'outcome':{k:v for k,v in outcome.items() if k not in ['probe_error','probe_command']}}),flush=True)
                    if not success:
                        raise RuntimeError('Rehearsal failed; inspect private log: '+str(log))
                finally:
                    # Remove only tags created by this fixture; never prune containers/volumes/cache.
                    for mode_log in case_dir.glob('*-build-*.log'):
                        subprocess.run(['sudo','-n','chown',str(os.getuid())+':'+str(os.getgid()),str(mode_log)],check=True)
                    fixture_tags = subprocess.check_output(['docker','image','ls','--format','{{.Repository}}:{{.Tag}}','--filter','reference=sunmoon-build/network-rehearsal-'+run_id+'-'+case+':*'],text=True).splitlines()
                    for tag in fixture_tags:
                        subprocess.run(['docker','image','rm',tag],check=True,stdout=subprocess.DEVNULL)
                    subprocess.run(['sudo','-n','rm','-rf','--',temporary+'/auth'],check=True)
            (output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        if hashlib.sha256((APP/'config.yaml').read_bytes()).hexdigest()!=config_before:
            raise RuntimeError('Default configuration changed')
    print(json.dumps({'result':'passed','cases':len(summary),'evidence':str(output)}),flush=True)


if __name__ == '__main__':
    run()
