#!/usr/bin/env bash
#
# memory-retrieval-seal.test.sh — the proof that hooks/memory-retrieval.py respects a
# project-local qmd index (`.qmd/index.yml`, made by `qmd init`).
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered, executed by the registry-lint
#   `proofs` CI job). Deliberately UNWIRED in engine/hooks.wiring.json: it is the PROOF for
#   memory-retrieval.py, not a hook itself.
#
# Why: a project with its own index is sealed (forge-one: its searches see only forge-one,
# and no other repo sees forge-one). The CLI calls inherit the cwd and are scoped by qmd
# itself; the resident daemon serves the GLOBAL index, and asking it leaked foreign memory
# into forge-one (2026-10-02). The states this suite pins:
#   A1 sealed cwd      — a subdir of a project with .qmd/index.yml is detected as sealed
#   A2 path mapping    — qmd://<collection>/ maps through the project's own config, with a
#                        relative `path: .` resolved against the project
#   A3 no daemon       — semantic recall in a sealed project never calls the daemon
#   A4 unsealed cwd    — a dir with no .qmd above it is not sealed (global behaviour kept)
#   B  end to end      — with qmd installed, the project's own fact is injected with the
#                        sealed hint (skipped, loudly, without qmd; A still ran)
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/memory-retrieval.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

PROJ="$TMP/sealed"
mkdir -p "$PROJ/.qmd" "$PROJ/memory/auto" "$PROJ/sub/deeper" "$TMP/open"
cat > "$PROJ/.qmd/index.yml" <<'EOF'
collections:
  sealed:
    path: .
    pattern: "**/*.md"
EOF
cat > "$PROJ/memory/auto/zorblax-calibration-rule.md" <<'EOF'
---
name: zorblax-calibration-rule
description: "Zorblax calibration always runs the quantel sweep before the flux reading, never after."
metadata:
  type: rule
  domain: app-local
  evidence: test fixture
---
EOF

# --- A: hook logic, no qmd needed ---------------------------------------------------
check_a() { # check_a <cwd> <expect-sealed 0|1>
  (cd "$1" && python3 - "$HOOK" "$PROJ" "$2" <<'PY'
import importlib.util, sys
hook, proj, expect = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
spec = importlib.util.spec_from_file_location("mr", hook)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
errs = []
if bool(m._PROJECT) != expect:
    errs.append(f"sealed={m._PROJECT!r}, expected sealed={expect}")
if expect:
    if m._PROJECT != proj:
        errs.append(f"project dir {m._PROJECT!r} != {proj!r}")
    if m._ROOTS.get("sealed") != proj:
        errs.append(f"qmd://sealed/ maps to {m._ROOTS.get('sealed')!r}, expected {proj!r}")
    called = []
    m._daemon_search = lambda *a, **k: called.append(1) or []
    m._cli_vsearch = lambda *a, **k: []
    m.semantic_search("zorblax calibration quantel sweep order", "qmd")
    if called:
        errs.append("semantic recall asked the global daemon from a sealed project")
print("\n".join(errs))
sys.exit(1 if errs else 0)
PY
  )
}
for case in "A1+A2+A3 sealed subdir|$PROJ/sub/deeper|1" "A4 unsealed dir|$TMP/open|0"; do
  IFS='|' read -r label dir expect <<<"$case"
  if out="$(check_a "$dir" "$expect" 2>&1)"; then echo "PASS $label"; else echo "FAIL $label: $out"; fail=1; fi
done

# --- B: end to end with a real project-local index ----------------------------------
QMD="$(command -v qmd || true)"
[ -z "$QMD" ] && [ -x "$HOME/.bun/bin/qmd" ] && QMD="$HOME/.bun/bin/qmd"
if [ -z "$QMD" ]; then
  echo "SKIP B end to end: qmd not installed (A ran)"
else
  (cd "$PROJ" && "$QMD" update >/dev/null 2>&1)
  out="$(cd "$PROJ/sub" && echo '{"prompt":"what is the zorblax calibration rule for the quantel sweep and flux reading","hook_event_name":"UserPromptSubmit"}' \
    | MEMORY_HOOK_QMD_BIN="$QMD" timeout 90 python3 "$HOOK")"
  if grep -q "zorblax-calibration-rule" <<<"$out" && grep -q "this project's own index only" <<<"$out"; then
    echo "PASS B end to end"
  else
    echo "FAIL B end to end: own fact or sealed hint missing. Output:"; echo "$out"; fail=1
  fi
fi

exit "$fail"
