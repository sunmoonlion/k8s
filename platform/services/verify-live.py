#!/usr/bin/env python3
"""Bounded live acceptance: RabbitMQ publish/consume and Casdoor TLS/login.
No deployment orchestration or credential output. Only this run's queue is removed.
"""
import argparse
import base64
import http.client
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import tempfile
import time
import sys
import uuid


class AcceptanceError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise AcceptanceError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kubectl', required=True)
    parser.add_argument('--kubeconfig', required=True)
    parser.add_argument('--ca', required=True)
    parser.add_argument('--skip-rabbitmq', action='store_true')
    parser.add_argument('--skip-casdoor', action='store_true')
    args = parser.parse_args()
    require(os.geteuid() == 0, 'Private input access requires root')
    credentials = json.load(sys.stdin)['service_credentials']
    prefix = [args.kubectl, '--kubeconfig=' + args.kubeconfig, '--context=kind-sunmoon-kind', '-n', 'platform-system']
    environment = dict(os.environ)
    for key in ('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'):
        environment.pop(key, None)
    environment['NO_PROXY'] = '*'
    if not args.skip_rabbitmq:
        queue = 'sunmoon-acceptance-' + uuid.uuid4().hex
        tunnel = subprocess.Popen(prefix + ['port-forward', '--address=127.0.0.1', 'service/rabbitmq', '0:15672'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=environment)
        port = None
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(tunnel.stdout, selectors.EVENT_READ)
                deadline = time.monotonic() + 15
                while time.monotonic() < deadline:
                    if tunnel.poll() is not None:
                        break
                    if not selector.select(timeout=0.5):
                        continue
                    line = tunnel.stdout.readline()
                    match = re.search(r'Forwarding from 127\.0\.0\.1:(\d+)', line)
                    if match:
                        port = int(match.group(1))
                        break
            require(port is not None, 'RabbitMQ private tunnel did not become ready')
            authentication = base64.b64encode((credentials['rabbitmq_username'] + ':' + credentials['rabbitmq_password']).encode()).decode()

            def request(method, path, body=None):
                connection = http.client.HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    connection.request(method, path, None if body is None else json.dumps(body), {'Authorization': 'Basic ' + authentication, 'Content-Type':'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    require(200 <= response.status < 300, 'RabbitMQ acceptance HTTP status ' + str(response.status) + ' during ' + method + ' ' + path)
                    return json.loads(data) if data else None
                finally:
                    connection.close()

            created = False
            try:
                request('PUT', '/api/queues/%2F/' + queue, {'durable':True,'auto_delete':False,'arguments':{'x-queue-type':'classic','x-expires':60000}})
                created = True
                result = request('POST','/api/exchanges/%2F/amq.default/publish', {'properties':{},'routing_key':queue,'payload':'sunmoon-verified','payload_encoding':'string'})
                require(result.get('routed') is True, 'RabbitMQ publish was not routed')
                result = request('POST','/api/queues/%2F/' + queue + '/get', {'count':1,'ackmode':'ack_requeue_false','encoding':'auto','truncate':256})
                require(len(result) == 1 and result[0]['payload'] == 'sunmoon-verified', 'RabbitMQ message roundtrip mismatch')
            finally:
                if created:
                    request('DELETE','/api/queues/%2F/' + queue)
        finally:
            tunnel.terminate()
            try:
                tunnel.wait(timeout=5)
            except subprocess.TimeoutExpired:
                tunnel.kill()
                tunnel.wait()
    if not args.skip_casdoor:
        with tempfile.TemporaryDirectory(prefix='sunmoon-identity-') as temporary:
            cookies = str(Path(temporary)/'cookies')
            origin = 'https://casdoor.sunmoonai.com:30443'
            base = ['curl','--silent','--show-error','--fail','--max-time','30','--noproxy','*','--cacert',args.ca,'--connect-to','casdoor.sunmoonai.com:30443:127.0.0.1:29443']
            payload = {'application':'app-built-in','organization':'built-in','username':'admin','password':credentials['casdoor_admin_password'],'type':'login'}
            result = subprocess.run(base + ['--cookie-jar',cookies,'--header','Content-Type: application/json','--header','Origin: '+origin,'--data-binary','@-',origin+'/api/login'], input=json.dumps(payload), capture_output=True, text=True, env=environment, timeout=35)
            require(result.returncode == 0, 'Casdoor trusted TLS/login request failed')
            login = json.loads(result.stdout)
            require(login.get('status') == 'ok', 'Casdoor administrator authentication rejected')
            result = subprocess.run(base + ['--cookie',cookies,origin+'/api/get-account'], capture_output=True, text=True, env=environment, timeout=35)
            require(result.returncode == 0, 'Casdoor authenticated session request failed')
            account = json.loads(result.stdout)
            require(account.get('status') == 'ok' and isinstance(account.get('data'),dict), 'Casdoor session did not return an account')
            require(account['data'].get('name') == 'admin' and account['data'].get('owner') == 'built-in', 'Casdoor session account mismatch')
    print(json.dumps({'rabbitmq_publish_consume':'skipped' if args.skip_rabbitmq else True,'casdoor_tls_chain':'skipped' if args.skip_casdoor else True,'casdoor_admin_login':'skipped' if args.skip_casdoor else True,'casdoor_session':'skipped' if args.skip_casdoor else True,'application_entry_changed':False}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Protocol responses and exception details can contain sensitive fields.
        print(json.dumps({'verified':False,'error_type':type(error).__name__, 'reason':str(error) if isinstance(error, AcceptanceError) else 'See private execution phase'}))
        raise SystemExit(1)
