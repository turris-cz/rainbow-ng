#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu
. "${0%/*}/utils.sh"
loadsrc ledid

fail() {
	echo "$@" >&2
	exit 1
}

LEDS="power lan-0 lan-1 wlan-1 indicator-1"

valid() {
	is_valid_led "$1" || fail "LED should be valid but it is not: $1"
}

not_valid() {
	! is_valid_led "$1" || fail "Led should not be valid but it is: $1"
}

for led in $LEDS; do
	valid "$led"
done
not_valid "pwr"
not_valid "usr"
not_valid "led"
not_valid "led0"
not_valid "ledfoo"
not_valid "led1x"
not_valid "p"
not_valid "1"

for i in $(seq 5); do
	valid "led$i"
done
not_valid "led6"
not_valid "led7"


canon() {
	local value="$1"
	local expected="$2"
	local res
	res="$(canonled "$value")" || fail "Led canon failed for: $value"
	[ "$res" = "$expected" ] || fail "Led canon is not correct: $res != $expected"
}

index=1
for led in $LEDS; do
	canon "$led" "$led"
	canon "led$index" "$led"
	index=$((index + 1))
done
canon "foo" "foo"
