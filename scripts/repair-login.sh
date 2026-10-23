#!/usr/bin/env bash
# Repair the misspelled launcher found in the laptop login diagnostic.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command start-hyprland
config_tool repair-login
