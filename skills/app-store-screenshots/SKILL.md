---
name: app-store-screenshots
description: Generate production-ready App Store screenshots for iOS by capturing real app screens via agent-browser and wrapping them in branded marketing slides. Use when preparing App Store / Play Store listing assets; triggers on "app store screenshots", "store listing images", "marketing screenshots" (store-listing context), "generate app store assets". NOT for landing-page/marketing-website screenshots (use screenshot-refresh).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# App Store Screenshots

**Trigger:** "build app store screenshots", "generate store images", "marketing screenshots"

**Implementation:** `tools/screenshot-generator/` — the reference implementation lives in the consuming app. See its `README.md` for full mechanics.

## What it does

Two-stage pipeline:

1. **Capture real PWA screens** via `agent-browser` at native iPhone viewport (430×932 CSS @ DPR=3 = 1290×2796 raster). Uses the App Store reviewer demo account against production so screens have realistic seeded data.
2. **Wrap in branded marketing slides** — a single HTML template (`index.html` + `slides.js`) renders gradient background + Inter caption + phone-shaped frame around each raw capture. `agent-browser` screenshots the `.stage` element to final PNGs. PIL downscales to 6.1" variants.

End-to-end re-run after a copy or capture change: **~5 seconds**.

## Apple's actual requirements (verified during a real App Store submission)

**Each upload slot in App Store Connect is strict about its own dimensions.** Apple's marketing language says "newer classes auto-derive from the largest" but in the actual upload UI, each slot accepts only specific pixel sizes. If you upload 1290×2796 (6.7") to the 6.5" slot, you'll get: _"The dimensions of one or more screenshots are wrong."_

| Display | Pixel size  | What it covers             | Notes                                          |
| ------- | ----------- | -------------------------- | ---------------------------------------------- |
| 6.9"    | 1320 × 2868 | iPhone 16 Pro Max          | Required for new submissions targeting iOS 18+ |
| 6.7"    | 1290 × 2796 | iPhone 14/15 Pro Max       | Master capture resolution                      |
| 6.5"    | 1284 × 2778 | iPhone 12/13/14 Pro Max    | Often required by App Store Connect            |
| 6.5"    | 1242 × 2688 | iPhone Xs Max / 11 Pro Max | Legacy alt for 6.5" slot                       |
| 6.1"    | 1179 × 2556 | iPhone 14/15 non-Pro       | Often required                                 |
| 6.3"    | 1206 × 2622 | iPhone 16 Pro              | Less commonly prompted                         |
| 5.5"    | 1242 × 2208 | iPhone 8 Plus (legacy)     | Only if supporting iOS 14 or earlier           |

**Strategy:** capture once at 6.7" (1290×2796), then derive every other class via uniform Lanczos resize. Aspect ratios across all the above are within 0.2% of each other (≈0.4614:1), so the resize is visually imperceptible. The shipped `downscale.py` generates 6.9, 6.5, 6.5-legacy, and 6.1 from the 6.7" master in one pass.

(The older Parth Jadhav skill scaffold listed only 4 sizes as required — that was both wrong and incomplete.)

**Other constraints:** PNG or JPG, RGB, no alpha; min 3 max 10 screenshots; marketing text overlay is standard practice (not against guidelines); accurate representation of the app (no fabricated features); no Apple/iPhone/iOS in caption text.

## When to use this skill

- New app needs initial App Store submission screenshots
- Existing app needs re-shoot after major UI change
- A/B testing a new caption set

## What NOT to use

- **Don't use the Parth Jadhav Next.js scaffold** the older skill version recommended. Tried it 2026-05-18; full Next.js scaffold is heavy overhead for 4 slides. The HTML approach in `tools/screenshot-generator/` produces equivalent output with zero install time and is editable in any text editor.
- **Don't use a native iPhone frame PNG asset.** Modern apps trend toward minimal frames (rounded-corner glow vs full iPhone bezel). The template uses a CSS-only frame which is more flexible.

## Usage

```bash
# NOTE: BCA has 4 slides; your app's count will differ (Apple allows 3-10).
# Re-capture all slides at 6.7":
./tools/screenshot-generator/capture.sh

# Single slide:
./tools/screenshot-generator/capture.sh 1

# After capture, derive 6.1":
python3 tools/screenshot-generator/downscale.py

# Live preview (gallery view of all slides at 28% scale):
./tools/screenshot-generator/capture.sh --preview
# then visit: http://127.0.0.1:8421/tools/screenshot-generator/index.html?gallery=1
```

## Adapting for a new app

When extending to another app:

1. **First time:** copy `tools/screenshot-generator/` into the new app
2. **Change brand colors** in `index.html` (`--accent`, `--accent-2`, `--bg`) to your app's brand accent color
3. **Reshoot raws** via `agent-browser` against that app's production URL + reviewer demo account, save to `_assets/app-store-screenshots/raw/`
4. **Edit `slides.js`** with that app's captions (sourced from the app's caption paste-sheet)
5. **Run capture + downscale**

When two or more apps consume the generator, **promote it** to a shared location at `software/_tools/screenshot-generator/` and accept per-app config (brand colors + raws dir + captions). Don't promote prematurely with only one consumer.

## Pre-submission risks to know

- **PWA-vs-native chrome:** raws captured from the web PWA lack the iOS system status bar at top. Apple rarely rejects on this, but the safe alternative is to reshoot raws from the iOS simulator on a Mac, then re-run `capture.sh` (frame + captions stay identical).
- **Caption-vs-screen mismatch:** reviewers compare caption text to what the screen actually shows. If the paste-sheet caption names features/axes that don't match the captured screen exactly, update the caption to match (e.g., a caption that lists data axes the rendered screen doesn't actually display — rewrite it to match the real screen).

## App-specific config

Brand colors, fonts, the reviewer demo account, the production URL, and the chosen
slide set are **app facts** — keep them in the consuming app's
`.claude/skills/CORE/` (e.g. `CORE/app-store.md`), not here. This skill stays
method-only.
