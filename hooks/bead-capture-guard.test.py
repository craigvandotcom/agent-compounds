# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered, executed by the registry-lint
# `proofs` CI job since ac-on0y.1) and lint.sh Check 18, which drives the same cases.
# Deliberately UNWIRED in engine/hooks.wiring.json: it is the PROOF for bead-capture-guard.py,
# not a hook itself. Declared so orphan detection (lint Check 21) does not read a live
# proof harness as a dead executable.
import json
import os
import subprocess
import sys
import tempfile

G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bead-capture-guard.py")
BLOCK, ALLOW = 2, 0
cases = [
 (BLOCK, 'br create "x" -t task -p 2',                              "bare create, no labels"),
 (ALLOW, 'br create "x" -t task -l "origin:ac-review,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"', "create with origin + probe"),
 (BLOCK, 'br create "x" -t task -l "triage,unrefined"',             "labels but no origin"),
 (ALLOW, 'br create --help',                                        "help"),
 (ALLOW, 'br list --json',                                          "other subcommand"),
 (ALLOW, 'bv --robot-next',                                         "bv untouched"),
 (ALLOW, 'br q "x" -t epic -l origin:manual',                       "quick capture with origin"),
 (BLOCK, 'br q "x" -l unrefined',                                   "quick capture without"),
 (ALLOW, 'br create "t" -t epic -l "origin:x" -d "then run br create foo"', "br create inside description"),
 (ALLOW, 'echo "br create foo"',                                    "br create inside echo string"),
 (ALLOW, 'git commit -m "br create thing"',                         "br create in commit msg"),
 (BLOCK, 'cd /tmp && br create "y" -t task',                        "chained after cd"),
  (ALLOW, 'cd /tmp && br create "y" -t task -l origin:ac-land,unrefined,impact:data -d "- AC: x. Probe: `true` - tier: none"', "chained, labelled"),
 (ALLOW, 'br create "x" -t epic --labels=origin:ac-backlog',        "--labels= form"),
 (BLOCK, 'br create "x" --labels=hygiene',                          "--labels= without origin"),
 (BLOCK, 'FOO=1 br create "x" -t task',                             "env-prefixed"),
 (BLOCK, 'br create "x" -l "notorigin:sneaky"',                     "origin as substring must not pass"),
  (ALLOW, 'br create "x" -t investigation -l "unrefined,origin:ac-qa,impact:data"', "origin second in list"),
 (ALLOW, 'br create "x" -t task -l "origin:unknown,unrefined" -d "- AC: x. Probe: `true` - tier: none"', "unknown is legal"),
 (ALLOW, "cat <<'EOF'\nbr create nope\nEOF",                        "heredoc body"),
 # --- origin gate: multi-line shapes (ac-y25j). A heredoc body is DATA, never a
 # command position: `br create` inside it stays ALLOW, but a `br create` on its own
 # line after a heredoc (or after any statement) is a real command and must be checked.
 (BLOCK, 'echo hi\nbr create "t" -t task -p 2 -l human-gate',
         "newline-separated create, no origin"),
 (BLOCK, "cat > /tmp/x.md <<'EOF'\nit's a body\nEOF\nbr create \"t\" -t task -p 2 -l human-gate",
         "apostrophe in heredoc body, then create, no origin"),
 (ALLOW, 'br create "x" -t epic -l "origin:a" ; br create "y" -t epic -l origin:b', "two labelled creates"),
 (BLOCK, 'br create "x" -l origin:a ; br create "y" -t task',       "second create unlabelled"),
 (ALLOW, 'echo "unbalanced \'quote',                                "unparseable -> fail open"),
 (ALLOW, '/Users/x/.local/bin/br create "z" -t epic -l origin:ac-review,impact:data', "absolute path br"),
 (BLOCK, '/Users/x/.local/bin/br create "z" -t bug',                "absolute path br, no origin"),
# qa-shared.md ships an origin placeholder the caller must substitute. An UNsubstituted
  # placeholder must still block — otherwise a copy-paste files beads with a literal
  # "origin:<ac-qa>" and the provenance data is junk.
  (BLOCK, 'br create "x" -t bug --labels "origin:<ac-qa>,qa-finding,unrefined"',
          "unsubstituted placeholder must block"),
  (ALLOW, 'br create "x" -t bug --labels "origin:ac-qa,qa-finding,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"',
          "substituted placeholder passes"),
 # --- readiness axis ---
 (BLOCK, 'br create "x" -t task -l "origin:ac-review"',        "task, origin but no readiness"),
 (BLOCK, 'br create "x" -t bug -l "origin:ac-review,review-finding"', "bug, no readiness"),
 (ALLOW, 'br create "x" -t task -l "origin:ac-review,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"',  "task + unrefined"),
 (ALLOW, 'br create "x" -t decision -l "origin:dream,human-gate"',    "decision + human-gate"),
 (BLOCK, 'br create "x" -t task -l "origin:x,refined" -d "- AC: x. Probe: `true` - tier: none"',  "refined rejected at create, sole writer is stamp-refined.sh"),
 # ac-4y7l.13: `refined` must be refused whatever readiness label rides beside it and
 # whatever the type — a readiness label present does not make it exempt.
 (BLOCK, 'br create "x" -t task -l "origin:x,unrefined,refined" -d "- AC: x. Probe: `true` - tier: none"',
         "refined beside a readiness label is still blocked"),
 (BLOCK, 'br create "x" -t task -l "origin:x,unrefined" -l "refined" -d "- AC: x. Probe: `true` - tier: none"',
         "refined in a separate -l flag is still blocked"),
 (BLOCK, 'br create "x" -l "origin:x,unrefined,refined" -d "- AC: x. Probe: `true` - tier: none"',
         "refined with no -t (defaults to task) is still blocked"),
 (BLOCK, 'br create "Epic: x" -t epic -l "origin:x,refined"',
         "refined on an epic is still blocked — no type exemption"),
 # Epics are containers, never picked up — exempt, and must stay exempt or every
 # epic-creation template in the registry breaks.
 (ALLOW, 'br create "Epic: x" -t epic -l "origin:ac-review,impact:data"',        "epic exempt from readiness"),
 (ALLOW, 'br create "Epic: x" --type=epic -l "origin:ac-hygiene,impact:data"',   "epic via --type= form"),
 # Unknowable type must SKIP readiness, not block: `<type>` could stand for epic.
 (ALLOW, 'br create "x" -t <type> -l "origin:ac-backlog"',      "placeholder type skips readiness"),
 (BLOCK, 'br create "x" -l "origin:ac-backlog"',                "no -t defaults to task, still needs readiness"),
 # -l is repeatable; readiness may live in the SECOND flag.
  (ALLOW, 'br create "x" -t task -l "origin:x" -l "unrefined" -d "- AC: x. Probe: `true` - tier: none"', "readiness in a repeated -l"),
  (BLOCK, 'br create "x" -t task -l "origin:x" -l "backend"',         "repeated -l, still no readiness"),
  # --- probe axis: born probe-bearing (ac-v5vi). Implementable types (bug/task/feature)
  # need one `Probe: `<command>`` ... tier: line in the body; epic/decision/investigation
  # are exempt; an absent description blocks; a placeholder body skips (bead_type doctrine).
  (BLOCK, 'br create "x" -t bug -l "origin:ac-triage,unrefined"',        "bug without Probe -> refused"),
 (ALLOW, 'br create "x" -t bug -l "origin:ac-triage,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"', "bug with Probe -> admitted"),
 (ALLOW, 'br create "x" -t investigation -l "origin:ac-triage,unrefined,impact:data"', "investigation without Probe -> admitted"),
  (ALLOW, 'br create "Epic: x" -t epic -l "origin:ac-triage,impact:data"',           "epic without Probe -> admitted"),
  (BLOCK, 'br create "x" -t task -l "origin:ac-triage,unrefined"',       "task, absent description -> blocked"),
  (ALLOW, 'br create "x" -t task -l "origin:ac-triage,unrefined,impact:data" -d "<body>"', "placeholder body skips probe"),
  # --- impact axis (ac-wp8i.3): an AUTOMATED origin needs exactly one closed-set impact
  # label; human/plan origins and human-gate forks are exempt (a refusal names them).
  (BLOCK, 'br create "x" -t task -l "origin:ac-implement,unrefined" -d "- AC: x. Probe: `true` - tier: none"',
          "automated origin, no impact -> refused"),
  (ALLOW, 'br create "x" -t task -l "origin:ac-human-session,unrefined" -d "- AC: x. Probe: `true` - tier: none"',
          "human origin, no impact -> admitted"),
  (BLOCK, 'br create "x" -t task -l "origin:ac-implement,unrefined,impact:perf" -d "- AC: x. Probe: `true` - tier: none"',
          "impact outside the closed set -> refused"),
  # --- subagent refusal (ac-wp8i.3): a subagent files NOTHING — every create, fork
  # included, is refused and returned to the coordinator as a PROPOSED-BEAD.
  (BLOCK, 'br create "x" -t task -l "origin:ac-review,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"',
          "subagent, non-gate create -> refused", {"agent_id": "sub-1"}),
  (BLOCK, 'br create "x" -t decision -l "origin:ac-review,human-gate"',
          "subagent, human-gate fork -> refused", {"agent_id": "sub-1"}),
  # --- evasion classes (ac-review 2026-09-10): the guard must see a `br create` reached
  # through command substitution, a shell `-c` wrapper, or a command wrapper.
  (BLOCK, 'out=$(br create "x" -t task)',         "command substitution, no origin"),
  (BLOCK, '`br create "x" -t task`',              "backtick substitution, no origin"),
  (BLOCK, "sh -c 'br create \"x\" -t task'",      "shell -c wrapper, no origin"),
  (BLOCK, 'bash -c "br create x -t task"',        "bash -c wrapper, no origin"),
  (BLOCK, 'xargs br create "x" -t task',          "xargs wrapper, no origin"),
  (BLOCK, 'env br create "x" -t task',            "env wrapper, no origin"),
  (ALLOW, 'out=$(date)',                          "substitution with no bead create"),
  (BLOCK, 'br create "x" -t task -l "origin:ac-review,unrefined,impact:data,human-gate" -d "- AC: x. Probe: `true` - tier: none"',
          "subagent, bare human-gate on a task -> refused", {"agent_id": "sub-1"}),
  (BLOCK, 'br create "ACTION: do x" -t task -l "origin:ac-review,human-gate" -d "<body>"',
          "subagent, ACTION fork -> refused", {"agent_id": "sub-1"}),
  # --- impact-axis origins (ac-review 2026-09-11): ac-qa and ac-land file automated
  # non-gate beads and now require impact; reflect/dream file only human-gate cards.
  (BLOCK, 'br create "x" -t task -l "origin:ac-qa,unrefined" -d "- AC: x. Probe: `true` - tier: none"',
          "ac-qa automated origin, no impact -> refused"),
  (ALLOW, 'br create "x" -t task -l "origin:ac-qa,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"',
          "ac-qa with impact -> admitted"),
  (BLOCK, 'br create "x" -t bug -l "origin:ac-land,unrefined" -d "- AC: x. Probe: `true` - tier: none"',
          "ac-land automated origin, no impact -> refused"),
  # --- subagent marker via the ambient AC_SUBAGENT env seam (harnesses that cannot supply
  # the agent_id stdin field set this instead).
  (BLOCK, 'br create "x" -t decision -l "origin:ac-review,human-gate"',
          "subagent via AC_SUBAGENT, decision fork -> refused", {}, {"AC_SUBAGENT": "1"}),
  (BLOCK, 'br create "x" -t task -l "origin:ac-review,unrefined,impact:data" -d "- AC: x. Probe: `true` - tier: none"',
          "subagent via AC_SUBAGENT, non-gate create -> refused", {}, {"AC_SUBAGENT": "1"}),
  # --- glued separators (ac-48vu): shlex keeps `;` / `&&` / `||` / `|` stuck to the
  # previous word, so the following `br create` was never a command of its own.
  (BLOCK, 'true; br create x -t task -l origin:x,refined',
          "glued semicolon, refined create is still inspected"),
  (BLOCK, 'cd /tmp; br create "y" -t task',
          "glued semicolon after cd, no origin"),
  (BLOCK, 'true&&br create "x" -t task',
          "glued && before br create, no origin"),
  (BLOCK, 'true||br create "x" -t task',
          "glued || before br create, no origin"),
  (BLOCK, 'true|br create "x" -t task',
          "glued pipe before br create, no origin"),
  (ALLOW, 'echo "true; br create foo"',
          "glued separator inside quotes is not a command"),
  (ALLOW, 'br create "x" -t epic -l "origin:manual" -d "a;b && c || d | e"',
          "separators inside a description stay data"),
]

