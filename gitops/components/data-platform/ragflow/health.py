"""Small stdlib-only checks; HTTP protocol encoding stays in the HTTP library."""
import http.client,json,socket,ssl,sys,time
from pathlib import Path
if sys.argv[1]=='api':
    connection=http.client.HTTPConnection('127.0.0.1',9380,timeout=5)
    try:
        connection.connect()
        context=ssl.create_default_context(cafile='/run/tls/ca.crt')
        connection.sock=context.wrap_socket(connection.sock,server_hostname='ragflow')
        connection.request('GET','/sunmoon/ready')
        response=connection.getresponse()
        assert response.status==200 and json.loads(response.read())=={'ready':True}
    finally:
        connection.close()
elif sys.argv[1]=='worker':
    assert time.time()-Path('/tmp/worker-ready').stat().st_mtime < 60
else:
    raise SystemExit('Expected api or worker check')
