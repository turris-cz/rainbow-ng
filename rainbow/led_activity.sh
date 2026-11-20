# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

led_activity_usage() {
	echo "Usage: $0 $1 activity [OPTION].. [TRIGGER]" >&2
}
led_activity_help() {
	led_usage "$1"
	cat >&2 <<-EOF
		Led mode '$1' that blinks with specific device activity.

		Options:
		  -l  List available activity triggers for this led and exit
		  -h  Print this help text and exit
	EOF
}

op_led_activity() {
	local id="$1"; shift
	local list="n"
	local OPTIND=1
	while getopts "t:lih" opt; do
		case "$opt" in
			l)
				list="y"
				;;
			h)
				led_activity_help "$id"
				exit 0
				;;
			*)
				led_activity_usage "$id"
				exit 2
				;;
		esac
	done
	shift $((OPTIND - 1))

	if [ "$list" = "y" ]; then
		all_supported_activities "$id"
		exit 0
	fi

	# Warning: this sets mode_args as this is expected to be called only from
	# op_led function!
	mode_args="activity"
	case "${1:-}" in
		"")
			;;
		activity|activity-inverted|heartbeat|heartbeat-inverted|disk-activity|usbport|netdev-?*)
			# We do not intentionally verify that these are available right
			# now. The module with the trigger can be loaded later and the
			# network device can be a hotplug one.
			mode_args="$1"
			shift
			;;
		*)
			# Anything else has to be something the kernel offers for this LED.
			# A color or the next operation is left for the caller.
			if [ -n "$(all_supported_activities "$id" | grep -xF -e "$1")" ]; then
				mode_args="$1"
				shift
			elif ! (parse_color "$1" inherit) && ! is_operation "$1"; then
				echo "The activity is not available for '$id': $1" >&2
				led_activity_usage "$id"
				exit 2
			fi
			;;
	esac
	SHIFTARGS=$#
}

# Triggers the kernel offers for the given led, one per line. The active one is
# listed without the brackets the kernel puts around it.
led_triggers() {
	local led sysfs
	led="$(canonled "$1")"
	if [ "$led" = "all" ]; then
		for led in $LEDS; do
			led_triggers "$led"
		done | sort -u
		return 0
	fi
	sysfs="$(led2sysfs "$led")" || return 0
	[ -e "$sysfs/trigger" ] || return 0
	tr ' ' '\n' <"$sysfs/trigger" | sed -e 's/^\[//' -e 's/\]$//'
}

# Provide supported activities that are filtered using grep
supported_activities() {
	local led="$1"; shift
	led_triggers "$led" | grep "$@" || true
}

# Triggers that can't be used as an activity just by their name. They either
# need parameters we have no way to pass or have their own mode.
_activity_needs_setup() {
	case "$1" in
		none|netdev|oneshot|pattern|gpio|transient|tty|switch[0-9]*)
			return 0
			;;
	esac
	return 1
}

# Lists all supported activities for given led.
all_supported_activities() {
	local trigger netdev
	led_triggers "$1" | while read -r trigger; do
		case "$trigger" in
			activity|heartbeat)
				echo "$trigger"
				echo "$trigger-inverted"
				;;
			netdev)
				for netdev in /sys/class/net/*; do
					[ -e "$netdev" ] || continue
					echo "netdev-${netdev##*/}"
				done
				;;
			phy[0-9]tpt|phy[0-9][0-9]tpt)
				# The short form is kept for the backward compatibility
				echo "${trigger%tpt}"
				echo "$trigger"
				;;
			*)
				_activity_needs_setup "$trigger" || echo "$trigger"
				;;
		esac
	done
}

# Check if activities are even supported for given led.
led_activities_supported() {
	type led2sysfs >/dev/null || return
	local led="$1"
	# The activities are supported only if we have kernel driver and that 
	if [ "$led" = "all" ]; then
		for led in $LEDS; do
			# We report that at least one led supports it here
			led_activities_supported "$led" && return
		done
	else
		led="$(canonled "$led")"
		led2sysfs "$led" >/dev/null \
			&& [ -n "$(all_supported_activities "$led")" ]
	fi
}


# This function applies activity trigger to led. This is kind of non-standard as
# this is called from backend.sh (from set_led) but this is same for any
# activity capable led.
apply_activity() {
	local led="$1"; shift
	local trigger="${1:-}"
	local sysfs port
	sysfs="$(led2sysfs "$led")"
	[ -e "$sysfs/trigger" ] || return
	case "$trigger" in
		"")
			internal_error "Missing activity arguments for:" "$led"
			;;
		activity|activity-inverted|heartbeat|heartbeat-inverted)
			_set_trigger "$sysfs" "${trigger%-inverted}" || return
			if [ "${trigger%-inverted}" = "$trigger" ]; then
				_set_attribute "$sysfs/invert" 0
			elif [ ! -e "$sysfs/invert" ] \
					|| ! echo 1 2>/dev/null >"$sysfs/invert"; then
				# Without the attribute the LED would signal the plain way
				return 1
			fi
			;;
		usbport)
			_set_trigger "$sysfs" "$trigger" || return
			for port in "$sysfs"/ports/*; do
				_set_attribute "$port" 1
			done
			;;
		timer)
			# Optional arguments are the time the LED is on and off, with a
			# dash for the one that is to be left on the kernel default.
			_set_trigger "$sysfs" "$trigger" || return
			if is_uint "${2:-}"; then
				_set_attribute "$sysfs/delay_on" "$2"
			fi
			if is_uint "${3:-}"; then
				_set_attribute "$sysfs/delay_off" "$3"
			fi
			;;
		phy[0-9]|phy[0-9][0-9])
			_set_trigger "$sysfs" "${trigger}tpt" || return
			;;
		netdev-*)
			_set_trigger "$sysfs" "netdev" || return
			if ! echo "${trigger#netdev-}" 2>/dev/null >"$sysfs/device_name"; then
				warning "The kernel refused the network device name: ${trigger#netdev-}"
				return 1
			fi
			# Optional arguments are the attributes of the trigger to switch
			# on, such as link, link_1000, tx or rx. The link and the traffic
			# in both directions are signaled when there are none.
			shift
			local what
			if [ -z "$*" ]; then
				set link tx rx
			else
				for what in link link_10 link_100 link_1000 link_2500 \
						link_5000 link_10000 half_duplex full_duplex \
						tx rx tx_err rx_err; do
					_set_attribute "$sysfs/$what" 0
				done
			fi
			for what in "$@"; do
				case "$what" in
					""|*[!a-z0-9_]*)
						continue
						;;
				esac
				_set_attribute "$sysfs/$what" 1
			done
			;;
		*)
			# Any other trigger the kernel has for this LED and that needs
			# no setup, such as disk-activity, disk-read, mmc0 or ata1.
			_set_trigger "$sysfs" "$trigger" || return
			;;
	esac
	return 0
}

# Set kernel trigger and check that the kernel took it
_set_trigger() {
	echo "$2" 2>/dev/null >"$1/trigger" || return
	grep -qF "[$2]" "$1/trigger"
}

# Write an attribute of a trigger. The trigger works without the attribute as
# well, so one that is missing or that the kernel refuses in the combination
# with the others is not a failure.
_set_attribute() {
	[ -e "$1" ] || return 0
	echo "$2" 2>/dev/null >"$1" || true
}
