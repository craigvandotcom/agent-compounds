#!/usr/bin/env bash
# journey-stamp-check.sh — mechanical staleness gate for review-critical journeys.
#
# Runs INSIDE AN APP REPO (not agent-compounds). Parses the YAML frontmatter of
# every `.claude/skills/CORE/journeys/*.md` doc, and for each `review-critical`
# journey decides MISSING / STALE / OK per the ancestry+surfaces test in
# _plans/2026-07-07-runtime-proof-doctrine.md §5 decision 1:
#
#   a stamp is OK iff `last_pass.sha` is an ancestor of the ship SHA
#   AND no file in `last_pass.sha..<ship-sha>` touches a diff-class in the
#   journey's declared `surfaces:`.
#
# Docs with no frontmatter are `peripheral` by convention and ignored — only
# `review-critical` journeys gate anything here.
#
# Usage:
#   journey-stamp-check.sh [--app <path>] [--sha <ship-sha>] [--lane store|testflight]
#
#   --app   path to the app repo to check (default: cwd)
#   --sha   the commit being shipped        (default: HEAD)
#   --lane  store     — BLOCKS (exit 1) on any MISSING/STALE review-critical journey
#           testflight — never blocks (exit 0); prints WARN lines instead
#
# Exit codes: 0 clean (or lane=testflight, regardless of findings) · 1 lane=store
# with ≥1 MISSING/STALE review-critical journey · 2 usage/setup error.
#
# Deps: bash + git + awk/sed/grep (POSIX-ish). No yq, no python.
set -euo pipefail

