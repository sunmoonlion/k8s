#!/usr/bin/env python3
"""Component stage graph: the only source is gitops/components/**/stage.yaml.

graph   Scan the component tree and write the merged stage list for Ansible.
select  Resolve a requested OBJECT against the templated graph (stdin JSON).

The directory holding a stage.yaml is the deployable object. Each file lists one
or more Flux stages whose paths are relative to that directory. Field values may
be Jinja expressions; they are rendered by Ansible, never here.
"""
import argparse
import json
import os
import sys

import yaml

STAGE_KEYS = {"name", "path", "dependsOn", "enabled", "images", "wait", "timeout", "healthChecks", "resources", "render", "volume"}
FILE_KEYS = {"defaults", "stages", "prepare"}
DEFAULTS = {"path": ".", "dependsOn": [], "enabled": True, "images": [], "wait": True, "timeout": "15m", "healthChecks": [], "resources": [], "render": None, "volume": None}


class PlainDumper(yaml.SafeDumper):
    def ignore_aliases(self, data):
        return True


def fail(message):
    raise SystemExit(f"stage graph: {message}")


def load_graph(components_root):
    stages, stage_paths, prepares = [], {}, []
    for directory, subdirs, files in os.walk(components_root):
        subdirs.sort()
        if "stage.yaml" not in files:
            continue
        obj = os.path.relpath(directory, components_root).replace(os.sep, "/")
        with open(os.path.join(directory, "stage.yaml"), encoding="utf-8") as handle:
            document = yaml.safe_load(handle) or {}
        unknown = set(document) - FILE_KEYS
        if unknown or not isinstance(document.get("stages"), list) or not document["stages"]:
            fail(f"{obj}/stage.yaml must contain only {sorted(FILE_KEYS)} and a non-empty stages list; got {sorted(unknown)}")
        defaults = document.get("defaults") or {}
        if set(defaults) - (STAGE_KEYS - {"name", "path"}):
            fail(f"{obj}/stage.yaml defaults accept only {sorted(STAGE_KEYS - {'name', 'path'})}")
        prepare = document.get("prepare")
        if prepare is None and os.path.isfile(os.path.join(directory, "prepare.yaml")):
            prepare = "./prepare.yaml"
        if isinstance(prepare, str):
            prepare = {"file": prepare, "vars": {}}
        if prepare is not None:
            if not isinstance(prepare, dict) or set(prepare) - {"file", "vars"} or "file" not in prepare:
                fail(f"{obj}/stage.yaml prepare must be a file path or {{file, vars}}")
            # "./x" or "../x" is relative to the object; anything else is relative to the components root.
            file = os.path.normpath(os.path.join(obj, prepare["file"]) if prepare["file"].startswith(("./", "../")) else prepare["file"]).replace(os.sep, "/")
            if not os.path.isfile(os.path.join(components_root, file)):
                fail(f"{obj}/stage.yaml prepare file {file} does not exist")
            prepare = {"file": file, "vars": prepare.get("vars") or {}}
            prepares.append({"object": obj, **prepare})
        for entry in document["stages"]:
            if not isinstance(entry, dict) or "name" not in entry or set(entry) - STAGE_KEYS:
                fail(f"{obj}/stage.yaml stage entries need a name and only {sorted(STAGE_KEYS)}")
            merged = {**DEFAULTS, **defaults, **entry}
            if merged["name"] in stage_paths:
                fail(f"duplicate stage name {merged['name']} in {obj}")
            path = os.path.normpath(os.path.join(obj, merged["path"])).replace(os.sep, "/")
            if path.startswith("../") or not os.path.isdir(os.path.join(components_root, path)):
                fail(f"{obj}/stage.yaml stage {merged['name']} path {path} does not exist")
            render = merged["render"]
            if render is None:
                # Objects with a prepare.yaml render their own templates unless they declare render explicitly.
                render = ["workload.yaml"] if prepare is None and os.path.isfile(os.path.join(components_root, path, "workload.yaml.j2")) else []
            for name in render:
                if not os.path.isfile(os.path.join(components_root, path, name + ".j2")):
                    fail(f"{obj}/stage.yaml stage {merged['name']} render target {name} has no {name}.j2 template")
            stage = {"name": merged["name"], "object": obj, "path": path, "dependencies": merged["dependsOn"], "enabled": merged["enabled"],
                     "images": list(merged["images"]), "wait": merged["wait"], "timeout": merged["timeout"], "health_checks": list(merged["healthChecks"]),
                     "resources": merged["resources"], "render": list(render), "volume": merged["volume"]}
            stages.append(stage)
            stage_paths[stage["name"]] = path
    names = set(stage_paths)
    for stage in stages:
        if isinstance(stage["dependencies"], list):
            for dependency in stage["dependencies"]:
                if isinstance(dependency, str) and "{{" not in dependency and dependency not in names:
                    fail(f"stage {stage['name']} depends on undefined stage {dependency}")
    return {"component_stages": stages, "stage_paths": stage_paths, "component_objects": sorted({s["object"] for s in stages}), "component_prepares": prepares}


