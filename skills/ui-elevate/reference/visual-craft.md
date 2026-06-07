# Reference: Visual Craft (appearance & layout)

The appearance axis. What to elevate toward once the UI is already consistent with
the app. Palette and voice are brand law → defer to `brand-system`; this file is
about how type, space, depth, imagery, and layout are *composed*.

---

## Typography — where premium is won or lost

- **Hierarchy through contrast, not count.** Use 3–5 deliberate, well-separated
  sizes. Avoid a clutter of near-identical sizes (16/17/18). Big jumps read as
  intentional; tiny ones read as accident.
- **Line-height scales inversely with size.** Headings tight (~1.05–1.25), body
  comfortable (~1.4–1.6), dense data UI tighter. Never one line-height everywhere.
- **Measure (line length).** Body text 45–75 characters. Constrain wide containers
  with `max-w-prose` / explicit `ch` widths. Full-bleed paragraphs are a slop tell.
- **Letter-spacing (tracking).** Large display headings: slightly negative
  (-0.01 to -0.03em). All-caps labels/eyebrows: positive (+0.04 to +0.1em). Body:
  leave default. Tuning tracking is one of the highest-signal premium moves.
- **Weight contrast** carries hierarchy alongside size. Pair a heavier heading with
  a regular body; don't make everything semibold (a common AI default).
- **Numerals:** use tabular/lining figures for aligned columns of numbers.
- **Avoid orphans/widows** in headings; prevent key phrases from wrapping badly
  (`text-balance` for headings, `text-pretty` for body where supported).

## Spacing & rhythm

- **One scale, applied consistently.** Use the app's spacing tokens (often a 4px
  base: 4/8/12/16/24/32/48/64). Ad-hoc values (13px, 27px) are an immediate flag.
- **Proximity = relationship.** Tighten space within a group, widen it between
  groups. Uniform spacing everywhere flattens meaning — real design has rhythm.
- **Whitespace is intentional, not leftover.** Premium UIs are generous and
  confident with space; cramped UIs feel cheap, aimlessly sparse UIs feel unfinished.
- **Vertical rhythm.** Consistent spacing between stacked blocks; align baselines
  where it matters.

## Alignment & layout

- **Optical over mathematical.** Center icons and glyphs by eye, not just by box.
  Account for visual weight (a triangle "play" icon needs nudging right).
- **Don't center everything.** Center hero/empty states; left-align scannable
  content, lists, forms, and long copy. Center-everything is a top AI tell.
- **Establish and hold a grid.** Columns and gutters align across sections; fix
  sub-pixel misalignments. Edges that almost-line-up read as broken.
- **Density to context.** A data dashboard wants tighter density and more
  information; a marketing hero wants air. Match density to the surface's job.
- **Responsive is composition, not just reflow.** Rework hierarchy and spacing per
  breakpoint; a desktop layout linearized to mobile usually feels off.

## Depth, elevation & surface

- **Elevation has logic.** Pick a light direction and keep shadows consistent with
  it. Higher elements cast softer, larger, lower-opacity shadows. Don't mix shadow
  languages within one screen.
- **Soft, layered shadows** (often two stacked: a tight contact shadow + a soft
  ambient one) read as premium; a single harsh `box-shadow` reads as default.
- **Borders as hairlines.** Prefer low-contrast 1px dividers / subtle borders over
  heavy black lines. Consider borderless separation via spacing or background tint.
- **Radii consistent** with the app's token; don't mix 4px and 16px arbitrarily.

## Color application (composition, not palette)

- Palette/pillar = `brand-system` law. Here: **restraint.** One accent used with
  intent beats many competing colors. Reserve the accent for the primary action.
- Build with neutrals; let the pillar accent punctuate. Backgrounds carry tone via
  subtle tint, not saturated fills.
- **No default template gradient** (the 45° purple→blue). If using gradient, keep
  it subtle, on-brand, and purposeful.

## Imagery & iconography

- **Real / owned over generic.** Authentic photography or custom illustration beats
  obvious stock or generic AI imagery — the latter is an instant credibility leak.
- **One art style** per surface; don't mix flat illustration with photoreal with 3D.
- **One icon family, one weight, one size system.** Mixed icon sets are a tell.
  Icons should be optically aligned with their text and carry real meaning.
- **Correct aspect ratios.** Never squish/stretch; never upscale a small asset.
  Use `aspect-ratio` + `object-fit` to keep media crisp and stable.