# ============================================================================
# Surface -> path-pattern mapping — MIRRORS the diff classifier in
# `ac-pipeline-builder/references/verification-gate.md` Step 1. This is the one clearly-marked table
# to hand-tune if an app's layout diverges from the classifier's assumptions.
# Fail-safe rule — DELIBERATELY STRICTER than verification-gate.md Step 1
# (which classifies an unmatched file as runtime-only): here an unclassifiable
# file counts as touching EVERY surface. Selection (merge smoke) may err loose;
# a staleness gate on store submission must err strict — over-block, never
# under-block. This asymmetry is documented in verification-gate.md §Journey
# registry.
#
#   class   | path pattern (grep -E, matched against the changed file's path)
#   --------|--------------------------------------------------------------
#   native  | ^ios/ | ^android/ | capacitor\.config | cap-build | @capacitor
#           | (+ content check: package.json diff mentions "capacitor")
#   webui   | \.(tsx|jsx|css)$ AND app/|components/|features/
#           | OR globals\.css | design\.md | tailwind\.config | @neometa/brand | tokens
#   webrt   | app/api/ | route\.(ts|js)$ | middleware | hooks/ | lib/.*(fetch|client|store|query)
#   logic   | lib/ | utils/ | server | supabase/ | migrations?/ | \.sql$
#   runtime | NOT ( \.(md|mdx)$ | \.test\. | \.spec\. | __tests__/ | ^\.github/
#           |       | ^docs/ | ^\.beads/ | ^scripts/ci/ )
# ============================================================================
#
# 2026-07-22 — two classifier corrections. The over-block rule below is correct
# in principle (a staleness gate must err strict), but it was firing on files
# with no runtime surface at all, which made the store lane UNSATISFIABLE:
#
#   1. `.beads/issues.jsonl` is a pure issue-tracker ledger. Measured: it was
#      touched in 50 of the last 50 commits — i.e. EVERY commit. Because an
#      unclassifiable file over-blocks to every surface, every `br close` marked
#      every review-critical journey STALE. A QA drive could therefore never
#      hold: pass the drive, stamp it, close one bead, blocked again. The gate
#      was permanently red for a reason unrelated to any code risk.
#   2. `scripts/ci/*` is CI tooling with no app-runtime surface — the exact
#      sibling of `^\.github/`, which was already excluded. `app/robots.ts` and
#      `app/sitemap.ts` fell through too: PAT_WEBUI_EXT requires .tsx/.jsx/.css,
#      so plain .ts under app/ matched nothing and over-blocked to native.
#
# DELIBERATELY NOT relaxed: package.json, pnpm-lock.yaml and next.config.mjs
# still over-block. Dependency and build-config changes genuinely can alter the
# native shell (the Capacitor plugin set lives in package.json), so erring
# strict there is correct, not noise.
#
# 2026-07-26 — narrow precision fix. `cap-build` was a bare path match inside
# PAT_NATIVE, so ANY edit to scripts/cap-build.sh staled every review-critical
# native journey — including an edit that only adds a fail-fast validation block,
# which cannot change the produced artifact.
#
# Fix: cap-build scripts are now CONTENT-decided, exactly like the dependency
# manifests — native is added only when the diff touches an env export, a
# build/sync invocation, a build-shaping variable, or an .env write
# (PAT_ARTIFACT_AFFECTING). NOT exempted wholesale the way scripts/ci/* is,
# because cap-build.sh genuinely does shape the artifact when it changes how env
# is injected; that case must still stale.
#
# READ THIS BEFORE ASSUMING A STALE VERDICT IS NOISE. This fix was originally
# scoped from an analysis that called the 2026-07-26 store-lane block a false
# positive. That analysis was WRONG, and the mistake is instructive: it filtered
# the native delta to ios/ + package.json + capacitor.config + scripts/cap-* and
# so missed `.env.capacitor`, which IS tracked and HAD changed — gaining
# NEXT_PUBLIC_SIGNUP_ENABLED (absent before, so native shipped a reachable
# /signup form while web disabled it) and NEXT_PUBLIC_GOOGLE_IOS_CLIENT_ID
# (absent before, so signInWithGoogleNative() threw and native Google sign-in was
# hard-broken). The auth journey was correctly STALE: those are exactly the two
# paths its last_pass recorded as UNPROVEN. The gate was doing its job.
# Enumerate the FULL changed-file set before concluding a stale verdict is noise.
#
# HONEST LIMITATION: this is a textual heuristic over the diff, not a semantic
# one. A sufficiently creative artifact-affecting edit that matches none of those
# patterns would slip through. It errs looser than before by design — if that
# proves wrong, tighten PAT_ARTIFACT_AFFECTING rather than restoring the bare
# path match.
# ============================================================================
PAT_NATIVE='^ios/|^android/|capacitor\.config|@capacitor'
# Native build scripts — classified explicitly (see classify_range) so the
# artifact-affecting content check decides their native-relevance instead of a
# bare path match. `cap-build` used to live in PAT_NATIVE above; see the
# 2026-07-26 note for why that was wrong.
PAT_BUILD_TOOLING='^scripts/cap-build'
# Lines in a build script that can actually change the produced artifact:
# a real env export, a build/sync invocation, a build-shaping variable, or a
# write into an .env file. Guard/validation edits (echo, grep, exit, arrays of
# variable NAMES) match none of these and therefore do not stale native.
PAT_ARTIFACT_AFFECTING='^[+-][[:space:]]*export[[:space:]]+[A-Za-z_]+=|^[+-][[:space:]]*(next build|pnpm[[:space:]]+.*build|xcodebuild)|^[+-].*(npx[[:space:]]+cap|cap[[:space:]]+(sync|copy|run|add))|^[+-].*(BUILD_TARGET|NODE_ENV=|BUILD_ID)|^[+-].*>[[:space:]]*\.env'
PAT_WEBUI_EXT='\.(tsx|jsx|css)$'
PAT_WEBUI_DIR='app/|components/|features/'
PAT_WEBUI_TOKENS='globals\.css|design\.md|tailwind\.config|@neometa/brand|tokens'
# `^app/.*\.ts$` — app-router TypeScript that is not a route/api file (robots.ts,
# sitemap.ts, opengraph-image.ts). Web-runtime concerns; never native.
PAT_WEBRT='app/api/|route\.(ts|js)$|middleware|hooks/|lib/.*(fetch|client|store|query)|^app/.*\.ts$'
PAT_LOGIC='lib/|utils/|server|supabase/|migrations?/|\.sql$'
# Dependency manifests — classified explicitly (see classify_range) so the
# capacitor content check decides their native-relevance instead of the
# catch-all over-block pre-empting it.
PAT_DEPS='^package\.json$|^pnpm-lock\.yaml$'
# `^\.beads/` = issue-tracker ledger, `^scripts/ci/` = CI tooling. Neither has a
# runtime surface. See the 2026-07-22 note above before adding to this list —
# anything excluded here can never mark a journey stale again.
PAT_DOC_TEST_CI='\.(md|mdx)$|\.test\.|\.spec\.|__tests__/|^\.github/|^docs/|^\.beads/|^scripts/ci/'

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
APP="$(pwd)"
SHIP_SHA="HEAD"
LANE="store"

usage() {
  echo "Usage: $0 [--app <path>] [--sha <ship-sha>] [--lane store|testflight]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --sha) SHIP_SHA="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "journey-stamp-check: unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$LANE" != "store" && "$LANE" != "testflight" ]]; then
  echo "journey-stamp-check: --lane must be 'store' or 'testflight' (got: $LANE)" >&2
  exit 2
fi

