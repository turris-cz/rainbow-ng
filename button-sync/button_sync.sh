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


# The brightness in the hardware changes in two ways. One is the button and the
# other is rainbow itself when it applies the value from UCI. In the second
# case UCI is right already and the value read back from the hardware would
# only replace it with a rounded one.
set_by_rainbow() {
	type brightness_to_raw >/dev/null 2>&1 || return 1
	type get_brightness_raw >/dev/null 2>&1 || return 1
	[ "$(brightness_to_raw "$(brightness)")" = "$(get_brightness_raw)" ]
}

# rainbow holds a lock on its directory for the whole run, so from the moment it
# stores a new brightness in UCI until the hardware has it. The two are
# compared under the same lock. A look in the middle of such a run would take
# the value the hardware still has for a press of the button and put it back
# to UCI, where the running rainbow would read it again.
rainbowdir="/var/run/rainbow"
mkdir -p "$rainbowdir"
exec 9<"$rainbowdir"

trap 'exit 0' INT QUIT TERM
old_brightness="$(get_brightness)"
while true; do
	flock -x 9
	current_brightness="$(get_brightness)"
	if [ "$old_brightness" != "$current_brightness" ]; then
		if ! set_by_rainbow; then
			echo "Brightness update using button to: $current_brightness"
			update_brightness "$current_brightness"
		fi
		old_brightness="$current_brightness"
	fi
	flock -u 9
	sleep 2
done
