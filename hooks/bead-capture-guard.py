#!/usr/bin/env python3
"""PreToolUse(Bash) guard — the bead creation contract, enforced at the moment of capture.

Canon: skills/beads-standards/reference/bead-create-contract.md. Change the contract THERE
first; this file and scripts/bead-template-lint.py both implement it. The lint imports this
module, so the two enforcers cannot drift — they share one implementation of the rules.

Enforced here:
  - `origin:<skill>` on every bead — which workflow created it.
  - a readiness label on every NON-EPIC bead — `unrefined` / `human-gate`.
  - a `Probe:` line on every IMPLEMENTABLE bead (`bug` / `task` / `feature`) — born
    probe-bearing; `epic` / `decision` / `investigation` are exempt.
  - exactly one `impact:<class>` label on every bead from an AUTOMATED origin — the class
    of damage if it ships; human/plan origins and `human-gate` fork beads are exempt.
  - a subagent (`agent_id` on stdin) files nothing but a `human-gate` fork — its
    discovered work goes back to the batch boundary as a PROPOSED-BEAD block.

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

WHY a pre-pass BEFORE shlex: shlex collapses newlines and raises on an apostrophe inside
a heredoc body ("bd-wywg8's"), so two multi-line shapes defeat the tokenizer — a `br create`
on its own line after any other statement lands mid-token-stream and is never seen, and an
unparseable heredoc body fails open by design. Both are resolved while the raw line
structure still exists: heredoc bodies are stripped (they are DATA, never a command
position — the `br create` text inside one must keep passing), and every remaining bare
newline becomes a `;` separator. Quoted newlines stay intact.

FAIL-OPEN on any parse failure. A guard that cannot understand a command must not wedge an
unattended ac-loop run at 3am; a missed stamp is caught by ac-align's nightly reconcile.
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
# them. This mirrors ac-align's nightly readiness-label repair, which fixes the same gap nightly for "open non-epic"
# beads — the gate and the repair must agree on the exemption or they fight each other.
READINESS_EXEMPT_TYPES = {"epic"}

# The probe axis (born probe-bearing, ac-v5vi): an implementable bead is created with at
# least one runnable acceptance probe. Containers, forks and unconfirmed leads own no probe
# yet — a filer that cannot name one files `investigation`, the type that says so.
IMPLEMENTABLE_TYPES = {"bug", "task", "feature"}
PROBE_EXEMPT_TYPES = {"epic", "decision", "investigation"}
PROBE = re.compile(r"Probe:\s*`[^`]+`[^\n]*\btier:")

# The impact axis (ac-wp8i.3): the class of damage if this bead's failure ships. CLOSED
# set — a new class is a contract change first, then this tuple. An automated origin must
# carry exactly one of these; `impact:trunk-red` names the failing suite/job in its
# `User impact:` line. Human origins (`manual`, `ac-human`, formerly `ac-human-session`),
# plan origins (`ac-beadify`, `ac-backlog`) and `human-gate` fork beads are EXEMPT — a
# fork is not an impact class — and a refusal must name those exemptions.
IMPACT_CLASSES = ("user-visible", "data", "security", "trunk-red")
IMPACT_REQUIRED_ORIGINS = (
    "ac-implement", "ac-review", "ac-triage", "ac-hygiene", "ac-align", "ac-prove",
    "curate-foods",
)

# The subagent refusal (ac-wp8i.3): a PreToolUse stdin carrying `agent_id` is a subagent,
# which may file ONLY a `human-gate` fork — everything else is proposed at the boundary.
SUBAGENT_EXEMPT_LABEL = "human-gate"

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

PROBE_MESSAGE = """\
BLOCKED: `br {sub}` (type `{typ}`) without a `Probe:` line in the body.

An implementable bead (bug / task / feature) is born probe-bearing: `## Acceptance
Criteria` carries at least one bullet of the shape

    - Probe: `grep -q '<string>' <file>` — tier: none

so pickup has something runnable to verify against. `epic`, `decision` and
`investigation` are exempt — containers, forks and unconfirmed leads own no
probe yet. A filer that cannot name a probe files the bead as `investigation`
— the type that says so — never as a probe-less task.

Canon: beads-standards/reference/bead-create-contract.md § Required axes.\
"""

IMPACT_MESSAGE = """\
BLOCKED: `br {sub}` from automated origin `{origin}` without exactly one `impact:` label.

`impact:<class>` records the class of damage if this bead's failure ships — exactly one of:

    impact:user-visible · impact:data · impact:security · impact:trunk-red

`impact:trunk-red` names the failing suite or job in the body's `User impact:` line.

Exempt, and never blocked for this axis: human origins (`manual`, `ac-human` — renamed
from `ac-human-session`), plan origins (`ac-beadify`, `ac-backlog`), and `human-gate`
fork beads — a fork is not an impact class.

Canon: beads-standards/reference/bead-create-contract.md § Required axes.\
"""

SUBAGENT_MESSAGE = """\
BLOCKED: `br {sub}` from a subagent — propose it in your hand-back.

