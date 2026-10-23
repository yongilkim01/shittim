#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: screenshot.sh [all|region]'
case ${SHITTIM_ARGS[0]:-all} in all) shittim_mode=--screenshot;; region) shittim_mode=--screenshot-region;; *) die '지원하지 않는 캡처 방식입니다.';; esac
run python3 "$SHITTIM_ROOT/scripts/control-service.py" "$shittim_mode"
