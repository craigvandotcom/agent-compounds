#!/usr/bin/env python3
# ---
# id: 28-citations
# prevents: any citation in live registry text — a `/ac-x` invocation, a file path (three
#   grammar forms), a named subagent stance, or a bare `ac-x` skill reference in hook-wiring
#   prose — pointing at something that does not exist; and the inverse: a references/,
#   reference/ or workflows/ file nothing in the registry cites
# scope: LIVE_TEXT AGENT_STANCES HOOKS
# severity: fail
# fixture: lint/fixtures/28-citations
# ---
"""28-citations — every citation form in the registry's live text resolves, both directions.

One walk, five forms sharing one shape (surface -> citation regex -> resolver
-> allowlist where one exists), over every tracked `.md` under `skills/`,
`hooks/`, `commands/` (ledgers/`_archive/`/`__pycache__` excluded) plus
`engine/hooks.wiring.json`'s `_doc`/`BACKSTOP` prose as one more surface.

  invoke   `/ac-x` terminal (never a path segment or sed address) -> a live
           `skills/ac-x/` dir; pure glob shorthand (`/ac-x-*`) skipped unless
           a real skill dir also carries the name. No allowlist.
  path     (1) `skills/<n>/.../<f>.<x>` repo-relative; (2) `<skill>/
           references|reference/<f>.<x>` resolved under `skills/`; (3)
           `<topdir>/.../<f>.<x>` for a top-level dir that does not recur as
           a per-skill subdir in 3+ skills (`root_dirs`) — also resolves
           under any skill's own directory. Scanned over the surface AND the
           wiring prose; the trigger corpus is exempt. Allowlist-eligible.
  stance   a `` `name` `` subagents mention or `subagent_type: "name"` ->
           `agents/*.md` or a harness built-in. No allowlist.
  bare-ac  a bare `ac-<name>` token (not path-adjacent, not bead-id-shaped)
           -> a live `skills/ac-<name>/` dir. Wiring prose ONLY — bead ids
           like `ac-f8fi` make this form unsafe over general skill text.
  inverse  every references/reference/workflows file under `skills/` (never
           `SKILL.md`) must be cited in the pointer corpus (LIVE_TEXT +
           `agents/*.md` + `README.md`) by full path, scoped `<sub>/<file>`,
           an inline-code slug (basename minus extension), or a glob that
           fnmatches it. Allowlist-eligible.

Allowlist `lint/allowlists/28-citations.txt` (`DATE key  # why`) admits both
classes from one file by shape: a governed-reference-shaped key under
`skills/` is an ORPHAN admission, any other key a PATH admission. Exact
membership only. Both classes are shrink-only (an orphan that gained a
reader, or a path that now resolves, is a violation — delete the line);
growth against the committed base (`lib.ratchet.base_ref`) is refused too —
the first landing has no committed version, that IS the seed.

Exit: 0 clean (>=1 file/manifest scanned), 1 findings, 2 scanned nothing.
"""

import fnmatch
import json
import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import ratchet, scope

CHECK_ID = "28-citations"
ALLOWLIST = os.path.join("lint", "allowlists", "28-citations.txt")
MANIFEST = "engine/hooks.wiring.json"
LEDGER_NAMES = ("FRICTIONS.md", "MAINTENANCE.md")

# --- invoke form (from check 2) ---------------------------------------------
TOKEN_RE = re.compile(r"(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]([^A-Za-z0-9_/:-]|$)")
GLOB_RE = re.compile(r"(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]-\*")

# --- path form (from check 28) ----------------------------------------------
FORM1 = re.compile(
    r"(?<![\w/.\-])skills/[A-Za-z0-9][A-Za-z0-9._-]*(?:/[A-Za-z0-9._-]+)+"
    r"\.[A-Za-z0-9]{1,5}\b"
)
FORM2 = re.compile(
    r"(?<![\w/.\-])[A-Za-z0-9][A-Za-z0-9._-]*/(?:references|reference)/"
    r"[A-Za-z0-9._-]+\.[A-Za-z0-9]{1,5}\b"
)
AMBIGUOUS_SUBDIR_THRESHOLD = 3

# --- stance form (from check 33) --------------------------------------------
BUILTINS = {"general", "general-purpose", "explore", "build", "plan"}
DECORATED = re.compile(r"(?:`|\*\*)([a-z][a-z-]{2,})(?:`|\*\*)\s+subagents?\b")
SUBAGENT_TYPE = re.compile(r'subagent_type:\s*"([a-z][a-z-]+)"')

