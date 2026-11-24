# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- An LED can follow any trigger the kernel offers, for example disk activity
  (`disk-activity`, `disk-read`, `disk-write`).
- Option `-n` prints the name of each LED next to its configuration.
- The Turris 1.x LED driver that is in OpenWrt is supported.

### Changed
After the update the LEDs can look different in these three cases:
- **LEDs switched on or off in LuCI:** the setting now has an effect. It was
  saved before, but ignored.
- **Color set for all LEDs:** it now applies to every LED, including the
  power LED.
- **Brightness levels on Turris Omnia:** `rainbow brightness` uses the same
  steps as the button on the router.

Other changes:
- A mistyped color, mode or operation is reported as an error.
- An LED that Rainbow can't set up the way it is configured is left alone or
  switched off.
- The configuration of an LED is printed to the standard output, so that
  scripts can read it.
- Values from the configuration and from the command line are checked before
  they are used.

### Fixed
- **Triggers set in LuCI:** an LED set to disk activity, a timer or another
  trigger no longer causes "Unsupported trigger" on every call and no longer
  goes dark.
- **Network and Wi-Fi:** `netdev-*` and `phyX` activities can be set from the
  command line, and the wlan LEDs no longer stay off in the automatic mode.
- **Brightness:** it no longer drops with every restart on Turris 1.x, the
  button sync no longer rewrites the stored value, and `rainbow brightness 0`
  switches off the blinking LED of the Mox.
- **Wrong configuration:** an invalid value or a missing configuration file
  no longer stops Rainbow without a word. It is reported and the default is
  used.
- **Missing and ignored LEDs:** an LED the router does not have no longer
  stops the setup of the others, and ignored LEDs are left out of the boot
  sequence.
- **Animations:** the ones set in the configuration are played, and the
  animator no longer uses more CPU the longer an animation runs.
- **Command line:** all the operations of one command are performed, for
  example `rainbow lan-0 green lan-1 blue`, and options given before an
  operation no longer break it.

## [0.1.4] - 2023-07-20
### Fixed
- button synchronization no longer overwrites UCI values
- maximum brightness is read from sysfs
- brightness value is computed correctly

## [0.1.3] - 2022-11-14
### Fixed
- Fixed 096: value too great for base (error token is "096")
- Fixed led_defaults: not found on Turris MOX
- Fixed reader_loop: bad jump: 8388608 error on Turris 1.X

## [0.1.2] - 2022-11-01
### Fixed
- Enforce bash as there is plenty of bashism inside
- Add missing includes
- Fix button-sync
- Add missing `compat_intensity` function

## [0.1.1] - 2022-09-22
### Fixed
- Fixed UCI support (replace unsupported dashes with underscores)
- Fixed mox auto mode

## [0.1.0] - 2022-09-15
### Added
- Initial implementation
