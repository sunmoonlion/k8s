# Data Platform Object Storage

This component provides the platform S3 object-storage capability by using the
official MinIO AIStor Operator and ObjectStore Helm charts.

Current scope:

- Kind development cluster.
- Remote development cluster such as C1.
- AIStor Free single-node ObjectStore.
- Kind uses one retained static `hostPath` volume.
- Remote development uses the cluster `local-path` StorageClass.
- Images pulled from the local Harbor project.
- Cluster-internal S3 API and Console services.

## Pinned Versions

| Component | Version |
|---|---:|
| AIStor Operator Chart | `5.7.0` |
| AIStor ObjectStore Chart | `1.0.14` |
| AIStor Operator | `RELEASE.2026-06-10T05-02-21Z` |
| AIStor Object Store | `RELEASE.2026-05-28T20-50-32Z` |

See [resources/CHARTS.md](./resources/CHARTS.md) for package checksums.

## License

AIStor requires a license before it creates the ObjectStore workload. Without a
license, the Operator and webhook run, but the ObjectStore remains in a red
state and S3 operations are unavailable.

Obtain an AIStor Free license from MinIO SUBNET and save it outside the
repository at:

```text
~/.config/sunmoonai/licenses/minio.license
```

The deployment script reads this path by default and recreates the Kubernetes
Secret after a Kind cluster rebuild. Do not commit the license file.

Import or update it with:

```bash
export KUBECONFIG="$HOME/.kube/kind-config"

kubectl create secret generic minio-license \
  --namespace data-platform-dev \
  --from-file=minio.license="$HOME/.config/sunmoonai/licenses/minio.license" \
  --dry-run=client -o yaml | kubectl apply -f -
```

The Operator watches the Secret and should reconcile the existing ObjectStore
without reinstalling the Helm releases.

## Deploy

Kind:

```bash
export KUBECONFIG="$HOME/.kube/kind-config"

./deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND deploy sunmoonai data-platform-dev development false
```

Remote development, for example C1:

```bash
./deploy-object-storage/deploy-object-storage.sh \
  --cluster C1 deploy sunmoonai data-platform-dev development false
```

To override the default license location for one deployment:

```bash
export AISTOR_LICENSE_FILE=/absolute/path/to/minio.license

./deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND deploy sunmoonai data-platform-dev development false
```

Use `--cluster C1` with the same command shape for the remote development
cluster.

## Status

```bash
export KUBECONFIG="$HOME/.kube/kind-config"

./deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND status sunmoonai data-platform-dev development
```

Use `--cluster C1` for the remote development cluster.

## Console

The Console Service remains `ClusterIP` and is not exposed through the public
Ingress. Open a temporary loopback-only tunnel:

```bash
./deploy-object-storage/deploy-object-storage.sh \
  --cluster KIND console sunmoonai data-platform-dev development
```

Then open `http://127.0.0.1:19090`. The tunnel exists only while the command is
running and closes with `Ctrl+C`.

See the Chinese operation guide:
[AIStor Console access](./docs/console-access.md).

## App Access Provisioning

App and Backend Bucket access is managed by the declaration-driven
[S3 resource provisioner](./provisioner/README.md). Declarations contain no
credentials; the provisioner creates least-privilege IAM resources and writes
the resulting standard S3 configuration to the target Kubernetes Namespace.

The Kind deployment uses a retained PV:

```text
PV:        object-storage-sunmoonai-dev-pv
hostPath:  /data/kind-local-storage/object-storage
node:      kind-worker
capacity:  10Gi
```

The deployment script creates the host directory and sets ownership to
`1000:1000` before applying the PV because Kubernetes `fsGroup` does not
reliably change permissions on a Kind `hostPath` volume.

Remote development deployments do not apply this Kind PV manifest. They use
dynamic PVC provisioning through `local-path`.

Uninstalling the Helm releases does not delete the PV, PVC, license Secret, or
root-credential Secret.
