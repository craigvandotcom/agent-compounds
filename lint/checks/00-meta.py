#!/usr/bin/env python3
# ---
# id: 00-meta
# prevents: an undeclared or unfired check (no id/prevents/scope/severity/fixture, or a fixture that does not go RED) scans nothing and passes
# scope: CHECKS
# severity: fail
# fixture: lint/checks/00-meta.test.sh
# ---
"""00-meta — the check on checks.

Every lint/checks file (test harnesses excluded) must carry a header declaring
id, prevents, scope, severity and fixture; `scope` must name a set that
lib.scope actually exposes; `warn` must carry an unexpired `expires` date; and
— except for this file, whose RED is its own test harness — running the check
against its declared fixture must go RED (exit 1). A check whose fixture exits
0 or 2 has a fixture that does not go RED, which is the vacuous-check class.

The check-file contract both this file and run.py honour:
  invocation   `python3 <check>.py [root]` / `bash <check>.sh [root]`
               root defaults to the real repo root; a given root (a fixture
               dir for the RED leg) is honoured via LINT_ROOT in lib.scope.
  exit 0       clean, and at least one file scanned
  exit 1       findings (or header/fixture defects, for this meta check)
  exit 2       scanned nothing — NOT-GATED, never a pass
"""

import os
import re
import subprocess
import sys
from datetime import date

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import frontmatter, scope  # noqa: E402

REQUIRED_FIELDS = ("id", "prevents", "scope", "severity", "fixture")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SELF_ID = "00-meta"

findings = []


def fail(msg):
    findings.append(msg)


def discover(root):
    checks_dir = os.path.join(root, "lint", "checks")
    if not os.path.isdir(checks_dir):
        return []
    out = []
    for fn in sorted(os.listdir(checks_dir)):
        if fn.endswith(".test.sh") or fn.startswith("00-meta"):
            continue
        if fn.endswith(".py") or fn.endswith(".sh"):
            out.append(os.path.join(checks_dir, fn))
    return out


def check_header(path):
    """Parse one check file's header. True = header fields hold."""
    rel = os.path.relpath(path, os.path.join(scope.ROOT))
    header = frontmatter.parse_file(path)
    if not header:
        fail(f"{rel}: no header block — id/prevents/scope/severity/fixture are undeclared")
        return False
    ok = True
    for field in REQUIRED_FIELDS:
        if not header.get(field):
            fail(f"{rel}: header field '{field}' missing")
            ok = False
    if not ok:
        return False
    stem = os.path.basename(path).rsplit(".", 1)[0]
    if header["id"] != stem:
        fail(f"{rel}: id '{header['id']}' does not match filename stem '{stem}'")
        ok = False
    if not isinstance(getattr(scope, header["scope"], None), frozenset):
        fail(f"{rel}: scope '{header['scope']}' names no set in lib.scope")
        ok = False
    if header["severity"] not in ("fail", "warn"):
        fail(f"{rel}: severity '{header['severity']}' is neither fail nor warn")
        ok = False
    if header["severity"] == "warn":
        exp = str(header.get("expires", ""))
        if not DATE.match(exp):
            fail(f"{rel}: severity warn requires expires: YYYY-MM-DD")
            ok = False
        elif exp < date.today().isoformat():
            fail(f"{rel}: severity warn expired {exp} — it must now fail")
            ok = False
    fx = str(header["fixture"])
    if not os.path.exists(os.path.join(scope.ROOT, fx)):
        fail(f"{rel}: fixture '{fx}' does not exist")
        ok = False
    return ok


def fixture_goes_red(path, header):
    """Run the check against its fixture; RED means exit 1."""
    fx = os.path.join(scope.ROOT, str(header["fixture"]))
    cmd = [sys.executable, path, fx] if path.endswith(".py") else ["bash", path, fx]
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", os.path.expanduser("~")),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "LINT_ROOT": fx,
    }
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120, env=env)
    if proc.returncode == 1:
        return True
    rel = os.path.relpath(path, scope.ROOT)
    if proc.returncode == 0:
        fail(f"{rel}: fixture {header['fixture']} does NOT go RED — the check passed against its own RED case")
    else:
        fail(f"{rel}: fixture leg NOT-GATED — running against {header['fixture']} exited {proc.returncode}, not a RED")
    return False


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    # Self-audit: this file's own header must hold too — but only when the
    # audited root IS the root it lives in (a fixture tree has no 00-meta).
    self_path = os.path.join(_HERE, "00-meta.py")
    scanned = 0
    if os.path.isfile(os.path.join(scope.ROOT, "lint", "checks", "00-meta.py")):
        scanned = 1
        check_header(self_path)

    others = discover(scope.ROOT)
    for path in others:
        scanned += 1
        if check_header(path):
            fixture_goes_red(path, frontmatter.parse_file(path))
            scanned += 1  # the fixture run scanned too

    if scanned == 0:
        print("00-meta NOT-CHECKED: no check files found under lint/checks — verified nothing", file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL 00-meta: {f}")
    if findings:
        return 1
    print(f"  ok: 00-meta — {scanned} header(s) validated, every fixture leg fired or is self-proven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
