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

`bead.py check <id|file>` (ac-m9y4.2) holds every rule a script can MEASURE — probe RED at
HEAD, banned probe shapes, touchers freshness (delegates to touchers.sh), a Consumes artifact
existing or promised by its blocker's own Delivers, a Delivers path never a symlink into
another repo, exactly one `origin:` label, `refined` never beside `human-gate`, and
`sensitive-prod` derived by calling prod-write-tripwire.sh (never a second copy of its rule).
Exit 0 clean, 1 refused (each refusal named on stderr), 2 NOT-GATED (the input, a blocker, or
a called tool could not be read/run — never silently treated as clean). A human-gate bead is
exempt from the probe-rule legs only (a ruled exemption — the plan's Decisions section);
every other leg still runs.

OUT OF SCOPE (this bead, ac-m9y4.2): moving any EXISTING gate onto this reader (the D3
beads — flight-check.sh, stamp-refined.sh, etc. keep their own copies until their own bead
lands). This file parses and checks; it does not yet replace anything.

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
import shlex
import shutil
import subprocess
import sys
import tempfile

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


def parent_child_children(show_data):
    """The ids from a `br show <epic> --json` payload's OWN `dependents` list that carry
    a parent-child edge — the epic's children, read from the PARENT side (the mirror of
    `dependencies`, which `from_br_json`/`_canonical` already normalise from the CHILD
    side; `br show` never puts the reverse edge in `dependencies`, so a second reader is
    needed here rather than a second call into that one). Accepts the same envelope
    shapes as `from_br_json` (dict, array-of-one, error envelope). Returns (ids, None) —
    `ids` may be empty — or (None, error-string)."""
    if isinstance(show_data, dict) and "error" in show_data:
        err_body = show_data.get("error")
        msg = err_body.get("message") if isinstance(err_body, dict) else err_body
        return None, f"br-read-failed: {msg}"
    if isinstance(show_data, list):
        if not show_data:
            return None, "br show returned an empty array — the id did not resolve"
        show_data = show_data[0]
    if not isinstance(show_data, dict):
        return None, f"br show returned an unexpected shape: {type(show_data).__name__}"
    ids = []
    for edge in show_data.get("dependents") or []:
        if not isinstance(edge, dict):
            continue
        eid = edge.get("id")
        if eid and edge.get("dependency_type") == "parent-child":
            ids.append(eid)
    return ids, None


def is_child_of(show_data, epic_id):
    """True when a `br show <bead> --json` payload's own (forward) `dependencies` carry
    a parent-child edge naming `epic_id` — the child's own view of the same edge
    `parent_child_children` reads from the parent's `dependents` list, routed through
    `from_br_json`'s existing normalisation rather than a second copy of it. Returns
    (bool, None) or (None, error-string)."""
    canon, err = from_br_json(show_data)
    if err:
        return None, err
    is_child = any(
        d["id"] == epic_id and d["dependency_type"] == "parent-child"
        for d in canon["dependencies"]
    )
    return is_child, None


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
        artifact_remainder = artifact_part.strip()
        # An unfilled placeholder is read over the WHOLE remainder — it may spell
        # itself as a multi-word sentence (`<the artifact ac-other promises>`), not
        # just one token. The artifact itself, once it is a real path rather than a
        # placeholder, is the first whitespace-delimited token after the arrow — a
        # trailing note (`(this bead stops the lane pushing; …)`, `(landed)`) is
        # commentary, never part of the path (fbde324c: "a Consumes artifact is a
        # whole word", settled earlier in flight-check.sh; this is that same rule's
        # one home now that flight-check reads Consumes through this reader).
        placeholder = bool(artifact_remainder and _PLACEHOLDER_RE.search(artifact_remainder))
        artifact_tokens = artifact_remainder.split()
        artifact = artifact_tokens[0] if artifact_tokens else None
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


# --- blocking_ids — the dependency_type axis, read once here (ac-m9y4.8) --------------


def blocking_ids(canon):
    """The ids a bead is BLOCKED BY — every dependency edge whose axis is `blocks`.
    `parent-child` (an epic's own child edge) and `related` are never blockers; this is
    the one home for that select so a caller (bead-artifact.py's `blocking_deps`) never
    re-derives `dependency_type` by hand."""
    return [d.get("id") for d in (canon.get("dependencies") or [])
            if d.get("dependency_type") == "blocks"]


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


# =======================================================================================
# `bead.py check <id|file>` (ac-m9y4.2) — every rule a script can MEASURE, one refusing
# command. The plan's D2 list, each leg below named by which bullet it is. A bead handed
# in as an EXISTING FILE (an offline body dump, a fixture) carries no labels or
# dependencies — the label/dependency-scoped legs (origin, refined/human-gate,
# sensitive-prod) are skipped for that shape, never guessed at.
# =======================================================================================

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))


