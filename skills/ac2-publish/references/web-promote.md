# web-promote — the web leg of the ship step, mechanics

Called by `ac2-publish/SKILL.md` § Ship, step 3. `$SHA` throughout is the **PROVEN** SHA that
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

```bash
PROJECT_ID="prj_Qg3T27oyWJ7QIjdfJLzy6aTRFxty"
PROJ_API="https://api.vercel.com/v9/projects/$PROJECT_ID"
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
