#!/usr/bin/env python3
"""Serialize trusted env values into data, not executable JavaScript text."""
import json
import os
import sys
from urllib.parse import quote

e = os.environ
q = lambda s:quote(s,safe='')
authdb=e.get('MONGO_AUTH_DB','admin')
host=e['DB_HOST']+':'+e['DB_PORT']
tls='&tls=true' if e.get('DB_TLS_ENABLED','false').lower() in ('1','true','yes','on') else ''
uri=e.get('MONGO_ADMIN_URI') or ('mongodb://'+q(e['MONGO_ADMIN_USER'])+':'+q(e['MONGO_ADMIN_PASSWORD'])+'@'+host+'/'+q(authdb)+'?authSource='+q(authdb)+tls)
if sys.argv[1:] == ['--uri']:
    print('mongodb://'+q(e['APP_DB_USER'])+':'+q(e['APP_DB_PASSWORD'])+'@'+host+'/'+q(e['APP_DB_NAME'])+'?authSource='+q(e['APP_DB_NAME'])+tls)
else:
    data={k:e.get(k,'') for k in ('APP_DB_NAME','APP_DB_USER','APP_DB_PASSWORD','ACTION','DEPROVISION_DROP_DATABASE')}
    data['uri']=uri
    print('const c = '+json.dumps(data)+';')
    print('''try {
 const app = connect(c.uri).getSiblingDB(c.APP_DB_NAME);
 const exists = app.getUser(c.APP_DB_USER);
 if (c.ACTION === 'deprovision') {
   if (exists) app.dropUser(c.APP_DB_USER);
   if (['true','1'].includes(c.DEPROVISION_DROP_DATABASE)) app.dropDatabase();
 } else {
   const spec = {pwd:c.APP_DB_PASSWORD,roles:[{role:'readWrite',db:c.APP_DB_NAME},{role:'dbAdmin',db:c.APP_DB_NAME}]};
   if (exists) app.updateUser(c.APP_DB_USER,spec);
   else app.createUser({user:c.APP_DB_USER,...spec});
   if (!app.getCollectionNames().includes('_init_marker')) app.createCollection('_init_marker');
 }
 quit(0);
} catch(e) { print('Database operation failed; credential-bearing error withheld'); quit(1); }
''')
