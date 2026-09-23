"""_bootstrap — makes `lib` importable for a check run standalone.

`python3 lint/checks/NN-some-check.py [root]` (no PYTHONPATH set) is a
supported invocation — 00-meta's own fixture runs every check this way. This
is the one place under lint/checks/ that reaches into `sys.path` directly:
every other check does `import _bootstrap` before `from lib import ...`
instead of carrying its own copy of this three-line dance.

When run.py invokes a check it already sets PYTHONPATH to `lint/` for the
subprocess (see run.py's `run_check()`), so the path insert below is a
harmless no-op there — never a second source of truth for the path, just
belt-and-braces for the invocation run.py does not own.
"""

import os
import sys

_LINT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _LINT not in sys.path:
    sys.path.insert(0, _LINT)
