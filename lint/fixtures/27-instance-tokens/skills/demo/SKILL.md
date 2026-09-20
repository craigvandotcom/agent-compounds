---
name: demo
---

# demo skill — the RED fixture for Check 27

This SKILL.md names `acme-widget`, the one word this fixture's
`lint/instance-tokens.local.txt` bans, so

    python3 lint/checks/27-instance-tokens.py <this fixture root>

exits 1: a tracked file carrying a banned word. Remove the word, or remove it
from the list, and the same command exits 0.
