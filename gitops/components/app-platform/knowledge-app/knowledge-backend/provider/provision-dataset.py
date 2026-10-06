"""Operator preparation through the official API; never executed by business workers."""
import json,re,sys,requests
inputs=json.load(sys.stdin)
client=requests.Session();client.trust_env=False;client.verify='/run/tls/ca.crt'
client.headers['Authorization']='Bearer '+inputs['token']
base=inputs['base'].rstrip('/')+'/api/v1'
def call(method,path,**kwargs):
    response=client.request(method,base+path,timeout=30,**kwargs)
    response.raise_for_status()
    data=response.json()
    assert data.get('code')==0, 'Provider refused operator request'
    return data
try:
    matches=[];seen=0
    for page in range(1,101):
        data=call('GET','/datasets',params={'page':page,'page_size':100,'orderby':'create_time','desc':'false'})
        rows=data['data'];total=data.get('total_datasets',data.get('total'))
        assert isinstance(rows,list) and isinstance(total,int) and not isinstance(total,bool)
        matches.extend(row for row in rows if row.get('name')==inputs['name']);seen+=len(rows)
        if seen>=total:break
        assert rows, 'Dataset enumeration truncated'
    else:raise RuntimeError('Dataset enumeration limit exceeded')
    assert len(matches)<=1, 'Ambiguous operator dataset name'
    prior=inputs['prior'];created=False
    if prior:
        assert len(matches)==1 and matches[0]['id']==prior['dataset_id'] and prior['dataset_name']==inputs['name'], 'Preserved dataset binding changed; explicit migration required'
    elif matches:
        raise RuntimeError('Unrecorded existing dataset; explicit ownership review required')
    else:
        row=call('POST','/datasets',json={'name':inputs['name'],'language':'Chinese','permission':'me','chunk_method':'naive','parser_config':{'chunk_token_num':128,'layout_recognize':'Plain Text','auto_keywords':0,'auto_questions':0,'raptor':{'use_raptor':False},'graphrag':{'use_graphrag':False}}})['data']
        matches=[row];created=True
    row=matches[0]
    assert re.fullmatch('[a-f0-9]{32}',row['id']) and row['name']==inputs['name']
    assert row['permission']=='me' and row['chunk_method']=='naive'
    print(json.dumps({'created':created,'binding':{'dataset_id':row['id'],'dataset_name':row['name']}}))
except Exception as error:
    print(json.dumps({'passed':False,'error_class':type(error).__name__}))
    sys.exit(1)
finally:client.close()
