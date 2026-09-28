#!/usr/bin/env python3
"""One navigation/dispatch entry; implementations remain in their owning modules."""
from pathlib import Path
import argparse
import os
import sys

ROOT = Path(__file__).resolve().parents[2]
# Pass argv directly without a shell; these backends default to plans/help.
ROUTES = {
    ('storage', 'ensure'): 'sunmoonai/kind-infrastructure/mount/ensure_storage.py',
    ('kind', 'prepare'): 'sunmoonai/kind-infrastructure/formal/prepare.py',
    ('kind', 'cluster'): 'sunmoonai/kind-infrastructure/formal/cluster.py',
    ('kind', 'lifecycle'): 'sunmoonai/kind-infrastructure/formal/lifecycle.py',
    ('harbor', 'prepare'): 'sunmoonai/registry-platform/host_prepare.py',
    ('harbor', 'lifecycle'): 'sunmoonai/registry-platform/host_runtime.py',
    ('harbor', 'mode'): 'sunmoonai/registry-platform/host_mode.py',
    ('harbor', 'backup'): 'sunmoonai/registry-platform/host_backup.py',
    ('harbor', 'entry'): 'sunmoonai/registry-platform/sni_proxy.py',
    ('harbor', 'materials'): 'sunmoonai/registry-platform/prepare-artifacts.py',
    ('harbor', 'certificates'): 'sunmoonai/registry-platform/certificates.py',
    ('harbor', 'images'): 'sunmoonai/registry-platform/images.py',
    ('harbor', 'client'): 'sunmoonai/registry-platform/client.py',
}


def platform(arguments):
    parser = argparse.ArgumentParser(description='Shared platform deployment after explicit cluster preparation')
    parser.add_argument('action', choices=('plan', 'deploy'))
    parser.add_argument('--cluster', required=True, choices=('KIND', 'C1', 'C2', 'C3'))
    parser.add_argument('--project', default='sunmoonai')
    parser.add_argument('--environment', default='development')
    parser.add_argument('--kubeconfig', type=Path)
    parser.add_argument('--kubectl', type=Path)
    parser.add_argument('--expected-uid')
    parser.add_argument('--registry-config', type=Path,
                        help='Independent registry profile; normally configured in the environment')
    parser.add_argument('--registry-credentials-file', type=Path,
                        help='Override the private consumer credential path from the registry profile')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(arguments)
    if args.action == 'plan' and args.apply:
        parser.error('plan cannot apply')
    if args.registry_config:
        os.environ['REGISTRY_CONFIG_FILE'] = str(args.registry_config)
    if args.registry_credentials_file:
        os.environ['REGISTRY_CREDENTIALS_FILE'] = str(args.registry_credentials_file)
    if args.apply:
        if (not args.kubeconfig or not args.kubectl or not args.expected_uid
                or not args.kubeconfig.is_absolute() or not args.kubectl.is_absolute()):
            parser.error('apply requires absolute --kubeconfig, --kubectl and --expected-uid')
        # The shared backend verifies the mapped kubeconfig/tool/UID before any
        # secret preparation or subscript invocation, for both KIND and kubeadm.
        os.environ.update(KUBECONFIG=str(args.kubeconfig), SUNMOON_KUBECTL=str(args.kubectl),
                          SUNMOON_EXPECTED_CLUSTER_UID=args.expected_uid)
    target = ROOT / 'sunmoonai/deploy-sunmoonai-all/deploy-sunmoonai-all.sh'
    os.execv('/bin/bash', ['bash', str(target), '--cluster', args.cluster, 'deploy',
                          args.project, args.environment, 'false' if args.apply else 'true'])


def main():
    args = sys.argv[1:]
    if not args or args in (['help'], ['--help'], ['-h']):
        print('Usage: ./sunmoon <module> <operation> [backend arguments]\n')
        for module, operation in ROUTES:
            print(f'  {module:8s} {operation}')
        print('\ncloud plan --cluster C1: print the kubeadm path only (no real-host validation).')
        print('platform plan/deploy --cluster KIND: shared platform backend, defaults to a plan.')
        print('platform deploy --apply requires explicit kubeconfig/kubectl/UID; main consumer migration is incomplete.')
        print('Use --help after a route for its arguments. Mutations require the backend apply flag.')
        print('kind routes accept --config <absolute JSON path>; otherwise formal/deploy-kind.json.')
        print('Current public registry/inbox still use the old kind. See README.md and legacy/README.md.')
        return
    if args[0] == 'platform':
        platform(args[1:])
        return
    if args[:2] == ['cloud', 'plan']:
        if len(args) != 4 or args[2] != '--cluster' or args[3] not in ('C1', 'C2', 'C3'):
            raise SystemExit('Expected: cloud plan --cluster C1|C2|C3')
        target = ROOT / 'sunmoonai/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.sh'
        os.execv('/bin/bash', ['bash', str(target), '--cluster', args[3], 'deploy', '--dry-run'])
    key = tuple(args[:2])
    if key not in ROUTES:
        raise SystemExit('Unknown or not yet admitted operation; see ./sunmoon help and README.md')
    if key[0] == 'kind':
        selector = argparse.ArgumentParser(add_help=False, allow_abbrev=False)
        selector.add_argument('--config', type=Path)
        selected, remaining = selector.parse_known_args(args[2:])
        if selected.config:
            if not selected.config.is_absolute():
                selector.error('--config requires an absolute path')
            os.environ['SUNMOON_KIND_CONFIG'] = str(selected.config)
        args = [*args[:2], *remaining]
    target = ROOT / ROUTES[key]
    os.execv(sys.executable, [sys.executable, '-B', str(target), *args[2:]])


if __name__ == '__main__':
    main()
