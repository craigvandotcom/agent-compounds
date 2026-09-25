"""pull_order.py — the pull order: the next move is always the one closest to implement.

Imported by ac-board (🎯 NEXT) and ac-human (the docket) so both rank alike.
The rationale lives in ac-pipeline/references/stage-table.md § Pull order.
"""
import re

# Each rung of the ladder, most mature first. A move's rank is its index here.
LADDER = ("red-pr",        # interrupt: a red PR poisons whatever lands next
          "reclaim",       # in-progress beads no live agent holds
          "implement",     # ready beads
          "gate",          # human gates that block beads, most freed first
          "refine-bead",   # unrefined beads
          "beadify",       # bead-ready, needs-a-ruling and polished plans
          "polish-plan",   # approved plans not yet polished
          "approve-plan",  # draft plans
          "idle-gate",     # human gates that block nothing
          "pool")          # backlog pool → a plan
rank = LADDER.index

# Plan stages, most mature first. `refined` is ac-beadify's refusal: a fork only a human settles.
PLAN_ORDER = ("bead-ready", "refined", "polished", "approved", "draft")
PLAN_RUNG = {"bead-ready": "beadify", "refined": "beadify", "polished": "beadify",
             "approved": "polish-plan", "draft": "approve-plan"}


def front(text):
    """A plan's frontmatter as {key: value}; {} when it has none."""
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fm = {}
    for line in (m.group(1).splitlines() if m else []):
        k = re.match(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if k: fm[k.group(1)] = k.group(2).strip("'\"")
    return fm


def plan_stage(fm):
    """The frontmatter status, with an approved plan that carries the polish stamp (the keys
    plan-approve.sh ready checks) reported as `polished`. None when there is no status."""
    st = fm.get("status")
    if st == "approved" and "polish_rounds" in fm and any(k.startswith("polish_fixpoint_") for k in fm):
        return "polished"
    return st


def blocks_counts(recs):
    """{id: open beads waiting on it through a `blocks` edge} from the jsonl records."""
    is_open = lambda r: r.get("status") not in ("closed", "tombstone") and not r.get("closed_at")
    n = {}
    for r in recs.values():
        if not is_open(r): continue
        for d in r.get("dependencies") or []:
            t = d.get("depends_on_id")
            if d.get("type") == "blocks" and is_open(recs.get(t, {})): n[t] = n.get(t, 0) + 1
    return n
