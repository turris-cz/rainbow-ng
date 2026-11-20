# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# UCI configuration helper functions

loadsrc led_activity

# Currently configured brightness level
# It is read from UCI every time. A variable can't stand in for it, as a value
# an operation refused would then still be applied on the way out.
brightness() {
	local __brightness
	__brightness="$(uci -q get "rainbow.all.brightness" || echo 255)"

	# The value ends up in shell arithmetic, so it has to be a number
	if ! is_uint "$__brightness"; then
		warning "Ignoring invalid rainbow.all.brightness: $__brightness"
		__brightness=255
	fi
	# This also removes the leading zeros
	__brightness="$(decimal "$__brightness")"
	if [ "$__brightness" -gt 255 ]; then
		__brightness=255
	fi
	echo "$__brightness"
}

# Set the new brightness level
update_brightness() {
	local brightness="$1"
	# We try to be clever here. We want to store brightness to UCI so we are
	# consistent (no external file) but we do not want to cause byte moves,
	# we want to only rewrite bytes so we always use three digits.
	uci set "rainbow.all=led"
	uci set "rainbow.all.brightness=$(printf '%03d' "$brightness")"
	uci commit rainbow.all.brightness
}


# Extract base configuration (level 0) from UCI
base_config() {
	[ "${_base_config_updated:-}" != "y" ] || return 0
	loadsrc animation
	# The subshell here is used to hide function.sh
	(
		set +u # functions.sh does not support unset variables being error
		. /lib/functions.sh

		# functions.sh counts the sections and the items of a list with shell
		# arithmetic on variables that a section, an option or a list of the
		# right name can preset, for example foo_LENGTH for the list foo. The
		# shell of busybox it is written for only fails on a value that is not
		# a number, but bash evaluates it as an expression. Let nothing but
		# the counting in functions.sh itself write those variables. An
		# option or a list named that way is dropped. The same goes for
		# LIST_STATE, as config_load passes every word of it to export and
		# that can set the counters as well.
		eval "_functions_$(declare -f config)"
		eval "_functions_$(declare -f config_set)"
		eval "_functions_$(declare -f append)"
		eval "_functions_$(declare -f list)"
		_functions_counting=""
		config_set() {
			case "${1}_${2}" in
				LIST_STATE)
					return 0
					;;
				NUM_SECTIONS|*_LENGTH)
					[ "$_functions_counting" = "y" ] || return 0
					;;
			esac
			_functions_config_set "$@"
		}
		append() {
			case "$1" in
				CONFIG_NUM_SECTIONS|CONFIG_*_LENGTH)
					return 0
					;;
				CONFIG_LIST_STATE)
					# list() adds the name of a variable here
					case "$2" in
						""|*[!A-Za-z0-9_]*)
							return 0
							;;
					esac
					;;
			esac
			_functions_append "$@"
		}
		# The counters can still come from somewhere else, such as the
		# environment, so make sure that they are numbers right before
		# functions.sh uses them.
		config() {
			is_uint "${CONFIG_NUM_SECTIONS:-0}" || CONFIG_NUM_SECTIONS=0
			_functions_config "$@"
		}
		list() {
			local _functions_counting="y" len
			config_get len "$CONFIG_SECTION" "${1}_LENGTH" 0
			is_uint "$len" || config_set "$CONFIG_SECTION" "${1}_LENGTH" 0
			_functions_list "$@"
		}

		config_load rainbow
		# The section for all the LEDs is the same for every one of them, so
		# read it once. A dash stands for what it does not set.
		color_r="-" color_g="-" color_b="-" mode="-" mode_args=""
		_uci_rainbow_options "all"
		all_r="$color_r" all_g="$color_g" all_b="$color_b"
		all_mode="$mode" all_mode_args="$mode_args"
		for led in $LEDS; do
			_uci_rainbow_section "$(echo "$led" | sed 's|-|_|')"
			echo "$color_r	$color_g	$color_b	$mode${mode_args:+	}$mode_args"
		done >"$rainbowdir/000-base"

		config_load system
		for led in $LEDS; do
			color_r="-" color_g="-" color_b="-" mode="-" mode_args=""
			sysfs="$(led2sysfs "$led")"; sysfs="${sysfs##*/}"
			config_foreach _uci_system_section "led"
			echo "$color_r	$color_g	$color_b	$mode${mode_args:+	}$mode_args"
		done >"$rainbowdir/000-system"
	)
	_base_config_updated="y"
}