# --- probe axis: file bodies and the dollar hatch (ac-6ian) ---
# `<body>` / `$VAR` stay a skip. `$(...)` does not: a command substitution the guard
# cannot reduce to one file is refused, and `$(cat path)` / `--description-file` are
# read so a real Probe line passes and a probe-less body does not.
_labelled = 'br create "x" -t task -l "origin:ac-triage,unrefined,impact:data" '
def _body_file(text):
    fh = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False)
    fh.write(text)
    fh.close()
    return fh.name
_with_probe = _body_file("- AC: x. Probe: `true` - tier: none\n")
_without_probe = _body_file("a body with no probe line\n")
cases += [
  (ALLOW, _labelled + '-d "$BODY"',
          "unsubstituted $VAR body still skips the probe axis"),
  (ALLOW, _labelled + "-d '${BODY}'",
          "unsubstituted ${VAR} body still skips the probe axis"),
  (BLOCK, _labelled + '-d "$(printf no-probe)"',
          "command substitution is not waved through"),
  (ALLOW, _labelled + '-d "$(cat <file>)"',
          "unsubstituted cat <file> template still skips"),
  (ALLOW, _labelled + '-d "$(cat ' + _with_probe + ')"',
          "cat substitution with a Probe line is inspected and admitted"),
  (BLOCK, _labelled + '-d "$(cat ' + _without_probe + ')"',
          "cat substitution without a Probe line is refused"),
  (ALLOW, _labelled + '--description-file ' + _with_probe,
          "description-file with a Probe line is inspected and admitted"),
  (BLOCK, _labelled + '--description-file ' + _without_probe,
          "description-file without a Probe line is refused"),
  (BLOCK, _labelled + '--description-file ' + _with_probe + '.missing',
          "description-file that cannot be read is refused"),
  (BLOCK, _labelled + '--description-file -',
          "description-file from stdin cannot be verified and is refused"),
]

