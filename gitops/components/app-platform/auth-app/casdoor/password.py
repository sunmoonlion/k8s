"""Casdoor 4.12.0 supported login/session and self-service password API."""
from account_protocol import Transport
from account_files import require


def login(settings, password):
    client = Transport(settings['hostname'], settings['port'], settings['ca'])
    status, result = client.request('POST', '/api/login', {'application':'app-built-in','organization':'built-in','username':'admin','password':password,'type':'login'}, origin=settings['origin'])
    require(status == 200 and isinstance(result, dict), 'Casdoor login API unavailable')
    if result.get('status') != 'ok':
        return None
    status, account = client.request('GET', '/api/get-account')
    require(status == 200 and account.get('status') == 'ok' and isinstance(account.get('data'), dict), 'Casdoor session was not established')
    user = account['data']
    # v4.12.0 object.User.IsGlobalAdmin() derives this from Owner == built-in.
    # It is a method, not a JSON isGlobalAdmin property.
    require(user.get('owner') == 'built-in' and user.get('name') == 'admin' and user.get('isAdmin') is True and user.get('isForbidden') is False and user.get('isDeleted') is False,
            'Casdoor account identity or global administrator privileges differ')
    return client


def inspect(settings, password):
    return {'owner':'built-in','username':'admin','administrator':True,'global_administrator':True} if login(settings,password) else None


def change(settings, old, new):
    client = login(settings, old)
    require(client is not None, 'Casdoor current credential was rejected')
    status, result = client.request('POST', '/api/set-password', {'userOwner':'built-in','userName':'admin','oldPassword':old,'newPassword':new}, form=True, origin=settings['origin'])
    require(status == 200 and result.get('status') == 'ok', 'Casdoor rejected the password change; API write is never blindly retried')


# This component stages its own initializer Secret. Flux remains the only live
# Secret writer; password changes never mutate completed initialization Jobs.
def _source_file(account, operation, name):
    from pathlib import Path
    from account_transaction import receipt_path
    return str(Path(receipt_path(account, operation)).parent / name)


def _run(argv, settings, data=None):
    import os, subprocess
    env = dict(os.environ, SOPS_AGE_KEY_FILE=settings['age_key'], HOME='/nonexistent', XDG_CONFIG_HOME='/nonexistent')
    if argv[0] == settings['kubectl']:
        import tempfile
        with tempfile.TemporaryDirectory(prefix='sunmoon-account-release-kube-') as temporary:
            env['HOME'] = temporary
            result = subprocess.run(argv+['--cache-dir='+temporary+'/cache'], input=data, text=True, capture_output=True, env=env, timeout=60)
    else:
        result = subprocess.run(argv, input=data, text=True, capture_output=True, env=env, timeout=60)
    require(result.returncode == 0, 'Casdoor account release command failed')
    return result.stdout


def _plaintext(ciphertext, settings):
    import json
    value = json.loads(_run([settings['sops'],'decrypt','--input-type','yaml','--output-type','json','/dev/stdin'],settings,ciphertext))
    value.pop('sops', None)
    return value


def _desired(manifest, current, target):
    import copy, json
    from account_files import require
    desired = copy.deepcopy(manifest)
    require(desired.get('kind') == 'Secret' and desired.get('metadata', {}).get('name') == 'casdoor-initial-identity', 'Unexpected Casdoor identity Secret')
    users = json.loads(desired['stringData']['init_data.json'])
    require(len(users.get('users', [])) == 1 and users['users'][0].get('owner') == 'built-in' and users['users'][0].get('name') == 'admin', 'Unexpected initializer account scope')
    require(users['users'][0]['password'] == current, 'Initializer Secret and current private account differ')
    users['users'][0]['password'] = target
    desired['stringData']['init_data.json'] = json.dumps(users)
    return desired


def _kube(settings, *args):
    return [settings['kubectl'], '--kubeconfig='+settings['kubeconfig'], '--context='+settings['context'], '--request-timeout=20s', *args]