# Parse given led setting from UCI
# The defaults of the board are overridden by what is set for all the LEDs and
# that by what is set for the given one.
_uci_rainbow_section() {
	local led="$1"
	color_r=255 color_g=255 color_b=255
	mode="auto" mode_args=""
	! type led_defaults >/dev/null 2>&1 || led_defaults "$led"
	[ "$all_r" = "-" ] || color_r="$all_r"
	[ "$all_g" = "-" ] || color_g="$all_g"
	[ "$all_b" = "-" ] || color_b="$all_b"
	if [ "$all_mode" != "-" ]; then
		mode="$all_mode"
		mode_args="$all_mode_args"
	fi
	_uci_rainbow_options "$led"
}

# Apply the options of one section of the rainbow config
_uci_rainbow_options() {
	local led="$1"
	local rawcolor rawmode trigger

	config_get rawcolor "$led" "color" ""
	parse_color "$rawcolor" \
		|| warning "Ignoring invalid color '$rawcolor' in: rainbow.$led"

	# The status is the name of this option in the rainbow of Turris OS 5 and
	# older. It is still what luci-app-rainbow and the migrated configs use.
	config_get rawmode "$led" "status" ""
	config_get rawmode "$led" "state" "$rawmode" # backward compatibility
	config_get rawmode "$led" "mode" "$rawmode"
	[ -n "$rawmode" ] || return 0
	case "$rawmode" in
		auto|disable|enable|activity|animate|ignore)
			;;
		*)
			warning "Ignoring invalid mode '$rawmode' in: rainbow.$led"
			return 0
			;;
	esac
	mode="$rawmode"
	mode_args=""
	if [ "$mode" = "activity" ]; then
		config_get trigger "$led" "trigger" "activity"
		case "$trigger" in
			""|*[!A-Za-z0-9_.:@-]*)
				warning "Ignoring invalid trigger '$trigger' in: rainbow.$led"
				trigger="activity"
				;;
		esac
		mode_args="$trigger"
	elif [ "$mode" = "animate" ]; then
		local animation animation_color_r animation_color_g animation_color_b
		animation_init
		config_list_foreach "$led" "animation" _for_uci_animation
		animation_finish
		mode_args="$animation"
	fi
}

_for_uci_animation() {
	local value="$1"
	read -r color time <<-EOF
		$value
	EOF
	animation_add "$color" "$time" \
		|| warning "Skipping invalid animation state for '$led': $1"
}

_uci_system_section() {
	local section="$1"
	local cursysfs
	config_get cursysfs "$section" "sysfs"
	if [ "$cursysfs" = "$sysfs" ]; then
		local default trigger
		config_get_bool default "$section" "default" "0"
		config_get trigger "$section" "trigger" "none"
		case "$trigger" in
			none)
				[ "$default" != "1" ] \
					|| mode="enable"
				;;
			timer)
				local on off
				config_get on "$section" "delayon"
				config_get off "$section" "delayoff"
				mode="activity"
				# A dash stands for the time that is not set
				is_uint "$on" || on="-"
				is_uint "$off" || off="-"
				mode_args="timer	$on	$off"
				;;
			default-on)
				mode="enable"
				;;
			heartbeat)
				mode="activity"
				if [ "$default" = "0" ]; then
					mode_args="heartbeat"
				else
					mode_args="heartbeat-inverted"
				fi
				;;
			netdev)
				local dev netmode what
				config_get dev "$section" "dev"
				config_get netmode "$section" "mode"
				case "$dev" in
					""|*[!A-Za-z0-9_.:@-]*)
						;;
					*)
						mode="activity"
						mode_args="netdev-$dev"
						# These are attributes of the trigger, for example
						# link, link_1000, tx or rx
						for what in $netmode; do
							case "$what" in
								*[!a-z0-9_]*)
									;;
								*)
									mode_args="$mode_args	$what"
									;;
							esac
						done
						;;
				esac
				;;
			usbdev|usbport)
				mode="activity"
				mode_args="usbport"
				# We ignore dev as rainbow simply follows all USB devices
				;;
			*)
				# Any other trigger the kernel has for this LED and that
				# needs no setup, such as disk-activity or phy0tpt
				if ! _activity_needs_setup "$trigger" \
						&& [ -n "$(supported_activities "$led" -xF -e "$trigger")" ]; then
					mode="activity"
					mode_args="$trigger"
				else
					warning "Unsupported trigger '$trigger' for: system.$section ($sysfs)"
					# We do not know how to set this one up, so keep the LED
					# the way /etc/init.d/led configured it.
					mode="ignore"
				fi
				;;
		esac
	fi
}
