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
  - a subagent files NOTHING — every `br create` is refused and returned to the
    coordinator as a PROPOSED-BEAD block; a human-gate fork is a proposal too, never a
    direct create. Subagent identity is harness-dependent: the `agent_id` stdin field OR
    the `AC_SUBAGENT=1` ambient marker a wrapper sets. Where a harness supplies neither
    (opencode sends `session_id`, not `agent_id`), the refusal is INERT and only the four
    label/body axes apply — best-effort, not a guarantee.

Command position is resolved through the shapes a create can hide in: command
substitution (`$(br create …)`, backticks), a shell `-c` wrapper (`sh -c 'br create …'`),
and command wrappers (`xargs`/`env`/`sudo` … `br create`). Only a real command-position
`br create` is inspected — a description or heredoc that quotes the text keeps passing.

WHY THIS IS A HARD GATE, not an advisory (maintainer ruling, 2026-08-23):
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
newline becomes a `;` separator. The same pre-pass space-pads `;`, `&&`, `||` and `|`,
glued or not — shlex keeps `true;` and `true&&br` as one token, so CONTROL never saw
the `br create` after them. Quoted newlines and quoted separators stay intact.

FAIL-OPEN on any parse failure. A guard that cannot understand a command must not wedge an
unattended ac-loop run at 3am; a missed stamp is caught by ac-tidy.
"""

import json
import os
import re
import shlex
import sys

SUBCOMMANDS = {"create", "q"}
CONTROL = {"&&", "||", ";", "|", "(", ")", "{", "}", "then", "do", "else", "fi", "done", "!"}
HELP = {"-h", "--help"}
# Command-position wrappers: `xargs br create`, `env br create`, `sudo br create` etc. are
# still a bead create; skip the wrapper (and its flags) before looking for `br`. Shell
# wrappers that carry the command in a `-c` argument are handled by shell_c_commands().
WRAPPERS = {"env", "xargs", "sudo", "command", "exec", "nice", "nohup", "time", "stdbuf", "setsid"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
ORIGIN = re.compile(r"(^|,)origin:[A-Za-z0-9][A-Za-z0-9._-]*(,|$)")

# Readiness: `stamp-refined.sh` is the sole writer AND sole stripper of `refined`
# (skills/beads-standards/SKILL.md) — applied at refine convergence, never at creation.
# Accepting `refined` here was the one door that sole-writer invariant left open, so a new
# bead carries only `unrefined` or `human-gate`.
READINESS = ("unrefined", "human-gate")

# Epics are containers, never picked up for implementation, so readiness is meaningless on
# them. This mirrors ac-tidy's nightly readiness-label repair, which fixes the same gap nightly for "open non-epic"
# beads — the gate and the repair must agree on the exemption or they fight each other.
READINESS_EXEMPT_TYPES = {"epic"}

# `refined` is stamped EXCLUSIVELY by stamp-refined.sh on refine convergence — the one
# label a create must never carry, whatever readiness label rides beside it and whatever
# the type (including epic, and including a create with no --type at all). This is a
# standalone axis, checked before the type-scoped readiness/probe axes below, precisely
# because those are type-scoped and `refined` must not be.
REFINED_LABEL = "refined"

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
    "ac-qa", "ac-land", "curate-foods",
)

# The subagent refusal (ac-wp8i.3): a PreToolUse stdin carrying `agent_id` is a subagent,
# which may file ONLY a `human-gate` fork — everything else is proposed at the boundary.
SUBAGENT_EXEMPT_LABEL = "human-gate"

REFINED_MESSAGE = """\
BLOCKED: `br {sub}` carries the `refined` label at creation.

`refined` is stamped EXCLUSIVELY by a refine pass on convergence
(stamp-refined.sh is its sole writer — skills/beads-standards/SKILL.md), never at
creation — whatever readiness label rides beside it in --labels, and whatever the
type (epic included). Drop it:

    -l "origin:<skill>,unrefined"     # needs a refine pass first — the usual case
    -l "origin:<skill>,human-gate"    # a decision/action card only a human can close

