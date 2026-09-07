"""manifest — readers for the consumer/registry manifests lint v2 checks read.

  packages(root)  -> skills/packages.json  (per-package budgets; lands with WS3)
  factory(root)   -> templates/factory.json (consumer manifest schema)

Both raise ManifestMissing (an OSError subclass) with a named message when the
file is absent — a check reading a missing manifest must fail loud, never scan
nothing and pass.
"""

import json
import os


class ManifestMissing(OSError):
    pass


def _read(path):
    if not os.path.isfile(path):
        raise ManifestMissing(f"manifest missing: {path}")
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as e:
        raise ManifestMissing(f"manifest unreadable (malformed JSON): {path}: {e}") from e


def packages(root):
    return _read(os.path.join(root, "skills", "packages.json"))


def factory(root):
    return _read(os.path.join(root, "templates", "factory.json"))
