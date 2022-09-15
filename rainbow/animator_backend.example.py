import os

class Backend:
    """Handler for all leds we can control."""
    LEDS = ["power"]

    def update(self, ledid: int, red: int, green: int, blue: int) -> None:
        """Update color of led on given index."""
        led = self.LEDS[ledid]
        fd = os.open(f"/sys/class/leds/rgb:{led}/multi_intensity", os.O_WRONLY)
        os.write(fd, f"{red} {green} {blue}".encode())
        os.close(fd)

    def apply(self) -> None:
        """Apply previous LEDs state updates if that is required."""
        # All current backends apply state immediately so this is not needed

    def handled(self, ledid: int) -> bool:
        """Informs animator if led animation for led on given index should be handled by it."""
        return True
