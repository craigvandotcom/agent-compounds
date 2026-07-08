# ac-qa-device — incident record

Full narratives behind the compressed rules in SKILL.md. Read when questioning a rule's
provenance or re-evaluating the tool layer — not needed for normal runs.

## 2026-06-11 — tool bake-off: agent-device vs AXe/XcodeBuildMCP

Settled by bake-off against a Capacitor app on iOS 26.5: AXe and XcodeBuildMCP tree
dumps are **webview-blind** — the webview renders as empty Groups, so no web content is
targetable. agent-device's XCUITest snapshot sees the full webview accessibility tree
(buttons, text fields, links, values). Result: agent-device is the see+act engine; AXe
is retained only as an engine-diverse fallback for point-probes on webview apps
(`setup.md`). Re-evaluate the tool layer when Xcode 27's first-party agent automation
ships (~fall 2026).

## 2026-06-15 — shared-sim collision: art-still + Body Compass

Both apps' builds defaulted to the bare "iPhone 17 Pro" simulator on the same Mac.
Booting/renaming by one app broke the other's name-match (build failure: `xcodebuild:
error: Unable to find a device matching…` while the name WAS listed) and agent-device
matched the wrong device. Root cause of the SKILL.md rules: dedicated uniquely-named
sim per app, target by UDID, ownership rule (never touch another app's sim).

## 2026-06-15 — stale agent-device session collision

A stale `default` agent-device session remained bound to a device that another app then
claimed, breaking that app's run. Root cause of the teardown rule: always close your
session (`agent-device close --session <app>`) and pass `--session <app>` on every call.
