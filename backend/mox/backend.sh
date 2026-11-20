# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# Turris Mox backend for generic rainbow script
LEDS="activity"

SYSFS="/sys/class/leds/mox:red:activity"

loadsrc led_activity

led2sysfs() {
	local led="$1"
	[ "$led" = "activity" ] || return
	echo "$SYSFS"
}

led_defaults() {
	local led="$1"
	color_r=255 color_g=0 color_b=0
}

preapply() {
	# TODO we can use pattern trigger to replace animator
	if [ -x /etc/init.d/rainbow-animator ]; then
		/etc/init.d/rainbow-animator pause
	fi
}

set_led() {
	local led="$1" r="$2" g="$3" b="$4" mode="$5"
	shift 5
	[ "$led" = "activity" ] || return
	# Nothing to do when the kernel does not provide the LED
	[ -d "$SYSFS" ] || return 0

	if [ "$mode" = "auto" ]; then # override auto mode
		mode="activity"
		set "heartbeat"
	fi
	local global_brightness
	global_brightness="$(brightness)"

	local brightness=255 trigger="none"
	case "$mode" in
		disable)
			brightness=0
			;;
		enable)
			;;
		activity)
			brightness=0
			trigger="activity"
			# The trigger switches the LED on its own, so the only way to
			# honor zero brightness is not to use it.
			if [ "$global_brightness" -eq 0 ] || [ "$r" -eq 0 ]; then
				trigger="none"
			fi
			;;
		animate)
			# For animation we we rely on animator
			;;
		*)
			internal_error "Unsupported mode:" "$mode"
			;;
	esac
	brightness=$(((brightness * global_brightness * r) / (255 * 255)))

	# We have to disable trigger first to make sure that changes are correctly
	# applied and not modified by this in the meantime.
	echo "none" > "$SYSFS/trigger"
	echo "$brightness" > "$SYSFS/brightness"
	if [ "$trigger" = "activity" ]; then
		apply_activity "$led" "$@" \
			|| warning "activity setup failed for: $led"
	else
		echo "$trigger" > "$SYSFS/trigger"
	fi
}

postapply() {
	if [ -x /etc/init.d/rainbow-animator ]; then
		/etc/init.d/rainbow-animator reload
	fi
}