# --- bare-ac form (from check 32) -------------------------------------------
BARE_AC_RE = re.compile(r"(?<![/\w.-])(ac-[a-z][a-z0-9-]*)(?![-/\w.])")

# --- inverse form (from check 31) -------------------------------------------
BACKTICK = re.compile(r"`([^`\n]+)`")


def general_surface(root):
    """Every tracked/committable `.md` file under skills/, hooks/ or
    commands/ — the shared surface for the invoke, path and stance forms.
    Ledgers are already gitignored (excluded from COMMITTABLE) but the name
    check is kept as cheap insurance; `_archive/` and `__pycache__` too."""
    out = []
    for rel in sorted(scope.COMMITTABLE):
        if not rel.endswith(".md"):
            continue
        if not (rel.startswith("skills/") or rel.startswith("hooks/") or rel.startswith("commands/")):
            continue
        base = rel.rsplit("/", 1)[-1]
        if base in LEDGER_NAMES or base == "FRICTIONS.md":
            continue
        if "_archive/" in rel or "__pycache__/" in rel:
            continue
        out.append(rel)
    return out


def _skill_names(root):
    skills_dir = os.path.join(root, "skills")
    try:
        return [d for d in os.listdir(skills_dir) if os.path.isdir(os.path.join(skills_dir, d))]
    except OSError:
        return []


def root_dirs(root):
    """Non-hidden, non-underscore top-level dirs minus `skills/` and minus
    any name recurring as a per-skill subdir >= AMBIGUOUS_SUBDIR_THRESHOLD."""
    try:
        names = os.listdir(root)
    except OSError:
        return []
    skill_names = _skill_names(root)
    dirs = []
    for d in sorted(names):
        if d == "skills" or d.startswith(".") or d.startswith("_"):
            continue
        if not os.path.isdir(os.path.join(root, d)):
            continue
        recurrence = sum(
            1 for s in skill_names if os.path.isdir(os.path.join(root, "skills", s, d))
        )
        if recurrence >= AMBIGUOUS_SUBDIR_THRESHOLD:
            continue
        dirs.append(d)
    return dirs


def build_form3(root):
    """Built fresh per root — a fixture tree gets its own alternation. A root
    with no matching top-level dirs gets a regex that never matches."""
    dirs = root_dirs(root)
    if not dirs:
        return re.compile(r"(?!)")
    alt = "|".join(re.escape(d) for d in dirs)
    return re.compile(
        r"(?<![\w/.\-])(?:" + alt + r")/[A-Za-z0-9][A-Za-z0-9._-]*"
        r"(?:/[A-Za-z0-9._-]+)*\.[A-Za-z0-9]{1,5}\b"
    )


def resolves(root, tok):
    for cand in (os.path.join(root, tok), os.path.join(root, "skills", tok)):
        if os.path.isfile(cand):
            return True
    for s in _skill_names(root):
        if os.path.isfile(os.path.join(root, "skills", s, tok)):
            return True
    return False


def path_tokens(text):
    toks = {m.group(0) for m in FORM1.finditer(text)}
    toks |= {m.group(0) for m in FORM2.finditer(text)}
    return toks


def walk_prose(node, path=""):
    """Strings at the prose surfaces: `_doc` fields and `assurance.BACKSTOP`."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk_prose(v, path + "/" + k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_prose(v, f"{path}[{i}]")
    elif isinstance(node, str):
        if path.endswith("/_doc") or path.endswith("/BACKSTOP"):
            yield path, node


def is_governed_shape(rel):
    """A references/, reference/ or workflows/ file under skills/ — the
    inverse form's population and the ORPHAN-vs-PATH allowlist-key shape."""
    if not rel.startswith("skills/") or rel.endswith("SKILL.md"):
        return False
    for sub in ("references/", "reference/", "workflows/"):
        if "/" + sub in "/" + rel:
            return True
    return False


def pointer_corpus(root):
    paths = set(scope.LIVE_TEXT)
    agents_dir = os.path.join(root, "agents")
    if os.path.isdir(agents_dir):
        for fn in os.listdir(agents_dir):
            if fn.endswith(".md"):
                paths.add("agents/" + fn)
    if os.path.isfile(os.path.join(root, "README.md")):
        paths.add("README.md")
    return sorted(paths)


def citation_tokens(text):
    return [m.group(1) for m in BACKTICK.finditer(text)]


