# run-loop fixture — clean

Commit often; push only through the push layer, never a bare `git push`:

```bash
git commit -m "chore(hygiene): round 1" -- file.txt
bash skills/ac-pipeline/scripts/push.sh --branch "$(git branch --show-current)"
```
