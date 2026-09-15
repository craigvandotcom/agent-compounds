#!/usr/bin/env bash
# plan-approve.sh — the ONE writer of plan approval. Sibling of polish-fixpoint.sh and
# stamp-refined.sh; never a fifth fixpoint mode, never a hand edit (ac-wp8i.10).
#
# THREE MODES, each its own verdict:
#
#   approve <plan> [who]  A HUMAN act, once. Refuses needs-human N (an open Decision card) ·
#                         no-decisions (no ## Decisions section) · no-seams (no ## Seams
#                         section) · seams-incomplete <path> (an existing Deliverable path
#                         with no ## Seams row) · uncited-decision N (a settled card with no
#                         `vision:` quote) · no-approver (empty identity). Writes
#                         status: approved, approved_by, approved_at, approved_sha256 —
#                         plus approved_section_digest, an internal per-section ledger this
#                         script alone reads to name WHICH section moved on a later `ready`.
#                         Approver defaults to `git config user.name`; there is no agent-
#                         identity fallback and no bare positional form — mode is required.
#
#   ready <plan>          An agent act, after polish. Refuses not-polished (no
#                         polish_rounds/polish_fixpoint_* keys) · not-approved (status is not
#                         `approved`, or an approval key is missing) · regate <sections>
#                         (a gated section's body moved since approval — names which). On
#                         success writes status: bead-ready, bead_ready_at, regate: none.
#
#   check <plan>          Read-only. Exit 0 only when the approval keys are present, the
#                         digest still matches the current gated bodies, and status is
#                         bead-ready or later (beadified, done) — so it proves a retired
#                         plan too. Never writes.
#
# THE DIGEST: sha256 over the concatenated bodies of `## Vision`, `## Deliverables`,
# `## Decisions`, `## Out of scope`, `## Success criterion` (prefix match — a real plan
# carries `## Deliverables (artifacts)`) plus the `Human gates:` line — extracted with the
# same awk shape touchers.sh uses for `## Delivers`, the header parameterized rather than a
# second parser. `approved_sha256` is that single digest, exactly as named in the plan;
# `approved_section_digest` is a per-section breakdown of the SAME six pieces so `ready` can
# name the section that moved instead of only reporting "something changed" — state that
# must live in the plan (git-durable) rather than a scratch dir, because `ready` can run in
# a session that never saw `approve`'s tmpdir.
#
# Verdict tokens (one greppable line each):
#   approve: APPROVED · REFUSED needs-human N · REFUSED no-decisions · REFUSED no-seams ·
#            REFUSED seams-incomplete <path...> · REFUSED uncited-decision N ·
#            REFUSED no-approver · NOT-GATED
#   ready:   READY · REFUSED not-polished · REFUSED not-approved · REFUSED regate <sections> ·
#            NOT-GATED
#   check:   OK: ... · REFUSED missing-keys · REFUSED digest-mismatch · REFUSED status <status> ·
#            NOT-GATED
#
# Usage: plan-approve.sh approve <plan-path> [approved-by]
#        plan-approve.sh ready   <plan-path>
#        plan-approve.sh check   <plan-path>
set -u

die_notgated() { printf 'NOT-GATED: %s\n' "$*"; exit 2; }

_sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else printf 'NOT-GATED: no shasum or sha256sum on PATH — cannot compute a digest\n'; exit 2; fi
}

# The touchers.sh:128 awk shape, header parameterized: everything between a line matching
# the header (prefix match) and the next `## ` header, exclusive of both.
_section_body() {
  local file="$1" header="$2"
  awk -v h="$header" '
    $0 ~ ("^" h) { on=1; next }
    /^## / { on=0 }
    on { print }
  ' "$file"
}

_human_gates_line() {
  grep -m1 '^Human gates:' "$1" || true
}

