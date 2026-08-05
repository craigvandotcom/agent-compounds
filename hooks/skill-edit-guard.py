#!/usr/bin/env python3
"""PreToolUse(Edit|Write) guard — skill-diet doctrine reminder on SKILL.md spine edits.

Why exit-2 + stderr, not context-injection (plan D4, 2026-07-19-2338-skill-doctrine-diet-promotion-governance.md):
this hook deploys org-wide across 4 harnesses (claude/codex/droid/grok), and context-injection
is NOT portable — Grok has no hook context-injection channel at all (it discards hook stdout AND
ignores Claude's hookSpecificOutput.additionalContext; proven twice, memory
`grok-hooks-no-context-injection-channel`), and additionalContext isn't wired for codex/droid
either. exit code + stderr is the only mechanism honored on every harness, so the reminder is
delivered as an advisory exit-2 block. (Whether Claude's PreToolUse *alone* could inject context
is contested and moot here — a portable hook can't rely on it; Grok gets the doctrine separately
via harness-sync's render_context_grok.)

Behavior: an edit reaching ANY file under a `skills/` directory (`skills/**`) gets an
ADVISORY reminder of the skill-diet doctrine (rule voice, provenance, no-net-growth,
promotion ladder) printed to stderr, signaled via exit 2. Two entry points, because
Edit|Write is not the only way to change a skill file: a `file_path` under skills/, OR
a Bash `command` that writes there (redirect, tee, in-place sed/perl, cp/mv). Wire the
hook on BOTH the Edit|Write and Bash matchers — on Bash alone it never sees Edit, and on
Edit|Write alone a one-line `perl -0pi` rewrites doctrine ungoverned.
Scope was SKILL.md-only until 2026-08-05; broadened on Craig's call — the standards
(promotion ladder, friction capture, single-home, no-provenance) bind every file in a
skill, not just the spine, so references/ and FRICTIONS.md edits must see them too.
Exit 2 BLOCKS this first
attempt — that is how the reminder reaches the model (an exit-0 hook's stderr is not shown to
it). The once-per-session flag (below) then lets the agent's RE-ISSUE of the edit through
(exit 0), so the edit lands on retry. Net effect = a one-time speed-bump, not a hard wall — but
it does depend on the agent choosing to retry, so it is not a silent pass-through. Enforcement
proper is the commit-time lint.sh no-net-growth gate; this hook is only the doorbell.

CRITICAL — must not infinite-loop: firing on every skills/ edit in a session would make the
agent retry into the same exit-2 forever. Fire ONCE PER SESSION via a session-scoped flag
file: first skills/ edit in a session prints the reminder + exits 2; every subsequent
skills/ edit in the same session exits 0 silently (flag already present).

Session key: CLAUDE_CODE_SESSION_ID when set (per-session flag, matches am-edit-guard.py's
`resolve_self()` idiom); falls back to a daily key (YYYY-MM-DD) when no session id is present
(e.g. other harnesses / manual invocation) so the guard still degrades to "at most once per
day" rather than firing every time. Fail-open on any exception (never brick a session).

Env: SKILL_EDIT_GUARD_FLAG_DIR (default /tmp/skill-edit-guard).
"""
import datetime
import fnmatch
import os
import re
import sys

# Shell constructs that WRITE into skills/. Edit|Write is not the only way to change a
# skill file: a redirect, tee, in-place sed/perl, or cp/mv reaches the same bytes and
# would otherwise skip this guard entirely. Heuristic and deliberately generous — the
# hook is advisory and fires once per session, so a false positive costs one retry
# while a miss costs an ungoverned edit.
BASH_WRITES_SKILLS = re.compile(
    r""">>?\s*"?[^"'|;&\s]*skills/"""              # > or >> into skills/
    r"""|\btee\s+(?:-\S+\s+)*"?[^"'|;&\s]*skills/"""  # tee into skills/
    r"""|\bsed\s+[^|;&]*-i[^|;&]*skills/"""        # in-place sed
    r"""|\bperl\s+[^|;&]*-[a-zA-Z0-9]*i[^|;&]*skills/"""  # in-place perl (-i, -pi, -0pi)
    r"""|\b(?:cp|mv|install|truncate)\s+[^|;&]*skills/"""  # copy/move/truncate
)

