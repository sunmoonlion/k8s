#!/usr/bin/env python3
"""Read-only Harbor 2.x catalog inventory using existing local Docker auth."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import ssl
import tempfile
import time
import urllib.error
import urllib.parse as url
import urllib.request as http


class NoRedirect(http.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Refusing credential-bearing redirect')


class Catalog:
    def __init__(self, host):
        if '/' in host or '@' in host or not host:
            raise ValueError('Expected registry host[:port]')
        config = json.loads((Path.home() / '.docker/config.json').read_text())
        self.auth = config.get('auths', {}).get(host, {}).get('auth')
        if not self.auth:
            raise RuntimeError('Missing local Docker basic credential; no credential changes made')
        self.base = 'https://' + host + '/api/v2.0'
        self.client = http.build_opener(http.ProxyHandler({}), NoRedirect(),
                                       http.HTTPSHandler(context=ssl.create_default_context()))
        self.calls = 0
        self.deadline = time.monotonic() + 900

    def get(self, path, params=None):
        for attempt in range(3):
            if time.monotonic() > self.deadline or self.calls >= 5000:
                raise RuntimeError('Inventory request budget exhausted')
            self.calls += 1
            req = http.Request(self.base + path + ('?' + url.urlencode(params) if params else ''),
                               headers={'Authorization': 'Basic ' + self.auth}, method='GET')
            try:
                with self.client.open(req, timeout=20) as response:
                    return json.load(response), response.headers
            except urllib.error.HTTPError as exc:
                if exc.code not in (429, 502, 503, 504) or attempt == 2:
                    raise RuntimeError(f'Harbor GET failed with HTTP {exc.code}') from None
            except (urllib.error.URLError, TimeoutError):
                if attempt == 2:
                    raise RuntimeError('Harbor GET connection failed') from None
            time.sleep(attempt + 1)

    def pages(self, path, params=None):
        items, total = [], None
        for page in range(1, 1001):
            data, headers = self.get(path, {**(params or {}), 'page': page, 'page_size': 100})
            if not isinstance(data, list) or headers.get('X-Total-Count') is None:
                raise RuntimeError('Missing pagination total; cannot claim full coverage')
            current = int(headers['X-Total-Count'])
            if current < 0 or (total is not None and current != total):
                raise RuntimeError('Catalog count changed during pagination; repeat inventory')
            total = current
            items.extend(data)
            if len(items) == total:
                return items
            if not data or len(items) > total:
                raise RuntimeError('Pagination count mismatch')
        raise RuntimeError('Pagination budget exhausted')

    def collect(self):
        user, _ = self.get('/users/current')
        if user.get('sysadmin_flag') is not True:
            raise RuntimeError('Full catalog requires existing system administrator visibility')
        result = {'schema': 1, 'started_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                  'registry': self.base, 'access': 'system-admin GET only',
                  'consistency': 'live inventory, not a write-frozen backup', 'projects': []}
        for project in self.pages('/projects'):
            project_name = project['name']
            pp = '/projects/' + url.quote(project_name, safe='')
            repos = self.pages(pp + '/repositories')
            if len(repos) != project['repo_count']:
                raise RuntimeError('Project repository count changed')
            p = {'name': project_name, 'repositories': []}
            result['projects'].append(p)
            for repo in repos:
                name = repo['name'].removeprefix(project_name + '/')
                # Harbor requires double escaping for nested repository paths.
                rp = pp + '/repositories/' + url.quote(url.quote(name, safe=''), safe='')
                artifacts = self.pages(rp + '/artifacts', {'with_tag': 'true', 'with_accessory': 'true'})
                if len(artifacts) != repo['artifact_count']:
                    raise RuntimeError('Repository artifact count changed')
                row = {'name': repo['name'], 'declared_artifact_count': repo['artifact_count'],
                       'listed_digests': sorted(a['digest'] for a in artifacts), 'artifacts': []}
                known = {a['digest'] for a in artifacts}
                for a in artifacts:
                    ap = rp + '/artifacts/' + url.quote(a['digest'], safe='')
                    tags = self.pages(ap + '/tags')
                    accessories = self.pages(ap + '/accessories')
                    children = [v['child_digest'] for v in (a.get('references') or [])]
                    children += [v['digest'] for v in accessories]
                    for child in children:
                        if child not in known:
                            detail, _ = self.get(rp + '/artifacts/' + url.quote(child, safe=''),
                                                 {'with_tag': 'true', 'with_accessory': 'true'})
                            if detail.get('digest') != child:
                                raise RuntimeError('Referenced artifact digest mismatch')
                            known.add(child)
                            artifacts.append(detail)
                    row['artifacts'].append({
                        **{k: a.get(k) for k in ['digest', 'type', 'size', 'media_type', 'manifest_media_type', 'references']},
                        'tags': sorted(t['name'] for t in tags),
                        'accessories': [{k: v.get(k) for k in ['digest', 'type', 'subject_artifact_digest']} for v in accessories]})
                if len({a['digest'] for a in row['artifacts']}) != len(row['artifacts']):
                    raise RuntimeError('Duplicate artifacts across pages')
                p['repositories'].append(row)
            print('Catalogued project', project_name, 'repositories', len(repos), flush=True)
        result['completed_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        result['requests'] = self.calls
        repos = [r for p in result['projects'] for r in p['repositories']]
        arts = [a for r in repos for a in r['artifacts']]
        result['summary'] = {'projects': len(result['projects']), 'repositories': len(repos),
                             'listed_artifacts': sum(len(r['listed_digests']) for r in repos),
                             'reachable_artifacts': len(arts), 'tags': sum(len(a['tags']) for a in arts),
                             'untagged': sum(not a['tags'] for a in arts),
                             'indexes': sum(bool(a['references']) for a in arts),
                             'accessories': sum(len(a['accessories']) for a in arts)}
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='harbor.sunmoonai.com:30443')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise RuntimeError('Choose a new output file to retain previous evidence')
    result = Catalog(args.host).collect()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=args.output.parent)
    with os.fdopen(fd, 'w') as stream:
        json.dump(result, stream, indent=2, ensure_ascii=False)
        stream.write('\n')
    os.rename(temporary, args.output)
    print(json.dumps(result['summary']))


if __name__ == '__main__':
    main()
