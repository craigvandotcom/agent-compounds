---
name: snippet-skill
description: fixture
---

Prose naming the antipattern `>> "$OUT/file"` must not trip the check.

```bash
bad_command > "$OUT/results.md"
bad2 >${HOME}/hits.md
allowed: append >> "$OUT/file" never truncates
fine: >/dev/null and tee "$OUT/x"
third: > "$OUT/final.md" # dcg-allow — documented antipattern
```

```sh
also bad > "$DIR/list"
```

Not a prescription — same shape in a committed script is never inspected:

```python
print("> \"$VAR/path\"")
```
