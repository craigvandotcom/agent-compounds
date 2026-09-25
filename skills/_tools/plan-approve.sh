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
#   check --approved <plan>
#                         Read-only, same key-presence and digest verification as plain
#                         check, with the status floor lowered to approved: approved,
#                         bead-ready, beadified and done all pass. Answers "is this
#                         approval still valid?" for a plan sitting at status: approved
#                         that has not yet been polished to bead-ready. Plain `check` is
#                         unchanged — ac-beadify and ac-prep gate on it and must keep
#                         refusing an approved-but-unpolished plan.
#
# THE DIGEST: sha256 over the concatenated bodies of `## Vision`, `## Deliverables`,
# `## Decisions`, `## Out of scope`, `## Success Criteria` (matcher `## Success [Cc]`,
# so both the capital-C and lowercase-c spellings hash instead of empty) and `## Seams`,
# plus the `Human gates:` line — extracted with the same awk shape touchers.sh uses for
# `## Delivers`, the header parameterized rather than a second parser. `approved_sha256`
# is that single digest, exactly as named in the plan;
# `approved_section_digest` is a per-section breakdown of the SAME seven pieces so `ready` can
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
#            NOT-GATED (same tokens for `check --approved`, floor lowered to approved)
#
# Usage: plan-approve.sh approve <plan-path> [approved-by]
#        plan-approve.sh ready   <plan-path>
#        plan-approve.sh check   <plan-path>
#        plan-approve.sh check --approved <plan-path>
set -u

die_notgated() { printf 'NOT-GATED: %s\n' "$*"; exit 2; }

# The Delivers-path extraction pattern has ONE home (skills/_tools/delivers-paths.sh).
_DP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/delivers-paths.sh"
[ -f "$_DP_HOME" ] || die_notgated "delivers-paths.sh missing at $_DP_HOME — the extraction pattern cannot be resolved"
. "$_DP_HOME"

# Fail-closed digest guard: `set -u` is on but there is no pipefail, so an exit
# inside `$( ... | _sha )` never reaches the caller — the error text would become
# the digest and every mode would exit 0. Each mode calls this FIRST so a missing
# sha tool refuses from the mode itself (exit 2), never from inside a substitution.
_require_sha() {
  command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 \
    || die_notgated "no shasum or sha256sum on PATH — cannot compute a digest"
}

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
    SuccessCriterion) _section_body "$file" "## Success [Cc]" | _sha ;;
    Seams)            _section_body "$file" "## Seams$" | _sha ;;
    HumanGates)       _human_gates_line "$file" | _sha ;;
  esac
}

_SECTION_LABELS="Vision Deliverables Decisions OutOfScope SuccessCriterion Seams HumanGates"

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
    _section_body "$file" "## Success [Cc]"
    _section_body "$file" "## Seams$"
    _human_gates_line "$file"
  } | _sha
}

# Read one frontmatter key's value (first match, between the opening and closing `---`).
_fm_get() {
  local file="$1" key="$2"
  awk -v k="^${key}:" 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm && $0 ~ k {sub(k,""); sub(/^[[:space:]]*/,""); print; exit}' "$file"
}

# Print the frontmatter block only (between the line-1 `---` and its closer), so
# predicates read the stamp, never a fenced example or body text.
_fm_block() {
  local file="$1"
  awk 'NR==1 && $0=="---" { infm=1; next } infm && $0=="---" { exit } infm' "$file"
}

# Print the file minus fenced code blocks, so a fenced example can never satisfy
# a section-existence predicate.
_unfenced() {
  awk '/^[[:space:]]*```/ { f = !f; next } !f' "$1"
}

