# The three tiers — render template

Extracted from the spine 2026-09-12 (ac-1p7j.37). The spine carries the
ordering rule (distance from a stall, tier-first; within a tier P0→P4 then
oldest; omit empty tiers); this file carries the render block.

```
### 🔴 Blocking — the line has stopped ({N})
   For each: {what} · {one-line memo/why} · → {action}
   • 🔁 {lane label} — {N} queued (oldest {age})            → work the queue
   • 🔁 Run the curator sitting — {N} queued (oldest {age}) → tap into the supervised sitting
     (the SAME lane line, ELEVATED — renders INSTEAD of the one above once >=20 queued or oldest >21 days; never both)
   • {bead id} {age} {decision title} — {memo summary}      → decide        (tap-ready)
   • {bead id} {age} {decision title} — {memo summary}      ⚠ stale — reverify
   • {bead id} {age} {decision title} — {memo summary}      ⚠ never verified — reverify
   • {bead id} {age} {decision title} ⚠ no memo             → frame, then decide
   • CI {run} failed                                        → investigate
   • {N} dependabot/grouped PRs                             → review as ONE batch
   • PR #{n} {substantive title}                            → review/merge (one each)
   • {journey} review-critical — stamp missing/stale         → run QA drive (ac-qa/ac-qa)
   (org-wide: group by repo · batch trivial, itemize substantive)

### 🟡 Feed the builders — next batch needs your sign-off ({N})
   Plans waiting on you; approving makes them loop-ready and they leave your view.
   • {plan} [{Nr {tier} → trajectory}, touched {date}]      → approve / refine
   • {journey} commerce/core — stamp missing/stale           → schedule a QA drive

### 🟢 Stock the hopper — what enters planning next ({N})
   • {active item} [{size}]                                 → plan
   • {triage candidate} (from {source})                    → approve into pool / discard
   • Replenish: {pool_count} pooled, active/ is thin        → promote (ac-align)
   • {N} pipeline proposals pending (nightly/weekly)        → review in Docket → apply/discard
```
