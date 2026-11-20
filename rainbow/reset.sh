# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

reset_usage() {
	echo "Usage: $0 reset [OPTION].." >&2
}
reset_help() {
	reset_usage
	cat >&2 <<-EOF
		Reset current runtime configuration.

		Options:
		  -n  Do not remove the current configuration. Only apply it
		  -a  Reset all priority levels and slots not just the current one
		  -b  Run boot sequence as part of reset
		  -h  Print this help text and exit
	EOF
}

op_reset() {
	local nowipe="n"
	local all="n"
	local bootseq="n"
	local OPTIND=1
	while getopts "nabh" opt; do
		case "$opt" in
			n)
				nowipe="y"
				;;
			a)
				all="y"
				;;
			b)
				bootseq="y"
				;;
			h)
				reset_help
				exit 0
				;;
			*)
				reset_usage
				exit 2
				;;
		esac
	done
	shift $((OPTIND - 1))
	SHIFTARGS=$#
	# What is left has to be the next operation
	local next
	next="$(next_argument "$@")"
	if [ -n "$next" ] && ! is_operation "$next"; then
		echo "Invalid argument for reset: $next" >&2
		reset_usage
		exit 2
	fi

	if [ "$nowipe" = "n" ]; then
		if [ "$all" = "y" ]; then
			rm -f "$rainbowdir"/*
		else
			rm -f "$rainbowdir/$(printf "%03d" "$priority")-$slot"
		fi
		# That can include the files generated from UCI, which an earlier
		# operation of this run may have created already.
		_base_config_updated=""
	fi

	# This comes before the boot sequence, so that the configuration is
	# applied even when the sequence does not get to its end.
	apply_needed="y"

	# Note: the boot sequence is silently ignored if there is none defined
	if [ "$bootseq" = "y" ] && type boot_sequence >/dev/null 2>&1; then
		# The LEDs that are to be ignored are not ours to play with. That
		# includes the ones with a trigger in the system config we can't
		# set up, which would otherwise stay in the last color of the
		# sequence.
		loadsrc uci
		base_config
		_boot_led() {
			[ "$mode" = "ignore" ] || echo "$led" >&3
		}
		# shellcheck disable=SC2046
		boot_sequence $(call_for_leds_config _boot_led 3>&1)
	fi
}