# One digest per gated piece, keyed by a single-token label (no spaces — the label is a
# frontmatter-safe, grep-safe name, not the literal header text).
_section_digest_one() {
  local file="$1" label="$2"
  case "$label" in
    Vision)           _section_body "$file" "## Vision" | _sha ;;
    Deliverables)     _section_body "$file" "## Deliverables" | _sha ;;
    Decisions)        _section_body "$file" "## Decisions" | _sha ;;
    OutOfScope)       _section_body "$file" "## Out of scope" | _sha ;;
    SuccessCriterion) _section_body "$file" "## Success criterion" | _sha ;;
    HumanGates)       _human_gates_line "$file" | _sha ;;
  esac
}

_SECTION_LABELS="Vision Deliverables Decisions OutOfScope SuccessCriterion HumanGates"

_compute_section_digests() {
  local file="$1" label out=""
  for label in $_SECTION_LABELS; do
    out="${out}${out:+,}${label}=$(_section_digest_one "$file" "$label")"
  done
  printf '%s' "$out"
}

_compute_overall_digest() {
  local file="$1"
  {
    _section_body "$file" "## Vision"
    _section_body "$file" "## Deliverables"
    _section_body "$file" "## Decisions"
    _section_body "$file" "## Out of scope"
    _section_body "$file" "## Success criterion"
    _human_gates_line "$file"
  } | _sha
}

# Read one frontmatter key's value (first match, between the opening and closing `---`).
_fm_get() {
  local file="$1" key="$2"
  awk -v k="^${key}:" 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm && $0 ~ k {sub(k,""); sub(/^[[:space:]]*/,""); print; exit}' "$file"
}

# Write/replace frontmatter keys. Args: file, then "key=value" pairs. Keys not already
# present are inserted just before the closing `---`; keys already present are replaced
# in place — idempotent, and it never disturbs a key it was not told to write (the same
# passthrough discipline polish-fixpoint.sh uses for its own polish_* keys).
_fm_write() {
  local file="$1"; shift
  head -1 "$file" | grep -q '^---[[:space:]]*$' || die_notgated "plan has no YAML frontmatter to stamp: $file"
  local tmp; tmp=$(mktemp)
  # Separators passed as literal bytes via -v (never as an awk \x escape — gawk/mawk/nawk
  # disagree on whether \x1e is an escape or four literal characters, so the shell resolves
  # the byte and awk only ever sees a plain string compare).
  awk -v pairs="$*" -v PAIRSEP="$(printf '\037')" -v KVSEP="$(printf '\036')" '
    BEGIN {
      n = split(pairs, kv, PAIRSEP)
      for (i = 1; i <= n; i++) {
        split(kv[i], one, KVSEP)
        keys[i] = one[1]; vals[i] = one[2]
      }
      nk = n
    }
    NR==1 && $0=="---" { infm=1; print; next }
    infm && $0=="---" {
      for (i = 1; i <= nk; i++) if (!seen[keys[i]]) printf "%s: %s\n", keys[i], vals[i]
      infm=0; print; next
    }
    infm {
      matched = 0
      for (i = 1; i <= nk; i++) {
        if ($0 ~ ("^" keys[i] ":")) { printf "%s: %s\n", keys[i], vals[i]; seen[keys[i]]=1; matched=1; break }
      }
      if (matched) next
    }
    { print }
  ' "$file" > "$tmp" \
  || { rm -f "$tmp"; die_notgated "frontmatter write failed for $file"; }
  mv "$tmp" "$file"
}