# --- probe-shape axis (moved from lint Check 19, ac-review ruling 5): a `Probe:` line
# that runs must still MEASURE — these three shapes pass `no probe, no bead` (a runnable
# command with no syntax error) while measuring nothing, so they are born-refused here
# rather than caught later as a stale skill-doc template.
cases += [
  (BLOCK, _labelled + '-d "- AC: x. Probe: `pnpm test:integration:local -- __tests__/x.test.ts` - tier: supabase-integration"',
          "pnpm -- passthrough probe -> refused"),
  (BLOCK, _labelled + '-d "- AC: x. Probe: `npx vitest run __tests__/x.test.ts` - tier: standing-vitest"',
          "bare vitest run probe -> refused"),
  (BLOCK, _labelled + '-d "- AC: x. Probe: `grep -c foo file.ts` - tier: none"',
          "grep -c pass/fail probe -> refused"),
  (ALLOW, _labelled + '-d "- AC: x. Probe: `pnpm test:one __tests__/x.test.ts` - tier: standing-vitest"',
          "pnpm test:one probe -> admitted"),
  (ALLOW, _labelled + '-d "- AC: x. Probe: `VITEST_AFFECTED_DISABLED=1 npx vitest run __tests__/x.test.ts` - tier: standing-vitest"',
          "affected-disabled vitest probe -> admitted"),
  (ALLOW, _labelled + '-d "- AC: x. Probe: `npx vitest run --config vitest.integration.local.config.mts __tests__/x.test.ts` - tier: supabase-integration"',
          "integration-config vitest probe -> admitted"),
  (ALLOW, _labelled + '-d "- AC: x. Probe: `grep -q foo file.ts` - tier: none"',
          "grep -q probe -> admitted"),
  (ALLOW, _labelled + '-d "- AC: x. Probe: `! grep -q foo file.ts` - tier: none"',
          "! grep -q probe -> admitted"),
]
fails = 0
for case in cases:
    want, cmd, name = case[0], case[1], case[2]
    extra = case[3] if len(case) > 3 else {}
    env_extra = case[4] if len(case) > 4 else None
    payload = {"tool_name": "Bash", "tool_input": {"command": cmd}}
    payload.update(extra)
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    p = subprocess.run([sys.executable, G], input=json.dumps(payload),
                       capture_output=True, text=True, env=env, timeout=30, check=False)
    got = p.returncode
    ok = got == want
    if not ok:
        fails += 1
        print(f"FAIL  want={want} got={got}  {name}\n      cmd: {cmd!r}\n      err: {p.stderr[:150]}")
    else:
        print(f"ok    {('BLOCK' if want==2 else 'ALLOW'):5}  {name}")
print(f"\n{len(cases)-fails}/{len(cases)} passed")
sys.exit(1 if fails else 0)