def compute_orphans(root):
    """Returns (orphans, candidate_count) — the governed reference files with
    no pointer, and how many governed files were checked in total."""
    corpus_paths = pointer_corpus(root)
    texts_by_rel = {}
    for rel in corpus_paths:
        try:
            with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
                texts_by_rel[rel] = fh.read()
        except OSError:
            continue
    tokens_by_rel = {rel: citation_tokens(t) for rel, t in texts_by_rel.items()}
    candidates = sorted(p for p in scope.LIVE_TEXT if is_governed_shape(p))

    orphans = []
    for cand in candidates:
        sub = cand.split("/")[-2]
        fn = cand.rsplit("/", 1)[-1]
        stem = fn.rsplit(".", 1)[0] if "." in fn else fn
        full, scoped = cand, f"{sub}/{fn}"
        pointed = False
        for rel, text in texts_by_rel.items():
            if rel == cand:
                continue
            if full in text or scoped in text:
                pointed = True
                break
            for tok in tokens_by_rel[rel]:
                if tok == stem:
                    pointed = True
                    break
                if "*" in tok and (fnmatch.fnmatch(scoped, tok) or fnmatch.fnmatch(full, tok)):
                    pointed = True
                    break
            if pointed:
                break
        if not pointed:
            orphans.append(cand)
    return orphans, len(candidates)