def _git_root():
    try:
        r = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    out = (r.stdout or "").strip()
    return out or None


# --- probe shapes: banned, and "does it even resolve" -----------------------------------

_SHELL_BUILTINS = {
    "test", "[", "cd", ":", ".", "source", "echo", "printf", "true", "false",
    "exit", "return", "export", "unset", "eval", "set",
}


def _leading_word(cmd):
    """The probe's leading command word, past a leading `!` negation."""
    toks = (cmd or "").strip().split()
    i = 0
    while i < len(toks) and toks[i] == "!":
        i += 1
    return toks[i] if i < len(toks) else ""


def probe_is_executable(cmd):
    """False when the probe's leading interpreter does not resolve on this PATH — the
    NOT-EXECUTED case (never a silent skip: the caller lists it, never drops it)."""
    lead = _leading_word(cmd)
    if not lead or lead.startswith("#") or "=" in lead:
        return True
    if lead in _SHELL_BUILTINS:
        return True
    return shutil.which(lead) is not None


def run_probe(cmd, timeout=60):
    """Run a probe once and return its exit code (124 on a timeout — bounded, per the
    bead's own Gotcha: probe execution must stay bounded, never watch a runaway)."""
    try:
        r = subprocess.run(
            ["sh", "-c", cmd],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=timeout,
        )
        return r.returncode
    except subprocess.TimeoutExpired:
        return 124
    except OSError:
        return 127


def _has_grep_dash_c(cmd):
    """A `grep`/`rg`/`egrep`/`fgrep` clause carrying a `-c`/`--count` flag: bare count
    output always exits 0 on any match, so a probe naming only the count proves nothing
    unless the count is compared — banned outright per the plan's D2 list."""
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        tokens = cmd.split()
    n = len(tokens)
    i = 0
    while i < n:
        if tokens[i] in ("grep", "egrep", "fgrep", "rg"):
            j = i + 1
            while j < n and tokens[j] not in ("&&", "||", ";", "|"):
                tok = tokens[j]
                if tok == "--count":
                    return True
                if tok.startswith("-") and not tok.startswith("--") and "c" in tok[1:]:
                    return True
                j += 1
        i += 1
    return False


_VITEST_RUN_RE = re.compile(r"pnpm\s+exec\s+vitest\s+run\b")
_PNPM_WHOLE_TEST_RE = re.compile(r"\bpnpm\s+test(:all)?\s*(?:$|&&|\|\||;)")


def _is_bare_vitest_run(cmd):
    """`pnpm exec vitest run` with nothing scoping it to one file runs the WHOLE suite."""
    m = _VITEST_RUN_RE.search(cmd or "")
    if not m:
        return False
    rest = cmd[m.end():]
    first_seg = re.split(r"&&|\|\||;|\|", rest, maxsplit=1)[0].strip()
    return first_seg == "" or first_seg.startswith("-")


def _split_clauses(cmd):
    return [c.strip() for c in re.split(r"&&|\|\||;", cmd or "") if c.strip()]


def _is_echo_only(cmd):
    """Every top-level clause is a bare `echo` — an echo cannot fail, so a probe built
    entirely from them certifies nothing (a negated `! grep …` clause is NOT echo, and is
    deliberately never stripped here — it still runs something, unlike a bare `grep`)."""
    clauses = _split_clauses(cmd)
    if not clauses:
        return False
    return all(re.match(r"^echo(\s|$)", c) for c in clauses)


