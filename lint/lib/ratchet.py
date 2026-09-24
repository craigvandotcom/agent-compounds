"""ratchet — the one allowlist format and the one shrink-only growth ratchet.

Format (every lint/allowlists/*.txt file):

    DATE key  # why

`DATE` is `YYYY-MM-DD` — the day the exception was admitted. `key` is one
whitespace-free token (a path, a skill name — whatever the check's
population keys on). A trailing `# why` comment is optional and never
parsed for meaning: one line, one exception, one auditable cost.

A line whose first non-space character is `#`, and a blank line, are pure
comment (the file's own header prose) and are ignored. Any other line MUST
match the format; `load_allowlist()` reports one that doesn't as a defect
string — never a crash, never a silent drop.

The growth ratchet: `base_ref()` resolves the commit an allowlist may not
have grown since (a line admitted today has nothing to compare against yet
— that IS the seed). `committed_keys()` reads a path's key set AS COMMITTED
at that base, None when the path did not exist there (the seed case).
`shrink_only()` is the diff itself: any key in the current file absent from
the committed one is growth, refused.

This is the ONE copy: checks 25, 29 and 31 (and 28, through its own
resolves-based reading) all parse through `load_allowlist`/`keys`, and 25/29/31
also share `base_ref`/`committed_keys`/`shrink_only` for their committed-base
growth check. A check's own file never redefines any of these.
"""

import os
import re
import subprocess

ENTRY = re.compile(r"^(\d{4}-\d{2}-\d{2})\s+(\S+)(?:\s+#.*)?$")
DEFAULT_BASE_REF = "origin/main"


def load_allowlist(path):
    """Parse one allowlist file. Returns (entries, defects).

    entries: list of (date, key) tuples in file order — the date is exposed
    for a caller that wants to report admission age (none does today).
    defects: list of "<path>:<lineno>: ..." strings, one per non-comment
    line that does not match `DATE key [# why]`.
    """
    entries, defects = [], []
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = ENTRY.match(line)
            if not m:
                defects.append(f"{path}:{lineno}: not `YYYY-MM-DD key  # why` — {line!r}")
                continue
            entries.append((m.group(1), m.group(2)))
    return entries, defects


def keys(path):
    """The key column only, as a list in file order. A caller that must
    surface malformed lines calls `load_allowlist` directly instead."""
    entries, _ = load_allowlist(path)
    return [k for _, k in entries]


def _git(root, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


def base_ref(root, default=DEFAULT_BASE_REF):
    """The commit an allowlist may not have grown since.

    `LINT_BASE_REF` env wins when set and resolvable — CI sets it to the
    pre-push SHA (`${{ github.event.before }}`, or the PR base sha on a
    pull_request event) so the ratchet judges against what was actually on
    the branch before, not a `origin/main` that a squash or force-push can
    move out from under a commit still in flight. Otherwise `default`
    (merge-base with HEAD). Falls back to HEAD^ (one commit back — the unit
    of review) when neither resolves. Returns "" when nothing does (a
    shallow or standalone checkout) — the caller's cue to skip the ratchet
    this run and say so, never a crash and never a false pass.
    """
    ref = os.environ.get("LINT_BASE_REF") or default
    if ref and _git(root, "rev-parse", "--verify", "--quiet", ref):
        b = _git(root, "merge-base", ref, "HEAD")
        if b:
            return b
    head = _git(root, "rev-parse", "--verify", "--quiet", "HEAD")
    if head and _git(root, "rev-parse", "--verify", "--quiet", "HEAD^"):
        return _git(root, "rev-parse", "HEAD^")
    return ""


def committed_keys(root, base, rel_path):
    """The key set of `rel_path` (repo-relative) as committed at `base`.

    None when the path did not exist there — the seed case: the file's
    first landing has no committed version, and the ratchet starts the
    moment one does. Tolerant of a dateless format (a bare path or skill
    name, no date): a non-comment line that is not `DATE key` is read
    whole as the key.
    """
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, "show", f"{base}:{rel_path}"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        return None
    out = []
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = ENTRY.match(line)
        out.append(m.group(2) if m else line)
    return out


def shrink_only(current, committed):
    """Keys in `current` (iterable) absent from `committed` (iterable, or
    None for the seed case) — the growth set. Empty when the allowlist only
    shrank or held, or when `committed` is None (nothing to compare yet)."""
    if committed is None:
        return []
    return sorted(set(current) - set(committed))
