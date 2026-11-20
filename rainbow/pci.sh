# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

loadsrc led_activity

# In some cases we need to detect what is inserted in the specific PCI slot and
# setup activity trigger from system according to that. This function tries to
# do the detection produces activity configuration.
# It expects path to sysfs to the PCI device to investigate.
# This echoes activity argument for activity status.
# If no device was detected or if activity for it is not supported it signals
# failure with returned value.
pci_device_activity_detect() {
	local led="$1"
	local syspci="$2"
	local name ata

	if [ -d "$syspci/ieee80211" ]; then
		if [ -n "$(supported_activities "$led" -xF 'netdev')" ]; then
			name="$(ls -1 "$syspci/net" 2>/dev/null | head -1)"
			if [ -n "$name" ]; then
				echo "netdev-$name"
				return
			fi
		fi
		# There is no network interface yet, so follow the radio instead
		name="$(ls -1 "$syspci/ieee80211" 2>/dev/null | head -1)"
		[ -n "$name" ] || return
		[ -n "$(supported_activities "$led" -xF "${name}tpt")" ] || return
		echo "${name}tpt"
		return
	fi

	for ata in "$syspci"/ata*; do
		[ -d "$ata" ] || continue
		[ -n "$(supported_activities "$led" -xF "${ata##*/}")" ] || continue
		echo "${ata##*/}"
		return
	done

	return 1
}
