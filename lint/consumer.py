#!/usr/bin/env python3
"""consumer.py — the install verifier (ac-6asz.2): is a stamped target actually installed?

Usage: lint/consumer.py <target-root>

Verifies, against the registry manifest (skills/packages.json, read through
lint/lib/manifest.py — never a second reader):
  1. factory.json present in the target, valid JSON, no unknown keys, and every
     key a declared package `requires` present and filled (no `<SET:` remnant,
     nothing empty) — a missing manifest or an unfilled key is a named failure,
     never a silent pass.
  2. the path-valued keys name files/dirs that exist under the target root.
  3. .claude/settings.json exists and carries the documented consumer keys.
  4. the stamped skill homes' symlinks all resolve (real dirs are local
     customizations and are left alone; only dangling links fail).

Exit codes as lint/run.py: 0 clean, 1 named failure(s), 2 usage error or the
target resolves to nothing scannable (NOT-GATED, never a pass). WS6 calls this
per matrix cell.
"""

import json
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "lib"))
from manifest import (  # noqa: E402
    ManifestMissing,
)
from manifest import (  # noqa: E402
    factory as read_factory_template,
)
from manifest import (  # noqa: E402
    packages as read_packages,
)

CHECK = "consumer"
REGISTRY_ROOT = os.path.dirname(_HERE)

# Top-level factory.json keys whose values are paths under the target root
# (serve_prod / ci_gate_script are commands; store / triage / human leaves are
# ids and names — those are fill-checked, never existence-checked).
PATH_KEYS = ("design_spec", "journeys_dir", "routes_manifest",
             "routes_public_manifest", "ui_audit")
# Nested path leaves, as key tuples from the instance root.
NESTED_PATH_KEYS = (("memory", "root"),)

# The documented consumer settings keys every deploy target carries
# (AGENTS.md distribution policy).
SETTINGS_KEYS = {"skillListingBudgetFraction": 0.02}

# Stamped skill homes, in preference order; the first is required (the canonical
# stamp), the rest are verified only when present.
REQUIRED_HOME = os.path.join(".claude", "skills")
OPTIONAL_HOMES = (os.path.join(".agents", "skills"),)

failures = []


def fail(msg):
    failures.append(f"{CHECK}: FAIL: {msg}")


def filled(value):
    """A filled manifest leaf: present, non-empty, no `<SET:` placeholder left."""
    if value is None:
        return False
    if isinstance(value, dict):
        return bool(value) and all(filled(v) for v in value.values())
    if isinstance(value, str):
        return bool(value.strip()) and "<SET:" not in value
    return True


def main(argv):
    if len(argv) != 2:
        print(f"{CHECK}: usage: lint/consumer.py <target-root>", file=sys.stderr)
        return 2
    target = argv[1]
    if not os.path.isdir(target):
        print(f"{CHECK}: NOT-GATED — target is not a directory: {target}; "
              f"nothing was scanned (this is NOT a pass)", file=sys.stderr)
        return 2

    try:
        pkgs = read_packages(REGISTRY_ROOT)
        template = read_factory_template(REGISTRY_ROOT)
    except ManifestMissing as e:
        print(f"{CHECK}: NOT-GATED — {e}; the registry side is broken, "
              f"so no target verdict is available (this is NOT a pass)", file=sys.stderr)
        return 2
    if not isinstance(pkgs, dict) or not pkgs:
        print(f"{CHECK}: NOT-GATED — registry manifest declares no packages; "
              f"nothing to verify against (this is NOT a pass)", file=sys.stderr)
        return 2
    template_keys = {k for k in template if not k.startswith("_")}

    required = set()
    for name, pkg in pkgs.items():
        if name.startswith("_"):
            continue
        for key in (pkg.get("requires") or []):
            if key not in template_keys:
                fail(f"registry manifest defect: package '{name}' requires "
                     f"'{key}', which templates/factory.json does not name")
            required.add(key)

    manifest_path = os.path.join(target, "factory.json")
    if not os.path.isfile(manifest_path):
        fail(f"no manifest: {manifest_path} is missing — the target is not installed")
    else:
        try:
            with open(manifest_path, encoding="utf-8") as fh:
                instance = json.load(fh)
        except json.JSONDecodeError as e:
            instance = None
            fail(f"manifest unreadable (malformed JSON): {manifest_path}: {e}")
        if instance is not None:
            if not isinstance(instance, dict):
                fail(f"manifest not an object: {manifest_path}")
            else:
                have = {k for k in instance if not k.startswith("_")}
                for key in sorted(have - template_keys):
                    fail(f"manifest carries key '{key}' templates/factory.json "
                         f"does not name — schema drift is deliberate or it is a defect")
                for key in sorted(required):
                    if key not in instance:
                        fail(f"package-required key '{key}' missing from {manifest_path}")
                    elif not filled(instance[key]):
                        fail(f"package-required key '{key}' unfilled in {manifest_path} "
                             f"(empty or carrying a '<SET:' placeholder)")
                for key in PATH_KEYS:
                    val = instance.get(key)
                    if isinstance(val, str) and val.strip() and "<SET:" not in val:
                        if not os.path.exists(os.path.join(target, val)):
                            fail(f"key '{key}' names '{val}', which does not exist "
                                 f"under {target}")
                for path in NESTED_PATH_KEYS:
                    node = instance
                    for part in path:
                        node = node.get(part) if isinstance(node, dict) else None
                    if isinstance(node, str) and node.strip() and "<SET:" not in node:
                        if not os.path.exists(os.path.join(target, node)):
                            fail(f"key '{'.'.join(path)}' names '{node}', which does "
                                 f"not exist under {target}")

    settings_path = os.path.join(target, ".claude", "settings.json")
    if not os.path.isfile(settings_path):
        fail(f"no consumer settings: {settings_path} is missing — the target carries none of the consumer keys")
    else:
        try:
            with open(settings_path, encoding="utf-8") as fh:
                settings = json.load(fh)
        except json.JSONDecodeError as e:
            settings = None
            fail(f"consumer settings unreadable (malformed JSON): {settings_path}: {e}")
        if isinstance(settings, dict):
            for key, want in SETTINGS_KEYS.items():
                if key not in settings:
                    fail(f"consumer settings lack '{key}' in {settings_path}")
                elif settings[key] != want:
                    fail(f"consumer settings key '{key}' is {settings[key]!r}, "
                         f"documented value is {want!r} ({settings_path})")

    homes = [(REQUIRED_HOME, True)] + [(h, False) for h in OPTIONAL_HOMES]
    for home, required_home in homes:
        home_dir = os.path.join(target, home)
        if not os.path.isdir(home_dir):
            if required_home:
                fail(f"no stamped skills: {home_dir} is missing — the target carries no install to verify")
            continue
        links = 0
        for entry in sorted(os.listdir(home_dir)):
            full = os.path.join(home_dir, entry)
            if os.path.islink(full):
                links += 1
                if not os.path.exists(full):
                    fail(f"dangling symlink: {os.path.join(home, entry)} "
                         f"-> {os.readlink(full)} (target does not exist)")
        if required_home and links == 0:
            fail(
                f"nothing scanned: {home_dir} holds no symlinks — "
                "an install with no links is not an install (this is NOT a pass)"
            )

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"{CHECK}: ok — {os.path.abspath(target)} is installed "
          f"({len(required)} package-required key(s) filled, skill homes resolve)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
