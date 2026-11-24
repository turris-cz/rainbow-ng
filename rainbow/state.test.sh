#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu
. "${0%/*}/utils.sh"
loadsrc state

rainbowdir="$(mktemp -d)"
trap 'rm -rf "$rainbowdir"' EXIT

LEDS="power lan-0 lan-1 wlan-1 indicator-1"

fail() {
	echo "$@" >&2
	exit 1
}

cmp_file() (
	local level="$1"
	local slot="$2"
	cat >"$rainbowdir/.cmpfile"
	trap 'rm -f "$rainbowdir/.cmpfile"' EXIT
	diff "$rainbowdir/.cmpfile" "$rainbowdir/$(printf "%03d" "$level")-$slot" \
		|| fail "Files are different"
)


default() {
	true
}
# A level where nothing is set is not stored
call_for_leds_config_level 50 "default" default
[ ! -e "$rainbowdir/050-default" ] || fail "Empty level was stored"

set_wlan-1() {
	if [ "$led" = "wlan-1" ]; then
		color_r=255
		color_g=0
		color_b=127
		mode="auto"
	fi
}
call_for_leds_config_level 51 "wlan-1" set_wlan-1
cmp_file 51 "wlan-1" <<EOF
-	-	-	-
-	-	-	-
-	-	-	-
255	0	127	auto
-	-	-	-
EOF

modify_wlan-1() {
	if [ "$led" = "wlan-1" ]; then
		color_r=0
		color_g=255
		color_b=0
		mode="activity"
		mode_args="netdev-wlan0	link	tx	rx"
	fi
}
call_for_leds_config_level 51 "wlan-1" modify_wlan-1
cmp_file 51 "wlan-1" <<EOF
-	-	-	-
-	-	-	-
-	-	-	-
0	255	0	activity	netdev-wlan0	link	tx	rx
-	-	-	-
EOF

modify_all() {
	color_r=127
	color_g=128
	color_b=255
	mode="auto"
	mode_args=""
}
call_for_leds_config_level 49 "all" modify_all
cmp_file 49 "all" <<EOF
127	128	255	auto
127	128	255	auto
127	128	255	auto
127	128	255	auto
127	128	255	auto
EOF


complete_config() {
	local r g b s a
	case "$led" in
		power|lan-0|lan-1|indicator-1)
			r=127
			g=128
			b=255
			s="auto"
			a=""
			;;
		wlan-1)
			r=0
			g=255
			b=0
			s="activity"
			a="netdev-wlan0	link	tx	rx"
			;;
		*)
			fail "Invalid led: $led"
			;;
	esac
	[ "$color_r" = "$r" ] || fail "Red color does not match: $color_r != $r"
	[ "$color_g" = "$g" ] || fail "Green color does not match: $color_g != $g"
	[ "$color_b" = "$b" ] || fail "Blue color does not match: $color_b != $b"
	[ "$mode" = "$s" ] || fail "Mode does not match: $mode != $s"
	[ "$mode_args" = "$a" ] || fail "Mode arguments do not match: '$mode_args' != '$a'"
}
call_for_leds_config complete_config


# A mode set on a higher level replaces the arguments of the lower one
set_enable() {
	if [ "$led" = "wlan-1" ]; then
		mode="enable"
		mode_args=""
	fi
}
call_for_leds_config_level 60 "enable" set_enable
check_enable() {
	[ "$led" != "wlan-1" ] && return
	[ "$mode" = "enable" ] || fail "Mode does not match: $mode != enable"
	[ -z "$mode_args" ] || fail "Arguments of the lower level were kept: '$mode_args'"
}
call_for_leds_config check_enable

# A level with nothing set is removed
unset_all() {
	color_r="-" color_g="-" color_b="-" mode="-" mode_args=""
}
call_for_leds_config_level 60 "enable" unset_all
[ ! -e "$rainbowdir/060-enable" ] || fail "Empty level was not removed"

# A temporary file that was left behind is not one of the levels
echo "junk" >"$rainbowdir/.049-all.new"
call_for_leds_config complete_config
