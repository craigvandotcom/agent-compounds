# web-promote — the web leg of the ship step, mechanics

Called by `ac-publish/SKILL.md` § Ship, step 3. `$SHA` throughout is the **PROVEN** SHA that
`ac-prove` returned — never `HEAD`, never your input `R`.

## There is nothing to build here

Vercel's Production Branch stays `main`, but **domain auto-assignment for the production branch
is OFF** (a Dashboard setting). So the push carrying `$SHA` ALREADY built a **production-target**
deployment — production env vars baked in — and it sits **Staged**, no domain attached, invisible
until promoted. **Assert there is no `vercel deploy --prod` anywhere in this step:** a fresh build
is a DIFFERENT artifact from the one the proof measured, so it voids every gate above it.

## The promote

```bash
# Locate $SHA's existing STAGED deployment — keyed on the git SHA, never on URL naming.
STAGED_URL=$(vercel ls <project> --meta githubCommitSha="$SHA" | ...)
[ -n "$STAGED_URL" ] || { echo "NOT-GATED: no staged deployment for $SHA — do not ship"; exit 2; }
vercel inspect "$STAGED_URL"   # confirm it built $SHA AND is a PRODUCTION-target build
vercel promote "$STAGED_URL"   # dashboard equivalent: "Promote to Production"
```

**NEVER promote a preview deployment.** A preview build bakes *preview* env vars into
`NEXT_PUBLIC_*` at build time — not swappable after the fact — so promoting one ships the wrong
keys and flags. Only the staged production-target build is a valid target, and `vercel inspect` is
the only thing that tells the two apart; URL naming is not evidence. A preview, or no staged build
for `$SHA`, **aborts this step** and is surfaced to Craig — never report a ship on an unverified
promote.

## Then re-assert the domain flag — and read it back

`vercel promote` silently resets `autoAssignCustomDomains` to `true` (vercel/vercel#15095). Left
true, the next push to `main` aliases straight to the live domain — auto-promotion is back and the
staged model this step rests on is gone.

**The token comes from the Vercel CLI's own credential store, not `.env.local`.** `vercel login`
writes it to `~/Library/Application Support/com.vercel.cli/auth.json` and keeps it current; a
hand-copied `VERCEL_TOKEN` in `.env.local` has already been observed commented out mid-separator
and later deleted outright, and an EMPTY token turns the read-back below into decoration — the
`curl` returns an auth error, `flag()` prints nothing, and the comparison is empty-vs-expected. So
resolve the token from the credential store when `$VERCEL_TOKEN` is unset, and REFUSE before the
first request if neither source has one. A read-back that cannot read must never look like a pass.

```bash
PROJECT_ID="prj_Qg3T27oyWJ7QIjdfJLzy6aTRFxty"
PROJ_API="https://api.vercel.com/v9/projects/$PROJECT_ID"

# Preferred source: the Vercel CLI credential store. Only fall back to an inherited env token.
VERCEL_TOKEN="${VERCEL_TOKEN:-}"          # set -u safe; every guard below reads it directly
VERCEL_AUTH_JSON="${VERCEL_AUTH_JSON:-$HOME/Library/Application Support/com.vercel.cli/auth.json}"
if [ -z "$VERCEL_TOKEN" ] && [ -r "$VERCEL_AUTH_JSON" ]; then
  VERCEL_TOKEN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("token") or "")' \
                  "$VERCEL_AUTH_JSON")"
fi
if [ -z "$VERCEL_TOKEN" ]; then
  echo "FATAL: no VERCEL_TOKEN — not in the environment, not in $VERCEL_AUTH_JSON." >&2
  echo "       Run 'vercel login' (or export VERCEL_TOKEN). The autoAssignCustomDomains" >&2
  echo "       read-back cannot run without it, and an unverified flag is not a ship." >&2
  exit 2
fi
export VERCEL_TOKEN

flag() { curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" "$PROJ_API" \
         | python3 -c 'import json,sys; print(json.load(sys.stdin).get("autoAssignCustomDomains"))'; }
case "$(flag)" in
  False|false) ;;
  *) curl -sS -X PATCH -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
       "$PROJ_API" -d '{"autoAssignCustomDomains":false}' >/dev/null
     case "$(flag)" in False|false) ;;
       *) echo "FATAL: autoAssignCustomDomains still set after PATCH — do not ship"; exit 2 ;; esac ;;
esac
```

The read-back is the point. A PATCH whose result nobody re-read is an assurance claim with no
loop behind it.

## Not here

Minting the version (step 1) · tagging (step 2) · the post-promotion check, which is an IDENTITY
check of the production alias's own deployment metadata against `$SHA`, never a version-string
grep (step 5) · native and mobile artifacts (`ac-distribute`).
