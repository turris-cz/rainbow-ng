# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