Canon: beads-standards/reference/bead-create-contract.md\
"""

READINESS_MESSAGE = """\
BLOCKED: `br {sub}` (type `{typ}`) without a readiness label.

A bead with no readiness label is UNGRADED — and ungraded is not "not ready", it is
unknown. Downstream pickup cannot tell the difference, so it gets implemented on a raw
note. Add one to --labels:

    -l "origin:<skill>,unrefined"     # needs a refine pass first — the usual case
    -l "origin:<skill>,human-gate"    # a decision/action card only a human can close

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
BLOCKED: `br {sub}` from a subagent — a subagent files NOTHING.

Return it to your coordinator as a PROPOSED-BEAD block for the conductor to confirm and
file: title · files · `User impact:` (and for a fork: gate reason · options ·
recommendation). No exceptions — a human-gate fork is a proposal too, never a direct create.

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
    """Space-pad unquoted shell separators so the tokenizer sees each command.

    A bare newline is a command separator, like ';'. So are `;`, `&&`, `||`, `|`, and
    the delimiters of command substitution — `$(`, its closed `)`, and a backtick pair.
    `out=$(br create …)`, `` `br create …` `` and `true;br create` all run `br create`
    as a real command. Without the pad the inner `br create` lands mid-token-stream
    (e.g. as `out=$(br` or `true;`) and is never inspected. shlex splits only on
    whitespace, so a glued delimiter must be space-padded or CONTROL never sees it.
    Never touched inside a quoted string, so a description that quotes `br create`
    keeps passing. An escaped separator stays literal.
    """
    out = []
    quote = None
    esc = False
    i = 0
    n = len(command)
    while i < n:
        ch = command[i]
        if esc:
            out.append(ch)
            esc = False
            i += 1
            continue
        if ch == "\\" and quote != "'":
            out.append(ch)
            esc = True
            i += 1
            continue
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "'\"":
            quote = ch
            out.append(ch)
            i += 1
            continue
        two = command[i:i + 2]
        if two in ("&&", "||"):
            out.append(" " + two + " ")
            i += 2
            continue
        if ch == "|":
            out.append(" | ")
            i += 1
            continue
        if ch in ("\n", "`", "(", ")", ";"):
            out.append(" ; ")
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def is_bead_create(cmd):
    """Return the subcommand if cmd is a `br create`/`br q` invocation, else None.

    Skips leading wrapper words (`xargs`, `env`, `sudo`, …) and their flags, then
    `VAR=value` assignments, so `xargs br create …` and `env FOO=1 br create …` are still
    seen. A wrapper's command-in-`-c` form is expanded by `shell_c_commands()` instead.
    """
    i = 0
    while i < len(cmd):
        name = cmd[i].rsplit("/", 1)[-1]
        if name in WRAPPERS:
            i += 1
            while i < len(cmd) and cmd[i].startswith("-") and cmd[i] not in ("-", "--"):
                i += 1
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", cmd[i]):
            i += 1
            continue
        break
    if i + 1 >= len(cmd):
        return None
    name = cmd[i].rsplit("/", 1)[-1]
    if name != "br":
        return None
    sub = cmd[i + 1]
    return sub if sub in SUBCOMMANDS else None


