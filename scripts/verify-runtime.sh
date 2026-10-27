#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_command python3
python3 "$SHITTIM_ROOT/scripts/design-tokens.py" --check
python3 "$SHITTIM_ROOT/scripts/runtime-status.py"
