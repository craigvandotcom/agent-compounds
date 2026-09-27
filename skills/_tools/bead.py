#!/usr/bin/env python3
"""bead.py — the one bead reader every tool parses cards through (ac-m9y4.1).

Canon: skills/beads-standards/reference/bead-schema.md (the plan that beadified this file:
_plans/_done/2026-09-27-1331-one-bead-model.md, deliverable D2).

Three Delivers extractors (`delivers-paths.sh`, `needs-device-gate.sh`'s own `extract_paths()`,
an inline pipeline in `close-evidence-check.sh`), a `dependency_type` reader in five scripts,
and eight `is_open` predicates each re-derive one fact their own way — a card can pass one
check and fail the next. This module is the one parser: thin adapters normalise a bead that
EXISTS (`br show --json`, a `.beads/issues.jsonl` row) and a bead being FILED (`br create`
argv, a markdown draft) into one canonical shape, and a handful of plain-text extractors read
that shape's `description` body — the same extractors a PLAN's own `## Deliverables` section
can call, since they take plain text, never a bead object.

OUT OF SCOPE (this bead, ac-m9y4.1): the `check` subcommand and its refusal rules
(ac-m9y4.2); moving any existing gate onto this reader (the D3 beads). This file parses;
it does not judge.

Canonical bead dict (every adapter below returns this shape):
    {
      "id": str | None,
      "title": str,
      "description": str,
      "status": str,
      "issue_type": str,
      "priority": int | None,
      "labels": [str, ...],
      "dependencies": [{"id": str, "dependency_type": str | None}, ...],
      "parent": str | None,
      "comments": [dict, ...],
    }
"""
from __future__ import annotations

import json
import os
import re
import subprocess

# ---------------------------------------------------------------------------
# `br --json` adapter — envelope-safe. Reads `br` itself, so this file joins
# lint 36's SANCTIONED list beside bead-artifact.py (its python twin).
# ---------------------------------------------------------------------------


