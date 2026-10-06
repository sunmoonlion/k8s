"""Change only the owned Kibana reader through Elasticsearch's password API."""
import contextlib
import importlib.util
import tempfile
from pathlib import Path
from urllib.parse import quote
from account_protocol import Transport
from account_files import extract,read_private,require


@contextlib.contextmanager
def session(settings):
    source=Path(__file__).resolve().parents[2]/'verify.py'
    spec=importlib.util.spec_from_file_location('elk_protocol',source)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    kube=[settings['kubectl'],'--kubeconfig='+settings['kubeconfig'],'--context='+settings['context'],'--request-timeout=20s','-n',settings['namespace']]
    with tempfile.TemporaryDirectory(prefix='sunmoon-account-kube-') as temporary:
        env={'PATH':'/usr/bin:/bin','NO_PROXY':'*','HOME':temporary}
        with module.forward(kube+['--cache-dir='+temporary+'/cache'],'elasticsearch',9200,env) as port:
            yield dict(settings,port=port)


def client(settings):
    return Transport(settings['hostname'],settings['port'],settings['ca'])


def administrator(settings):
    return ('elastic',extract(read_private(settings['admin_file']),'elastic_password'))


def owned_user(settings):
    c = client(settings); username = settings['username']
    status, users = c.request('GET','/_security/user/'+quote(username,safe=''),credentials=administrator(settings))
    user=users.get(username) if isinstance(users,dict) else None
    require(status==200 and user and user.get('enabled') and user.get('roles')==[username] and user.get('metadata',{}).get('sunmoon_owner')==settings['owner'], 'Kibana reader is disabled, foreign, or has different permissions')
    return user


def inspect(settings,password):
    owned_user(settings)
    status,user=client(settings).request('GET','/_security/_authenticate',credentials=(settings['username'],password))
    if status==401:return None
    require(status==200 and user.get('username')==settings['username'] and user.get('roles')==[settings['username']], 'Kibana reader authentication identity differs')
    return {'username':settings['username'],'roles':[settings['username']],'owner':settings['owner']}


def change(settings,old,new):
    owned_user(settings)
    status,result=client(settings).request('POST','/_security/user/'+quote(settings['username'],safe='')+'/_password',{'password':new},credentials=administrator(settings))
    require(status==200, 'Elasticsearch rejected the reader password change; API write is never blindly retried')