FLAG_DIR = os.environ.get("SKILL_EDIT_GUARD_FLAG_DIR", "/tmp/skill-edit-guard")

REMINDER = """\
ADVISORY (skill-edit-guard): you are editing a file under skills/.

Skill-diet doctrine binds EVERY file in a skill — SKILL.md, references/, FRICTIONS.md,
MAINTENANCE.md, tools/.
  - RULE VOICE: state the rule, not its cause, discovery, or author. Imperative,
    present tense. One idea per line. A rule that needs a paragraph to be believed is
    not yet well stated -- sharpen it instead of defending it. Minimum necessary change
    in the optimal location: prefer deleting to adding, and name what a new line replaces.
  - NO PROVENANCE IN SKILL TEXT: who / when / which bead / promoted-from goes in the
    commit message and ledgers, never the artifact. Bare rule-IDs only where grepped
    as names. No dates, no run ids, no "measured", no discovery narrative.
  - NO-NET-GROWTH: SKILL.md core is loaded every invocation, so it holds or shrinks.
    Growth is bought with an offsetting DELETION or a move to references/ — never with
    a written justification. No stamp, no textual exception. Run
    `node scripts/skill-diet-conservation.mjs` when moving content, to confirm nothing
    unique is lost.
  - PROMOTION LADDER (skills/skill-builder/references/promotion-ladder.md): UP needs
    PROOF (N green runs / probe-verified, + Craig sign-off for conductor core); DOWN
    needs only disuse. A NEW LESSON enters at the BOTTOM (FRICTIONS.md / references),
    never straight into core. Removed content ages in MAINTENANCE.md before git-delete.
  - FRICTION CAPTURE (skills/skill-builder/references/friction-capture.md): landing a
    lesson learned from friction? Log it in FRICTIONS.md first — promotion is
    evidence-driven, not vibes-driven.
  - SINGLE-HOME (ac-gcj/ac-znk.7): restating a rule whose canon lives in an owning
    domain skill (ac-pipeline/references/*, agent-mail/references/*, beads-standards)?
    Point at it with a `§` anchor. A deliberate copy carries
    `<!-- mirror: <canon> §... -- edit there first -->`. A rule true in ANY workflow is
    domain canon, not workflow text.

(Fires once per session. This first attempt is blocked to surface the reminder; re-issue the edit to proceed.)
"""


def allow():
    sys.exit(0)


def session_key():
    # Subagents INHERIT the parent's CLAUDE_CODE_SESSION_ID, so a session-only key means
    # the conductor's first skills/ edit disarms the guard for every child it spawns —
    # and in a delegation-heavy pipeline the children are the ones doing the editing.
    # Key on session + agent so each editing agent gets exactly one reminder.
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID")
    agent = os.environ.get("AGENT_NAME") or os.environ.get("CLAUDE_AGENT_ID") or ""
    if sid:
        return sid + ("-" + agent if agent else "")
    # No session id available (other harnesses / manual invocation) -> degrade to a
    # daily key so the guard still fires at most once per day, never every call.
    return "daily-" + datetime.date.today().isoformat() + ("-" + agent if agent else "")


def already_fired(key):
    flag_path = os.path.join(FLAG_DIR, key)
    try:
        if os.path.exists(flag_path):
            return True
        os.makedirs(FLAG_DIR, exist_ok=True)
        with open(flag_path, "w") as f:
            f.write(datetime.datetime.now().isoformat(timespec="seconds") + "\n")
        return False
    except Exception:
        # Cannot judge whether we already fired -> fail open (never block/loop).
        return True


def main():
    import json

    try:
        data = json.load(sys.stdin)
    except Exception:
        allow()
    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path")
    command = tool_input.get("command")

    if path:
        rel = path.replace(os.sep, "/")
        if not (fnmatch.fnmatch(rel, "*/skills/*") or fnmatch.fnmatch(rel, "skills/*")):
            allow()
    elif isinstance(command, str) and command:
        if not BASH_WRITES_SKILLS.search(command):
            allow()
    else:
        allow()

    if already_fired(session_key()):
        allow()

    print(REMINDER, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("skill-edit-guard fail-open: %s" % e, file=sys.stderr)
        sys.exit(0)
