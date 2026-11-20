# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# Canonize color to RGB 0-255 format.
# Sets three variables: color_r, color_g, color_b
parse_color() {
	local r="" g="" b=""
	_parse_color "$@" || return
	[ -z "$r" ] || color_r="$r"
	[ -z "$g" ] || color_g="$g"
	[ -z "$b" ] || color_b="$b"
}

_parse_value() {
	local value="$1"
	local mode="$2"
	case "$value" in
		x*)
			# Only hexadecimal digits may reach the arithmetic expansion
			value="${value#x}"
			case "$value" in
				""|*[!0-9a-fA-F]*) return 1 ;;
			esac
			[ "${#value}" -le 8 ] || return 1
			value="$((16#$value))"
			;;
	esac

	if [ "$mode" = "inherit" ] && [ "$value" = "-" ]; then
		true
	elif [ -n "$value" ]; then
		case "$value" in
			*[!0-9]*) return 1 ;;
		esac
		[ "${#value}" -le 9 ] || return 1
		value="$(decimal "$value")"
		[ "$value" -le 255 ] || return 1
	fi

	echo "$value"
}

_parse_color() {
	local value="$1"
	local mode="${2:-}"

	if [ -z "$value" ]; then
		return # Empty value means no modification
	fi

	# No valid color uses any other character. The checks below work line by
	# line, so a value that spans several lines must not get to them.
	case "$value" in
		*[!0-9a-zA-Z,-]*) return 1 ;;
	esac

	case "$value" in
		-)
			if [ "$mode" = "inherit" ]; then
				r="-" g="-" b="-"
				return
			fi
			;;
		red)
			r=255 g=0 b=0
			return
			;;
		green)
			r=0 g=255 b=0
			return
			;;
		blue)
			r=0 g=0 b=255
			return
			;;
		yellow)
			r=255 g=255 b=0
			return
			;;
		cyan)
			r=0 g=255 b=255
			return
			;;
		magenta)
			r=255 g=0 b=255
			return
			;;
		white)
			r=255 g=255 b=255
			return
			;;
		black)
			r=0 g=0 b=0
			return
			;;
	esac

	if echo "$value" | grep -qE "^([0-9-]*|x[0-9a-fA-F]+),([0-9-]*|x[0-9a-fA-F]+),([0-9-]*|x[0-9a-fA-F]+)$"; then
		matched="y"
		r="$(_parse_value "${value%%,*}" "$mode")" || return
		local inter="${value%,*}"
		g="$(_parse_value "${inter#*,}" "$mode")" || return
		b="$(_parse_value "${value##*,}" "$mode")" || return
		return
	fi

	if echo "$value" | grep -qE "^[RGB]([0-9]+|x[0-9a-fA-F]+)(,[RGB]([0-9]+|x[0-9a-fA-F]+))*$"; then
		matched="y"
		while read -r spec; do
			case "$spec" in
				R*)
					r="$(_parse_value "${spec#R}" "$mode")" || return
					;;
				G*)
					g="$(_parse_value "${spec#G}" "$mode")" || return
					;;
				B*)
					b="$(_parse_value "${spec#B}" "$mode")" || return
					;;
			esac
		done <<-EOF
			$(echo "$value" | tr ',' '\n')
		EOF
		return
	fi

	# Hex format for backward compatibility
	if echo "$value" | grep -qE "^[0-9a-fA-F]{6}$"; then
		r="$(_parse_value "x${1:0:2}" "")" || return
		g="$(_parse_value "x${1:2:2}" "")" || return
		b="$(_parse_value "x${1:4:2}" "")" || return
		return
	fi

	return 1
}
