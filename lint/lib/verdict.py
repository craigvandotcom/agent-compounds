"""lint/lib/verdict.py — the one contract for what a check's exit code means.

Every lint check exits one of four defined codes. `lint/run.py` and
`lint/checks/00-meta.py`'s static-tree fixture leg read the number through
this module, never a duplicated `== 0` / `== 2` / `== 77` branch of their
own — the point is one definition, read everywhere.

    PASS       0   clean, and (for a disk-scanning check) at least one file
                   scanned
    FAIL       1   a real finding
    NOT_GATED  2   the check ran but scanned nothing — never a pass
    SKIP       77  an honest skip — the check's own adopter-local input was
                   absent from this root

Any other exit code (a timeout, an uncaught exception exiting a non-1 code,
a killed process, a stray `sys.exit(5)`) is outside the contract entirely:
`label()` names it `error`, the same word wherever it is read. An `error`
fails a run exactly like a `fail` — see `lint/run.py`'s exit computation and
`lint/README.md`'s exit-code section.

`00-meta.py`'s OTHER fixture leg (a `run.sh` fixture) reads a deliberately
INVERTED contract — 0 means the check under test went RED, not that the
fixture harness passed — and must never read through this module.
"""

PASS = 0
FAIL = 1
NOT_GATED = 2
SKIP = 77

_LABELS = {
    PASS: "ok",
    FAIL: "fail",
    NOT_GATED: "not-gated",
    SKIP: "skip",
}


def label(rc):
    """The one word for an exit code: ok · fail · not-gated · skip · error."""
    return _LABELS.get(rc, "error")
