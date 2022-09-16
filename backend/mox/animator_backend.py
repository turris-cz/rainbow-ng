# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2022, CZ.NIC z.s.p.o. (https://www.nic.cz/)

import os
from euci import EUci


class Backend:
    """Handler for all LEDs we can control."""

    def __init__(self):
        self._fd = os.open("/sys/class/leds/mox:red:activity/brightness", os.O_WRONLY)
        self.uci = EUci()

    def update(self, ledid: int, red: int, green: int, blue: int) -> None:
        """Update color of LED on given index."""
        assert ledid == "activity"
        brightness = self.uci.get("rainbow", "all", "brightness", dtype=int, default=255)
        os.write(self._fd, f"{red * brightness / 255}".encode())

    def apply(self) -> None:
        """Apply previous LEDs state updates if that is required."""
        # We apply immediately so we do not need this.

    @staticmethod
    def handled(ledid: int) -> bool:
        """Informs animator if given LED animation should be handled by it."""
        return True