if ! git -C "$APP" rev-parse --git-dir >/dev/null 2>&1; then
  echo "journey-stamp-check: '$APP' is not a git repo" >&2
  exit 2
fi

JOURNEYS_DIR="$APP/.claude/skills/CORE/journeys"
[[ -d "$JOURNEYS_DIR" ]] || JOURNEYS_DIR="$APP/CORE/journeys"   # bare-path form (matches ac-dashboard's walk)
if [[ ! -d "$JOURNEYS_DIR" ]]; then
  echo "journey-stamp-check: no journeys dir at $JOURNEYS_DIR — nothing to gate"
  exit 0
fi

# ---------------------------------------------------------------------------
# YAML helpers — tiny, deliberately not general-purpose
# ---------------------------------------------------------------------------

# Print only the frontmatter block (between the first two '---' lines).
# Empty output means "no frontmatter" == peripheral == ignore.
extract_frontmatter() {
  awk '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR==1 { next }
    /^---[[:space:]]*$/ { exit }
    { print }
  ' "$1"
}

# yaml_get <text> <key> -> scalar value, inline comment / quotes stripped.
yaml_get() {
  local text="$1" key="$2" line val
  line=$(printf '%s\n' "$text" | grep -E "^[[:space:]]*${key}:" | head -1) || true
  [[ -z "$line" ]] && { printf ''; return; }
  val="${line#*:}"
  val="${val%%#*}"
  val="$(printf '%s' "$val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  val="${val%\"}"; val="${val#\"}"
  val="${val%\'}"; val="${val#\'}"
  printf '%s' "$val"
}

# Slice the (indented) block under a top-level `key:` header out of the
# frontmatter — stops at the next non-indented (top-level) line.
yaml_block() {
  local text="$1" key="$2"
  printf '%s\n' "$text" | awk -v k="^${key}:" '
    $0 ~ k { f=1; next }
    f && /^[^[:space:]]/ { f=0 }
    f { print }
  '
}

