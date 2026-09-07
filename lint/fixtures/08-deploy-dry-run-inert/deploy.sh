#!/bin/sh
# Fixture for lint/checks/08-deploy-dry-run-inert (RED case): a deploy.sh whose
# --dry-run WRITES into the target dir it was asked to preview. The check must
# flag the leak (exit 1). Nothing here touches the real repo.
touch "$1/stamped-by-dry-run"
exit 0