def select(data):
    requested, graph = data["object"], {}
    for stage in data["stages"]:
        if stage["name"] in graph:
            raise SystemExit("Duplicate component stage")
        if not isinstance(stage["enabled"], bool) or not isinstance(stage["dependencies"], list):
            raise SystemExit(f"Stage {stage['name']} enabled/dependsOn must render to a boolean and a list")
        graph[stage["name"]] = dict(stage)
    app_names = data["application_names"]
    modules = data["modules"]
    objects = sorted({s["object"] for s in graph.values()})
    groups = {prefix for obj in objects for prefix in ["/".join(obj.split("/")[:i]) for i in range(1, len(obj.split("/")))]}
    if requested not in set(objects) | groups | set(modules) | {"all"}:
        raise SystemExit("Unknown OBJECT; choose a listed platform, application, component or infrastructure module")

    def matches(obj):
        return requested == "all" or obj == requested or obj.startswith(requested + "/")

    def application_of(obj):
        parts = obj.split("/")
        if len(parts) >= 3 and parts[0] == "app-platform" and parts[1].endswith("-app") and parts[1][:-4] in app_names:
            return parts[1][:-4]
        return None

    chosen = [s for s in graph.values() if matches(s["object"])]
    active = [s["name"] for s in chosen if s["enabled"]]
    disabled = [s["object"] for s in chosen if not s["enabled"]]
    closure, visiting, done, blocked = [], set(), set(), []

    def visit(name):
        if name not in graph:
            raise SystemExit("Undefined stage dependency: " + name)
        if name in visiting:
            raise SystemExit("Cyclic stage dependency: " + name)
        if name in done:
            return
        visiting.add(name)
        stage = graph[name]
        if not stage["enabled"]:
            blocked.append(name)
        for dependency in stage["dependencies"]:
            visit(dependency)
        visiting.remove(name)
        done.add(name)
        closure.append(name)

    for name in active:
        visit(name)
    selected_objects = sorted({s["object"] for s in chosen})
    services = sorted({s["object"] for s in graph.values() if s["name"] in active and application_of(s["object"]) is None})
    active_objects = sorted({graph[n]["object"] for n in active})
    apps = {app: sorted({obj.split("/")[2] for obj in active_objects if application_of(obj) == app}) for app in app_names}
    selected_modules = {name: (info["enabled"] and (requested == "all" or name == requested)) for name, info in modules.items()}
    material_ids = sorted({image for stage in graph.values() if stage["name"] in active for image in stage.get("images", [])})
    action = data["action"]
    if action in ["select", "deploy", "stage", "build", "check"] and requested in modules and not modules[requested]["enabled"]:
        raise SystemExit("Selected infrastructure module is disabled")
    if action in ["select", "deploy", "stage", "build", "check"] and requested != "all" and disabled and not active:
        raise SystemExit("Selected object is disabled; change its owning config explicitly")
    if action in ["select", "deploy", "stage", "build", "check"] and blocked:
        raise SystemExit("Disabled dependency: " + ", ".join(sorted(set(blocked))))
    if action == "stage" and any(selected_modules.values()) and requested != "all":
        raise SystemExit("Stage accepts Flux-owned component objects; host modules use plan/config/deploy/check")
    if action == "build" and (any(selected_modules.values()) or services or not any(apps.values())):
        raise SystemExit("Build accepts application source components only")
    files = []
    config_objects = selected_objects + sorted({graph[n]["object"] for n in closure})
    for file in data["config_files"]:
        normalized = file.removeprefix("../gitops/components/")
        directory = normalized.rsplit("/", 1)[0]
        if (requested == "all" or file == data["site"] or directory == "host"
                or (directory in modules and selected_modules.get(directory))
                or (directory == "services" and services)
                or (directory == "applications" and any(apps.values()))
                or (file.startswith("../gitops/") and any(obj == directory or obj.startswith(directory + "/") or directory.startswith(obj + "/") for obj in config_objects))):
            files.append(file)
    return {"object": requested, "action": action, "objects": selected_objects, "selected_stages": active, "required_stages": closure,
            "dependency_stages": [n for n in closure if n not in active], "disabled_objects": sorted(set(disabled)),
            "blocked_dependencies": sorted(set(blocked)), "services": services, "service_image_ids": material_ids, "applications": apps,
            "modules": selected_modules, "configuration_files": files, "known_objects": objects,
            "source_scope": "One immutable OCI bundle is promoted; unselected declarations must stay unchanged."}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    graph = commands.add_parser("graph")
    graph.add_argument("--components", required=True)
    graph.add_argument("--output", required=True)
    commands.add_parser("select")
    args = parser.parse_args()
    if args.command == "graph":
        result = load_graph(args.components)
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write("# Generated by components/stages.py from gitops/components/**/stage.yaml; do not edit.\n")
            yaml.dump(result, handle, Dumper=PlainDumper, sort_keys=False, allow_unicode=True, width=1000)
        print(json.dumps({"stages": len(result["component_stages"]), "objects": len(result["component_objects"]), "output": args.output}))
    else:
        print(json.dumps(select(json.load(sys.stdin))))


if __name__ == "__main__":
    main()