# surfaces_of <text> -> newline-separated list from `surfaces: [a, b]`
surfaces_of() {
  local raw
  raw=$(printf '%s\n' "$1" | grep -E '^surfaces:' | head -1) || true
  raw="${raw#surfaces:}"
  raw=$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*\[(.*)\][[:space:]]*(#.*)?$/\1/')
  printf '%s' "$raw" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$' || true
}

# ---------------------------------------------------------------------------
# classify_range <repo> <git-range> -> newline-separated set of diff-classes
# touched by any file in that range. Empty range -> empty set.
# ---------------------------------------------------------------------------
classify_range() {
  local repo="$1" range="$2" files f hit
  local -a classes=()

  files=$(git -C "$repo" diff --name-only "$range" -- . 2>/dev/null || true)
  [[ -z "$files" ]] && return 0

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" =~ $PAT_DOC_TEST_CI ]]; then
      continue  # doc/test/CI file — no surface, explicitly out of scope
    fi
    classes+=(runtime)
    hit=0
    if [[ "$f" =~ $PAT_NATIVE ]]; then classes+=(native); hit=1; fi
    if [[ "$f" =~ $PAT_WEBUI_EXT ]] && [[ "$f" =~ $PAT_WEBUI_DIR ]]; then classes+=(webui); hit=1; fi
    if [[ "$f" =~ $PAT_WEBUI_TOKENS ]]; then classes+=(webui); hit=1; fi
    if [[ "$f" =~ $PAT_WEBRT ]]; then classes+=(webrt); hit=1; fi
    if [[ "$f" =~ $PAT_LOGIC ]]; then classes+=(logic); hit=1; fi
    if [[ "$f" =~ $PAT_DEPS ]]; then
      # Dependency manifests: they affect every WEB surface, but whether they
      # affect NATIVE is decided by the content check below (does the diff touch
      # a capacitor package?). Classifying them here — rather than letting them
      # fall through to the over-block — is what keeps that content check alive.
      # Before 2026-07-22 they hit the `hit -eq 0` branch, which unconditionally
      # added `native`, making the content check dead code that could never
      # change an outcome.
      classes+=(webui webrt logic); hit=1
    fi
    if [[ "$f" =~ $PAT_BUILD_TOOLING ]]; then
      # Native build scripts: they shape the native artifact, but ONLY when the
      # diff touches something that actually changes it. Marked hit=1 here so the
      # catch-all below does not pre-empt the content check further down — the
      # same shape the dependency manifests use.
      hit=1
    fi
    if [[ $hit -eq 0 ]]; then
      # Not doc/test/CI, but matches none of the specific surfaces either —
      # unclassifiable: over-block, count it as touching every surface.
      classes+=(native webui webrt logic)
    fi
  done <<< "$files"

  # Native-relevance of a dependency change is content-decided, not path-decided.
  # Covers pnpm-lock.yaml too: a transitive Capacitor bump can land in the lock
  # file without package.json changing at all.
  local dep_file
  for dep_file in package.json pnpm-lock.yaml; do
    if printf '%s\n' "$files" | grep -qx "$dep_file"; then
      if git -C "$repo" diff "$range" -- "$dep_file" 2>/dev/null | grep -qE 'capacitor'; then
        classes+=(native)
      fi
    fi
  done

  # Native-relevance of a build-script change is content-decided too. A guard or
  # validation block added to cap-build.sh cannot change the artifact it produces,
  # so it must not stale a runtime journey; an env export, a build/sync
  # invocation, or a build-shaping variable can, so it must.
  local build_file
  while IFS= read -r build_file; do
    [[ -z "$build_file" ]] && continue
    if git -C "$repo" diff "$range" -- "$build_file" 2>/dev/null \
         | grep -qE "$PAT_ARTIFACT_AFFECTING"; then
      classes+=(native)
    fi
  done < <(printf '%s\n' "$files" | grep -E "$PAT_BUILD_TOOLING" || true)

  [[ ${#classes[@]} -eq 0 ]] && return 0
  printf '%s\n' "${classes[@]}" | sort -u
}

# ---------------------------------------------------------------------------
# Main — walk review-critical journeys, print one verdict line each
# ---------------------------------------------------------------------------
BLOCKING=0
CHECKED=0

shopt -s nullglob
for jf in "$JOURNEYS_DIR"/*.md; do
  fm=$(extract_frontmatter "$jf")
  [[ -z "$fm" ]] && continue  # no frontmatter -> peripheral, ignore

  criticality=$(yaml_get "$fm" criticality)
  [[ "$criticality" != "review-critical" ]] && continue
  CHECKED=$((CHECKED + 1))

  journey=$(yaml_get "$fm" journey)
  [[ -z "$journey" ]] && journey="$(basename "$jf" .md)"

  surf_arr=()
  while IFS= read -r _s; do
    [[ -n "$_s" ]] && surf_arr+=("$_s")
  done < <(surfaces_of "$fm")   # bash-3.2-safe (macOS /bin/bash has no mapfile)

  lp_block=$(yaml_block "$fm" last_pass)
  verdict=""
  reason=""

  if [[ ${#surf_arr[@]} -eq 0 ]]; then
    verdict="MISSING"
    reason="frontmatter has no surfaces: field — cannot evaluate staleness (fix the registry entry)"
  elif [[ -z "$lp_block" ]]; then
    verdict="MISSING"
    reason="no last_pass stamp recorded"
  else
    lp_sha=$(yaml_get "$lp_block" sha)
    if [[ -z "$lp_sha" ]]; then
      verdict="MISSING"
      reason="last_pass block present but sha is empty"
    elif ! git -C "$APP" merge-base --is-ancestor "$lp_sha" "$SHIP_SHA" 2>/dev/null; then
      verdict="STALE"
      reason="last_pass.sha ($lp_sha) is not an ancestor of ship SHA ($SHIP_SHA)"
    else
      range="${lp_sha}..${SHIP_SHA}"
      touched=$(classify_range "$APP" "$range")
      hit_surface=""
      for s in "${surf_arr[@]}"; do
        if printf '%s\n' "$touched" | grep -qx "$s"; then
          hit_surface="$s"
          break
        fi
      done
      if [[ -n "$hit_surface" ]]; then
        verdict="STALE"
        reason="intervening diffs ($range) touch surface '$hit_surface'"
      else
        lp_build=$(yaml_get "$lp_block" build)
        lp_date=$(yaml_get "$lp_block" date)
        verdict="OK"
        reason="sha=$lp_sha build=$lp_build date=$lp_date is an ancestor; no intervening surface diffs"
      fi
    fi
  fi

  if [[ "$LANE" == "testflight" && "$verdict" != "OK" ]]; then
    echo "WARN  $journey: $verdict — $reason"
  else
    echo "$verdict  $journey: $reason"
  fi

  if [[ "$verdict" != "OK" ]]; then
    BLOCKING=1
  fi
done

if [[ $CHECKED -eq 0 ]]; then
  echo "journey-stamp-check: no review-critical journeys found under $JOURNEYS_DIR"
  exit 0
fi

if [[ "$LANE" == "store" && $BLOCKING -eq 1 ]]; then
  echo "journey-stamp-check: BLOCKED — one or more review-critical journeys are MISSING/STALE (lane=store)" >&2
  exit 1
fi

exit 0
