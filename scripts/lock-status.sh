#!/usr/bin/env bash
# One status line for the lock screen: network glyph and battery. Reads sysfs only; prints nothing secret.
set -u
network='󰖪'
for interface in /sys/class/net/*; do
    [[ -e $interface/device && $(cat "$interface/operstate" 2>/dev/null) == up ]] || continue
    if [[ -d $interface/wireless ]]; then network='󰖩'; break; fi
    network='󰈀'
done
battery=''
for supply in /sys/class/power_supply/*; do
    [[ $(cat "$supply/type" 2>/dev/null) == Battery && $(cat "$supply/scope" 2>/dev/null || echo System) == System ]] || continue
    capacity=$(cat "$supply/capacity" 2>/dev/null) || continue
    [[ $capacity =~ ^[0-9]+$ ]] || continue
    if [[ $(cat "$supply/status" 2>/dev/null) == Charging ]]; then glyph='󰂄'
    elif (( capacity <= 15 )); then glyph='󰁺'
    else glyph='󰁹'; fi
    battery="$capacity%  $glyph"
    break
done
if [[ -n $battery ]]; then printf '%s    │    %s\n' "$network" "$battery"; else printf '%s\n' "$network"; fi
