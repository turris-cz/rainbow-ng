#!/bin/sh

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu
. "$(dirname "$(readlink -f "$0")")/utils.sh"

loadsrc backend
loadsrc state
loadsrc uci

type get_brightness >/dev/null \
	|| fail "Button sync is not supported on this board!"


trap 'exit 0' INT QUIT TERM
old_brightness="$(get_brightness)"
while true; do
	# TODO we might race here with rainbow configuration (uci changes but change
	# is not yet propagated). It is very unlikely but probably possible.
	current_brightness="$(get_brightness)"
	if [ "$old_brightness" != "$current_brightness" ]; then
		echo "Brightness update using button to: $current_brightness"
		update_brightness "$current_brightness"
		old_brightness="$current_brightness"
	fi
	sleep 2
done
