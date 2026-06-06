---
description: Prepare VM for heavy parallel work — assess state, free resources, restart leaky processes, report capacity
---

**You are the operations engineer.** Prepare this machine for a demanding parallel workload. Assess current state, free what you can, restart anything leaky, and report final capacity. Be conservative — only stop things that are clearly unnecessary for the session.

---

## I/O Contract

|                  |                                                                        |
| ---------------- | ---------------------------------------------------------------------- |
| **Input**        | Current machine state (auto-detected)                                  |
| **Output**       | Capacity report + optional sudo commands for the user to run manually  |
| **Artifacts**    | None (stateless — safe to run repeatedly)                              |
| **Verification** | Before/after memory comparison shows improvement                       |

## Prerequisites

- Linux VM with `/proc` filesystem
- PM2 processes managed via `pm2`

---

## Configuration

```
PM2=pm2

# Processes that are ALWAYS needed during heavy work
ESSENTIAL_PM2="qmd-mcp mcp-agent-mail"

# Processes that CAN be stopped safely (restart after session)
STOPPABLE_PM2="happy-daemon pai-scheduler"

# Processes that should be RESTARTED (leak mitigation)
RESTART_PM2="cass-indexer"

# Caches safe to clear (paths relative to $HOME)
CLEARABLE_CACHES=".cache/ms-playwright .cache/ms-playwright-go .cache/pip"

# How many parallel CC sessions the user expects
TARGET_SESSIONS=3

# Estimated per-session memory (MB) — Claude Code + MCP children
PER_SESSION_MB=1200
```

---

## Phase 1: Baseline Snapshot

Capture current state. Print a compact summary.

```bash
echo "=== BASELINE SNAPSHOT ==="
free -h
echo "---"
df -h / | tail -1
echo "---"
swapon --show
```

```bash
$PM2 jlist 2>/dev/null | python3 -c "
import json, sys
procs = json.load(sys.stdin)
print(f'{'Name':25s} {'Status':10s} {'Mem':>7s}  {'CPU':>5s}  Restarts')
print('-' * 65)
total_mb = 0
for p in procs:
    name = p['name']
    status = p['pm2_env']['status']
    mem = p['monit']['memory'] / (1024*1024)
    cpu = p['monit']['cpu']
    restarts = p['pm2_env']['restart_time']
    total_mb += mem
    print(f'{name:25s} {status:10s} {mem:6.0f}MB  {cpu:4.1f}%  {restarts}')
print(f'\nTotal PM2 memory: {total_mb:.0f}MB')
"
```

Record the baseline available memory (parse from `free`):

```bash
BASELINE_AVAIL=$(awk '/^Mem:/ {print $7}' <(free -m))
echo "Baseline available: ${BASELINE_AVAIL}MB"
```

---

## Phase 2: Intelligent Triage

Evaluate what's running and decide actions. Use these rules:

**Stop** — processes in `STOPPABLE_PM2` that aren't needed for bead-work:
- `happy-daemon`: code indexer, not needed during focused sessions
- `pai-scheduler`: cron-like scheduler — safe to pause for a few hours

**Restart** — processes in `RESTART_PM2` with known leaks:
- `cass-indexer`: connector growth bug, restart resets to ~6MB

**Keep** — processes in `ESSENTIAL_PM2`:
- `qmd-mcp`: needed for search
- `mcp-agent-mail`: needed for agent coordination
- `pai-slack-bot`: notifications — ask user

Ask the user:

```
AskUserQuestion(
  questions: [{
    question: "Which optional services should we keep running?",
    header: "Keep alive",
    multiSelect: true,
    options: [
      { label: "pai-slack-bot", description: "Slack notifications — useful if monitoring from phone" },
      { label: "pai-scheduler", description: "Scheduled jobs — safe to stop for a few hours" },
      { label: "happy-daemon", description: "Code indexer — not needed for bead-work" }
    ]
  }]
)
```

---

## Phase 3: Execute Cleanup

### 3a. Stop non-essential PM2 processes

For each process the user chose NOT to keep:

```bash
$PM2 stop <process-name>
```

### 3b. Restart leaky processes

```bash
$PM2 restart cass-indexer
```

Wait 3 seconds, then verify it restarted cleanly:

```bash
$PM2 show cass-indexer | grep -E "(status|memory)"
```

### 3c. Clear safe caches

Only clear caches from `CLEARABLE_CACHES` that exist and are large (>50MB):

```bash
for cache_dir in $CLEARABLE_CACHES; do
    full_path="$HOME/$cache_dir"
    if [ -d "$full_path" ]; then
        size=$(/usr/bin/du -sm "$full_path" | cut -f1)
        if [ "$size" -gt 50 ]; then
            echo "Clearing $cache_dir (${size}MB)"
            rm -rf "$full_path"
        fi
    fi
done
```

### 3d. Clear old temp files (>24h)

```bash
find /tmp -maxdepth 1 -user $(whoami) -mtime +1 -exec rm -rf {} + 2>/dev/null
```

---

## Phase 4: Sudo Commands (User-Executed)

Claude cannot run `sudo`. Print these commands for the user to run manually if they want maximum headroom:

```
echo ""
echo "=== OPTIONAL: Run these in another terminal for maximum headroom ==="
echo ""
echo "# Drop page cache (frees buffer/cache memory for applications)"
echo "sudo sysctl -w vm.drop_caches=3"
echo ""
echo "# Clear and re-enable swap (removes stale swap pages)"
echo "sudo swapoff -a && sudo swapon -a"
echo ""
echo "# Trim journal logs older than 3 days"
echo "sudo journalctl --vacuum-time=3d"
echo ""
```

---

## Phase 5: Final Report

Re-capture state and compare:

```bash
echo "=== POST-PREP SNAPSHOT ==="
free -h
```

```bash
FINAL_AVAIL=$(awk '/^Mem:/ {print $7}' <(free -m))
GAINED=$((FINAL_AVAIL - BASELINE_AVAIL))
echo ""
echo "Available memory: ${BASELINE_AVAIL}MB → ${FINAL_AVAIL}MB (+${GAINED}MB freed)"
```

```bash
$PM2 jlist 2>/dev/null | python3 -c "
import json, sys
procs = json.load(sys.stdin)
running = [p for p in procs if p['pm2_env']['status'] == 'online']
stopped = [p for p in procs if p['pm2_env']['status'] == 'stopped']
total_mb = sum(p['monit']['memory']/(1024*1024) for p in running)
print(f'PM2: {len(running)} running ({total_mb:.0f}MB), {len(stopped)} stopped')
for p in running:
    print(f'  ✓ {p[\"name\"]}')
for p in stopped:
    print(f'  ⏸ {p[\"name\"]}')
"
```

### Capacity Estimate

Calculate estimated headroom for parallel sessions:

```
Available MB from free output
- (TARGET_SESSIONS × PER_SESSION_MB) for Claude Code sessions
- 500MB safety buffer
= Remaining headroom
```

Print a clear verdict:

- **Green:** >1GB headroom after estimated sessions
- **Yellow:** 0-1GB headroom — workable but watch memory
- **Red:** Negative headroom — reduce session count or stop more processes

---

## Phase 6: Session Restore Reminder

Print a restore command the user can run after the heavy session:

```
echo ""
echo "=== AFTER YOUR SESSION ==="
echo "Restore stopped services:"
echo "  $PM2 start all"
echo ""
```