A subagent's discovered product work is not filed directly: return it to the batch
boundary as a PROPOSED-BEAD block for the conductor to confirm. The one exception is the
worker's mid-bead `human-gate` fork — add `human-gate` to --labels to file a decision card
that unblocks you.

Canon: beads-standards/reference/bead-create-contract.md § Subagent creates.\
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


def strip_heredoc_bodies(command):
    """Drop heredoc bodies (<<TAG / <<'TAG' / <<-TAG ... terminator line) before shlex.

    The body is data — it may quote anything, including `br create` text and an
    apostrophe — and none of it is a real command position. The opener line is kept;
    body lines and the terminator line are dropped. A `<<-` tag strips leading tabs
    from the terminator, matching bash.
    """
    lines = command.split("\n")
    out = []
    tag = None
    dash = False
    for line in lines:
        if tag is not None:
            check = line.lstrip("\t") if dash else line
            if check == tag:
                tag = None
            continue  # body lines are data, never commands
        m = re.search(r"<<(-?)(['\"]?)([A-Za-z0-9_][A-Za-z0-9_.-]*)\2", line)
        if m:
            tag = m.group(3)
            dash = m.group(1) == "-"
        out.append(line)
    return "\n".join(out)


def newlines_to_separators(command):
    """Newline is a command separator, like ';' — but never inside a quoted string.

    The `;` is space-padded: shlex only splits on whitespace, so a bare `;` glued to
    a token would hide the boundary from CONTROL the same way the newline did.
    """
    out = []
    quote = None
    esc = False
    for ch in command:
        if esc:
            out.append(ch)
            esc = False
        elif ch == "\\" and quote != "'":
            out.append(ch)
            esc = True
        elif quote:
            out.append(ch)
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
            out.append(ch)
        elif ch == "\n":
            out.append(" ; ")
        else:
            out.append(ch)
    return "".join(out)


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
    applies, ac-align repairs readiness nightly, and lint Check 19 catches stale templates
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


def description(cmd):
    """The -d/--description/--body VALUE, or None when absent."""
    return flag_value(cmd, {"-d", "--description", "--body"}, ("--description=", "--body="))


def has_probe(cmd):
    """True when the body carries a `Probe: `<command>`` ... tier: line.

    An absent description BLOCKS (a probe-less create is exactly what this axis exists
    to refuse). An unsubstituted template placeholder skips, the same doctrine as
    `bead_type`: it could stand for anything, ac-align repairs nightly, and lint Check 19
    catches stale templates statically.
    """
    d = description(cmd)
    if d is None:
        return False
    if d.startswith("<") or d.startswith("$"):
        return True
    return bool(PROBE.search(d))


def origin_skill(cmd):
    """The `<skill>` of the first `origin:<skill>` label, or None. One origin per bead."""
    for label in all_labels(cmd):
        if label.startswith("origin:"):
            return label[len("origin:"):]
    return None


def valid_impact(cmd):
    """True when the labels carry EXACTLY one impact class from the closed set."""
    classes = [lab[len("impact:"):] for lab in all_labels(cmd) if lab.startswith("impact:")]
    return len(classes) == 1 and classes[0] in IMPACT_CLASSES


def has_label(cmd, name):
    return name in all_labels(cmd)


def main():
    raw = sys.stdin.read()
    data = json.loads(raw) if raw.strip() else {}

    if data.get("tool_name") not in (None, "Bash"):
        allow()

    # A subagent may file only a `human-gate` fork; its discovered work is proposed back
    # at the batch boundary, never filed directly (bead-create-contract § Subagent creates).
    is_subagent = bool(data.get("agent_id"))

    command = (data.get("tool_input") or {}).get("command") or ""
    if "br" not in command:
        allow()

    # Multi-line shapes first: a heredoc body is DATA (never a command position) and a
    # bare newline is a command separator. Both must be resolved while the raw line
    # structure still exists — shlex collapses newlines and raises on an apostrophe in
    # a heredoc body, failing open on exactly the bypass this guard exists to block.
    command = strip_heredoc_bodies(command)
    command = newlines_to_separators(command)

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
        if is_subagent and not has_label(cmd, SUBAGENT_EXEMPT_LABEL):
            print(SUBAGENT_MESSAGE.format(sub=sub), file=sys.stderr)
            sys.exit(2)
        if not has_origin(cmd):
            print(MESSAGE.format(sub=sub), file=sys.stderr)
            sys.exit(2)
        typ = bead_type(cmd)
        if typ is not None and typ not in READINESS_EXEMPT_TYPES and not has_readiness(cmd):
            print(READINESS_MESSAGE.format(sub=sub, typ=typ), file=sys.stderr)
            sys.exit(2)
        if typ is not None and typ in IMPLEMENTABLE_TYPES and not has_probe(cmd):
            print(PROBE_MESSAGE.format(sub=sub, typ=typ), file=sys.stderr)
            sys.exit(2)
        origin = origin_skill(cmd)
        if (
            origin in IMPACT_REQUIRED_ORIGINS
            and not has_label(cmd, SUBAGENT_EXEMPT_LABEL)
            and not valid_impact(cmd)
        ):
            print(IMPACT_MESSAGE.format(sub=sub, origin=origin), file=sys.stderr)
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
