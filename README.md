# Rainbow

Rainbow is an RGB LEDs manipulation script. It is intended for runtime changes of
color and brightness of LEDs. The permanent configuration that is used as a
base for runtime changes is stored in UCI (it has to be used directly to modify
it).


## UCI Configuration

The primary UCI config of Rainbow is `rainbow`. At the same time, this is not the
only config Rainbow honors and uses. There is also `system`. The reason for this
is because OpenWrt's native LEDs handling already supports some of the features
Rainbow implements and having the configuration in multiple places results in
conflicts. Rainbow tries to resolve them by almost always preferring `system`
configuration.

The `rainbow` config is expected to contain sections of type `led` where section
name is LED name or `all` for all LEDs. The available LED names can be listed
using `rainbow -l`.

The `rainbow.LED` (where `LED` is a valid name of the LED) sections can contain
options:

* `color`: default color of LED (the default depends on the specific LED). See
  `rainbow all -h` for possible values. Note that inheritance is not supported
  in UCI configuration as there is nowhere to inherit values from.
* `mode`: default mode of LED. Continue reading for all available modes (the
  default is `auto`). The option `status` from Turris OS 5 and older is read as
  well.

The LAN LEDs of the Turris 1.x share one color in the hardware. When they are
given different colors, all of them show the color of the highest numbered one
that is not disabled.

The section `all` serves as global defaults for other LEDs. It has also one
additional option `brightness`. It is an integer between 0 and 255 specifying
global LEDs brightness.

The brightness can be set at runtime with `rainbow brightness`. It takes one of
the levels 0 to 8, or the exact value between 0 and 255 with the option `-p`.
On Turris Omnia the levels are the steps of the button on the router, which are
0, 1, 5, 12, 25, 40, 70 and 100 percent. On the other boards they are spread
evenly. `rainbow brightness -q` always prints the value between 0 and 255.

The `mode` option can have the following values:

* `auto`: the default behavior for given LED.
* `disable`: disable LED, so it simply is not used.
* `enable`: enable LED, so it always shines when the router is powered on.
* `activity`: the LED should blink with specific system events (see the following
  section for explanation and configuration). This is not available on all
  platforms as it depends on Kernel support!
* `animate`: performs specified animation (see the following section for
  explanation and configuration).
* `ignore`: instruct Rainbow that this LED should be ignored by it (not
  touched).

### Activity

This mode allows LED to be controlled by events happening in the system (Kernel
events). This configuration is mostly possible in the UCI config `system` and thus
we allow use of that as well. When the trigger is configured in both configs the
`system` one is used.

The activity is not available on all platforms due to implementation. The
notable omission are Turris 1.x routers.

The supported activity triggers (UCI config `trigger` in the appropriate LED section
in `rainbow` config):

* `activity`: Flash the LED with system activity (faster blinking for higher
  activity). This is the default if no `trigger` option is specified.
* `activity-inverted`: Blink the LED with system activity (same as `activity` but in
  the default state, the LED is enabled).
* `heartbeat`: Variant on `activity` that blinks twice instead of once.
* `heartbeat-inverted`: Variant on `activity-inverted` for `heartbeat`.
* `disk-activity`: Blinks with disk activity (any disk activity is considered).
* `disk-read` and `disk-write`: Blinks only when a disk is read or only when it
  is written.
* `usbport`: Blinks with activity on any USB port.
* `netdev-NETDEV`: Blink with activity on a specific network device where `NETDEV`
  is the name of that device.
* `mmcX`: Flashes when writing or reading to and from a specific MMC device where
  `X` is the index of that device.
* `phyX`: Blinks with activity on wireless interface where `X`is index of that
  interface. This is a short form of the kernel trigger `phyXtpt`. The other
  triggers of the wireless device, such as `phyXrx` and `phyXtx`, can be used by
  their full name.
* `ataX`: Blink when writing or reading to and from a specific ATA device where
  `X` is the index of that device.
* `netfilter-ID`: Flashes when firewall rule with specified `ID` is triggered.

Any other trigger that the kernel offers for the LED and that needs no further
setup can be used by its name as well.

The full list of available activities is available by invoking:
`rainbow all activity -l`.

For the LEDs configured in the UCI config `system` Rainbow understands the
triggers `none`, `default-on`, `heartbeat`, `timer` (with `delayon` and
`delayoff`), `netdev` (with `dev` and `mode`), `usbport` and every trigger
listed by the command above. An LED with any other trigger, or with a `netdev`
trigger that has no usable `dev`, is reported and left alone, so that it stays
the way `/etc/init.d/led` configured it.

### Animate

This allows the specification of animation patterns. The simplest variant is periodically
enabling and disabling the LED, but more complex patterns can be specified as well.

The animation is specified as a set of color and time in millisecond pairs. The
color changes from one color to the next one in the duration of the specified time.

In the configuration, the animation is specified as a list of those color and time in
milliseconds pairs. For example the following UCI list gradually dims and
light ups green color on all the LEDs:
`rainbow.all.animation='green 1000' 'black 1000'`

The animations are played by the `rainbow-animator` service. It is a separate
package and nothing is animated when it is not installed.


## Hardware integration

This section describes how to implement hardware integration for rainbow and
what that actually means. This is here as developer documentation not expected
to be read by end-users.

The integration has to be done by implementing a shell file `backend.sh` and
installed in the same directory as the rest of the rainbow. This directory in
the repository also contains a commented example backend file you can use to
understand what you have to implement to get Rainbow working on a new platform.

### Button sync

Some of the boards have a hardware button that allows limited LED brightness
control. We have to sync the setting to the configuration so that the brightness level set with the button is
not wiped after reboot or any rainbow call. This is provided by
the `rainbow-button-sync` service and the `button_sync.sh` shell script. The
`button_sync.sh` uses the same backend file as `rainbow.sh` and needs only one
additional function to be present there - `get_brightness`. The configuration is
saved to the UCI config `rainbow`.

The brightness in the hardware also changes when Rainbow applies the value from
UCI. With the functions `get_brightness_raw` and `brightness_to_raw` in the
backend the button sync recognizes such a change and leaves UCI as it is.

### Animator

The animations are designed to work well with the Kernel LED pattern trigger. The
issue is that not every board has a kernel driver and not only that but also not
every kernel driver allows us to control color using the trigger. To allow
animations even on such platforms we have `rainbow-animator` service that runs
`animator.py`. To make this works you have to implement `animator_backend.py`
which is a simplified backend implemented in Python. You also have to pause
the animator in the `preapply` function in `backend.sh` with
`/etc/init.d/rainbow-animator pause` and reload it in the `postapply` function with
`/etc/init.d/rainbow-animator reload`. The example animator backend file with
comments is provided in this repository.

The animator can be configured to limit the number of updates which is highly
desirable to not load the CPU with LED animations. By default, the number of updates in
a second is set to 15. You can use UCI `rainbow.animation.ups` to set a different
value if you want to tweak it.

## Tests

The unit tests of the parsers and of the state handling are run with:
```
%: make test
```

## Installation

The default install target only installs rainbow itself, not the device-specific backend.
```
%: make install
%: make mox-install
```
