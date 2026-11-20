#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

set -eu

rainbowdir="/var/run/rainbow"
mkdir -p "$rainbowdir"
[ "${RAINBOW_DIRECTORY_LOCKED-:}" = "y" ] \
	|| RAINBOW_DIRECTORY_LOCKED="y" exec flock -x "$rainbowdir" "$0" "$@"

# We hold the lock, so any temporary file found here was left behind by a run
# that did not finish.
rm -f "$rainbowdir"/.[0-9][0-9][0-9]-*.new

. "$(dirname "$(readlink -f "$0")")/utils.sh"
loadsrc state
loadsrc ledid
loadsrc backend

################################################################################
usage() {
	cat >&2 <<-EOF
		Turris leds manipulation.

		Usage: $0 [OPTION].. <OPERATION>...

		Options:
		  -p INT  Set priority to given led setting (in default 50 is used)
		  -n STR  Slot name ('default' used if not specified)
		  -l      List all available LEDs by name
		  -x      Run in debug mode
		  -h      Print this help text and exit

		Operations:
		  reset       Reset rainbow state (wipe any runtime changes)
		  brightness  Set upper limit on brightness of all leds
		  all         Configure all available leds at once
		  ledX        Where X is number (up to 12 on Omnia and 8 on 1.x)
		  Configure specific led by name:
		    $LEDS

		Every operation has some additional arguments. You can list them by
		passing -h option after specifying the operation.
	EOF
}

priority=50
slot="default"
list_leds="n"
while getopts "p:n:lxh" opt; do
	case "$opt" in
		p)
			if is_uint "$OPTARG" && [ "$(decimal "$OPTARG")" -le 100 ]; then
				priority="$(decimal "$OPTARG")"
			else
				echo "Priority is not in the range from 0 to 100: $OPTARG" >&2
				usage
				exit 2
			fi
			;;
		n)
			if [ "${OPTARG#*/}" != "$OPTARG" ]; then
				echo "The slot name can't contain '/'" >&2
				usage
				exit 2
			fi
			slot="$OPTARG"
			;;
		l)
			list_leds="y"
			;;
		x)
			set -x
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 2
			;;
	esac
done
shift $((OPTIND - 1))

if [ "$list_leds" = "y" ]; then
	for led in $LEDS; do
		echo "$led"
	done
	exit 0
fi

# An empty argument is what a script passes for a variable it left empty, so
# it is skipped. With nothing else there is no operation to perform.
has_operation="n"
for arg in "$@"; do
	[ -z "$arg" ] || has_operation="y"
done
[ "$has_operation" = "y" ] || {
	usage
	exit 2
}

# Check if the argument is the start of an operation. The operations use it to
# tell an argument they do not know from the operation that follows them.
is_operation() {
	case "$1" in
		reset|brightness)
			return 0
			;;
		binmask|intensity|get)
			type compatibility >/dev/null 2>&1
			return
			;;
	esac
	is_valid_led "$1"
}

# Print the first argument that is not empty. That is the one the main loop
# takes for the next operation, as it skips the empty ones.
next_argument() {
	local arg
	for arg in "$@"; do
		if [ -n "$arg" ]; then
			printf '%s\n' "$arg"
			return
		fi
	done
}

################################################################################
# Helper function that is used in combination with parse_leds_file.
# This takes variables and passes them as an appropriate arguments as set_led
# functions expect it.
call_set_led() {
	[ "$mode" != "ignore" ] || return 0
	shift $# # we do not care about our arguments
	set "$@" "$led" "$color_r" "$color_g" "$color_b" "$mode"
	while read -r arg; do
		set "$@" "$arg"
	done <<-EOF
		$(printf '%s\n' "$mode_args" | tr '\t' '\n')
	EOF
	# An LED that can't be configured must not stop the remaining ones
	set_led "$@" \
		|| warning "Unable to configure the LED: $led"
}

# Apply the stored configuration to the LEDs if any operation changed it
apply_config() {
	[ "$apply_needed" = "y" ] || return 0
	apply_needed="n"
	loadsrc uci
	base_config
	! type preapply >/dev/null 2>&1 || preapply
	call_for_leds_config call_set_led
	! type postapply >/dev/null 2>&1 || postapply
}

# Every operation stores its change right away. When a later one on the same
# command line fails, the LEDs still have to get what was stored before it, so
# apply on any exit.
apply_needed="n"
trap apply_config EXIT

# Every operation reports the number of arguments it did not use in SHIFTARGS.
# Those are the following operations.
while [ $# -gt 0 ]; do
	operation="${1:-}"
	shift
	case "$operation" in
		reset)
			loadsrc reset
			op_reset "$@"
			shift $(($# - SHIFTARGS))
			;;
		brightness)
			loadsrc brightness
			op_brightness "$@"
			shift $(($# - SHIFTARGS))
			;;
		"")
			;;
		*)
			if is_valid_led "$operation"; then
				loadsrc led
				op_led "$operation" "$@"
				shift $(($# - SHIFTARGS))
			else
				SHIFTARGS=$#
				type compatibility >/dev/null 2>&1 \
					&& compatibility "$operation" "$@"
				if [ "$SHIFTARGS" -lt $# ]; then
					shift $(($# - SHIFTARGS))
				else
					echo "Invalid operation: $operation" >&2
					usage
					exit 2
				fi
			fi
			;;
	esac
done

apply_config
