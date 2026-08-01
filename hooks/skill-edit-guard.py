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

Behavior: an Edit|Write whose target matches a skill spine (`skills/**/SKILL.md`) gets an
ADVISORY reminder of the skill-diet doctrine (promotion ladder, conservation gate,
no-net-growth discipline) printed to stderr, signaled via exit 2. Exit 2 BLOCKS this first
attempt — that is how the reminder reaches the model (an exit-0 hook's stderr is not shown to
it). The once-per-session flag (below) then lets the agent's RE-ISSUE of the edit through
(exit 0), so the edit lands on retry. Net effect = a one-time speed-bump, not a hard wall — but
it does depend on the agent choosing to retry, so it is not a silent pass-through. Enforcement
proper is the commit-time lint.sh no-net-growth gate; this hook is only the doorbell.

CRITICAL — must not infinite-loop: firing on every SKILL.md edit in a session would make the
agent retry into the same exit-2 forever. Fire ONCE PER SESSION via a session-scoped flag
file: first skill-spine edit in a session prints the reminder + exits 2; every subsequent
skill-spine edit in the same session exits 0 silently (flag already present).

Session key: CLAUDE_CODE_SESSION_ID when set (per-session flag, matches am-edit-guard.py's
`resolve_self()` idiom); falls back to a daily key (YYYY-MM-DD) when no session id is present
(e.g. other harnesses / manual invocation) so the guard still degrades to "at most once per
day" rather than firing every time. Fail-open on any exception (never brick a session).

Env: SKILL_EDIT_GUARD_FLAG_DIR (default /tmp/skill-edit-guard).
"""
import datetime
import fnmatch
import os
import sys

FLAG_DIR = os.environ.get("SKILL_EDIT_GUARD_FLAG_DIR", "/tmp/skill-edit-guard")

REMINDER = """\
ADVISORY (skill-edit-guard): you are editing a SKILL.md spine file.

Skill-diet doctrine applies — before adding content, check whether it belongs here:
  - PROMOTION LADDER (skills/skill-builder/references/promotion-ladder.md): going UP
    (references/ -> core) needs PROOF (N green runs / probe-verified fact, + Craig
    sign-off for conductor core). Going DOWN needs only disuse. Unique content being
    removed is NOT deleted outright -- it ages in the skill's MAINTENANCE.md holding
    pen (review-by window) before git-delete.
  - FRICTION CAPTURE (skills/skill-builder/references/friction-capture.md): if this
    edit is landing a lesson/fix learned from friction, log it in the skill's
    FRICTIONS.md first -- promotion should be evidence-driven, not vibes-driven.
  - NO-NET-GROWTH: SKILL.md core is loaded every invocation. Net line growth in core
    without an evidence stamp or a matching demotion/deletion will fail the lint.sh
    no-net-growth gate. Run `node scripts/skill-diet-conservation.mjs` if you are
    moving or removing content, to confirm nothing unique is lost.
  - SINGLE-HOME (ac-gcj/ac-znk.7): about to restate a rule whose canon lives in an
    owning domain skill (ac-pipeline/references/* — git discipline, delegation,
    run-ledger, verification gate; agent-mail/references/* — coordination;
    beads-standards — beads canon)? Point at it with a `§` anchor instead. The rare
    deliberate copy carries a `<!-- mirror: <canon> §... -- edit there first -->` mark.
    Litmus (ac-znk.4): a rule true in ANY workflow is domain canon, not workflow text —
    workflow files keep one-line when/who bindings + pointers.

(Fires once per session. This first attempt is blocked to surface the reminder; re-issue the edit to proceed.)
"""


def allow():
    sys.exit(0)


def session_key():
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID")
    if sid:
        return sid
    # No session id available (other harnesses / manual invocation) -> degrade to a
    # daily key so the guard still fires at most once per day, never every call.
    return "daily-" + datetime.date.today().isoformat()


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
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        allow()

    rel = path.replace(os.sep, "/")
    if not (fnmatch.fnmatch(rel, "*/skills/*/SKILL.md") or fnmatch.fnmatch(rel, "skills/*/SKILL.md")):
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
