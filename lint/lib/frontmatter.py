"""frontmatter — the one YAML-subset parser for lint v2.

Two block shapes, one implementation:

  --- fenced YAML   (`---` line, key: value lines, closing `---`) — SKILL.md
  # --- fenced      (same, each line prefixed by a comment marker) — the check
                     file HEADER contract (id / prevents / scope / severity /
                     expires / fixture). 00-meta.py and run.py both parse the
                     header through this module, so the two enforcers cannot
                     drift.

Supported values: plain scalars, quoted scalars, inline lists `[a, b]`, and
block lists (`key:` followed by `- item` lines). Anything richer is not YAML
the registry's frontmatter uses; the parser returns what it can and reports
what it skipped.
"""

import re

_FENCE = re.compile(r"^-{3,}\s*$")


def parse_block(lines):
    """Parse a key/value block (no fences) into a dict."""
    out = {}
    current = None
    for raw in lines:
        line = raw.rstrip()
        if not line.strip() or line.strip().startswith("#"):
            continue
        stripped = line.strip()
        if stripped.startswith("- ") and current is not None:
            out[current] = out.get(current) or []
            if isinstance(out[current], list):
                out[current].append(stripped[2:].strip())
            continue
        if ":" not in stripped:
            continue
        key, _, val = stripped.partition(":")
        key, val = key.strip(), val.strip()
        if val == "":
            out[key] = []
            current = key
            continue
        current = None
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            out[key] = [v.strip().strip("'\"") for v in inner.split(",")] if inner else []
        elif val[:1] in "'\"" and val[-1:] == val[:1] and len(val) >= 2:
            out[key] = val[1:-1]
        else:
            out[key] = val
    return out


def parse(text):
    """Parse --- fenced YAML frontmatter from file text. Empty dict when absent."""
    lines = text.splitlines()
    if not lines or not _FENCE.match(lines[0].strip()):
        return {}
    end = None
    for i, line in enumerate(lines[1:], start=1):
        if _FENCE.match(line):
            end = i
            break
    if end is None:
        return {}
    return parse_block(lines[1:end])


def parse_comment_block(text):
    """Parse the # - fenced header contract from a check file's comment block.

    Accepts lines between a `# ---` fence pair, with the `#` prefix stripped
    before parsing; also accepts the same fields without a closing fence when
    a non-comment or non-header line ends the block.
    """
    lines = text.splitlines()
    start = None
    header_lines = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if start is None:
            if stripped in ("# ---", "---"):
                start = i
            continue
        if stripped in ("# ---", "---"):
            break
        if stripped.startswith("#"):
            header_lines.append(stripped.lstrip("#"))
            continue
        break  # first non-comment line ends the header
    if start is None or not header_lines:
        return {}
    return parse_block(header_lines)


def parse_file(path):
    """Read and parse a check file's # - fenced header, with a managed handle."""
    with open(path, encoding="utf-8") as fh:
        return parse_comment_block(fh.read())
