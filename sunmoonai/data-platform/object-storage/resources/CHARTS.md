# AIStor Helm Charts

The charts in this directory are vendored from the official MinIO Helm
repository so Data Platform deployments do not depend on live chart downloads.

Repository:

```text
https://helm.min.io/
```

Pinned charts:

| Chart | Version | Package SHA-256 |
|---|---:|---|
| `aistor-operator` | `5.7.0` | `bdd78103db14c247eac91da42896b3bb88a220a6a6abb48a6d8e5d0720a31328` |
| `aistor-objectstore` | `1.0.14` | `c3acc5a8b7ef0801ae62b7e9a0a1e38c526165f4073845139e30fbe0db83365b` |

The package archives were downloaded on 2026-06-11. Upgrade these charts only
after reviewing CRD compatibility, image changes, release notes, and rollback
requirements.
