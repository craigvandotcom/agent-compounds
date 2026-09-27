---
name: long-running-watcher-keeps-old-code-after-field-rename
description: a watch/TUI process that re-runs a JSON producer each tick but loaded its parser once shows an impossible 0 after a same-day field rename — restart the watcher, don't debug the data
metadata:
  type: recipe
  domain: org
  evidence: 2026-09-27 — commit 0029f614 renamed board.sh --json `n_ready` → `n_pick` and updated tui.py; two ac-board watch windows started before it kept printing "▶ /ac-implement 0 ready beads"
  tags: [ac-board, tui, debugging, stale-process]
---

A long-running display process (ac-board's `tui.py` watch loop) imports its code once
at start but re-shells the producer (`board.sh --json`) every tick. After a commit that
renames a field in the producer's JSON and updates the consumer in the same commit, the
**old** process gets **new** data: it looks up the old key, finds nothing, and its
`.get(key, 0)` default prints a plausible-looking but impossible value ("0 ready beads").

**Diagnose:** when a watcher shows an impossible value, compare the process start time
(`ps -o lstart= -p <pid>`) with the last commit touching the consumer. Started before it →
stale code.

**Fix:** restart the watcher. The data pipeline is fine — every fresh `board.sh --json`
run carried the right count.

**Prevention:** a consumer that defaults a missing key to 0 turns schema drift into a
silent wrong answer; failing loud on a missing key surfaces it at once.
