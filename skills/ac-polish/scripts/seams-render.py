#!/usr/bin/env python3
"""seams-render.py — render a kept seams map (map.json) to one self-contained map.html.

The JSON is the asset; this file only draws it, so the page can never disagree with the data.
Three sections a human reads before a build: the N² grid (fenced files down, seven stages
across — the EMPTY cells are the finding, and a table cannot show absence), the flow map as
ordered steps with their sensors, the boundary map as the interface table. Plus the header:
object, traced_at, seams_load, and a coverage note.

ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
  PROBE:      skills/ac-polish/scripts/seams-merge.test.py § kept map — RED/GREEN over the writers
  SCHEDULE:   once per seams hand-off (seams-merge.py handoff --keep) and on every CI run via
              scripts/run-all-harnesses.sh
  MODE:       blocking — the html is written only from a map.json this script parsed whole
  ON-FAILURE: closed — an unreadable or shapeless map.json exits 2 NOT-GATED, writes nothing

Usage: seams-render.py <map.json> [<map.html>]   (default: beside the json)
"""
import html
import json
import os
import sys

STAGES = ["create", "transport", "store", "read", "update", "delete", "cleanup"]


def die2(msg):
    print(f"seams-render: NOT-GATED {msg}", file=sys.stderr)
    sys.exit(2)


def esc(s):
    return html.escape(str(s if s is not None else ""), quote=True)


def live(d, lens):
    return [e for e in (d.get("edges", {}).get(lens, {}) or {}).values() if not e.get("dropped")]


def none_ish(cell):
    c = str(cell or "").strip().strip("`*").lower()
    return c.split(" ")[0].rstrip(",;:—–(") in ("none", "swallow", "n/a", "") if c else True


