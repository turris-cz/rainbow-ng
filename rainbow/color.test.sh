#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu
. "${0%/*}/utils.sh"
loadsrc color

fail() {
	echo "$@" >&2
	exit 1
}

check() {
	local repre="$1"
	local r="$2" g="$3" b="$4" mode="${5:-}"
	local color_r="?" color_g="?" color_b="?"
	parse_color "$repre" "$mode" || fail "Parse failed for: $repre"
	[ "$color_r" = "$r" ] || fail "Red color not matches $color_r != $r for: $repre"
	[ "$color_g" = "$g" ] || fail "Green color not matches $color_g != $g for: $repre"
	[ "$color_b" = "$b" ] || fail "Blue color not matches $color_b != $b for: $repre"
}

check_fail() {
	local repre="$1" mode="${2:-}"
	local color_r="?" color_g="?" color_b="?"
	! parse_color "$repre" "$mode" || fail "Parse did not fail for: $repre"
	[ "$color_r" = "?" ] || fail "Red color modified"
	[ "$color_g" = "?" ] || fail "Green color modified"
	[ "$color_b" = "?" ] || fail "Blue color modified"
}

check "0,0,0" 0 0 0
check "255,0,255" 255 0 255
check "42,0,1" 42 0 1
check "0,0,255" 0 0 255
check "255,0,0" 255 0 0
check ",0,0" "?" 0 0
check "128,," 128 '?' '?'
check ",," '?' '?' '?'
check_fail "532,0,0"
check_fail "0,342,123"
check_fail "42,255,256"

check "xFF,0,x7f" 255 0 127
check "x0,x0,x0" 0 0 0
check ",x2A," "?" 42 "?"
check_fail "x100,0,0"
check_fail "xG,0,0"

check "R0,G0,B0" 0 0 0
check "R255,B255" 255 '?' 255
check "R42,B1" 42 '?' 1
check "B255" '?' '?' 255
check "G255" '?' 255 '?'
check "" '?' '?' '?'

check "Rx0,Gx0,Bx0" 0 0 0
check "RxFF,BxFF" 255 '?' 255
check "Rx2A,Bx1" 42 '?' 1
check "Bxff" '?' '?' 255
check "GxFf" '?' 255 '?'

check "red" 255 0 0
check "green" 0 255 0
check "blue" 0 0 255
check "yellow" 255 255 0
check "cyan" 0 255 255
check "magenta" 255 0 255
check "white" 255 255 255
check "black" 0 0 0

check "-" "-" "-" "-" inherit
check "-,255,-" "-" "255" "-" inherit
check "123,-,-" "123" "-" "-" inherit

check_fail "ABCDF"
check_fail "ABCDF01"
check_fail "orange"
check_fail "Rx1FF"
check_fail "Rx"
check_fail "R-1"
check_fail "1,2"
check_fail "1,2,3,4"

# Nothing that is not a plain number may get to the shell arithmetic. The
# marker would be created by a command substitution in an array subscript.
marker="$(mktemp -u)"
check_fail "Rx1+marker[\$(touch $marker)]"
check_fail "x1+marker[\$(touch $marker)],2,3"
check_fail "R1
Rx1+marker[\$(touch $marker)]"
check_fail "x1+marker[\$(touch $marker)]
1,2,3"
check_fail "FF00FF
x"
[ ! -e "$marker" ] || {
	rm -f "$marker"
	fail "A color value was executed"
}


check "000000" 0 0 0
check "FF00FF" 255 0 255
check "2A0001" 42 0 1
check "0000ff" 0 0 255
check "fF0000" 255 0 0
