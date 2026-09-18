#!/usr/bin/env bash
# flight-check.sh — fixture RED case: mentions is_test_shaped, which it must never do.
# calls is_test_shaped indirectly (a stray reference, not a definition)
echo "checking is_test_shaped contract"
