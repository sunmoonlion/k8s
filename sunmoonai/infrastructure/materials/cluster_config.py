"""Pure kubeadm v1beta4/Calico configuration rendering; no cluster operations.

Cloud 未经实机验证. Single control plane, IPv4, iptables and Calico VXLAN are
explicit supported inputs, matching the present one-master/two-worker design.
"""
import ipaddress
import json
import re
from bundle import below, sha256


def validate(profile):
    if not re.fullmatch(r'c[0-9]+', profile['cluster']):
        raise ValueError('Explicit cloud cluster name cN required')
    pod = ipaddress.IPv4Network(profile['pod_cidr'], strict=True)
    service = ipaddress.IPv4Network(profile['service_cidr'], strict=True)
    if pod.overlaps(service) or not 8 <= pod.prefixlen <= 24 or not 8 <= service.prefixlen <= 24:
        raise ValueError('Invalid/overlapping pod and service CIDRs')
    nodes = profile['nodes']
    if sum(n['role'] == 'master' for n in nodes) != 1 or any(n['role'] not in ('master', 'worker') for n in nodes):
        raise ValueError('This adapter requires exactly one master; HA needs a separate validated profile')
    names, addresses = set(), set()
    for n in nodes:
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?', n['name']):
            raise ValueError('Invalid Kubernetes node name')
        ip = ipaddress.IPv4Address(n['ip'])
        if ip.is_loopback or ip.is_unspecified or ip.is_multicast or ip in pod or ip in service:
            raise ValueError('Node IP conflicts with cluster networks')
        names.add(n['name']); addresses.add(n['ip'])
    if len(names) != len(nodes) or len(addresses) != len(nodes):
        raise ValueError('Duplicate node identity/address')
    endpoint = profile['endpoint']
    host, port = endpoint.rsplit(':', 1)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', host) or not port.isdigit() or not 1 <= int(port) <= 65535:
        raise ValueError('Explicit API host:port required')
    if profile['proxy_mode'] != 'iptables':
        raise ValueError('Unified validated profile uses iptables kube-proxy')
    if any(not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', s) for s in profile.get('api_sans', [])):
        raise ValueError('Unsupported API certificate SAN')
    return profile


def registration(node):
    return {'name': node['name'], 'criSocket': 'unix:///run/containerd/containerd.sock',
            'imagePullPolicy': 'Never', 'imagePullSerial': True,
            'kubeletExtraArgs': [{'name': 'node-ip', 'value': node['ip']}]}


def init_documents(profile, data):
    validate(profile)
    master = next(n for n in profile['nodes'] if n['role'] == 'master')
    tags = {s.rsplit('/', 1)[1].split(':', 1)[0]: s.rsplit(':', 1)[1] for s in data['kubeadm_images']}
    return [
        {'apiVersion': 'kubeadm.k8s.io/v1beta4', 'kind': 'InitConfiguration',
         'bootstrapTokens': [], 'localAPIEndpoint': {'advertiseAddress': master['ip'], 'bindPort': 6443},
         'patches': {'directory': '/var/lib/sunmoon/clusters/' + profile['cluster'] + '/patches'},
         'nodeRegistration': registration(master)},
        {'apiVersion': 'kubeadm.k8s.io/v1beta4', 'kind': 'ClusterConfiguration',
         'clusterName': 'sunmoon-' + profile['cluster'], 'kubernetesVersion': 'v' + data['versions']['kubernetes'],
         'controlPlaneEndpoint': profile['endpoint'], 'imageRepository': 'registry.k8s.io',
         'networking': {'podSubnet': profile['pod_cidr'], 'serviceSubnet': profile['service_cidr'], 'dnsDomain': 'cluster.local'},
         'apiServer': {'certSANs': sorted({n['ip'] for n in profile['nodes']} | {profile['endpoint'].rsplit(':', 1)[0]} | set(profile.get('api_sans', [])))},
         'dns': {'imageRepository': 'registry.k8s.io/coredns', 'imageTag': tags['coredns']},
         'etcd': {'local': {'imageRepository': 'registry.k8s.io', 'imageTag': tags['etcd']}},
         # The owner's five-year request concerns Harbor TLS. Do not silently
         # lengthen Kubernetes control-plane credentials as part of this change.
         'certificateValidityPeriod': '8760h', 'caCertificateValidityPeriod': '87600h'},
        {'apiVersion': 'kubelet.config.k8s.io/v1beta1', 'kind': 'KubeletConfiguration',
         'cgroupDriver': 'systemd', 'failSwapOn': True, 'rotateCertificates': True},
        {'apiVersion': 'kubeproxy.config.k8s.io/v1alpha1', 'kind': 'KubeProxyConfiguration',
         'mode': 'iptables', 'clusterCIDR': profile['pod_cidr']},
    ]


def join_document(profile, node, ticket):
    validate(profile)
    if node['role'] != 'worker' or not re.fullmatch(r'[a-z0-9]{6}\.[a-z0-9]{16}', ticket['token']):
        raise ValueError('Only workers with a valid bootstrap token may join')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', ticket['ca_pin']) or not re.fullmatch(r'[a-f0-9-]{36}', ticket['uid']):
        raise ValueError('Invalid cluster CA pin or UID')
    if ticket['endpoint'] != profile['endpoint']:
        raise ValueError('Ticket API endpoint differs from profile')
    return {'apiVersion': 'kubeadm.k8s.io/v1beta4', 'kind': 'JoinConfiguration',
            'nodeRegistration': registration(node),
            'discovery': {'bootstrapToken': {'apiServerEndpoint': ticket['endpoint'], 'token': ticket['token'],
                                           'caCertHashes': [ticket['ca_pin']], 'unsafeSkipCAVerification': False},
                          'tlsBootstrapToken': ticket['token']}}


def multi_json(documents):
    # JSON is a YAML subset; multi-document separators support kubeadm without
    # adding a YAML dependency to the new cloud node's bootstrap runtime.
    return '\n---\n'.join(json.dumps(d, indent=2) for d in documents) + '\n'


def image_patch(name, reference, workload=False):
    spec = {'containers': [{'name': name, 'image': reference, 'imagePullPolicy': 'Never'}]}
    return {'spec': {'template': {'spec': spec}}} if workload else {'spec': spec}


def kubeadm_patches(images):
    by_name = {i['source'].rsplit('/', 1)[1].split(':', 1)[0]: i['reference'] for i in images}
    patches = {name + '+strategic.json': image_patch(name, by_name[name])
               for name in ('kube-apiserver', 'kube-controller-manager', 'kube-scheduler', 'etcd')}
    patches['corednsdeployment+strategic.json'] = image_patch('coredns', by_name['coredns'], True)
    return patches, image_patch('kube-proxy', by_name['kube-proxy'], True)


def calico_objects(profile, data, root):
    # Rendering happens on the management machine, never on the remote node.
    validate(profile)
    return calico_for_network(profile['pod_cidr'], profile['cluster'], data, root)


def calico_for_network(pod_cidr, cluster, data, root, detection='kubernetes-internal-ip'):
    """Shared cloud/KIND Calico renderer; adapters supply network/identity only."""
    import yaml
    network = ipaddress.IPv4Network(pod_cidr, strict=True)
    if (not 8 <= network.prefixlen <= 24 or not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,62}', cluster)
            or detection not in ('kubernetes-internal-ip', 'interface=eth0')):
        raise ValueError('Unsupported shared Calico network/identity/detection')
    record = next(x for x in data['shared_calico_materials'] if 'source' not in x)
    path = below(root, record['material_root_relative_path'])
    if sha256(path) != record['sha256']:
        raise ValueError('Calico upstream manifest SHA differs')
    objects = [d for d in yaml.safe_load_all(path.read_text()) if d]
    images = {x['source']: x['reference'] for x in data['shared_calico_materials'] if 'source' in x}
    seen = set()
    for obj in objects:
        obj.setdefault('metadata', {}).setdefault('labels', {})['sunmoonai.com/cluster-bootstrap'] = cluster
        if obj['kind'] == 'ConfigMap' and obj['metadata']['name'] == 'calico-config':
            obj['data']['calico_backend'] = 'vxlan'
        if obj['kind'] not in ('DaemonSet', 'Deployment'):
            continue
        spec = obj['spec']['template']['spec']
        for container in spec.get('initContainers', []) + spec.get('containers', []):
            if container['image'] not in images:
                raise ValueError('Calico manifest contains an unlocked image')
            seen.add(container['image'])
            container['image'] = images[container['image']]
            container['imagePullPolicy'] = 'Never'
            if container['name'] == 'calico-node':
                values = {'CALICO_IPV4POOL_CIDR': pod_cidr, 'CALICO_IPV4POOL_IPIP': 'Never',
                          'CALICO_IPV4POOL_VXLAN': 'Always', 'CLUSTER_TYPE': 'k8s', 'FELIX_BPFENABLED': 'false',
                          'IP_AUTODETECTION_METHOD': detection}
                container['env'] = [e for e in container['env'] if e['name'] not in values]
                container['env'] += [{'name': k, 'value': v} for k, v in values.items()]
                container['readinessProbe']['exec']['command'] = ['/bin/calico-node', '-felix-ready']
                container['livenessProbe']['exec']['command'] = ['/bin/calico-node', '-felix-live']
    if seen != set(images):
        raise ValueError('Incomplete Calico image set')
    return {'apiVersion': 'v1', 'kind': 'List', 'items': objects}
