#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
for shittim_arg in "${SHITTIM_ARGS[@]}"; do
    [[ $shittim_arg == --update ]] || die "사용법: $0 [--dry-run] [--update]"
done
config_tool capture "${SHITTIM_ARGS[@]}"
