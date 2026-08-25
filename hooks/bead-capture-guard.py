#!/usr/bin/env python3
"""PreToolUse(Bash) guard — the bead creation contract, enforced at the moment of capture.

Canon: skills/beads-standards/reference/bead-create-contract.md. Change the contract THERE
first; this file and scripts/bead-template-lint.py both implement it. The lint imports this
module, so the two enforcers cannot drift — they share one implementation of the rules.

Enforced here:
  - `origin:<skill>` on every bead — which workflow created it.
  - a readiness label on every NON-EPIC bead — `unrefined` / `human-gate`.

WHY THIS IS A HARD GATE, not an advisory (Craig, 2026-08-23):
`origin:` already existed as an OPTIONAL hint — plan 2026-07-16-1729-epic-bead-quality-
invariants.md §3 specified it, and §9 chose "convention, not a hard gate". Measured outcome
five weeks later: of 3818 beads across 7 repos, ~50% carry no origin signal at all and 1232
of those have no recoverable one. Prose alone was tried and it did not hold. The label was
never the problem; the absence of an enforcer was.

WHY exit-2 + stderr, not context-injection: identical reasoning to skill-edit-guard.py —
this wiring deploys org/app/machine scope across 4 harnesses, and stdout/additionalContext
are not portable (Grok discards both). Exit code + stderr is honored everywhere.

WHY shlex, not regex-over-the-raw-string: a bead description legitimately contains prose
like "run br create ...", and heredoc bodies contain arbitrary text. Naive segmentation
false-positives on those and would block valid work. Tokenizing respects quoting, so only
a real command-position `br create` is inspected, and only the actual `-l/--labels` VALUE
is searched for `origin:` — never the description.

FAIL-OPEN on any parse failure. A guard that cannot understand a command must not wedge an
unattended ac-loop run at 3am; a missed stamp is caught by the ac-bead-refine backstop.
"""

import json
import re
import shlex
import sys

SUBCOMMANDS = {"create", "q"}
CONTROL = {"&&", "||", ";", "|", "(", ")", "{", "}", "then", "do", "else", "fi", "done", "!"}
HELP = {"-h", "--help"}
ORIGIN = re.compile(r"(^|,)origin:[A-Za-z0-9][A-Za-z0-9._-]*(,|$)")

# Readiness: `refined` is stamped exclusively by a refine pass, never at creation, so in
# practice a new bead carries `unrefined` or `human-gate`. `refined` is still accepted —
# rejecting it here would be this guard second-guessing the refine pass.
READINESS = ("unrefined", "refined", "human-gate")

# Epics are containers, never picked up for implementation, so readiness is meaningless on
# them. This mirrors ac-tidy Phase 2f, which repairs the same gap nightly for "open non-epic"
# beads — the gate and the repair must agree on the exemption or they fight each other.
READINESS_EXEMPT_TYPES = {"epic"}

READINESS_MESSAGE = """\
BLOCKED: `br {sub}` (type `{typ}`) without a readiness label.

A bead with no readiness label is UNGRADED — and ungraded is not "not ready", it is
unknown. Downstream pickup cannot tell the difference, so it gets implemented on a raw
note. Add one to --labels:

    -l "origin:<skill>,unrefined"     # needs a refine pass first — the usual case
    -l "origin:<skill>,human-gate"    # a decision/action card only Craig can close

Do NOT pass `refined` at creation: it is stamped exclusively by a refine pass on
convergence. Epics are exempt — they are containers, never picked up.

Canon: beads-standards/reference/bead-create-contract.md\
"""

MESSAGE = """\
BLOCKED: `br {sub}` without an `origin:<skill>` label.

Every bead must record which workflow created it. Add it to --labels:

    br {sub} "..." -t task -p 2 -l "origin:<skill>,unrefined"

`<skill>` is the skill that is creating this bead — e.g. origin:ac-review,
origin:ac-hygiene, origin:ac-beadify, origin:ac-triage, origin:curate-foods.
If you are creating it by hand, outside any skill, use origin:manual.
If you genuinely cannot tell, `origin:unknown` is legal and honest — use it
rather than guessing or inventing a source.

Canon: beads-standards/reference/origin-provenance.md. Rationale: the
optional-hint version of this rule left half the board with no provenance,
so it is now gated rather than advised.\
"""


