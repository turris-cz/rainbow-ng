# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# Turris 1.x backend for generic rainbow script
LEDS="wan lan-1 lan-2 lan-3 lan-4 lan-5 wlan power"

# it doesn't matter which led we use here, device always points to the same
# location
SYSFS="/sys/class/leds/rgb:wan/device"

loadsrc led_activity
loadsrc compat

led2sysfs() {
	local led="$1"
	echo "/sys/class/leds/rgb:$led"
}

led_defaults() {
	local led="$1"
	case "$led" in
		power)
			color_r=0 color_g=255 color_b=0
			;;
		lan*|wlan)
			color_r=0 color_g=0 color_b=255
			;;
		wan)
			color_r=0 color_g=255 color_b=255
			;;
	esac
}

# The button on the router steps through the brightness levels. Report the one
# in use in the 0-255 range, with the same steps preapply uses the other way.
get_brightness() {
	local level
	level="$(get_brightness_raw)"
	if [ "$level" -ge 7 ]; then
		echo 255
	else
		echo "$((level * 32))"
	fi
}

get_brightness_raw() {
	cat "$SYSFS/brightness_level"
}

# Set the brightness each of the eight levels stands for
set_brightness_levels() {
	if [ -e "$SYSFS/brightness_values" ]; then
		# Driver in Turris OS
		echo "$*" >"$SYSFS/brightness_values"
	elif [ -d "$SYSFS/brightness_levels" ]; then
		# Driver in OpenWrt, one file per level
		local level=0 value
		for value in "$@"; do
			sysfs_write "$value" "$SYSFS/brightness_levels/$level"
			level=$((level + 1))
		done
	fi
}

preapply() {
	if [ -x /etc/init.d/rainbow-animator ]; then
		/etc/init.d/rainbow-animator pause
	fi

	local brightness_level
	brightness_level="$(($(brightness) / 32))"
	# we only have 8 indexes - 0-7
	if [ "$brightness_level" -gt 7 ]; then
		brightness_level=7
	fi
	set_brightness_levels 0 2 4 8 16 32 64 255
	sysfs_write "$brightness_level" "$SYSFS/brightness_level"
}

set_led() {
	local led="$1" r="$2" g="$3" b="$4" mode="$5"
	shift 5
	# Nothing to do for an LED the kernel does not provide
	[ -d "$(led2sysfs "$led")" ] || return 0

	if [ "$mode" = "auto" ]; then # override auto mode for some
		case "$led" in
			power)
				mode="enable"
				;;
			wlan)
				# The CPLD has no hardware trigger for this LED, so follow
				# the first wireless device when there is one.
				if [ -n "$(supported_activities "$led" -xF 'phy0tpt')" ]; then
					mode="activity"
					set "phy0tpt"
				else
					mode="disable"
				fi
				;;
		esac
	fi

	local sysfs brightness trigger="none"
	sysfs="$(led2sysfs "$led")"
	brightness="$(cat "$sysfs/max_brightness")"
	case "$mode" in
		auto)
			trigger="turris1x-cpld"
			;;
		disable)
			brightness=0
			;;
		enable)
			;;
		activity)
			trigger="activity"
			;;
		animate)
			# For animation we rely on animator
			;;
		*)
			internal_error "Unsupported mode:" "$mode"
			;;
	esac

	# We have to disable trigger first to make sure that changes are correctly
	# applied and not modified by this in the meantime.
	echo "none" > "$sysfs/trigger"
	echo "$brightness" > "$sysfs/brightness"
	echo "$r $g $b" > "$sysfs/multi_intensity"
	if [ "$trigger" = "activity" ]; then
		apply_activity "$led" "$@" \
			|| warning "activity setup failed for: $led"
	elif ! echo "$trigger" 2>/dev/null >"$sysfs/trigger"; then
		warning "The trigger '$trigger' is not available for: $led"
	fi
}

postapply() {
	if [ -x /etc/init.d/rainbow-animator ]; then
		/etc/init.d/rainbow-animator reload
	fi
}

boot_sequence() {
	local sysfs

	for led in $LEDS; do
		sysfs="$(led2sysfs "$led")"
		[ -d "$sysfs" ] || continue
		echo "none" > "$sysfs/trigger"
		echo "1" > "$sysfs/brightness"
		echo "0 255 0" > "$sysfs/multi_intensity"
	done
	sleep 1

	for led in $LEDS; do
		sysfs="$(led2sysfs "$led")"
		[ -d "$sysfs" ] || continue
		echo "none" > "$sysfs/trigger"
		echo "1" > "$sysfs/brightness"
		echo "0 0 255" > "$sysfs/multi_intensity"
	done
	sleep 1
	# Note: we apply in the end so we don't have to restore previous state
}

# Parse operations that were previously available with rainbow
compatibility() {
	local operation="$1"; shift
	SHIFTARGS=$#
	case "$operation" in
		binmask)
			compat_binmask "$@"
			;;
		intensity)
			compat_intensity 7 "$@"
			;;
		get)
			compat_get 7 "$@"
			;;
	esac
	shift $(($# - SHIFTARGS))
	SHIFTARGS=$#
}