def shell_c_commands(command):
    """Yield the command strings a shell wrapper runs via its `-c` argument.

    `sh -c 'br create …'`, `bash -c "br create …"` carry the real command as a quoted
    argument, so the shlex command-position scan never sees a `br` token. Tokenize and
    hand each `-c` argument back to the caller to run through the same pipeline.
    """
    try:
        tokens = shlex.split(command, comments=False, posix=True)
    except ValueError:
        return
    for i, tok in enumerate(tokens):
        if tok in ("-c", "--command") and 0 < i and tokens[i - 1].rsplit("/", 1)[-1] in SHELLS:
            if i + 1 < len(tokens):
                yield tokens[i + 1]


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
    """The declared --type; `task` (br's own default — no -t defaults to task) when no
    -t/--type flag is present at all; None when it IS present but still an unsubstituted
    placeholder.

    None means "cannot know" and the readiness/probe checks are SKIPPED — a template
    placeholder like `-t <type>` could stand for `epic`, so enforcing readiness on it
    would block a legitimate epic template. An ABSENT flag is not that case: `br create`
    with no `-t` at all is created as `task` by `br` itself, so the type-scoped checks
    apply exactly as they would to an explicit `-t task` — under-enforcing here was the
    gap a bare `br create x -l origin:x,refined` used to walk through.
    """
    val = flag_value(cmd, {"-t", "--type"}, ("--type=",))
    if val is None:
        return "task"  # br's own default when -t/--type is omitted entirely
    if val.startswith("<") or val.startswith("$"):
        return None  # present but an unsubstituted template placeholder — cannot know
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


def has_refined(cmd):
    """True when ANY label flag carries `refined` — across every -l/--labels flag,
    the same repeatable-flag handling all_labels() already gives every other axis."""
    return REFINED_LABEL in all_labels(cmd)


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
    """The -d/--description/--body VALUE, or None when absent.

    Does not read `--description-file`. That flag is a path, not the body; `has_probe`
    opens it. Callers that want the inline text (the template lint's human-gate check)
    must keep seeing the flag value, not the file.
    """
    return flag_value(cmd, {"-d", "--description", "--body"}, ("--description=", "--body="))


# Unsubstituted template tokens. `$VAR` / `${VAR}` are the deliberate hatch (a skill
# template the caller has not filled in yet). `$(...)` is command substitution and is
# NOT in this set — a body the guard has not read is not a probe.
_VAR = re.compile(r"^\$[A-Za-z_][A-Za-z0-9_]*$")
_BRACE_VAR = re.compile(r"^\$\{[A-Za-z_][A-Za-z0-9_]*\}$")
# The one substitution the fleet actually files with: `-d "$(cat <path>)"`. Reduced to
# a file read so the probe axis sees the body. Anything else that starts with `$` is
# refused rather than waved through.
_CAT_SUB = re.compile(r"^\$\(\s*cat\s+(?:--\s+)?(.+?)\s*\)$", re.DOTALL)
_BODY_CAP = 1_048_576


def _template_token(val):
    return val.startswith("<") or bool(_VAR.match(val) or _BRACE_VAR.match(val))


def _plain_path(raw):
    """A single literal path inside `$(cat ...)`, or None when it is not one file."""
    path = raw.strip()
    if len(path) >= 2 and path[0] == path[-1] and path[0] in ("'", '"'):
        path = path[1:-1]
    if not path or any(c in path for c in "$`;|&<>\n"):
        return None
    return path


def _read_body_file(path):
    """File text, or None when the path cannot be read. None refuses — never fail-open."""
    if not path or path == "-" or "\x00" in path:
        return None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read(_BODY_CAP)
    except OSError:
        return None


def probe_body(cmd):
    """The text `has_probe` searches.

    True  — unsubstituted template; skip, same doctrine as `bead_type`.
    str   — the body, whether it came from `-d` or from a file.
    None  — no body, an unreadable file, stdin (`--description-file -`), or a `$...`
            value this guard cannot reduce to a file. All of those refuse.
    """
    file_flag = flag_value(cmd, {"--description-file"}, ("--description-file=",))
    if file_flag is not None:
        if _template_token(file_flag):
            return True
        # A command-substituted path, or `-` (stdin). The hook's stdin is the tool
        # payload, not the description, so neither form can be verified.
        if file_flag.startswith("$") or file_flag == "-":
            return None
        return _read_body_file(file_flag)

    d = description(cmd)
    if d is None:
        return None
    if _template_token(d):
        return True
    cat = _CAT_SUB.match(d)
    if cat:
        raw = cat.group(1).strip()
        if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ("'", '"'):
            raw = raw[1:-1]
        # `$(cat <file>)` is the unsubstituted template the docs ship. A real path
        # never has that shape; refusing it would block the template before substitution.
        if raw.startswith("<") and raw.endswith(">"):
            return True
        path = _plain_path(cat.group(1))
        if path is None:
            return None
        return _read_body_file(path)
    if d.startswith("$"):
        return None
    return d


