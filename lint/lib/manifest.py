"""manifest — readers for the consumer/registry manifests lint v2 checks read.

  packages(root)  -> skills/packages.json  (per-package budgets; lands with WS3)
  factory(root)   -> templates/factory.json (consumer manifest schema)
  validate(path)  -> a filled instance checked against the template's keys

All readers raise ManifestMissing (an OSError subclass) with a named message
when the file is absent — a check reading a missing manifest must fail loud,
never scan nothing and pass. validate() fails loud on malformed JSON, on a
key the template names but the instance lacks, and on a key the template does
not name (schema drift is deliberate or it is a defect); keys starting with
"_" are reserved comments and exempt both ways.
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


def _keys(obj):
    return {k for k in obj if not k.startswith("_")}


def packages(root):
    return _read(os.path.join(root, "skills", "packages.json"))


def factory(root):
    return _read(os.path.join(root, "templates", "factory.json"))


def validate(path, template_root=None):
    """Check a filled manifest against the template's key set. Returns the instance.

    Raises ManifestMissing naming the defect: unreadable JSON, a key the
    template names that the instance lacks, or a key the template does not
    name. '_' keys are comments, exempt from the comparison. template_root
    defaults to THIS repo (the registry — where templates/factory.json lives),
    derived from this module's own location, so an instance validated from an
    app repo still finds the template.
    """
    instance = _read(path)
    if template_root is None:
        template_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))))
    template = _read(os.path.join(template_root, "templates", "factory.json"))
    if not isinstance(instance, dict) or not isinstance(template, dict):
        raise ManifestMissing(f"manifest not an object: {path}")
    want, have = _keys(template), _keys(instance)
    missing = sorted(want - have)
    unknown = sorted(have - want)
    if missing:
        raise ManifestMissing(f"manifest missing key(s) the template names: {path}: {missing}")
    if unknown:
        raise ManifestMissing(f"manifest carries key(s) the template does not name: {path}: {unknown}")
    return instance
