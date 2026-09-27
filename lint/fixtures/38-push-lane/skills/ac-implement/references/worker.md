# worker fixture

Prose is allowed to say `git push` in a sentence — this line is not inside a fenced
code block, so it is out of scope for Check 38.

```bash
# A comment may quote git push to explain what this forbids — comments are out of scope.
git add -- file.txt
git commit -m "..." -- file.txt
git push origin main
```