def _run_br(args, timeout=30):
    """A wedged `br` must not hang every caller forever — bounded, same shape as a
    refused read (empty stdout, non-zero rc) so callers need no third branch."""
    try:
        r = subprocess.run(["br", *args], capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, "", f"br {' '.join(args)} timed out after {timeout}s"
    return r.returncode, r.stdout or "", r.stderr or ""


def read_bead(bead_id):
    """`br show --json <id>` -> (bead-dict, None) or (None, error-string).

    With --json, a `br` failure is a VALID error envelope on stdout at rc 0 with an
    EMPTY stderr — a raw decode reads that as "a bead with nothing on it" instead of
    a failed read. Mirrors bead-artifact.py's `show()`.
    """
    rc, out, err = _run_br(["show", "--json", bead_id])
    if rc != 0 or not out.strip():
        return None, f"br show exited {rc}: {err.strip()[:200]}"
    try:
        data = json.loads(out)
    except json.JSONDecodeError as exc:
        return None, f"br show returned unparseable JSON: {exc}"
    return from_br_json(data)


def from_br_json(data):
    """Normalise a `br show --json` payload — a dict, a one-element array, or an
    error envelope — into the canonical bead dict. Returns (dict, None) or
    (None, error-string)."""
    if isinstance(data, dict) and "error" in data:
        err_body = data.get("error")
        msg = err_body.get("message") if isinstance(err_body, dict) else err_body
        return None, f"br-read-failed: {msg}"
    if isinstance(data, list):
        if not data:
            return None, "br show returned an empty array — the id did not resolve"
        data = data[0]
    if not isinstance(data, dict):
        return None, f"br show returned an unexpected shape: {type(data).__name__}"
    data = data.get("issue", data)
    return _canonical(data, dep_key="dependency_type", target_key="id"), None


def from_jsonl_row(row):
    """Normalise one `.beads/issues.jsonl` row (an already-parsed dict) into the
    canonical bead dict. Same field names as `br show --json` EXCEPT each
    `dependencies` edge carries `type`/`depends_on_id` where `br show` carries
    `dependency_type`/`id` — the exact normalisation the plan names."""
    if not isinstance(row, dict):
        return None, f"jsonl row is not an object: {type(row).__name__}"
    return _canonical(row, dep_key="type", target_key="depends_on_id"), None


def _canonical(data, dep_key, target_key):
    deps = []
    for edge in data.get("dependencies") or []:
        if not isinstance(edge, dict):
            continue
        tid = edge.get(target_key)
        if not tid:
            continue
        deps.append({"id": tid, "dependency_type": edge.get(dep_key)})
    return {
        "id": data.get("id"),
        "title": data.get("title") or "",
        "description": data.get("description") or "",
        "status": data.get("status") or "",
        "issue_type": data.get("issue_type") or "task",
        "priority": data.get("priority"),
        "labels": labels_of(data.get("labels")),
        "dependencies": deps,
        "parent": data.get("parent") or data.get("parent_id"),
        "comments": data.get("comments") or [],
    }


# ---------------------------------------------------------------------------
# A bead being FILED, not yet on the board: `br create` argv, or a markdown draft.
# ---------------------------------------------------------------------------


def _flag_value(tokens, names, prefixes):
    """Value of the first matching flag, in two-token, `=`-joined, or attached form
    (same shape as hooks/bead-capture-guard.py's `flag_value`)."""
    for i, tok in enumerate(tokens):
        if tok in names:
            if i + 1 < len(tokens):
                return tokens[i + 1]
        for p in prefixes:
            if tok.startswith(p) and len(tok) > len(p):
                return tok[len(p):]
    return None


def from_create_argv(argv):
    """Normalise a `br create` (or `br q`) argv list into the canonical bead dict.
    Thin: title, description, issue_type, labels and parent only — a bead being
    filed has no id, status (`open` by convention), dependencies or comments yet.
    `argv` may or may not carry the leading `br create` tokens."""
    tokens = list(argv)
    if tokens and tokens[0].rsplit("/", 1)[-1] == "br":
        tokens = tokens[1:]
    if tokens and tokens[0] in ("create", "q"):
        tokens = tokens[1:]

    title = _flag_value(tokens, {"--title"}, ("--title=",))
    if title is None:
        for tok in tokens:
            if not tok.startswith("-"):
                title = tok
                break

    desc = _flag_value(tokens, {"-d", "--description", "--body"}, ("--description=", "--body="))
    desc_file = _flag_value(tokens, {"--description-file"}, ("--description-file=",))
    if desc is None and desc_file and desc_file not in ("-",) and os.path.isfile(desc_file):
        try:
            with open(desc_file, "r", encoding="utf-8", errors="replace") as fh:
                desc = fh.read()
        except OSError:
            desc = None

    issue_type = _flag_value(tokens, {"-t", "--type"}, ("--type=",)) or "task"

    labels = []
    for i, tok in enumerate(tokens):
        val = None
        if tok in ("-l", "--labels"):
            if i + 1 < len(tokens):
                val = tokens[i + 1]
        elif tok.startswith("--labels="):
            val = tok.split("=", 1)[1]
        elif tok.startswith("-l") and len(tok) > 2:
            val = tok[2:]
        if val:
            labels.extend(p.strip() for p in val.split(",") if p.strip())

    return {
        "id": None,
        "title": title or "",
        "description": desc or "",
        "status": "open",
        "issue_type": issue_type,
        "priority": None,
        "labels": labels,
        "dependencies": [],
        "parent": _flag_value(tokens, {"--parent"}, ("--parent=",)),
        "comments": [],
    }


_TITLE_HEADING_RE = re.compile(r"^#\s+(.*\S)\s*$")
_TITLE_FIELD_RE = re.compile(r"^Title:\s*(.*\S)\s*$", re.IGNORECASE)


def from_markdown(text):
    """Normalise a bead drafted as a markdown document — a leading `# Title`
    heading or a `Title:` field line, with the remainder as the description body —
    into the canonical bead dict. A bead staged as a file before `br create` ever
    runs (an ac-beadify draft, a PLAN's own body) shares this shape."""
    lines = (text or "").splitlines()
    title = ""
    body_start = 0
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        m = _TITLE_HEADING_RE.match(line) or _TITLE_FIELD_RE.match(line)
        if m:
            title = m.group(1).strip()
            body_start = i + 1
        break  # only the FIRST non-blank line is ever a title line
    description = "\n".join(lines[body_start:]).lstrip("\n")
    return {
        "id": None,
        "title": title,
        "description": description,
        "status": "open",
        "issue_type": "task",
        "priority": None,
        "labels": [],
        "dependencies": [],
        "parent": None,
        "comments": [],
    }


def labels_of(value):
    """Labels as a list, whichever shape the source carries them in — a list
    (`br show --json`, a jsonl row) or a comma-joined string (an argv `-l` value)."""
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    if isinstance(value, str):
        return [p.strip() for p in value.split(",") if p.strip()]
    return []


# ---------------------------------------------------------------------------
# Plain-text extractors over a `description` body. Take plain text, never a bead
# object, so a PLAN's own `## Deliverables` section can call the same extractor a
# bead's `## Delivers` uses (`heading=` on `delivers()`).
# ---------------------------------------------------------------------------

_SECTION_RE_CACHE = {}


def section(text, name):
    """The body of `## <name>` up to the next `## ` heading, or the end of text."""
    pattern = _SECTION_RE_CACHE.get(name)
    if pattern is None:
        pattern = re.compile(
            r"^##[ \t]*" + re.escape(name) + r"[ \t]*\n(.*?)(?=^##[ \t]|\Z)",
            re.MULTILINE | re.DOTALL,
        )
        _SECTION_RE_CACHE[name] = pattern
    m = pattern.search(text or "")
    return m.group(1) if m else ""


_PROBE_RE = re.compile(r"Probe:\s*`([^`]*)`")


def probes(text):
    """Every `Probe: \\`<command>\\`` line's command, in document order."""
    return _PROBE_RE.findall(text or "")


# --- Consumes: `<blocker-id> -> <artifact>` / `→`; `none`; a `<placeholder>` ------------

_PLACEHOLDER_RE = re.compile(r"<[^>]*>")
_BLOCKER_ID_RE = re.compile(r"^([A-Za-z][A-Za-z0-9._-]*)")


def consumes(text):
    """Every `## Consumes` line as `{"raw","blocker","artifact","placeholder"}`.
    Accepts `->` and the unicode `→` (normalised to `->`); the literal word `none`
    (any case, optional trailing period), alone, declares zero entries. An artifact
    naming an unfilled `<placeholder>` is flagged `placeholder: True` so a caller can
    refuse it — this reader never refuses on its own (OUT: the check subcommand,
    ac-m9y4.2)."""
    body = (text or "").strip()
    if not body or re.match(r"^none\.?$", body, re.IGNORECASE):
        return []
    out = []
    for raw_line in body.splitlines():
        line = re.sub(r"^[ \t]*[-*][ \t]*", "", raw_line.strip())
        line = line.replace("→", "->")
        if not line or re.match(r"^none\.?$", line, re.IGNORECASE):
            continue
        if "->" not in line:
            continue
        blocker_part, _, artifact_part = line.partition("->")
        m = _BLOCKER_ID_RE.match(blocker_part.strip())
        blocker = m.group(1).rstrip("-._") if m else None
        artifact = artifact_part.strip() or None
        placeholder = bool(artifact and _PLACEHOLDER_RE.search(artifact))
        out.append({
            "raw": raw_line,
            "blocker": blocker,
            "artifact": artifact,
            "placeholder": placeholder,
        })
    return out


# --- Delivers: whole-word paths, repo-root files, `.hidden/path`, `~/cross-repo`, ------
# --- the `deleted-<kind>:` grammar, and the touchers-line exclusion (defined ONCE) -----

ARTIFACT_RE = re.compile(
    r"(?<![\w./-])(?:\./)?(?:"
    r"~/[A-Za-z0-9_@.()\[\]-]+(?:/[A-Za-z0-9_@.()\[\]-]+)*"                      # ~/cross-repo path
    r"|\.[A-Za-z0-9_@()\[\]-]+(?:/[A-Za-z0-9_@.()\[\]-]+)+(?:\.[A-Za-z0-9]{1,10})?"  # .hidden/path (ext optional)
    r"|[A-Za-z0-9_@()\[\]-]+(?:/[A-Za-z0-9_@.()\[\]-]+)+\.[A-Za-z0-9]{1,10}"     # dir/dir/file.ext
    r"|[A-Za-z0-9_@()\[\]-]+\.[A-Za-z0-9]{1,10}"                                 # repo-root file.ext
    r")(?![\w/-])"
)

# A dotted CHILD BEAD ID (`ac-2h8w.3`) is path-shaped to ARTIFACT_RE but is not a file —
# the same exclusion close-evidence-check.sh already applies inline (this is that one home).
_BEAD_ID_SHAPE_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)+(\.[0-9]+)+$")

