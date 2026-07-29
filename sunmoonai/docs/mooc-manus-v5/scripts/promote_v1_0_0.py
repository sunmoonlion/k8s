#!/usr/bin/env python3
"""Promote the accepted V5 image digests to the single release tag 1.0.0."""

from __future__ import annotations

import base64
import json
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REGISTRY = "harbor.sunmoonai.com:30443"
PROJECT = "app-images"
TAG = "1.0.0"

IMAGES = {
    "tpl-admin-frontend": "sha256:b426551c0e027b25965995e23486c590c29fa52047779dd14721d93a245a74f1",
    "tpl-admin-backend": "sha256:b24ce7a39e7e10a5541b2a29ff9795a6944d6f17ec4d0479e2051f59a0688c56",
    "tpl-web-frontend": "sha256:c848bee9b5e3d852c8c5adfc36f66d4ac86d909030120f354bfece88b141bd78",
    "tpl-web-backend": "sha256:41dc3a781033dda3e60cd3594ffac7caf767e3c8cb2295ac0b8a21986fbd2414",
    "tpl-admin-frontend-vue": "sha256:5380b1b56b3c6f0c825b2e0a2df03b0e23517eb8de6d440edccbe2579b738a57",
    "tpl-web-backend-nest": "sha256:8d17b350df03968c4a847a4f089a2145e3ba326cdbb16db1f2996146cb359536",
    "info-admin-frontend": "sha256:3cb6966c4f0eef9d2121333318b94a05cce60630809578a222215fb72a4b6954",
    "info-admin-backend": "sha256:06baa0ba2c0deb7bf9408bab3a4ecc1d459dafdc19611d8ecd77041acbc5b43a",
    "info-web-frontend": "sha256:909c3357d1924ee337142af6871db0cb6809abc541973ab6e769de3850e7295c",
    "info-web-backend": "sha256:b6a5a2e26f2409ed732c06179b3cbeabdbf29f61daf1aa7ac145df52b3b01c48",
    "knowledge-admin-frontend": "sha256:85b66d68d54784e6a70f3f5d51a7893db62dea4d2a64a91672c66a037d8e3efb",
    "knowledge-admin-backend": "sha256:0b8b949fd2247395f5df329dc705b32b39c33af9d195adf43f3a50865fe8701d",
    "knowledge-web-frontend": "sha256:92706a8939cf77dbac90190a501102540fe91dfa62c8d8e9fb75d6854890d39f",
    "knowledge-web-backend": "sha256:a2718a1b254eddc81b096836c8bb2e86e8be52a3dfa25c6da6295b04bcb545f1",
    "research-admin-frontend": "sha256:f4225868225bcffe9d34e482ebad132ee13c6ac000e31820bcfe7be6efdc1e4c",
    "research-admin-backend": "sha256:1b9c3b6b5e5af377961ff2e2b2ae861d6057e878663ab671674a1c25dd5c774b",
    "research-web-frontend": "sha256:a34ba8238a1b116f2726a3e5bca2582d9ab1e7c388e28ad0b6f40d740906f04c",
    "research-web-backend": "sha256:901ee1c2fd0ddcacc178a832ec215c84ad6237e81a02030300107030e9df8202",
}

REACT_LEGACY_SOURCE = (
    "tpl-admin-frontend",
    "sha256:358f24459dcf62b52cd10fcb84a0fa2ac6432d5b96dff2b07d279bc3f98759e2",
)


def docker_auth() -> str:
    config = json.loads((Path.home() / ".docker/config.json").read_text())
    auth = config["auths"][REGISTRY]["auth"]
    base64.b64decode(auth, validate=True)
    return auth


AUTH = docker_auth()
TLS = ssl.create_default_context()


def harbor(method: str, path: str, body: dict | None = None) -> tuple[int, bytes]:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(
        f"https://{REGISTRY}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Basic {AUTH}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, context=TLS, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def artifact(repo: str, reference: str) -> dict:
    encoded_repo = urllib.parse.quote(repo, safe="")
    encoded_ref = urllib.parse.quote(reference, safe="")
    status, payload = harbor(
        "GET",
        f"/api/v2.0/projects/{PROJECT}/repositories/{encoded_repo}/artifacts/{encoded_ref}",
    )
    if status != 200:
        raise RuntimeError(f"artifact lookup failed: repo={repo} status={status}")
    return json.loads(payload)


def add_tag(repo: str, digest: str) -> None:
    current = artifact(repo, digest)
    tags = {item["name"] for item in current.get("tags") or []}
    if TAG not in tags:
        try:
            existing_release = artifact(repo, TAG)
        except RuntimeError:
            existing_release = None
        if existing_release is not None and existing_release["digest"] != digest:
            encoded_repo = urllib.parse.quote(repo, safe="")
            encoded_digest = urllib.parse.quote(existing_release["digest"], safe="")
            encoded_tag = urllib.parse.quote(TAG, safe="")
            status, _ = harbor(
                "DELETE",
                f"/api/v2.0/projects/{PROJECT}/repositories/{encoded_repo}"
                f"/artifacts/{encoded_digest}/tags/{encoded_tag}",
            )
            if status not in (200, 202):
                raise RuntimeError(
                    f"stale release tag deletion failed: repo={repo} status={status}"
                )
            print(
                f"REPLACED stale {repo}:{TAG} "
                f"{existing_release['digest']} -> {digest}"
            )
        encoded_repo = urllib.parse.quote(repo, safe="")
        encoded_digest = urllib.parse.quote(digest, safe="")
        status, _ = harbor(
            "POST",
            f"/api/v2.0/projects/{PROJECT}/repositories/{encoded_repo}/artifacts/{encoded_digest}/tags",
            {"name": TAG},
        )
        if status not in (200, 201):
            raise RuntimeError(f"tag creation failed: repo={repo} status={status}")
    promoted = artifact(repo, TAG)
    if promoted["digest"] != digest:
        raise RuntimeError(
            f"digest mismatch after promotion: repo={repo} "
            f"expected={digest} actual={promoted['digest']}"
        )
    print(f"PROMOTED {repo}:{TAG} {digest}")


def promote_react_legacy() -> str:
    source_repo, source_digest = REACT_LEGACY_SOURCE
    source = f"{REGISTRY}/{PROJECT}/{source_repo}@{source_digest}"
    target = f"{REGISTRY}/{PROJECT}/tpl-admin-frontend-react:{TAG}"
    subprocess.run(["docker", "pull", source], check=True)
    subprocess.run(["docker", "tag", source, target], check=True)
    subprocess.run(["docker", "push", target], check=True)
    promoted = artifact("tpl-admin-frontend-react", TAG)
    print(f"PROMOTED tpl-admin-frontend-react:{TAG} {promoted['digest']}")
    return promoted["digest"]


def main() -> None:
    for repo, digest in IMAGES.items():
        add_tag(repo, digest)
    react_digest = promote_react_legacy()
    print(
        json.dumps(
            {
                "result": "passed",
                "release_tag": TAG,
                "image_count": len(IMAGES) + 1,
                "tpl-admin-frontend-react": react_digest,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