def process_allowlist(root, orphans_set):
    """Split allowlist keys into the two admission classes by SHAPE, not
    existence (a PATH admission's target often looks reference-shaped too,
    so existence alone can't tell them apart): a governed-reference-shaped
    key is an ORPHAN admission, any other key a PATH admission. Returns
    (allowed_dangling, allowed_orphan, defects, all_keys — the last feeds
    the growth ratchet). Known gap: an ORPHAN entry whose file is later
    deleted outright reads as an unresolved PATH admission next run rather
    than a "file no longer exists" defect — narrow; today's list has none."""
    path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(path):
        return set(), set(), [], set()
    entries, defects = ratchet.load_allowlist(path)
    allowed_dangling, allowed_orphan, seen = set(), set(), set()
    for _date, key in entries:
        if key in seen:
            defects.append(f"{ALLOWLIST}: duplicate entry {key}")
            continue
        seen.add(key)
        if is_governed_shape(key):
            if not os.path.isfile(os.path.join(root, key)):
                defects.append(
                    f"{ALLOWLIST}: {key} names a file that no longer exists "
                    "— the list only shrinks: remove the entry")
            elif key in orphans_set:
                allowed_orphan.add(key)
            else:
                defects.append(
                    f"{ALLOWLIST}: {key} is no longer an orphan — something points "
                    "at it now; the list only shrinks: remove the entry")
        else:
            if resolves(root, key):
                defects.append(
                    f"{ALLOWLIST}: {key} now RESOLVES — the fix landed; "
                    "delete the line (shrink-only)")
            else:
                allowed_dangling.add(key)
    return allowed_dangling, allowed_orphan, defects, seen


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    surface = general_surface(root)
    texts = {}
    for rel in surface:
        try:
            with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
                texts[rel] = fh.read()
        except OSError:
            continue

    manifest_path = os.path.join(root, MANIFEST)
    manifest_present = os.path.isfile(manifest_path)
    manifest_fields = []
    if manifest_present:
        try:
            with open(manifest_path, encoding="utf-8") as fh:
                manifest = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"FAIL {CHECK_ID}: {MANIFEST} is unreadable ({exc}) — the "
                  "wiring-prose forms have nothing to verify")
            return 1
        manifest_fields = list(walk_prose(manifest))

    if len(texts) + (1 if manifest_present else 0) == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no live skill text or wiring manifest under {root} "
              "— verified nothing", file=sys.stderr)
        return 2

    findings = []       # hard-fail: invoke, stance, bare-ac (no allowlist)
    path_hits = []       # (location, token) — allowlist-eligible

    # --- invoke form -----------------------------------------------------
    skills_dir = os.path.join(root, "skills")
    tokens, glob_prefixes = [], []
    for text in texts.values():
        for m in TOKEN_RE.finditer(text):
            tok = m.group(0)
            tok = tok[1:] if tok[0] != "/" else tok
            tok = tok[:-1] if tok[-1] not in "abcdefghijklmnopqrstuvwxyz" else tok
            tokens.append(tok)
        for m in GLOB_RE.finditer(text):
            g = m.group(0)
            g = g[1:] if g[0] != "/" else g
            g = g[:-2] if g.endswith("-*") else g
            glob_prefixes.append(g)
    distinct_invoke = sorted({t[1:] for t in tokens if re.fullmatch(r"/ac-[a-z][a-z-]*", t)})
    globs = set(glob_prefixes)
    for tok in distinct_invoke:
        if not os.path.isdir(os.path.join(skills_dir, tok)) and tok in globs:
            continue
        if not os.path.isdir(os.path.join(skills_dir, tok)):
            findings.append(f"invoke: /{tok} referenced but skills/{tok}/ does not exist")

    # --- stance form -------------------------------------------------------
    agents_dir = os.path.join(root, "agents")
    roster = {os.path.splitext(fn)[0] for fn in os.listdir(agents_dir) if fn.endswith(".md")} \
        if os.path.isdir(agents_dir) else set()
    known_stances = roster | BUILTINS
    for rel, text in texts.items():
        for m in DECORATED.finditer(text):
            name = m.group(1)
            if name not in known_stances:
                findings.append(f"stance: {rel}: '{m.group(0).strip()}' — no agent named "
                                 f"'{name}' in agents/ (stance references must resolve; "
                                 "write a lens prompt instead)")
        for m in SUBAGENT_TYPE.finditer(text):
            name = m.group(1)
            if name not in known_stances:
                findings.append(f"stance: {rel}: subagent_type \"{name}\" — no agent named "
                                 f"'{name}' in agents/")

    # --- path form: surface + wiring prose ----------------------------------
    form3 = build_form3(root)
    exempt = set(scope.CORPUS)
    for rel, text in texts.items():
        if rel in exempt:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            toks = path_tokens(line) | {m.group(0) for m in form3.finditer(line)}
            for tok in sorted(toks):
                if not resolves(root, tok):
                    path_hits.append((f"{rel}:{n}", tok))
    for label, text in manifest_fields:
        toks = path_tokens(text) | {m.group(0) for m in form3.finditer(text)}
        for tok in sorted(toks):
            if not resolves(root, tok):
                path_hits.append((f"{MANIFEST}{label}", tok))

    # --- bare-ac form: wiring prose ONLY -------------------------------------
    live_skills = set(_skill_names(root))
    for label, text in manifest_fields:
        for m in BARE_AC_RE.finditer(text):
            name = m.group(1)
            if name not in live_skills:
                findings.append(f"bare-ac: {MANIFEST}{label}: skill reference '{name}' "
                                 f"names no live skills/{name}/ directory")

    # --- inverse form: orphan references ------------------------------------
    orphans, candidate_count = compute_orphans(root)

    # --- allowlist + growth ratchet ------------------------------------------
    allowed_dangling, allowed_orphan, al_defects, al_keys = process_allowlist(root, set(orphans))
    notes = []
    if os.path.isfile(os.path.join(root, ALLOWLIST)):
        base = ratchet.base_ref(root)
        if base:
            committed = ratchet.committed_keys(root, base, ALLOWLIST)
            if committed is None:
                notes.append(f"allowlist has no committed version at base {base[:12]} — this "
                              "is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                for entry in ratchet.shrink_only(al_keys, committed):
                    al_defects.append(
                        f"{ALLOWLIST}: allowlist GREW vs base {base[:12]}: '{entry}' is not in "
                        "the committed list — the allowlist only shrinks; clean the tree and "
                        "remove an entry instead")
        else:
            notes.append("no resolvable base ref — growth ratchet skipped this run "
                          "(shallow or standalone checkout)")

    open_path_hits = [(loc, tok) for loc, tok in path_hits if tok not in allowed_dangling]
    open_orphans = [o for o in orphans if o not in allowed_orphan]

    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    for d in al_defects:
        print(f"FAIL {CHECK_ID}: {d}")
    for loc, tok in open_path_hits:
        print(f"FAIL {CHECK_ID}: path: {loc} cites '{tok}' — no such file")
    for o in open_orphans:
        print(f"FAIL {CHECK_ID}: inverse: {o} is an orphan — nothing in the registry points at "
              "it: delete it, or wire a reader; the allowlist is a dated shrinking rest home, "
              "not an amnesty")
    for n in notes:
        print(f"NOTE: {n}")

    total = len(findings) + len(al_defects) + len(open_path_hits) + len(open_orphans)
    if total:
        print(f"FAIL {CHECK_ID}: {total} finding(s) across the invoke/path/stance/bare-ac/"
              "inverse forms — fix the citation, wire a reader, or admit a dated allowlist entry")
        return 1
    print(f"  ok: {CHECK_ID} — {len(texts)} file(s) + wiring prose scanned, "
          f"{len(distinct_invoke)} invoke token(s), {candidate_count} reference file(s) checked, "
          "every citation form clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