def probe_shape_violation(cmd):
    """The refused-shape reason for `cmd`, or `None` when it is clean. bead-schema.md
    § The probe rule / the plan's D2 refused-shapes list: `grep -c`, a bare whole-suite
    script (`pnpm exec vitest run` unscoped, `pnpm test`/`pnpm test:all` bare,
    `run-all-proofs.sh`), a destructive/whole-environment invocation (`supabase`,
    `db:reset`, `db:verify`), or every clause being an echo."""
    if not (cmd or "").strip():
        return None
    if _has_grep_dash_c(cmd):
        return ("bare `grep -c`/`--count` always exits 0 on any match count > 0; "
                "compare the count explicitly instead of naming the bare count")
    if re.search(r"\brun-all-proofs(?:\.sh)?\b", cmd):
        return "`run-all-proofs.sh` runs the WHOLE suite; name this bead's own test file instead"
    if _is_bare_vitest_run(cmd):
        return "bare `pnpm exec vitest run` runs the WHOLE suite; scope it to this bead's own test file"
    if _PNPM_WHOLE_TEST_RE.search(cmd):
        return "bare `pnpm test`/`pnpm test:all` runs the WHOLE suite; name this bead's own test file"
    if re.search(r"\bsupabase\b", cmd):
        return "invokes `supabase` directly; a probe never drives a live/whole-environment command"
    if re.search(r"\bdb:reset\b", cmd):
        return "invokes `db:reset`, which wipes data; a probe never runs a destructive command"
    if re.search(r"\bdb:verify\b", cmd):
        return "invokes `db:verify`, a whole-environment command; verify this bead's own artifact instead"
    if _is_echo_only(cmd):
        return "every clause is `echo`, which cannot fail; name a command that goes RED when the work is absent"
    return None


def probe_red_violations(probe_list, human_gate_exempt, timeout=60):
    """Every named probe RED at HEAD, plus the banned-shape leg — the plan's D2 bullets
    1-2 together, since both read the same probe list. Returns (refused, not_gated, info)
    — `info` carries the NOT-EXECUTED list (never a silent skip, never a refusal on its
    own: an unresolvable interpreter cannot be judged either way)."""
    if human_gate_exempt:
        return [], [], ["probe rule: skipped — a human-gate bead is exempt (a ruled exemption)"]
    refused = []
    info = []
    if not probe_list:
        return refused, [], info
    not_executed = []
    executed = []
    green = []
    for p in probe_list:
        reason = probe_shape_violation(p)
        if reason:
            refused.append(f"banned probe shape: `{p}` — {reason}")
            continue
        if not probe_is_executable(p):
            not_executed.append(p)
            continue
        executed.append(p)
        if run_probe(p, timeout=timeout) == 0:
            green.append(p)
    if not_executed:
        info.append("NOT-EXECUTED: " + "; ".join(f"`{p}`" for p in not_executed))
    if executed and len(green) == len(executed):
        refused.append(
            "RED: all %d executable probe(s) are already GREEN at HEAD (%s) — "
            "there is nothing left for this bead's work to flip"
            % (len(executed), "; ".join(f"`{p}`" for p in green))
        )
    return refused, [], info


# --- touchers freshness — delegates to touchers.sh, never a second copy of its rule -----


