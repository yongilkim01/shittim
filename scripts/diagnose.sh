#!/usr/bin/env bash
# Collect diagnostics without changing the running desktop or login settings.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
require_command python3
exec python3 "$SHITTIM_ROOT/scripts/diagnose.py" "$@"