# _fm_write's caller passes pairs as "key<0x1e>value<0x1f>key<0x1e>value…" — small helper
# so call sites stay readable.
_fm_pairs() {
  local out="" first=1
  while [ $# -ge 2 ]; do
    if [ "$first" -eq 1 ]; then first=0; else out="${out}"$'\x1f'; fi
    out="${out}${1}"$'\x1e'"${2}"
    shift 2
  done
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------------------
# approve
# ---------------------------------------------------------------------------------------
mode_approve() {
  local plan="$1" who="${2-}"
  [ -n "$plan" ] && [ -r "$plan" ] || die_notgated "plan missing or unreadable: ${plan:-<none>}"

  local root; root=$(git rev-parse --show-toplevel 2>/dev/null)

  # needs-human N — an open Decision card. A card is a top-level bullet block inside
  # ## Decisions; "settled" is a bold `**settled:` token on the block, "needs-human" the
  # bare word as a standalone token (never inside "settled").
  local dec_body; dec_body=$(_section_body "$plan" "## Decisions")
  local numbered maxb b block settled_no_vision=0 open_needs_human=0
  numbered=$(printf '%s\n' "$dec_body" | awk '{ if ($0 ~ /^[[:space:]]*[-*][[:space:]]/) b++; printf "%d\t%s\n", b+0, $0 }')
  maxb=$(printf '%s\n' "$numbered" | awk -F'\t' '{ if ($1+0 > m) m = $1+0 } END { print m+0 }')
  b=0
  while [ "$b" -le "$maxb" ]; do
    block=$(printf '%s\n' "$numbered" | awk -F'\t' -v want="$b" '$1+0 == want { sub(/^[0-9]*\t/, ""); print }')
    b=$((b + 1))
    [ -n "$(printf '%s' "$block" | tr -d '[:space:]')" ] || continue
    if printf '%s' "$block" | grep -q '\*\*settled:'; then
      printf '%s' "$block" | grep -q 'vision:[[:space:]]*"' || settled_no_vision=$((settled_no_vision + 1))
    elif printf '%s' "$block" | grep -qE '(^|[^a-zA-Z-])needs-human([^a-zA-Z-]|$)'; then
      open_needs_human=$((open_needs_human + 1))
    fi
  done

  if [ "$open_needs_human" -gt 0 ]; then
    printf 'REFUSED needs-human %s: Decision card(s) still need a human ruling\n' "$open_needs_human"
    exit 1
  fi

  if ! grep -q '^## Decisions' "$plan"; then
    printf 'REFUSED no-decisions: %s carries no ## Decisions section\n' "$plan"
    exit 1
  fi

  if ! grep -q '^## Seams' "$plan"; then
    printf 'REFUSED no-seams: %s carries no ## Seams section\n' "$plan"
    exit 1
  fi

  # seams-incomplete <path> — every Deliverable path that exists in the tree owes a row in
  # ## Seams (matched by basename substring, the same short-form the Seams table itself
  # uses — `plan-approve.sh` for `skills/_tools/plan-approve.sh`).
  local seams_body; seams_body=$(_section_body "$plan" "## Seams")
  local deliv_body; deliv_body=$(_section_body "$plan" "## Deliverables")
  local paths incomplete="" p base
  paths=$(printf '%s\n' "$deliv_body" | grep -oE '(\./)?[][A-Za-z0-9_@.()-]+(/[][A-Za-z0-9_@.()-]+)+\.[A-Za-z0-9]{1,6}' | sort -u)
  if [ -n "$root" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      p="${p#./}"
      [ -f "$root/$p" ] || continue
      base=$(basename "$p")
      printf '%s\n' "$seams_body" | grep -qF "$base" || incomplete="${incomplete}${incomplete:+ }${p}"
    done <<EOF
$paths
EOF
  fi
  if [ -n "$incomplete" ]; then
    printf 'REFUSED seams-incomplete %s\n' "$incomplete"
    exit 1
  fi

  if [ "$settled_no_vision" -gt 0 ]; then
    printf 'REFUSED uncited-decision %s: settled Decision card(s) carry no vision: quote\n' "$settled_no_vision"
    exit 1
  fi

  # Approver: an explicit (possibly empty) second arg overrides; omitted defaults to
  # `git config user.name`. There is no agent-identity fallback.
  if [ $# -ge 2 ]; then
    who="$2"
  else
    who=$(git config user.name 2>/dev/null || true)
  fi
  if [ -z "$who" ]; then
    printf 'REFUSED no-approver: no approver identity (pass one, or set git config user.name)\n'
    exit 1
  fi

  local ts; ts=$(date -u +%Y-%m-%d)
  local overall; overall=$(_compute_overall_digest "$plan")
  local sections; sections=$(_compute_section_digests "$plan")

  _fm_write "$plan" "$(_fm_pairs \
    status approved \
    approved_by "$who" \
    approved_at "$ts" \
    approved_sha256 "$overall" \
    approved_section_digest "$sections")"

  printf 'APPROVED: %s — status: approved, approved_by: %s, approved_sha256: %s\n' "$plan" "$who" "${overall:0:12}"
  exit 0
}

# ---------------------------------------------------------------------------------------
# ready
# ---------------------------------------------------------------------------------------
mode_ready() {
  local plan="$1"
  [ -n "$plan" ] && [ -r "$plan" ] || die_notgated "plan missing or unreadable: ${plan:-<none>}"

  if ! grep -q '^polish_rounds:' "$plan" || ! grep -q '^polish_fixpoint_' "$plan"; then
    printf 'REFUSED not-polished: %s carries no polish stamp keys (polish_rounds / polish_fixpoint_*)\n' "$plan"
    exit 1
  fi

  local status approved_by approved_at approved_sha approved_sections
  status=$(_fm_get "$plan" status)
  approved_by=$(_fm_get "$plan" approved_by)
  approved_at=$(_fm_get "$plan" approved_at)
  approved_sha=$(_fm_get "$plan" approved_sha256)
  approved_sections=$(_fm_get "$plan" approved_section_digest)
  if [ "$status" != "approved" ] || [ -z "$approved_by" ] || [ -z "$approved_at" ] || [ -z "$approved_sha" ] || [ -z "$approved_sections" ]; then
    printf 'REFUSED not-approved: %s is not status: approved with a complete approval record\n' "$plan"
    exit 1
  fi

  local current; current=$(_compute_section_digests "$plan")
  local label changed="" old new
  for label in $_SECTION_LABELS; do
    old=$(printf '%s' "$approved_sections" | tr ',' '\n' | awk -F= -v l="$label" '$1==l{print $2}')
    new=$(printf '%s' "$current" | tr ',' '\n' | awk -F= -v l="$label" '$1==l{print $2}')
    [ "$old" = "$new" ] || changed="${changed}${changed:+ }${label}"
  done
  if [ -n "$changed" ]; then
    printf 'REFUSED regate %s\n' "$changed"
    exit 1
  fi

  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  _fm_write "$plan" "$(_fm_pairs status bead-ready bead_ready_at "$ts" regate none)"
  printf 'READY: %s — status: bead-ready, bead_ready_at: %s, regate: none\n' "$plan" "$ts"
  exit 0
}

# ---------------------------------------------------------------------------------------
# check (read-only)
# ---------------------------------------------------------------------------------------
mode_check() {
  local plan="$1"
  [ -n "$plan" ] && [ -r "$plan" ] || die_notgated "plan missing or unreadable: ${plan:-<none>}"

  local status approved_by approved_at approved_sha
  status=$(_fm_get "$plan" status)
  approved_by=$(_fm_get "$plan" approved_by)
  approved_at=$(_fm_get "$plan" approved_at)
  approved_sha=$(_fm_get "$plan" approved_sha256)
  if [ -z "$approved_by" ] || [ -z "$approved_at" ] || [ -z "$approved_sha" ]; then
    printf 'REFUSED missing-keys: %s carries no complete approval record\n' "$plan"
    exit 1
  fi

  case "$status" in
    bead-ready|beadified|done) : ;;
    *)
      printf 'REFUSED status %s: %s is not bead-ready or later\n' "${status:-<none>}" "$plan"
      exit 1 ;;
  esac

  local overall; overall=$(_compute_overall_digest "$plan")
  if [ "$overall" != "$approved_sha" ]; then
    printf 'REFUSED digest-mismatch: %s — gated sections moved since approval\n' "$plan"
    exit 1
  fi

  printf 'OK: %s — status: %s, digest verified\n' "$plan" "$status"
  exit 0
}

# ---------------------------------------------------------------------------------------
# dispatch — mode is REQUIRED; the bare positional form (plan path with no mode) is gone
# ---------------------------------------------------------------------------------------
MODE="${1:-}"
case "$MODE" in
  approve) shift; mode_approve "$@" ;;
  ready)   shift; mode_ready "$@" ;;
  check)   shift; mode_check "$@" ;;
  '')      die_notgated "a mode is required: approve | ready | check" ;;
  *)       die_notgated "unknown mode '$MODE' — expected approve | ready | check" ;;
esac