def allow():
    sys.exit(0)


def commands(tokens):
    """Yield each command's token list, split at shell control operators."""
    current = []
    for tok in tokens:
        if tok in CONTROL:
            if current:
                yield current
            current = []
        else:
            current.append(tok)
    if current:
        yield current


def is_bead_create(cmd):
    """Return the subcommand if cmd is a `br create`/`br q` invocation, else None."""
    i = 0
    # Skip leading VAR=value environment assignments.
    while i < len(cmd) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", cmd[i]):
        i += 1
    if i + 1 >= len(cmd):
        return None
    name = cmd[i].rsplit("/", 1)[-1]
    if name != "br":
        return None
    sub = cmd[i + 1]
    return sub if sub in SUBCOMMANDS else None


def flag_value(cmd, names, prefixes):
    """Value of the first matching flag, in two-token, =-joined, or attached form."""
    for i, tok in enumerate(cmd):
        if tok in names:
            if i + 1 < len(cmd):
                return cmd[i + 1]
        for p in prefixes:
            if tok.startswith(p) and len(tok) > len(p):
                return tok[len(p):]
    return None


def bead_type(cmd):
    """The declared --type, or None when absent or still an unsubstituted placeholder.

    None means "cannot know" and the readiness check is SKIPPED. A template placeholder
    like `-t <type>` could stand for `epic`, so enforcing readiness on it would block a
    legitimate epic template. Under-enforcing here is correct: the origin check still
    applies, ac-tidy repairs readiness nightly, and lint Check 19 catches stale templates
    statically anyway.
    """
    val = flag_value(cmd, {"-t", "--type"}, ("--type=",))
    if val is None or val.startswith("<") or val.startswith("$"):
        return None
    return val.strip().lower()


def all_labels(cmd):
    """Every label across ALL label flags — `-l` is repeatable, so one lookup is not enough."""
    out = []
    for i, tok in enumerate(cmd):
        val = None
        if tok in ("-l", "--labels"):
            if i + 1 < len(cmd):
                val = cmd[i + 1]
        elif tok.startswith("--labels="):
            val = tok.split("=", 1)[1]
        elif tok.startswith("-l") and len(tok) > 2:
            val = tok[2:]
        if val:
            out.extend(p.strip() for p in val.split(","))
    return out


def has_readiness(cmd):
    return any(r in all_labels(cmd) for r in READINESS)


def has_origin(cmd):
    """True if an actual -l/--labels VALUE carries an origin: token."""
    for i, tok in enumerate(cmd):
        if tok in ("-l", "--labels"):
            if i + 1 < len(cmd) and ORIGIN.search(cmd[i + 1]):
                return True
        elif tok.startswith("--labels="):
            if ORIGIN.search(tok.split("=", 1)[1]):
                return True
        elif tok.startswith("-l") and len(tok) > 2:
            # attached form: -l"origin:x" collapses to a single token
            if ORIGIN.search(tok[2:]):
                return True
    return False


def main():
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}

    if data.get("tool_name") not in (None, "Bash"):
        allow()

    command = (data.get("tool_input") or {}).get("command") or ""
    if "br" not in command:
        allow()

    # Unparseable shell (unbalanced quotes, exotic syntax) -> fail open.
    try:
        tokens = shlex.split(command, comments=False, posix=True)
    except ValueError:
        allow()

    for cmd in commands(tokens):
        sub = is_bead_create(cmd)
        if sub is None:
            continue
        if any(t in HELP for t in cmd):
            continue
        if not has_origin(cmd):
            print(MESSAGE.format(sub=sub), file=sys.stderr)
            sys.exit(2)
        typ = bead_type(cmd)
        if typ is not None and typ not in READINESS_EXEMPT_TYPES and not has_readiness(cmd):
            print(READINESS_MESSAGE.format(sub=sub, typ=typ), file=sys.stderr)
            sys.exit(2)

    allow()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # never wedge a session on a guard bug
        print("bead-capture-guard fail-open: %s" % e, file=sys.stderr)
        sys.exit(0)
