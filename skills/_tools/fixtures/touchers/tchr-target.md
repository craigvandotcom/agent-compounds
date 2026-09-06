# tchr-target — a fixture artifact for touchers.test.sh

This file exists so that "the path exists in the tree" is TRUE for the harness without
depending on the live registry. It is referenced by its two siblings in this directory,
and by nothing else that matters: the harness scopes every declared command to this dir.
