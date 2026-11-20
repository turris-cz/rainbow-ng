# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

# Common utilities for rainbow scripts

# All rainbow scripts should set this but by adding it here as well we make sure
set -eu

warning() {
	echo "Warning:" "$@" >&2
}

fail() {
	echo "$0:" "$@" >&2
	exit 1
}

internal_error() {
	echo "$0: Internal error:" "$@" >&2
	exit 3
}

# Check that the value is a non-negative decimal integer of a sane length.
# The shell evaluates variables used in arithmetic recursively, including
# command substitutions in array subscripts. Nothing that comes from the
# command line or from UCI may reach $(( )) before it passed this check.
is_uint() {
	case "${1:-}" in
		""|*[!0-9]*) return 1 ;;
	esac
	[ "${#1}" -le 9 ]
}

# Print the decimal number without its leading zeros. The shell would read it
# as an octal number with them. The 10# prefix that does the same in bash is
# not available in the shell of busybox, which runs button_sync.sh.
decimal() {
	local value="${1#"${1%%[!0]*}"}"
	echo "${value:-0}"
}

# Write the value to a file in sysfs. A file that does not exist is skipped,
# so that rainbow can do the rest of its work with a kernel that does not
# provide it.
sysfs_write() {
	[ -e "$2" ] || return 0
	echo "$1" >"$2"
}

# This function should be used to load any other source files that are part of
# rainbow except of this one.
srcdir="$(dirname "$(readlink -f "$0")")"
loadsrc() {
	local name="$1"
	if ! echo "${_src_loaded:-}" | grep -qF "+$name+"; then
		. "$srcdir/$name.sh"
		_src_loaded="${_src_loaded:-}+$name+"
	fi
}
