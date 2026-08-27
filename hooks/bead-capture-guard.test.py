# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-harnesses.sh (glob-discovered, executed by the registry-lint
# `harnesses` CI job since ac-on0y.1) and lint.sh Check 18, which drives the same cases.
# Deliberately UNWIRED in hooks/hooks.json: it is the PROOF for bead-capture-guard.py,
# not a hook itself. Declared so orphan detection (lint Check 21) does not read a live
# proof harness as a dead executable.
import json, os, subprocess, sys
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bead-capture-guard.py")
BLOCK, ALLOW = 2, 0
cases = [
 (BLOCK, 'br create "x" -t task -p 2',                              "bare create, no labels"),
 (ALLOW, 'br create "x" -t task -l "origin:ac-review,unrefined"',   "create with origin"),
 (BLOCK, 'br create "x" -t task -l "triage,unrefined"',             "labels but no origin"),
 (ALLOW, 'br create --help',                                        "help"),
 (ALLOW, 'br list --json',                                          "other subcommand"),
 (ALLOW, 'bv --robot-next',                                         "bv untouched"),
 (ALLOW, 'br q "x" -l origin:manual',                               "quick capture with origin"),
 (BLOCK, 'br q "x" -l unrefined',                                   "quick capture without"),
 (ALLOW, 'br create "t" -l "origin:x" -d "then run br create foo"', "br create inside description"),
 (ALLOW, 'echo "br create foo"',                                    "br create inside echo string"),
 (ALLOW, 'git commit -m "br create thing"',                         "br create in commit msg"),
 (BLOCK, 'cd /tmp && br create "y" -t task',                        "chained after cd"),
 (ALLOW, 'cd /tmp && br create "y" -t task -l origin:ac-land,unrefined', "chained, labelled"),
 (ALLOW, 'br create "x" --labels=origin:ac-tidy',                   "--labels= form"),
 (BLOCK, 'br create "x" --labels=hygiene',                          "--labels= without origin"),
 (BLOCK, 'FOO=1 br create "x" -t task',                             "env-prefixed"),
 (BLOCK, 'br create "x" -l "notorigin:sneaky"',                     "origin as substring must not pass"),
 (ALLOW, 'br create "x" -l "unrefined,origin:ac-qa-device"',        "origin second in list"),
 (ALLOW, 'br create "x" -t task -l "origin:unknown,unrefined"',     "unknown is legal"),
 (ALLOW, "cat <<'EOF'\nbr create nope\nEOF",                        "heredoc body"),
 (ALLOW, 'br create "x" -l "origin:a" ; br create "y" -l origin:b', "two labelled creates"),
 (BLOCK, 'br create "x" -l origin:a ; br create "y" -t task',       "second create unlabelled"),
 (ALLOW, 'echo "unbalanced \'quote',                                "unparseable -> fail open"),
 (ALLOW, '/Users/x/.local/bin/br create "z" -l origin:ac-review',   "absolute path br"),
 (BLOCK, '/Users/x/.local/bin/br create "z" -t bug',                "absolute path br, no origin"),
 # qa-shared.md ships a two-twin placeholder the caller must substitute. An UNsubstituted
 # placeholder must still block — otherwise a copy-paste files beads with a literal
 # "origin:<ac-qa-device|ac-qa-browser>" and the provenance data is junk.
 (BLOCK, 'br create "x" -t bug --labels "origin:<ac-qa-device|ac-qa-browser>,qa-finding,unrefined"',
         "unsubstituted twin placeholder must block"),
 (ALLOW, 'br create "x" -t bug --labels "origin:ac-qa-device,qa-finding,unrefined"',
         "substituted twin placeholder passes"),
 # --- readiness axis ---
 (BLOCK, 'br create "x" -t task -l "origin:ac-review"',        "task, origin but no readiness"),
 (BLOCK, 'br create "x" -t bug -l "origin:ac-review,review-finding"', "bug, no readiness"),
 (ALLOW, 'br create "x" -t task -l "origin:ac-review,unrefined"',     "task + unrefined"),
 (ALLOW, 'br create "x" -t decision -l "origin:dream,human-gate"',    "decision + human-gate"),
 (ALLOW, 'br create "x" -t task -l "origin:x,refined"',              "refined accepted, not second-guessed"),
 # Epics are containers, never picked up — exempt, and must stay exempt or every
 # epic-creation template in the registry breaks.
 (ALLOW, 'br create "Epic: x" -t epic -l "origin:ac-review"',        "epic exempt from readiness"),
 (ALLOW, 'br create "Epic: x" --type=epic -l "origin:ac-hygiene"',   "epic via --type= form"),
 # Unknowable type must SKIP readiness, not block: `<type>` could stand for epic.
 (ALLOW, 'br create "x" -t <type> -l "origin:ac-bead-capture"',      "placeholder type skips readiness"),
 (ALLOW, 'br create "x" -l "origin:ac-bead-capture"',                "absent type skips readiness"),
 # -l is repeatable; readiness may live in the SECOND flag.
 (ALLOW, 'br create "x" -t task -l "origin:x" -l "unrefined"',       "readiness in a repeated -l"),
 (BLOCK, 'br create "x" -t task -l "origin:x" -l "backend"',         "repeated -l, still no readiness"),
]
fails = 0
for want, cmd, name in cases:
    p = subprocess.run([sys.executable, G], input=json.dumps({"tool_name":"Bash","tool_input":{"command":cmd}}),
                       capture_output=True, text=True)
    got = p.returncode
    ok = got == want
    if not ok:
        fails += 1
        print(f"FAIL  want={want} got={got}  {name}\n      cmd: {cmd!r}\n      err: {p.stderr[:150]}")
    else:
        print(f"ok    {('BLOCK' if want==2 else 'ALLOW'):5}  {name}")
print(f"\n{len(cases)-fails}/{len(cases)} passed")
sys.exit(1 if fails else 0)