def touchers_freshness_check(desc, label=""):
    """Calls `touchers.sh check` on the description body. Returns (rc, message):
    0 OK, 1 REFUSED, 2 NOT-GATED. One home for the derivation (touchers.sh); this is
    only a caller."""
    touchers_path = os.path.join(_TOOLS_DIR, "touchers.sh")
    if not os.path.isfile(touchers_path):
        return 2, f"touchers.sh not found at '{touchers_path}'"
    fd, tmp = tempfile.mkstemp(prefix="bead-check-touchers-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(desc or "")
        r = subprocess.run(
            ["bash", touchers_path, "check", tmp, label or "description"],
            capture_output=True, text=True, timeout=60,
        )
        msg = (r.stderr or r.stdout or "").strip()
        return r.returncode, msg
    except subprocess.TimeoutExpired:
        return 2, "touchers.sh timed out"
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


# --- Consumes: exists on the tree, or promised by the blocker's own Delivers ------------


def consumes_violations(cons_entries, root, resolve_blocker=None):
    """An unfilled `<placeholder>` is always refused (the plan's canon: Consumes accepts
    `->`/`→` and `none`, never a placeholder). Otherwise: the artifact must already exist
    on the tree, OR the named blocker's own `## Delivers` must promise that exact path.
    `resolve_blocker` defaults to `read_bead` (a real `br show`); a caller injects a fake
    for a test that must not shell out. Returns (refused, not_gated)."""
    if resolve_blocker is None:
        resolve_blocker = read_bead
    refused = []
    not_gated = []
    for c in cons_entries:
        if c.get("placeholder"):
            refused.append(f"Consumes: unfilled <placeholder> artifact ({c['raw'].strip()})")
            continue
        artifact = c.get("artifact")
        if not artifact:
            continue
        full = expand_cross_repo(artifact) if is_cross_repo(artifact) else os.path.join(root, artifact)
        if os.path.exists(full):
            continue
        blocker = c.get("blocker")
        if not blocker:
            refused.append(f"Consumes: artifact '{artifact}' is absent from the tree and names no blocker to check a promise")
            continue
        bcanon, berr = resolve_blocker(blocker)
        if berr:
            not_gated.append(f"Consumes: cannot verify blocker '{blocker}' for artifact '{artifact}' — {berr}")
            continue
        bdelivers = delivers(bcanon.get("description", ""))
        promised = {p for d in bdelivers for p in d["paths"]}
        if artifact not in promised:
            refused.append(
                f"Consumes: artifact '{artifact}' is absent from the tree and blocker "
                f"'{blocker}' does not promise it in its own Delivers"
            )
    return refused, not_gated


# --- Delivers: never a symlink into another repo ----------------------------------------


def delivers_symlink_violations(delivers_entries, root):
    """A `## Delivers` path that resolves, via a symlink, OUTSIDE this repo — the
    canonical file lives elsewhere and this bead cannot claim to deliver it. A declared
    cross-repo `~/` path is a different, intentional shape and is exempt."""
    out = []
    root_real = os.path.realpath(root)
    for d in delivers_entries:
        for p in d.get("paths", []):
            if is_cross_repo(p):
                continue
            full = os.path.join(root, p)
            if not os.path.islink(full):
                continue
            resolved = os.path.realpath(full)
            if resolved == root_real or resolved.startswith(root_real + os.sep):
                continue
            out.append(
                f"Delivers: '{p}' is a symlink resolving outside this repo ({resolved}) — "
                "edit at the canonical source, or declare it as cross-repo with a ~/ path"
            )
    return out


# --- origin / refined-human-gate label rules --------------------------------------------

_ORIGIN_LABEL_RE = re.compile(r"^origin:[A-Za-z0-9]")


def origin_violation(labels):
    """Exactly one `origin:` label — zero is unattributed, two is corrupt data."""
    origins = [l for l in (labels or []) if _ORIGIN_LABEL_RE.match(l)]
    if len(origins) == 0:
        return "origin: no origin:<skill> label present"
    if len(origins) > 1:
        return f"origin: {len(origins)} origin: labels present ({', '.join(origins)}) — exactly one is required"
    return None


def refined_human_gate_violation(labels):
    """`refined` never beside `human-gate` — a human-gate bead is a decision/action for a
    human, never a worker claim."""
    labels = labels or []
    if "refined" in labels and "human-gate" in labels:
        return "refined: co-present with human-gate — a human-gate bead never carries refined"
    return None


# --- sensitive-prod — derived by calling prod-write-tripwire.sh, never a second copy ----


def sensitive_prod_check(desc, labels, decision_blocks_count, label=""):
    """Calls prod-write-tripwire.sh — the ONE home of the prod-write signal predicate.
    Returns (rc, message): 0 OK, 1 REFUSED, 2 NOT-GATED."""
    tripwire_path = os.path.join(_TOOLS_DIR, "prod-write-tripwire.sh")
    if not os.path.isfile(tripwire_path):
        return 2, f"prod-write-tripwire.sh not found at '{tripwire_path}'"
    fd, tmp = tempfile.mkstemp(prefix="bead-check-prodwrite-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(desc or "")
        labels_csv = ",".join(labels or [])
        r = subprocess.run(
            ["bash", tripwire_path, tmp, labels_csv, str(decision_blocks_count), label or "description"],
            capture_output=True, text=True, timeout=30,
        )
        msg = (r.stderr or r.stdout or "").strip()
        return r.returncode, msg
    except subprocess.TimeoutExpired:
        return 2, "prod-write-tripwire.sh timed out"
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def _decision_blocks_count(bead_id):
    """How many `blocks` dependency edges point at a `DECISION`-titled bead — read
    directly off `br show --json` (never through the canonical dependency dict, which
    drops `title` on purpose: adding it there would silently break every existing exact
    equality assertion the ac-m9y4.1 reader already shipped). Returns `None` on a
    cannot-check read, never a guessed zero."""
    rc, out, err = _run_br(["show", "--json", bead_id])
    if rc != 0 or not out.strip():
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    if isinstance(data, list):
        data = data[0] if data else {}
    if not isinstance(data, dict):
        return None
    data = data.get("issue", data)
    count = 0
    for edge in data.get("dependencies") or []:
        if not isinstance(edge, dict):
            continue
        if edge.get("dependency_type") == "blocks" and str(edge.get("title") or "").startswith("DECISION"):
            count += 1
    return count


# --- the orchestrator --------------------------------------------------------------------


def cmd_check(target):
    """`bead.py check <id|file>` — every rule above, one refusing command. Prints OK /
    REFUSED / NOT-GATED lines and returns the process exit code: 0 clean, 1 refused (each
    named), 2 NOT-GATED (never read as a pass)."""
    root = _git_root() or os.getcwd()
    refused = []
    not_gated = []
    info = []

    if os.path.isfile(target):
        try:
            with open(target, "r", encoding="utf-8", errors="replace") as fh:
                desc = fh.read()
        except OSError as exc:
            print(f"bead.py check: NOT-GATED {target} — cannot read file: {exc}", file=sys.stderr)
            return 2
        labels = []
        canon = None
        bead_id = target
    else:
        canon, err = read_bead(target)
        if err:
            print(f"bead.py check: NOT-GATED {target} — {err}", file=sys.stderr)
            return 2
        desc = canon.get("description", "")
        labels = canon.get("labels") or []
        bead_id = canon.get("id") or target

    human_gate = "human-gate" in labels

    p_refused, p_not_gated, p_info = probe_red_violations(probes(desc), human_gate)
    refused += p_refused
    not_gated += p_not_gated
    info += p_info

    t_rc, t_msg = touchers_freshness_check(desc, bead_id)
    if t_rc == 1:
        refused.append(f"touchers: {t_msg}")
    elif t_rc not in (0, 1):
        not_gated.append(f"touchers: {t_msg}")

    cons = consumes(section(desc, "Consumes"))
    c_refused, c_not_gated = consumes_violations(cons, root)
    refused += c_refused
    not_gated += c_not_gated

    refused += delivers_symlink_violations(delivers(desc), root)

    if canon is not None:
        ov = origin_violation(labels)
        if ov:
            refused.append(ov)
        rhv = refined_human_gate_violation(labels)
        if rhv:
            refused.append(rhv)

        dbc = _decision_blocks_count(bead_id)
        if dbc is None:
            not_gated.append("sensitive-prod: could not re-read dependency titles to count DECISION blocks edges")
        else:
            s_rc, s_msg = sensitive_prod_check(desc, labels, dbc, bead_id)
            if s_rc == 1:
                refused.append(f"sensitive-prod: {s_msg}")
            elif s_rc not in (0, 1):
                not_gated.append(f"sensitive-prod: {s_msg}")
    else:
        info.append("origin/refined-human-gate/sensitive-prod: skipped — file input carries no labels")

    for m in info:
        print(f"bead.py check: {m}")
    for m in refused:
        print(f"bead.py check: REFUSED {bead_id} — {m}", file=sys.stderr)
    for m in not_gated:
        print(f"bead.py check: NOT-GATED {bead_id} — {m}", file=sys.stderr)

    if not_gated:
        return 2
    if refused:
        return 1
    print(f"bead.py check: OK {bead_id}")
    return 0


def main(argv):
    if len(argv) >= 2 and argv[0] == "check":
        return cmd_check(argv[1])
    print("usage: bead.py check <id|file>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
