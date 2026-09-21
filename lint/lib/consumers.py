"""consumers — the consumer-dir union for the deployed-surface checks (07, 12, 14).

The union is the ORG root's own `.claude` plus every deploy target's `.claude`. Both
facts are ASKED of `engine/machine.sh` — the one reader of this machine's facts
(`machine.json`) — and neither is derived here. Nothing in this file parses that file,
counts parents from its own location, or spells a roster path: a second parser is a
second copy, and the two drift. A per-machine file names only what this machine has, so
a dir this union produces that does not exist is skipped downstream by the callers
(they only keep `isdir()` hits) — guessing a room or an app that does not apply costs
nothing.

The reader's exit code carries its state, and it PROPAGATES as an exception, because
the callers answer the two failure states differently (a NOT-CONFIGURED machine is a
disclosed SKIP — a fresh clone legitimately has no consumer layer; a WRONG one is
NOT-CHECKED, exit 2, because only a human can fix it):

    0  configured      -> `consumer_dirs()` returns the union
    4  NOT-CONFIGURED  -> MachineNotConfigured (no machine.json)
    2  WRONG           -> MachineWrong (unparseable, or a named key/path the reader
                          refuses, or the reader itself is missing)

`AC_MACHINE_FILE` is the reader's own fixture seam and is inherited by the subprocess,
so a test points it at a fixture and every path here follows.
"""

import os
import subprocess

_AC_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
READER = os.path.join(_AC_ROOT, "engine", "machine.sh")


class MachineNotConfigured(Exception):
    """The reader found no machine settings file — its exit 4."""


class MachineWrong(Exception):
    """The reader has a machine settings file it refuses, or cannot run — its exit 2."""


_answered = {}


def _ask(flag):
    """Run the reader once and return its stdout; raise its state as an exception."""
    try:
        proc = subprocess.run([READER, flag], capture_output=True, text=True, timeout=60)
    except OSError as exc:
        raise MachineWrong(f"{READER} is not runnable: {exc}") from exc
    if proc.returncode == 0:
        return proc.stdout
    lines = [line for line in proc.stderr.splitlines() if line.strip()]
    message = lines[0] if lines else f"{READER} {flag} exited {proc.returncode}"
    if proc.returncode == 4:
        raise MachineNotConfigured(message)
    raise MachineWrong(message)


def org_root():
    """The org root, as the reader resolved and validated it."""
    if "org_root" not in _answered:
        _answered["org_root"] = _ask("--org-root").strip()
    return _answered["org_root"]


def target_paths():
    """Every deploy target's absolute path, in the order the machine's file names them."""
    if "targets" not in _answered:
        _answered["targets"] = tuple(
            line.split("\t", 1)[0] for line in _ask("--targets").splitlines() if line.strip()
        )
    return _answered["targets"]


def consumer_dirs():
    """The union: org root's `.claude` ∪ every target path's `.claude`, sorted.

    Raises MachineNotConfigured / MachineWrong rather than returning a smaller union:
    an empty list here would read as "no consumer layer" when the truth is that the
    machine's facts could not be resolved at all.
    """
    return sorted(
        {os.path.join(org_root(), ".claude")}
        | {os.path.join(path, ".claude") for path in target_paths()}
    )
