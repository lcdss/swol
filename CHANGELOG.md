# Changelog

## [1.4.1] - 26-08-23

### Fixed

- the System Colors switch now applies immediately; it only took effect on
  the next app start before

## [1.4.0] - 26-08-23

### Added

- optional SecureOn password per device, appended to the magic packet for
  hardware that requires it; exports carry it as an optional
  `secureOnPassword` key and older device files import unchanged
- home screen widget listing the saved devices; tapping one sends the wake
  packets without opening the app, with a "Waking..." status line while they
  go out
- the app follows the system's Material You colors on Android 12+; a System
  Colors switch under Settings > Appearance goes back to the app's own palette

### Changed

- wake and discovery use the phone's real subnet instead of assuming /24: the
  extra broadcast goes to the actual subnet broadcast address, discovery
  sweeps the whole subnet (clamped to /22), and a target outside the subnet
  (wake over WAN) gets unicast only
- a MAC address pasted in any common notation -- hyphens, Cisco dots, bare
  hex -- is reformatted instead of rejected, and devices saved with hyphens
  now actually wake
- the port field opens a numeric keyboard
- opening the discover page no longer stutters the transition; the scan
  starts after the animation settles

### Fixed

- a discovery probe error no longer leaves the scan hanging with the
  progress bar stuck
- malformed Wi-Fi info from the platform no longer crashes discovery or wake
- the wake dialog wording: packets are "sent", not "send Packages"

## [1.3.2] - 26-08-23

### Fixed

- the device type selector still showed its error before any interaction; it
  is now a real form field validating on interaction, like the text fields
- typing a port number now highlights the matching quick-select chip; that
  sync was wired to a callback nothing invoked

## [1.3.1] - 26-08-23

Bug-fix pass over the whole app after a full review.

### Fixed

- hostnames with digits or hyphens (`web1.local`, `my-nas.lan`) are now
  accepted in the IP address field; letters-only names were the only ones
  allowed before
- the add/edit device form no longer opens with every field already marked
  invalid before any interaction
- network discovery could crash and lose a device when a slow ping answered
  after the scan had closed its stream; the progress bar also stopped at 99%
- importing a devices file raced a delete against the write and could lose the
  imported list; the import is now a plain awaited overwrite
- exporting with no devices saved shared a 0-byte file that could not be
  imported back; it now exports a valid empty list
- waking a device whose hostname resolves only to IPv6 left the wake dialog on
  an endless spinner; stream errors now render a message
- an unresolvable hostname produced two error messages for the same problem
- rotating the phone or switching theme while the wake dialog was open resent
  the magic packets and restarted the ping loop
- "save with errors" with a non-numeric port silently saved nothing; the port
  field now accepts only digits and survives junk
- devices hidden by the type filter kept a stale online status until
  re-filtered
- re-running the release workflow for an already-released version minted
  duplicate `-build-N` releases; it now skips the release step
- an incomplete `key.properties` now fails the build naming the missing keys

## [1.3.0] - 26-08-22

Full toolchain and dependency upgrade after roughly 20 months without a
release. No intentional changes to how the app is used.

### Changed

- Flutter 3.27 -> 3.47, Dart 3.6 -> 3.13
- every dependency moved to its current release, including the majors
  `file_picker` 8 -> 12, `share_plus` 10 -> 13, `network_info_plus` 6 -> 8,
  `device_info_plus` 11 -> 13, `package_info_plus` 8 -> 10 and `dart_ping` 9 -> 10
- moved to the standalone `material_ui` package, which is where Material now
  lives after being extracted from the Flutter SDK
- localizations are generated into `lib/l10n` -- the synthetic `flutter_gen`
  package the imports used has been removed from the tool
- Android project regenerated on the current template: Gradle 9.3.1, AGP 9.1.0,
  Kotlin 2.4.0, Kotlin build DSL, compileSdk/targetSdk 36
- the Material 3 palette is now seeded from the launcher icon colour instead of
  using the default baseline scheme
- toolchain pinned in `mise.toml`; CI pins the same version instead of floating
  on the stable channel, and now runs the tests

### Fixed

- the project could not be built from a clean clone at all: the Android SDK
  levels were read from a gitignored `local.properties` that only CI wrote
- a malformed `devices.json` crashed the app on startup instead of being
  reported
- the IP address validators accepted anything -- an ungrouped alternation left
  the pattern matching the empty string, so the address field's live check
  never rejected a keystroke and `192.168.1.10.5` passed full validation
- sorting devices by type could throw `Invalid argument(s)`: the comparator was
  not a valid ordering when a device had no type
- the launcher icon was blank on Android 8 and newer, because the adaptive icon
  resource declared no background or foreground
- status and navigation bar icons were dark-on-dark in dark theme
- the discover screen span forever instead of reporting that there was no
  usable Wi-Fi address
- every add/edit form leaked its five text controllers
- the filter chips mutated the parent's state directly, so filter and sort
  selections could disagree with what was displayed
- release signing read the store password where the key password was meant

### Removed

- iOS references in the docs; Android has been the only target since 1.2.1
- unreferenced widgets and screens, and the unmaintained `import_sorter`

## [1.2.1] - 24-12-27

### Feature

- a device's address may be a hostname as well as an IP

### Changed

- dependencies updated
- iOS support dropped; Android is the only target
- missing strings localized

## [1.2.0] - 23-08-21

### Feature

- Online/Offline state of all devices on the home page is shown and automatically updated
- internal changes and enhancements for a better user experience


## [1.1.0] - 23-07-05

First feature update which provides easier mac and ip address typing in form fields and some small ui changes and additions

### Feature

- auto delimiters for mac and ip address in form fields
- discover devices subnet info
- device info in about screen


## [1.0.2] - 23-06-21

### Bugfix
- fix keyboard glitch

### Feature
- version info is shown in about screen


## [1.0.1] - 23-06-18

###  Bugfix

- keyboard on Add Custom Page now behaves normally instead of disposing as soon as the user pressed on an input field
- wol packages are now additionally sent as broadcast magic packages


## [1.0.0] - 23-06-11

Initial Version of Simple Wake On Lan released! The attached binaries (`.aab` for Android and `.ipa` for iOS) are also the ones uploaded to the Google PlayStore and Apple AppStore respectively. The `.apk` file can be installed directly from here for Android devices.


### Feature

- Automatic device discovery
- Simple interface to send Wake On Lan packets
- Export and import user data as a `json` file

### Screenshots

|                                          |                                     |
|:----------------------------------------:|:-----------------------------------:|
| ![play_integrity](docs/screenshot-1.png) | ![dark_mode](docs/screenshot-2.png) |  

|                                    |                                 |
|:----------------------------------:|:-------------------------------:|
| ![settings](docs/screenshot-3.png) | ![about](docs/screenshot-4.png) |