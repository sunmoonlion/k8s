#!/usr/bin/env python3
"""Rebuild the private identity-preparation record from the LIVE KIND state.

Use only when the original preparation directory (kind_identity_prepare.py --output)
is lost. Nothing is written to the cluster or the database. The record is not a
copied receipt: every fact is re-proven now — runtime Secret contract and release
annotation, catalog (runtime roles exist, old login retired), real TCP database
probes (positive and denied) and real AMQP logins (positive and cross-vhost denied).
The resulting directory is consumed by the image-only upgrade route
(release.runtime_identity_upgrade) via kind_database_activation.load_preparation.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
from urllib.parse import unquote, urlsplit

import development_release
import kind_database_activation as activation
import kind_database_rehearsal as common
import kind_identity_prepare as preparation


def inventory_facts(app, inventory):
    roles = {row["name"]: row for row in inventory["roles"]}
    runtime = {app + "_backend_" + role for role in development_release.RUNTIME_ROLES}
    old = app + "_backend_user"
    migration = app + "_backend_user_migration"
    if not runtime <= set(roles) or migration not in roles or old not in roles:
        raise common.RehearsalError("runtime_identities_not_activated")
    if any(not roles[name]["login"] for name in runtime) or not roles[migration]["login"]:
        raise common.RehearsalError("runtime_identity_cannot_login")
    if inventory["memberships"]:
        raise common.RehearsalError("unexpected_role_membership")
    return {"old_logins_retired": not roles[old]["login"], "revisions": inventory["revisions"]}


def recover(args):
    output = args.output.absolute()
    if output != output.resolve() or not output.parent.is_dir():
        raise common.RehearsalError("output_parent_missing_or_symlink")
    if subprocess.run(["git", "-C", str(output.parent), "rev-parse", "--show-toplevel"],
                      capture_output=True).returncode == 0:
        raise common.RehearsalError("private_output_path_required")
    common.verify_kind(args)
    app = args.app
    secret = common.get(args, preparation.NS, "secret", app + "-backend-runtime")
    annotations = secret.get("metadata", {}).get("annotations", {})
    if annotations.get("sunmoonai.com/release-id") != args.prepared_release_id:
        raise common.RehearsalError("runtime_secret_release_mismatch")
    # the Secret must be the one the preparation reserved (marker set by kind_identity_prepare), never a hand-made one
    if annotations.get(preparation.MARKER) != "prepared-not-database-activated":
        raise common.RehearsalError("runtime_secret_marker_mismatch")
    development_release.verify_runtime_secret_contract(secret, app)
    context = SimpleNamespace(kubeconfig=args.kubeconfig, cluster_uid=args.cluster_uid)
    inventory = json.loads(activation.admin_sql(context, app, activation.inventory_sql(app)))
    facts = inventory_facts(app, inventory)
    passwords = {role: unquote(urlsplit(base64.b64decode(secret["data"][role.upper() + "_DATABASE_URL"]).decode()).password)
                 for role in development_release.RUNTIME_ROLES}
    output.mkdir(mode=0o700)  # after all read-only checks; refuses an existing directory
    common.ERROR_DIR = output
    probes = activation.verify_logins(context, app, passwords)
    amqp = preparation.verify_amqp(args, secret)
    plan = {"app": app, "cluster_uid": args.cluster_uid, "release_id": args.prepared_release_id,
            "source_sha256": preparation.source_hashes(),
            "release_sha256": "recovered-from-live",
            "runtime_secret": {"metadata": {"name": secret["metadata"]["name"], "namespace": secret["metadata"]["namespace"],
                                            "annotations": annotations},
                               "data": secret["data"]},
            "recovered_from_live": True, "database_activated": True}
    raw = preparation.encoded(plan)
    digest = hashlib.sha256(raw).hexdigest()
    common.private_write(output / "plan.private.json", raw)
    common.private_write(output / "reserve-runtime-secret-result.private.json", preparation.encoded(secret))
    common.private_write(output / "amqp-proof.json", common.encoded(amqp))
    applied = {"app": app, "plan_sha256": digest, "applied": True, "live_amqp_login_verified": True,
               "database_activated": True, "recovered_from_live": True, "database_probes": probes,
               "old_identities_retired": facts["old_logins_retired"], "credentials_printed": False}
    common.private_write(output / "applied.json", preparation.encoded(applied))
    folder = output / "database-activation"
    folder.mkdir(mode=0o700)
    common.private_write(folder / "catalog-after.private.json", preparation.encoded(inventory))
    common.private_write(folder / "complete.json", preparation.encoded(
        {"release_id": args.prepared_release_id, "probes": probes, "old_logins_retired": facts["old_logins_retired"],
         "recovered_from_live": True, "revisions": facts["revisions"]}))
    summary = {"app": app, "prepared_release_id": args.prepared_release_id, "plan_sha256": digest,
               "database_probes": probes, "amqp": amqp, "old_identities_retired": facts["old_logins_retired"],
               "output": str(output), "credentials_printed": False}
    print(common.encoded(summary), flush=True)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", choices=common.APPS, required=True)
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--cluster-uid", required=True)
    parser.add_argument("--prepared-release-id", required=True,
                        help="release id the live runtime Secret was prepared for (its annotation)")
    parser.add_argument("--output", type=Path, required=True, help="new private directory outside Git")
    args = parser.parse_args()
    recover(args)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(common.encoded({"status": "failed", "reason": str(exc) if isinstance(exc, common.RehearsalError)
                              else type(exc).__name__}), flush=True)
        raise SystemExit(1)
