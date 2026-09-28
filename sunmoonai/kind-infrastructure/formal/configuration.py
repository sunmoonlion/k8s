"""Public formal KIND configuration, no host inspection or mutations on load."""
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re

DEFAULT = Path(__file__).resolve().with_name('deploy-kind.json')
LIMIT_FLOORS = {'memory_free_gib': 16, 'docker_free_gib': 30, 'data_reserve_gib': 20,
                'initial_data_gib': 2, 'initial_node_gib': 10, 'metadata_margin_gib': 2,
                'windows_reserve_gib': 50}
TIMEOUTS = {'api_ready_seconds', 'nodes_ready_seconds', 'rollout_seconds', 'create_seconds'}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate formal configuration field: ' + key)
        result[key] = value
    return result


def load():
    path = Path(os.environ.get('SUNMOON_KIND_CONFIG') or DEFAULT)
    if not path.is_absolute() or path.resolve() != path or not path.is_file():
        raise ValueError('Formal config must be an absolute regular file without symlinks')
    data = json.loads(path.read_text(), object_pairs_hook=unique_fields)
    keys = {'schema', 'cluster', 'storage_uuid', 'materials_root', 'kubeconfig', 'kubeconfig_owner',
            'pod_cidr', 'service_cidr', 'api_port', 'port_mappings', 'limits', 'timeouts'}
    if not isinstance(data, dict) or set(data) != keys or type(data['schema']) is not int or data['schema'] != 1:
        raise ValueError('Unknown/missing formal configuration fields or schema')
    # This migration is authorized for this identity only. These are admission
    # constraints, not a second set of operational defaults.
    if (data['cluster'] != 'sunmoon-kind-main'
            or data['storage_uuid'] != 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'):
        raise ValueError('Cluster/disk identity differs from the approved migration')
    for key in ('materials_root', 'kubeconfig'):
        if not isinstance(data[key], str):
            raise ValueError('Invalid path type: ' + key)
        value = Path(data[key])
        if not value.is_absolute() or '..' in value.parts or value == Path('/') or str(value) != data[key]:
            raise ValueError('Invalid absolute path: ' + key)
    if data['materials_root'] == data['kubeconfig']:
        raise ValueError('Material and kubeconfig paths must differ')
    if not isinstance(data['kubeconfig_owner'], str) or not re.fullmatch(r'[a-z_][a-z0-9_-]*', data['kubeconfig_owner']):
        raise ValueError('Invalid kubeconfig owner')
    if any(not isinstance(data[key], str) for key in ('pod_cidr', 'service_cidr')):
        raise ValueError('Network CIDRs must be strings')
    networks = [ipaddress.ip_network(data[key], strict=True) for key in ('pod_cidr', 'service_cidr')]
    if any(net.version != 4 or not net.is_private for net in networks) or networks[0].overlaps(networks[1]):
        raise ValueError('Pod/Service networks must be separate private IPv4 networks')
    def port(value):
        return type(value) is int and 1 <= value <= 65535 and value != 30443
    if not port(data['api_port']):
        raise ValueError('Invalid API port or collision with the public registry')
    mappings = data['port_mappings']
    if not isinstance(mappings, list) or len(mappings) != 5:
        raise ValueError('Exactly five approved node port mappings required')
    expected = {30443, 30080, 30444, 30445, 30446}
    actual, hosts = set(), {data['api_port']}
    for item in mappings:
        if not isinstance(item, dict) or set(item) != {'containerPort', 'hostPort', 'listenAddress', 'protocol'}:
            raise ValueError('Invalid port mapping fields')
        node_port = item['containerPort']
        if type(node_port) is not int or node_port not in expected or node_port in actual:
            raise ValueError('Unknown/duplicate container port')
        if (not port(item['hostPort']) or item['hostPort'] in hosts or item['protocol'] != 'TCP'
                or item['listenAddress'] not in ('127.0.0.1', '0.0.0.0')
                or (node_port == 30443 and item['listenAddress'] != '127.0.0.1')):
            raise ValueError('Invalid/colliding host port or exposed TLS backend')
        actual.add(node_port)
        hosts.add(item['hostPort'])
    for group, expected_keys in (('limits', set(LIMIT_FLOORS)), ('timeouts', TIMEOUTS)):
        if not isinstance(data[group], dict) or set(data[group]) != expected_keys:
            raise ValueError('Unknown/missing fields in ' + group)
        for key, value in data[group].items():
            floor = LIMIT_FLOORS[key] if group == 'limits' else 1
            if type(value) is not int or not floor <= value <= 86400:
                raise ValueError('Invalid limit/timeout or below approved reserve: ' + key)
    return path, data


try:
    CONFIG_PATH, CONFIG = load()
except (OSError, ValueError, TypeError) as error:
    raise SystemExit('Formal configuration rejected: ' + str(error)) from None

# Timing and stricter capacity settings can change during normal operation;
# persisted cluster identity/paths/network/port mappings must not drift.
IDENTITY = {k: v for k, v in CONFIG.items() if k not in ('limits', 'timeouts')}
IDENTITY_SHA256 = digest(IDENTITY)
CONFIG_SHA256 = digest(CONFIG)
