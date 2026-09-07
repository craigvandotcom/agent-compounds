---
name: demo
---

# demo skill — the RED fixture for Check 27

This SKILL.md deliberately names the body-compass app so that running
`python3 lint/checks/27-instance-tokens.py <this fixture root>` exits 1:
the hit has no allowlist entry in the fixture tree, which is exactly the
"live file carrying an app name outside the allowlist" RED case.
