# Reference: Art-Direction Menu — divergent looks to seed a brainstorm

A **vocabulary lookup**, not a build spec. When a brainstorm wants genuinely
divergent directions (Phase 1 generation), pull names from here so the options span
real art-direction space instead of clustering on one safe look. Each row is a
**name + one-liner + admissibility ruling** — the ruling is binding, the technique
note is a starting point, never a mandate to ship the look by default.

> **Generic skill — method only, zero app facts.** Brand fit is scored per app in the
> brainstorm's Brand-Alignment rubric; this menu carries only the portfolio-wide
> admissibility rulings, not app specifics.

> Distilled from [MengTo/Skills](https://github.com/MengTo/Skills) (MIT) — the
> `web-design` / `ui` art-direction presets — filtered through the gate decisions of
> 2026-07-17 (MengTo distillation epic). Rulings below are binding.

---

## Admitted looks (gate-approved, brand-filtered)

- **Skeuomorphic (tactile).** — *Per-app opt-in, never a default.* Layered
  inset + outer `box-shadow` stack over a top→bottom surface gradient
  (`--sk-bg-top/mid/bottom`), 160–240ms transitions. A strong, opinionated look; turn
  it on for a specific surface deliberately, don't reach for it as the house style.
  Hover glow is web/marketing only (no `:hover` inside a native `/app` shell).

- **Mesh gradient (restrained).** — *Restrained, non-default variant only.* A muted,
  brand-neutral mesh field over a dark base (e.g. `--mesh-bg #030712`) can add depth —
  but it is admissible **only** when it does not drift to the purple/blue 45° AI-default
  fingerprint. Cite `ac-ui-polish/reference/critique-polish.md` §D (anti AI-default
  gradient) whenever proposing it, so the review catches drift.

- **Dither atmosphere.** — *Site hero only.* Bayer-4×4 ordered-dither canvas texture,
  monochrome (passes brand — no colour bans). Keep the `prefers-reduced-motion` and
  `maxDpr` clamps from the source. Never inside `/app` (rAF canvas = perf liability in
  the shell).

- **Brutalist type-scale.** — *Type technique only, palette stripped.* Oversized
  display type — `clamp(4rem, 10vw, 15rem)`, tracking `-0.03em` to `-0.06em` — for a
  bold editorial hero. The source's `#E61919` red palette is **off-brand — do not
  import it**; take the scale, leave the colour.

- **Corner-diagonals (demoted — vocabulary only).** — `clip-path: polygon(…)`
  chamfered corners (8 / 14 / 24px cuts). Sci-fi / engineered feel, **off-brand for
  wellness surfaces** — named here for vocabulary completeness only; no full
  distillation, do not adopt as a default treatment.

---

## Vocabulary-only rows (named for divergence, not distilled)

**Mood presets (SKIP-A).** Nineteen upstream "art-direction" presets are prose
mood-boards with no reusable tokens — their only value is *naming a look*. Use them as
divergence prompts in Phase 1, never as technique to lift; brand filters thin several
(Inter/Geist, teal, and pure-white/pure-black bans):

> agency-grid-minimal · blue-cloudy-clean-modern · book-serif-index ·
> clean-minimal-beige-light · dark-blue-contrasting-clean · dark-glass-clean-layout ·
> dither-laser-dark · editorial-tech · framed-tech-dark-border-gradient ·
> glass-dark-clock · high-contrast-skeuomorphic-clean · image-first-grid ·
> light-mode-paper-technical · nested-container-clean-agency · orange-clean-paper-saas ·
> solar-duotone-bold · split-layout-technical · tech-green-dark-modern ·
> technical-wireframe-info

**Banned (SKIP-B).** `funky-purple-container-tech` — purple is the meditation cliché
(brand-system anti-pattern §4.2). **Inadmissible portfolio-wide**; listed only so a
brainstorm never re-proposes it as novel.
