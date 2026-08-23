# Changelog

## [Unreleased]

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