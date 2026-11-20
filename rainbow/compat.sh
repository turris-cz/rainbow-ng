# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# These are common arguments that were previously provided by rainbow but are
# now obsolete. They are implemented separately so backend can choose which it
# has to support (depending on rainbow introduction to the platform).

compat_binmask() {
	if [ $# -eq 0 ]; then
		echo "Invalid binmask usage. Missing number."
		exit 2
	fi

	_compat_binmask_modify() {
		[ "$1" != "$led" ] \
			|| mode="$2"
	}

	local binmask="$1"
	shift
	# The mask is used in shell arithmetic, so make sure it is a number
	case "$binmask" in
		0x*|0X*)
			binmask="${binmask#0[xX]}"
			case "$binmask" in
				""|*[!0-9a-fA-F]*) binmask="" ;;
			esac
			[ "${#binmask}" -le 8 ] && [ -n "$binmask" ] \
				&& binmask="$((16#$binmask))" \
				|| binmask=""
			;;
		*)
			is_uint "$binmask" \
				&& binmask="$(decimal "$binmask")" \
				|| binmask=""
			;;
	esac
	if [ -z "$binmask" ]; then
		echo "Invalid binmask usage. The mask has to be a number." >&2
		exit 2
	fi

	local mask=1
	for led in $LEDS; do
		mask=$((mask << 1))
	done

	for led in $LEDS; do
		mask=$((mask >> 1))
		local mode="disable"
		[ "$((binmask & mask))" -eq 0 ] \
			|| mode="enable"
		call_for_leds_config_level "$priority" "$slot" _compat_binmask_modify \
			"$led" "$mode"
	done
	apply_needed="y"
	SHIFTARGS=$#
}


compat_intensity() {
	local max="$1"; shift
	if [ $# -gt 0 ]; then
		# The value is used in shell arithmetic, so make sure it is a number
		if ! is_uint "$1"; then
			echo "Invalid intensity usage. The value has to be a number from 0 to $max." >&2
			exit 2
		fi
		local intensity
		intensity="$(decimal "$1")"
		[ "$intensity" -le "$max" ] || intensity="$max"
		loadsrc uci
		update_brightness "$((intensity * 255 / max))"
		apply_needed="y"
		shift
	else
		echo "Invalid intensity usage. Missing intensity value." >&2
		exit 2
	fi
	SHIFTARGS=$#
}


compat_get() {
	local max="$1"; shift
	if [ "${1:-}" = "intensity" ]; then
		local brightness
		if type get_brightness_raw >/dev/null 2>&1; then
			brightness=$(get_brightness_raw);
		elif type get_brightness >/dev/null 2>&1; then
			brightness=$(get_brightness);
		else
			echo "Backend doesn't provide a get_brightness_raw or get_brightness function" >&2
			exit 2
		fi
		echo "$brightness"
		shift
	else
		echo "Invalid get usage. Missing 'intensity' argument." >&2
		exit 2
	fi
	SHIFTARGS=$#
}