_DELETED_KIND_RE = re.compile(r"^[ \t]*[-*][ \t]*deleted-([A-Za-z0-9_-]+):")
_TOUCHERS_LINE_RE = re.compile(r"^[ \t]*touchers:")
_BULLET_RE = re.compile(r"^[ \t]*[-*][ \t]")


def extract_paths(text):
    """Whole-word path-shaped tokens in plain text, sorted and deduped."""
    out = []
    for m in ARTIFACT_RE.finditer(text or ""):
        tok = m.group(0)
        if _BEAD_ID_SHAPE_RE.match(tok):
            continue
        out.append(tok)
    return sorted(set(out))


def is_cross_repo(path):
    return bool(path) and path.startswith("~/")


def expand_cross_repo(path):
    return os.path.expanduser(path) if is_cross_repo(path) else path


def delivers(text, heading="Delivers"):
    """Every `## <heading>` bullet (default `Delivers`; pass `heading="Deliverables"`
    for a plan) as `{"path","paths","deleted_kind","touchers","raw"}`.

    A `deleted-<kind>:` bullet promises the artifact's ABSENCE — the deletion IS the
    deliverable — so `deleted_kind` carries the kind while `path` still names the
    (absent) artifact. The bullet's own `touchers:` line is excluded from path
    extraction (it names paths inside its own `-g` glob and reason, never a
    delivery) but is returned verbatim for a caller that wants it — ONE home for
    the exclusion every one of the four existing readers duplicated inline."""
    body = section(text, heading)
    numbered = []
    block_idx = -1
    for line in body.splitlines():
        if _BULLET_RE.match(line):
            block_idx += 1
        numbered.append((block_idx, line))
    max_idx = max((i for i, _ in numbered), default=-1)

    out = []
    for want in range(0, max_idx + 1):
        block_lines = [ln for i, ln in numbered if i == want]
        if not block_lines:
            continue
        block = "\n".join(block_lines)
        touchers_line = next(
            (ln.strip() for ln in block_lines if _TOUCHERS_LINE_RE.match(ln)), None
        )
        content = "\n".join(ln for ln in block_lines if not _TOUCHERS_LINE_RE.match(ln))
        dm = _DELETED_KIND_RE.match(block_lines[0])
        deleted_kind = dm.group(1) if dm else None
        paths = extract_paths(content)
        out.append({
            "path": paths[0] if paths else None,
            "paths": paths,
            "deleted_kind": deleted_kind,
            "touchers": touchers_line,
            "raw": block,
        })
    return out


# --- is_open / gate_kind — the two predicates every other reader re-derives -----------


def is_open(status):
    """`closed` is the sole terminal state — `open`, `in_progress` and `blocked`
    are all still open work. Blocking logic (a Consumes blocker, a dependency edge)
    reads this same axis: a blocker is satisfying only once it is `closed`."""
    return (status or "").strip().lower() != "closed"


_GATE_PREFIX_RE = re.compile(r"^([A-Za-z]+):")
_GATE_PREFIX_KIND = {"DECISION": "DECISION", "HUMAN": "DECISION", "ACTION": "ACTION"}


def gate_kind(title):
    """`DECISION` for a `DECISION:`/`HUMAN:` title, `ACTION` for `ACTION:`, else
    `None` — docket.sh's binary split and lint 19's `PREFIX_KIND` both already map
    `HUMAN:` to the decision side; this is the third reader that must agree."""
    m = _GATE_PREFIX_RE.match((title or "").strip())
    if not m:
        return None
    return _GATE_PREFIX_KIND.get(m.group(1).upper())
