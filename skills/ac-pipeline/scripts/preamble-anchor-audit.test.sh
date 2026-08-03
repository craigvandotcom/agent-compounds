#!/usr/bin/env bash
# Preamble anchor audit.
#
# Every file that CONSTRUCTS a child prompt carries the child-spawn ENVIRONMENT CONTRACT
# block plus a paste-instruction telling a future conductor where to insert it — "above its
# `<anchor>` line". This audit asserts that each named anchor actually OCCURS in the prompt
# body it governs. An anchor that exists only inside the header instruction is the inert-paste
# failure mode: a conductor following the instruction literally cannot find the insertion
# point, so the preamble never reaches any child.
#
# Position-based by design, NOT occurrence-count-based: several carriers line-wrap the anchor
# inside the instruction, so the joined phrase matches only the body and a count-based check
# false-positives on files that are already correct. The assertion is that the anchor occurs
# at a line AFTER the first `ENVIRONMENT CONTRACT` line.
#
# Exit 0 only when every governed carrier's named anchor is found in its body.

set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

rc=0
checked=0
broken=0

for f in $(grep -rl "ENVIRONMENT CONTRACT (non-negotiable)" skills/ --include='*.md' | sort); do
  case "$f" in
    # The canon source. It defines the block, constructs no local prompt body, and is
    # legitimately exempt from the anchor rule.
    */ac-pipeline/references/delegation-contract.md) continue ;;
  esac

  checked=$((checked + 1))
  cline=$(grep -n 'ENVIRONMENT CONTRACT (non-negotiable)' "$f" | head -1 | cut -d: -f1)

  # Flatten the header (everything up to and including the contract line) so a line-wrapped
  # anchor becomes one greppable phrase. `command tr` — a bare `tr` can hit a shell alias.
  hdr=$(sed -n "1,${cline}p" "$f" | command tr '\n' ' ')

  # Three sanctioned instruction phrasings, most specific first. Order matters: the
  # `above the ... opening line` carriers also contain an `above its \`prompt: """\` fence`
  # clause, which must NOT be mistaken for the anchor.
  anchor=$(printf '%s' "$hdr" | grep -o 'above its `[^`]*` line' | head -1 | sed 's/^above its `//; s/` line$//')
  [ -n "$anchor" ] || anchor=$(printf '%s' "$hdr" | grep -o 'above the `[^`]*` opening line' | head -1 | sed 's/^above the `//; s/` opening line$//')
  [ -n "$anchor" ] || anchor=$(printf '%s' "$hdr" | grep -o 'beginning `[^`]*`' | head -1 | sed 's/^beginning `//; s/`$//')

  if [ -z "$anchor" ]; then
    echo "NO-ANCHOR-NAMED  $f"
    rc=1
    broken=$((broken + 1))
    continue
  fi

  # An instruction may quote the anchor truncated with an ellipsis; probe the stem.
  probe=${anchor%…}

  last=$(grep -nF -- "$probe" "$f" | tail -1 | cut -d: -f1)
  if [ -z "$last" ] || [ "$last" -le "$cline" ]; then
    echo "BROKEN  $f  anchor=[$probe]"
    rc=1
    broken=$((broken + 1))
  else
    echo "ok      $f  anchor=[$probe] (body hit at line $last)"
  fi
done

echo "audit: $checked governed carriers checked, $broken broken"
exit $rc