def stage(settings, account, operation):
    import json, os, tempfile, yaml
    from pathlib import Path
    from account_files import extract, read_private, validate_password, write_private
    old = extract(read_private(account['current_file']),account['current_field'])
    target = validate_password(read_private(account['initial_file']),account)
    require(read_private(account['initial_backup_file']) == target and old != target, 'An independent, different target preset is required')
    lock_text = Path(settings['source_lock']).read_text()
    lock = yaml.safe_load(lock_text)
    live = json.loads(_run(_kube(settings,'-n','flux-system','get','ocirepository','platform','-o','json'),settings))
    require(live['spec']['ref']['digest'] == lock['digest'], 'Promoted source is not the live source; complete that deployment before account staging')
    before = _source_file(account,operation,'source-before.yaml')
    saved = read_private(before)
    require(saved is None or saved == lock_text, 'This operation already captured a different rollback source')
    ciphertext = _run(['git','-C',settings['repo'],'show',lock['revision']+':'+settings['manifest']],settings)
    prior = _plaintext(ciphertext,settings)
    desired = _desired(prior,old,target)
    destination = Path(settings['repo'])/settings['manifest']
    require(destination.is_file() and not destination.is_symlink(), 'Identity candidate is missing or redirected')
    actual = _plaintext(destination.read_text(),settings)
    require(actual in [prior,desired], 'Unreviewed Casdoor identity changes are present')
    if saved is None:
        write_private(before,lock_text)
    if actual != desired:
        recipient=Path(settings['recipient']).read_text().strip()
        encrypted = _run([settings['sops'],'encrypt','--age',recipient,'--encrypted-regex','^(data|stringData)$','--input-type','json','--output-type','yaml','/dev/stdin'],settings,json.dumps(desired))
        require(_plaintext(encrypted,settings) == desired,'Encrypted candidate recovery differs')
        info=destination.stat()
        fd, temporary=tempfile.mkstemp(prefix='.account-stage-',dir=destination.parent)
        try:
            with os.fdopen(fd,'w') as stream:
                stream.write(encrypted);stream.flush();os.fsync(stream.fileno())
            os.chmod(temporary,info.st_mode & 0o777);os.chown(temporary,info.st_uid,info.st_gid)
            os.replace(temporary,destination)
        finally:
            if os.path.exists(temporary):os.unlink(temporary)
    return {'object':account['object'],'staged_secret':settings['manifest'],'runtime_changed':False,'source_backup':before}


def validate_candidate(settings, account, operation):
    import json, yaml
    from pathlib import Path
    from account_files import extract, read_private, validate_password, write_private
    previous_text=read_private(_source_file(account,operation,'source-before.yaml'))
    require(previous_text is not None,'Stage the account candidate before rotating')
    before=yaml.safe_load(previous_text)
    require(isinstance(before,dict),'Stage the account candidate before rotating')
    lock_text=Path(settings['source_lock']).read_text(); candidate=yaml.safe_load(lock_text)
    require(candidate['repository'] == before['repository'] and candidate['path'] == before['path'] and candidate['digest'] != before['digest'], 'Promote the reviewed immutable account candidate before rotation')
    publication=yaml.safe_load(Path(settings['publication']).read_text())
    require(publication == candidate,'Promoted source differs from the native immutable publisher receipt')
    require(candidate['revision'] != before['revision'], 'Account candidate must have a distinct committed revision')
    require(_run(['git','-C',settings['repo'],'status','--porcelain','--untracked-files=all','--','gitops'],settings).strip() == '', 'Commit all declaration changes before rotation')
    changed=_run(['git','-C',settings['repo'],'diff','--name-only',before['revision'],candidate['revision'],'--','gitops'],settings).splitlines()
    require(changed == [settings['manifest']], 'Account release must change only the selected identity Secret; publish topology changes separately')
    live=json.loads(_run(_kube(settings,'-n','flux-system','get','ocirepository','platform','-o','json'),settings))
    require(live['spec']['ref']['digest'] == before['digest'], 'Live source changed after account candidate preparation')
    jobs=json.loads(_run(_kube(settings,'-n',settings['namespace'],'get','jobs','-o','json'),settings))
    active=[j for j in jobs['items'] if j.get('status',{}).get('active',0) and any(v.get('secret',{}).get('secretName')=='casdoor-initial-identity' for v in j['spec']['template']['spec'].get('volumes',[]))]
    require(not active,'A dependent identity initializer is active; wait for it before rotating')
    current=extract(read_private(account['current_file']),account['current_field'])
    target=validate_password(read_private(account['initial_file']),account)
    prior=_plaintext(_run(['git','-C',settings['repo'],'show',before['revision']+':'+settings['manifest']],settings),settings)
    desired=_desired(prior,current,target)
    published=_plaintext(_run(['git','-C',settings['repo'],'show',candidate['revision']+':'+settings['manifest']],settings),settings)
    require(published == desired,'Committed encrypted account candidate differs from the private preset')
    after=_source_file(account,operation,'source-after.yaml')
    existing=read_private(after)
    require(existing is None or existing == lock_text, 'This operation captured another target source')
    if existing is None:write_private(after,lock_text)
    return {'source_before':_source_file(account,operation,'source-before.yaml'),'source_after':after,'candidate_digest':candidate['digest']}


def verify_runtime(settings, account):
    import base64,json
    from account_files import extract,read_private
    result=json.loads(_run(_kube(settings,'-n',settings['namespace'],'get','secret','casdoor-initial-identity','-o','json'),settings))
    users=json.loads(base64.b64decode(result['data']['init_data.json']))
    require(len(users['users'])==1 and users['users'][0]['owner']=='built-in' and users['users'][0]['name']=='admin' and users['users'][0]['password']==extract(read_private(account['current_file']),account['current_field']), 'Live Flux identity Secret is not synchronized with the current credential')
    return {'live_secret_matches':True}
