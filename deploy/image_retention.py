#!/usr/bin/env python3
"""Root-owned deployment hook: retain active/rollback Starfall images only.

Installed once by install-retention.sh. No container, volume, download, or
registry deletion. Never source deployment-owned shell files as root.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPOSITORY = "ghcr.io/mrwells99/starfall"
TAG = re.compile(r"sha-[a-f0-9]{7}\Z")
STATE = Path("/var/lib/starfall-image-retention/state.json")


def docker(*args):
    return subprocess.check_output(["/usr/bin/docker", *args], text=True)


def valid_tag(value):
    if value is not None and not TAG.fullmatch(value):
        raise ValueError("Unrecognized release tag; cleanup skipped")
    return value


def image_tag(reference):
    prefix = REPOSITORY + ":"
    if reference.startswith(prefix) and TAG.fullmatch(reference[len(prefix):]):
        return reference[len(prefix):]
    return None


def read_deployment_tags(root):
    env = {}
    for line in (root / ".env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip('"\'')
    if env.get("STARFALL_IMAGE", REPOSITORY) != REPOSITORY:
        raise ValueError("Custom image repository; cleanup skipped")
    if not env.get("STARFALL_TAG"):
        raise ValueError("Missing target release; cleanup skipped")
    tags = {valid_tag(env["STARFALL_TAG"])}
    previous = root / ".last-tag"
    if previous.exists():
        tags.add(valid_tag(previous.read_text().strip() or None))
    # An image remains protected until public client feeds have moved too.
    for relative in ("downloads/manifest.json", "downloads/linux/manifest.json"):
        path = root / relative
        if path.exists():
            tags.add(valid_tag(json.loads(path.read_text())["server_tag"]))
    return tags - {None}


def retention_plan(images, containers, deployment_tags, state, phase):
    state = dict(state)
    for field in ("current", "rollback"):
        valid_tag(state.get(field))
    in_use = {c["Image"] for c in containers}  # Includes stopped containers.
    running = {image_tag(c["Config"]["Image"]) for c in containers if c["State"]["Running"]}
    running.discard(None)
    if len(running) > 1:
        raise ValueError("Mixed running Starfall releases; cleanup skipped")
    if len(running) == 1:
        active = next(iter(running))
        if not state.get("current"):
            state["current"] = active
        elif phase == "after" and state["current"] != active:
            state["rollback"] = state["current"]
            state["current"] = active
    keep = deployment_tags | {state.get("current"), state.get("rollback")} | running
    remove = []
    for image in images:
        if image["Id"] in in_use:
            continue
        for reference in image.get("RepoTags") or []:
            tag = image_tag(reference)
            if tag and tag not in keep:
                remove.append(reference)
    return state, sorted(set(remove))


def save_state(path, state):
    # The installer creates this root-owned directory outside the deploy tree.
    fd, temporary = tempfile.mkstemp(prefix=".state-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("before", "after"):
        raise ValueError("Usage: starfall-image-retention before|after")
    phase = sys.argv[1]
    root = Path.cwd()
    tags = read_deployment_tags(root)
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    ids = docker("image", "ls", "--quiet", "--no-trunc", "--filter", "reference=" + REPOSITORY + ":sha-*").split()
    images = json.loads(docker("image", "inspect", *sorted(set(ids)))) if ids else []
    container_ids = docker("container", "ls", "--all", "--quiet").split()
    containers = json.loads(docker("container", "inspect", *container_ids)) if container_ids else []
    state, remove = retention_plan(images, containers, tags, state, phase)
    # Persist rollback protection before attempting any deletion.
    save_state(STATE, state)
    print("Starfall image retention: current=%s rollback=%s; %d old tags eligible" %
          (state.get("current"), state.get("rollback"), len(remove)), flush=True)
    for reference in remove:
        # Removing by tag preserves aliases; no --force and no generic prune.
        result = subprocess.run(["/usr/bin/docker", "image", "rm", reference], check=False)
        if result.returncode:
            print("Kept image Docker could not remove: " + reference, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print("Starfall image cleanup skipped: " + str(error), file=sys.stderr)
        sys.exit(1)
