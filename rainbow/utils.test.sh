#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu
. "${0%/*}/utils.sh"

fail() {
	echo "$@" >&2
	exit 1
}

for value in 0 7 007 255 123456789; do
	is_uint "$value" || fail "Should be a number: $value"
done
# The last ones are what must never get to the shell arithmetic
for value in "" "-" "-1" "1.5" "0x10" "1 2" "1234567890" 'a[$(true)]' "1
2"; do
	! is_uint "$value" || fail "Should not be a number: $value"
done

check_decimal() {
	[ "$(decimal "$1")" = "$2" ] || fail "decimal $1 is not $2"
}
check_decimal 0 0
check_decimal 000 0
check_decimal 007 7
check_decimal 120 120
check_decimal 0120 120
