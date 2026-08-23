<img src="docs/icon.png" width="96" align="right"  alt=""/>

# swol - Simple Wake on Lan

<p float="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://www.dart.dev"><img src="https://img.shields.io/badge/Dart-%230175C2.svg?logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://github.com/lcdss/swol/actions/workflows/lint.yml"><img src="https://github.com/lcdss/swol/actions/workflows/lint.yml/badge.svg?branch=main" alt="Workflow Lint"></a>
  <a href="https://github.com/lcdss/swol/releases"><img src="https://img.shields.io/github/release/lcdss/swol.svg?logo=github&color=blue" alt="GitHub Release"></a>
</p>

swol is an Android app that sends Wake-on-LAN packets to devices on your local network.

It is a fork of [herzhenr/simple-wake-on-lan](https://github.com/herzhenr/simple-wake-on-lan),
trimmed to Android only.

## Usage

Wake on LAN (WoL) is a network protocol that allows a device to be turned on or awakened remotely
over a network while it is sleeping. This project aims to make the process of waking devices easy
with a mobile application.

## Screenshots

|                                          |                                     |
|:----------------------------------------:|:-----------------------------------:|
| ![play_integrity](docs/screenshot-1.png) | ![dark_mode](docs/screenshot-2.png) |  

|                                    |                                 |
|:----------------------------------:|:-------------------------------:|
| ![settings](docs/screenshot-3.png) | ![about](docs/screenshot-4.png) |

## Features

- Automatic device discovery across the local `/24`
- Live online/offline status for saved devices
- Devices addressable by IP or by hostname
- Export and import the device list as a `json` file (see below)

The app stores the added devices in a `json` file which can be exported and imported within the app
UI. An example of the file structure is shown below:

```json
[
  {
    "id": "6b353440-d183-11ed-964b-69a9facd6cfd",
    "hostName": "Raspberry Pi",
    "ipAddress": "192.168.1.9",
    "macAddress": "12:12:12:12:12:12",
    "wolPort": 9,
    "deviceType": "server",
    "secureOnPassword": "12:AB:34:CD:56:EF",
    "modified": "2023-04-14T14:17:45.974511"
  },
  {
    "id": "87c87ab0-d184-13ed-9d56-a5f550305985",
    "hostName": "Printer",
    "ipAddress": "192.168.1.10",
    "macAddress": "f0:f0:f0:f0:f0:f0",
    "wolPort": 9,
    "deviceType": "printer",
    "modified": "2023-04-14T14:18:14.997081"
  }
]
```

`deviceType` must be one of `server`, `desktop`, `laptop`, `printer`, `network`, `iot`, `tv`,
`mobile` or `other`. Anything else imports fine but shows no icon. `secureOnPassword` is
optional: when present (six hex pairs, like a MAC) it is appended to the magic packet for
hardware that supports SecureOn.

## Download

Grab an APK or App Bundle from [GitHub Releases](https://github.com/lcdss/swol/releases).
`app-arm64-v8a-release.apk` is the right build for essentially any current phone.

## Architecture

Flutter, targeting Android only, using the [Material 3](https://m3.material.io) design system via
the standalone [`material_ui`](https://pub.dev/packages/material_ui) package. There is no backend:
discovery is ICMP over the local subnet, waking is a UDP magic packet, and hostname lookups go to
whatever resolver the device already uses. Devices are persisted as a single `devices.json` in the
app documents directory.

## Build

The toolchain is pinned in [`mise.toml`](mise.toml). With [mise](https://mise.jdx.dev) installed:

```sh
mise install          # installs the pinned Flutter
flutter pub get       # also generates the localizations
flutter run
```

Without mise, install the [Flutter SDK](https://flutter.dev/docs/get-started/install) at the version
`mise.toml` names.

Useful commands:

```sh
dart analyze --fatal-infos                      # what CI gates on
dart format --output=none --set-exit-if-changed .
flutter test
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

Release builds fall back to the debug signing keys unless `android/key.properties` exists:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=keystore.jks   # resolved relative to android/app/
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