def has_probe(cmd):
    """True when the body carries a `Probe: `<command>`` ... tier: line.

    An absent description BLOCKS (a probe-less create is exactly what this axis exists
    to refuse). An unsubstituted template placeholder skips, the same doctrine as
    `bead_type`: it could stand for anything, ac-tidy repairs nightly, and lint Check 19
    catches stale templates statically.

    `--description-file` is read and inspected — `br create --help` recommends it for
    the multi-paragraph body a probe block is. `-d "$(cat <path>)"` is the same read.
    A `$...` body that is not that `cat` (and not a bare `$VAR`) is not admitted: the
    old `startswith("$")` hatch waved every command substitution through without seeing
    a Probe line.
    """
    body = probe_body(cmd)
    if body is True:
        return True
    if not body:
        return False
    return bool(PROBE.search(body))


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


def scan_tokens(tokens, is_subagent):
    """Run every command in a token stream through the full contract, refusing on the
    first violation. Shared by the outer command and any wrapper-expanded inner command."""
    for cmd in commands(tokens):
        sub = is_bead_create(cmd)
        if sub is None:
            continue
        if any(t in HELP for t in cmd):
            continue
        # A subagent files NOTHING — every create goes back to the coordinator as a
        # PROPOSED-BEAD. No fork exemption: a human-gate card is a proposal too.
        if is_subagent:
            print(SUBAGENT_MESSAGE.format(sub=sub), file=sys.stderr)
            sys.exit(2)
        if not has_origin(cmd):
            print(MESSAGE.format(sub=sub), file=sys.stderr)
            sys.exit(2)
        # Standalone axis, checked before the type-scoped ones below: `refined` is
        # refused whatever else rides beside it in --labels and whatever the type
        # (epic and an absent -t included) — sole-writer invariant, no exemption.
        if has_refined(cmd):
            print(REFINED_MESSAGE.format(sub=sub), file=sys.stderr)
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


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except ValueError:
        data = {}  # malformed stdin JSON fails open the same as no stdin at all

    if data.get("tool_name") not in (None, "Bash"):
        allow()

    # A subagent may file only a `human-gate` fork; its discovered work is proposed back
    # at the batch boundary, never filed directly (bead-create-contract § Subagent creates).
    # The subagent marker is harness-dependent: `agent_id` on the stdin payload, OR the
    # ambient `AC_SUBAGENT` a harness wrapper sets when it CAN tell a subagent from the
    # main session. Neither is sent by every deployed harness (opencode sends session_id,
    # not agent_id), so where both are absent the refusal is inert and only the four
    # label/body axes apply. The seam is here so a wrapper can enforce it without a
    # guard change.
    is_subagent = bool(data.get("agent_id")) or os.environ.get("AC_SUBAGENT") == "1"

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

    scan_tokens(tokens, is_subagent)

    # A shell wrapper runs the real command from its `-c` argument; scan each too.
    for inner in shell_c_commands(command):
        inner = newlines_to_separators(strip_heredoc_bodies(inner))
        try:
            inner_tokens = shlex.split(inner, comments=False, posix=True)
        except ValueError:
            continue
        scan_tokens(inner_tokens, is_subagent)

    allow()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # never wedge a session on a guard bug
        print("bead-capture-guard fail-open: %s" % e, file=sys.stderr)
        sys.exit(0)
