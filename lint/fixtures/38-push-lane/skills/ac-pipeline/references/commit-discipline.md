# commit-discipline fixture — clean

Commit often; push only through the push layer — never a bare `git push`.

```bash
git commit -m "feat: summary" -- file.txt
bash skills/ac-pipeline/scripts/push.sh
```
