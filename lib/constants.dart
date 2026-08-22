import 'package:material_ui/material_ui.dart';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:swol/l10n/app_localizations.dart';

import 'package:swol/widgets/chip_cards.dart';

class AppConstants {
  /// Seed for the Material 3 tonal palettes, taken from the launcher icon.
  static const seedColor = Color(0xFF287980);

  /// Navigation Bar Icons
  static const homeIcon = Icons.home;
  static const settingsIcon = Icons.settings;
  static const aboutIcon = Icons.info;

  /// HomePage Elements
  static const wakeUp = Icons.power_settings_new_outlined;
  static const edit = Icons.mode_edit_outline_outlined;
  static const macText = 'MAC';
  static const ipText = 'IP';
  static const add = Icon(Icons.add);
  static const sort = Icon(Icons.sort);

  // Home Ping Timeouts and Intervals for scanning
  static const homePingTimeout = 1;
  static const homePingInterval = 12;

  // Wake Up Dialog Elements
  static const errorMessageColor = Colors.red;
  static const successMessageColor = Colors.green;

  // Discover Page Elements
  static const addCustomDeviceType = 'desktop';

  // Form Elements
  static const formIcon = Icons.done_rounded;
  static const nameValidationRegex = r'^.{1,100}$';
  static const hostValidationRegex = r'^([a-z]+\.){1,}[a-z]{2,}$';
  static const ipValidationRegex =
      r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}|([a-z]+\.){1,}[a-z]{2,}$';
  static const ipSubStringValidationRegex =
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2})\.){0,3}((25[0-5]|2[0-4][0-9]|[01]?[0-9]{1,2}))?|([a-z]+\.){1,}[a-z]{2,}$';
  static const macValidationRegex =
      r'^(?:[0-9A-Fa-f]{2}([-:]))(?:[0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2}$';
  static const macSubStringValidationRegex =
      r'^(?:[0-9A-Fa-f]{2}(?:([-:])|$)){0,5}[0-9A-Fa-f]{0,2}$';
  static const portValidationRegex =
      r'^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$';
  static const formWrongFormatIcon = Icons.assignment_outlined;
  static const formInvalidArgument = Icons.cancel_outlined;

  // replacement patterns for the rich text controllers of mac and ip address
  static final macPattern = RegExp(r"[:-]");
  static final ipPattern = RegExp(r"\.");

  // WOL Port Chips
  static List<CustomChoiceChip<int>> getChipsWolPorts({BuildContext? context}) {
    final List<CustomChoiceChip<int>> chipsWolPorts = <CustomChoiceChip<int>>[
      const CustomChoiceChip(value: 7),
      const CustomChoiceChip(value: 9),
    ];
    if (context != null) {
      return chipsWolPorts
          .map(
            (e) => CustomChoiceChip<int>(
              label: AppLocalizations.of(context)!.formPort(e.value),
              value: e.value,
            ),
          )
          .toList();
    } else {
      return chipsWolPorts;
    }
  }

  // Icon chips
  /// Device type value to icon. Insertion order is the chip order.
  static const deviceTypeIcons = <String, IconData>{
    'server': Icons.storage_rounded,
    'desktop': Icons.desktop_mac_rounded,
    'laptop': Icons.laptop_mac,
    'printer': Icons.print_rounded,
    'network': Icons.lan_rounded,
    'iot': Icons.smart_toy,
    'tv': Icons.tv_rounded,
    'mobile': Icons.phone_iphone,
    'other': Icons.tune_rounded,
  };

  static String deviceTypeLabel(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;

    return switch (value) {
      'server' => l10n.deviceChoiceServer,
      'desktop' => l10n.deviceChoiceDesktop,
      'laptop' => l10n.deviceChoiceLaptop,
      'printer' => l10n.deviceChoicePrinter,
      'network' => l10n.deviceChoiceNetwork,
      'iot' => l10n.deviceChoiceIOT,
      'tv' => l10n.deviceChoiceTv,
      'mobile' => l10n.deviceChoiceMobile,
      _ => l10n.deviceChoiceOther,
    };
  }

  static List<CustomChoiceChip<String>> getChipsDeviceTypes({
    BuildContext? context,
  }) {
    return deviceTypeIcons.entries
        .map(
          (entry) => CustomChoiceChip(
            label: context == null ? null : deviceTypeLabel(context, entry.key),
            icon: entry.value,
            value: entry.key,
          ),
        )
        .toList();
  }

  // Theme Chips
  static List<CustomChoiceChip<AdaptiveThemeMode>> getChipsTheme({
    required BuildContext context,
  }) {
    return <CustomChoiceChip<AdaptiveThemeMode>>[
      CustomChoiceChip(
        label: AppLocalizations.of(context)!.settingsThemeSelectorSystem,
        icon: Icons.brightness_4_rounded,
        value: AdaptiveThemeMode.system,
      ),
      CustomChoiceChip(
        label: AppLocalizations.of(context)!.settingsThemeSelectorLight,
        icon: Icons.brightness_5_rounded,
        value: AdaptiveThemeMode.light,
      ),
      CustomChoiceChip(
        label: AppLocalizations.of(context)!.settingsThemeSelectorDark,
        icon: Icons.brightness_2_rounded,
        value: AdaptiveThemeMode.dark,
      ),
    ];
  }

  /// SettingsPage Elements
  static const warningIcon = Icons.warning;
  static const checkIcon = Icons.check;
  static const denyIcon = Icons.close;

  /// AboutPage Elements
  static const sourceCodeIcon = Icons.code;
  static const licenseIcon = Icons.article;
  static const sourceCodeLink =
      'https://github.com/herzhenr/simple-wake-on-lan';

  /// Other
  static const screenPadding = EdgeInsets.only(
    left: 20,
    right: 20,
    top: 0,
    bottom: 0,
  );
  static const screenPaddingScrollView = EdgeInsets.only(
    left: 20,
    right: 20,
    top: 0,
    bottom: 80,
  );
  static final borderRadius = BorderRadius.circular(10);
}
