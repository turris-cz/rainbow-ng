# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

import os


class Backend:
    """Handler for all leds we can control."""

    # All available leds in order on the box
    LEDS = ["wan", "lan-1", "lan-2", "lan-3", "lan-4", "lan-5", "wlan", "power"]

    def __init__(self):
        # The LEDs are opened when they are asked for, as the kernel does not
        # have to provide all of them and can add one later
        self._fds = [None] * len(self.LEDS)

    def update(self, ledid: int, red: int, green: int, blue: int) -> None:
        """Update color of led on given index."""
        if not self.handled(ledid):
            return
        try:
            os.write(self._fds[ledid], f"{red} {green} {blue}".encode())
        except OSError:
            # The LED is gone. It is opened again once the kernel has it back.
            os.close(self._fds[ledid])
            self._fds[ledid] = None

    def apply(self) -> None:
        """Apply previous LEDs state updates if that is required."""
        # We apply immediately so we do not need this.

    def handled(self, ledid: int) -> bool:
        """Informs animator if given led animation should be handled by it."""
        # On 1.x all leds have to be animated using animator, unless the kernel does not
        # provide the LED
        if ledid >= len(self._fds):
            return False
        if self._fds[ledid] is None:
            try:
                self._fds[ledid] = os.open(f"/sys/class/leds/rgb:{self.LEDS[ledid]}/multi_intensity", os.O_WRONLY)
            except OSError:
                return False
        return True