def render(d):
    obj = d.get("object") or "?"
    files = d.get("files") or []
    load = d.get("seams_load") or {}
    obj_rows = live(d, "object")
    flow_rows = live(d, "flow")
    bnd_rows = live(d, "boundary")
    grid = {}  # (path, stage) -> edge
    for e in obj_rows:
        grid[(e["path"], e["key"].split(" × ")[0])] = e
    extra = sorted({e["path"] for e in obj_rows} - set(files))
    all_files = list(files) + extra
    filled = sum(1 for f in all_files for s in STAGES if (f, s) in grid)
    total = len(all_files) * len(STAGES)

    css = """
    body{font:14px/1.45 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;margin:0;padding:24px 28px;color:#1c1c1c;background:#fff}
    h1{font-size:22px;margin:0 0 4px} h2{font-size:16px;margin:28px 0 8px;border-bottom:1px solid #ddd;padding-bottom:4px}
    .meta{color:#555;font-size:13px;margin-bottom:6px} .meta code{background:#f3f3f3;padding:1px 4px;border-radius:3px}
    .load span{display:inline-block;margin-right:14px;padding:2px 8px;border-radius:10px;background:#eee;font-size:12px}
    .load .hot{background:#fde2e2} .load .zero{background:#e3f4e3}
    table{border-collapse:collapse;font-size:12.5px} th,td{border:1px solid #e2e2e2;padding:4px 7px;vertical-align:top;text-align:left}
    th{background:#f6f6f6;font-weight:600;position:sticky;top:0}
    .grid td.cell{width:110px;text-align:center;font-family:ui-monospace,Menlo,monospace;font-size:11.5px}
    .grid td.filled{background:#e7f0fb} .grid td.filled.nocontract{background:#fdebd0} .grid td.empty{background:#fafafa;color:#bbb}
    .grid td.path{font-family:ui-monospace,Menlo,monospace;white-space:nowrap}
    .grid td.path.extra{color:#a33}
    .sensor-none,.fail-none,.assert-none{color:#a33;font-weight:600}
    .legend span{display:inline-block;margin-right:14px;font-size:12px} .legend i{display:inline-block;width:12px;height:12px;border:1px solid #ccc;vertical-align:-2px;margin-right:4px}
    details summary{cursor:pointer;color:#345} .small{font-size:12px;color:#666}
    """
    out = [f"<!doctype html><meta charset=utf-8><title>seams — {esc(obj)}</title><style>{css}</style>",
           f"<h1>seams — {esc(obj)}</h1>",
           f"<div class=meta>traced_at <code>{esc(d.get('traced_at') or '?')}</code> · rounds {esc(d.get('rounds'))} · readers {esc(d.get('readers'))} · verdict <code>{esc(d.get('verdict') or 'unstamped')}</code></div>",
           f"<div class=meta>fence — object: <code>{esc(' · '.join(d.get('object_terms') or []))}</code></div>",
           f"<div class=meta>files: {len(files)} on the fence · grid {filled}/{total} cells filled</div>"]
    if d.get("coverage_note"):
        out.append(f"<div class=meta><b>coverage:</b> {esc(d['coverage_note'])}</div>")
    if load:
        out.append("<div class='meta load'>" + "".join(
            f"<span class='{'zero' if str(v) == '0' else ('hot' if k in ('competing-writers','unasserted-edges','unsensed-steps','unchecked-assumptions','untrusted-inputs') else '')}'>{esc(k)} {esc(v)}</span>"
            for k, v in load.items()) + "</div>")

    # N² grid
    out.append("<h2>object map — files × stages (empty cells are the finding)</h2>")
    out.append("<div class=legend><span><i style='background:#e7f0fb'></i>edge with a contract</span><span><i style='background:#fdebd0'></i>edge, contract none</span><span><i style='background:#fafafa'></i>empty</span><span style='color:#a33'>red path = row outside the files line (older run)</span></div>")
    out.append("<table class=grid><tr><th>file</th>" + "".join(f"<th>{s}</th>" for s in STAGES) + "</tr>")
    for f in all_files:
        cls = "path extra" if f in extra else "path"
        out.append(f"<tr><td class='{cls}'>{esc(f)}</td>")
        for s in STAGES:
            e = grid.get((f, s))
            if e is None:
                out.append("<td class='cell empty'>·</td>")
            else:
                line = str(e.get("path:line") or "").strip("`")
                line = line.split(":", 1)[1].split(" ")[0] if ":" in line else ""
                nc = none_ish(e.get("contract"))
                title = esc(f"{e.get('role','')}\ncontract: {e.get('contract','')}")
                out.append(f"<td class='cell filled{' nocontract' if nc else ''}' title='{title}'>:{esc(line) or '?'}</td>")
        out.append("</tr>")
    out.append("</table>")

    # flow
    out.append(f"<h2>flow map — {len(flow_rows)} steps, in map order</h2>")
    out.append("<table><tr><th>flow</th><th>step</th><th>path:line</th><th>controller</th><th>sensor</th><th>on-failure</th></tr>")
    for e in sorted(flow_rows, key=lambda e: (e.get("first_round", 0), e.get("seq", 0))):
        sen = e.get("sensor", ""); fl = e.get("on-failure", "")
        out.append("<tr>" + "".join(f"<td>{esc(e.get(k,''))}</td>" for k in ("flow", "step", "path:line", "controller"))
                   + f"<td class='{'sensor-none' if none_ish(sen) else ''}'>{esc(sen)}</td>"
                   + f"<td class='{'fail-none' if none_ish(fl) else ''}'>{esc(fl)}</td></tr>")
    out.append("</table>")

    # boundary
    out.append(f"<h2>boundary map — {len(bnd_rows)} sides (the interface table)</h2>")
    out.append("<table><tr><th>interface</th><th>side</th><th>path:line</th><th>producer</th><th>assumes</th><th>asserts</th></tr>")
    for e in sorted(bnd_rows, key=lambda e: (e.get("interface", ""), e.get("side", ""), e.get("path", ""))):
        asr = e.get("asserts", "")
        out.append("<tr>" + "".join(f"<td>{esc(e.get(k,''))}</td>" for k in ("interface", "side", "path:line", "producer", "assumes"))
                   + f"<td class='{'assert-none' if none_ish(asr) else ''}'>{esc(asr)}</td></tr>")
    out.append("</table>")

    # cross-lens
    cross = d.get("cross_lens") or []
    if cross:
        out.append(f"<h2>seams seen by more than one lens ({len(cross)}) — fix these first</h2><table><tr><th>path</th><th>what each lens sees</th><th>lenses</th></tr>")
        for r in cross:
            out.append("<tr>" + "".join(f"<td>{esc(c)}</td>" for c in r) + "</tr>")
        out.append("</table>")
    out.append(f"<p class=small>rendered from map.json by seams-render.py — edit the data, never this page.</p>")
    return "\n".join(out) + "\n"


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__); return 2
    src = argv[0]
    dst = argv[1] if len(argv) > 1 else os.path.join(os.path.dirname(src), "map.html")
    try:
        d = json.load(open(src, encoding="utf-8"))
    except (OSError, ValueError) as e:
        die2(f"cannot read map.json: {e}")
    if not isinstance(d, dict) or "edges" not in d:
        die2("map.json has no `edges` — not a kept seams map")
    with open(dst, "w", encoding="utf-8") as f:
        f.write(render(d))
    print(f"seams-render: wrote {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