_missing_done_when() {
  local file="$1"
  _section_body "$file" "## Deliverables" | awk '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    {
      if ($0 ~ /^[-*][[:space:]]/) {
        if (in_bullet && !has_done) missing++
        in_bullet=1; has_done=0
      } else if ($0 ~ /^\|/) {
        if (in_bullet && !has_done) { missing++; in_bullet=0; has_done=0 }
        n=split($0, cell, "|")
        for (i=1; i<=n; i++) cell[i]=trim(cell[i])
        if (!table_seen) {
          if (cell[2] ~ /^[-: ]+$/) next
          for (i=1; i<=n; i++) if (tolower(cell[i]) ~ /done when/) done_col=i
          table_seen=1
          if (!done_col) table_bad=1
          next
        }
        if (cell[2] ~ /^-+$/) next
        if (cell[2] ~ /^[[:space:]]*[A-Za-z][A-Za-z0-9_-]*[[:space:]]*$/ && done_col && cell[done_col] == "") missing_table++
        next
      }
      if (in_bullet && $0 ~ /Done when:[[:space:]]*[^[:space:]]/) has_done=1
    }
    END {
      if (in_bullet && !has_done) missing++
      print missing + missing_table + table_bad
    }
  '
}

# Write/replace frontmatter keys. Args: file, then "key=value" pairs. Keys not already
# present are inserted just before the closing `---`; keys already present are replaced
# in place — idempotent, and it never disturbs a key it was not told to write (the same
# passthrough discipline polish-fixpoint.sh uses for its own polish_* keys).
_fm_write() {
  local file="$1"; shift
  [ "$(head -1 "$file")" = "---" ] || die_notgated "plan has no exact YAML frontmatter opener on line 1: $file"
  # Frontmatter values are single-line by construction: a literal newline inside a
  # value would land as a new key line on write — the injection ENVIRON alone cannot
  # stop (it stops escape EXPANSION, not embedded newlines). Refuse instead of
  # writing it.
  case "$*" in
    *$'\n'*) die_notgated "refusing multi-line frontmatter value" ;;
  esac
  local tmp; tmp=$(mktemp)
  # Pairs travel via the environment, never -v: awk expands escapes in -v
  # assignments, so a crafted approver name could add frontmatter keys.
  # Separators stay -v as literal bytes resolved by the shell (gawk/mawk/nawk
  # disagree on whether \x1e is an escape or four literal characters, so awk
  # only ever sees a plain string compare).
  PAIRS="$*" awk -v PAIRSEP="$(printf '\037')" -v KVSEP="$(printf '\036')" '
    BEGIN {
      n = split(ENVIRON["PAIRS"], kv, PAIRSEP)
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
  mv "$tmp" "$file" \
  || { rm -f "$tmp"; die_notgated "frontmatter move failed for $file"; }
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
  _require_sha

  # needs-human N — an open Decision card. A card is a top-level bullet block inside
  # ## Decisions, per the one card grammar in skills/ac-plan/references/decisions.md:
  # the open token `needs-human` is checked BEFORE `settled:` (plain or bold), so a
  # block carrying the open token is open even beside a settled-looking line; a
  # settled block wants a `vision: "<quoted line>"` quote.
  local dec_body; dec_body=$(_section_body "$plan" "## Decisions")
  local numbered maxb b block settled_no_vision=0 open_needs_human=0
  # A card is ONE top-level bullet block: only a column-0 bullet starts a new
  # block, so indented sub-bullets (`-` or `+`) stay inside the enclosing card.
  # Splitting on indented bullets instead false-refuses the prescribed `-`
  # sub-bullet card (the `settled:` line lands alone, with no `vision:`).
  numbered=$(printf '%s\n' "$dec_body" | awk '{ if ($0 ~ /^[-*][[:space:]]/) b++; printf "%d\t%s\n", b+0, $0 }')
  maxb=$(printf '%s\n' "$numbered" | awk -F'\t' '{ if ($1+0 > m) m = $1+0 } END { print m+0 }')
  b=0
  while [ "$b" -le "$maxb" ]; do
    block=$(printf '%s\n' "$numbered" | awk -F'\t' -v want="$b" '$1+0 == want { sub(/^[0-9]*\t/, ""); print }')
    b=$((b + 1))
    [ -n "$(printf '%s' "$block" | tr -d '[:space:]')" ] || continue
    if printf '%s' "$block" | grep -qE '(^|[^a-zA-Z-])needs-human([^a-zA-Z-]|$)'; then
      open_needs_human=$((open_needs_human + 1))
    elif printf '%s' "$block" | grep -qE '(^|[^a-zA-Z-])settled:'; then
      printf '%s' "$block" | grep -q 'vision:[[:space:]]*"' || settled_no_vision=$((settled_no_vision + 1))
    fi
  done

  if [ "$open_needs_human" -gt 0 ]; then
    printf 'REFUSED needs-human %s: Decision card(s) still need a human ruling\n' "$open_needs_human"
    exit 1
  fi

  if ! _unfenced "$plan" | grep -q '^## Decisions'; then
    printf 'REFUSED no-decisions: %s carries no ## Decisions section\n' "$plan"
    exit 1
  fi

  # Exact match only — a look-alike header (e.g. a seams-mode hand-off's
  # "## Seams — seen by more than one lens" reader evidence) must never satisfy
  # this refusal or be digested as the plan's own Seams table (ac-4y7l.3).
  if ! _unfenced "$plan" | grep -q '^## Seams$'; then
    printf 'REFUSED no-seams: %s carries no ## Seams section\n' "$plan"
    exit 1
  fi

  # seams-incomplete <path> — every path extracted from the whole ## Deliverables
  # bullet blocks owes a row in ## Seams, matched by FULL path (the Seams table
  # carries the same full form) and exempting nothing: a new file's row
  # reads `new — no touchers`. No git anywhere, so the check behaves the same inside
  # and outside a worktree.
  local seams_body; seams_body=$(_section_body "$plan" "## Seams$")
  local deliv_body; deliv_body=$(_section_body "$plan" "## Deliverables")
  local missing_done_when
  missing_done_when=$(_missing_done_when "$plan")
  if [ "$missing_done_when" -gt 0 ]; then
    printf 'REFUSED no-done-when %s: every deliverable needs a non-empty Done when observable\n' "$missing_done_when"
    exit 1
  fi
  local paths incomplete="" p
  paths=$(printf '%s\n' "$deliv_body" | extract_paths)
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    p="${p#./}"
    printf '%s\n' "$seams_body" | grep -qF "$p" || incomplete="${incomplete}${incomplete:+ }${p}"
  done <<EOF
$paths
EOF
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
  _require_sha

  if [ -z "$(_fm_get "$plan" polish_rounds)" ] || ! _fm_block "$plan" | grep -q '^polish_fixpoint_'; then
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
  # `--approved` is parsed as a flag, never taken as the plan path: `check --approved x`
  # must not treat `--approved` itself as the plan and NOT-GATE on a missing/unreadable
  # "plan".
  local approved_floor=0
  if [ "${1-}" = "--approved" ]; then
    approved_floor=1
    shift
  fi
  local plan="$1"
  [ -n "$plan" ] && [ -r "$plan" ] || die_notgated "plan missing or unreadable: ${plan:-<none>}"
  _require_sha

  local status approved_by approved_at approved_sha
  status=$(_fm_get "$plan" status)
  approved_by=$(_fm_get "$plan" approved_by)
  approved_at=$(_fm_get "$plan" approved_at)
  approved_sha=$(_fm_get "$plan" approved_sha256)
  if [ -z "$approved_by" ] || [ -z "$approved_at" ] || [ -z "$approved_sha" ]; then
    printf 'REFUSED missing-keys: %s carries no complete approval record\n' "$plan"
    exit 1
  fi

  if [ "$approved_floor" -eq 1 ]; then
    case "$status" in
      approved|bead-ready|beadified|done) : ;;
      *)
        printf 'REFUSED status %s: %s is not approved or later\n' "${status:-<none>}" "$plan"
        exit 1 ;;
    esac
  else
    case "$status" in
      bead-ready|beadified|done) : ;;
      *)
        printf 'REFUSED status %s: %s is not bead-ready or later\n' "${status:-<none>}" "$plan"
        exit 1 ;;
    esac
  fi

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
