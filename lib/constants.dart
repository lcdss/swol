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

  /// One IPv4 octet, 0-255.
  static const _octet = r'(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)';

  /// An RFC 1123 hostname label: letters, digits and inner hyphens.
  static const _label = r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?';

  /// A dotted hostname. The final label must start with a letter so that a
  /// dotted quad is never mistaken for a name and sent to the resolver -- see
  /// [isHost]. A bare label with no dot is also rejected on purpose: Android
  /// resolvers apply no search domain, so it could not resolve anyway.
  static const _hostname =
      '(?:$_label\\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?';

  /// Note the outer group: without it the alternation would bind to the
  /// anchors, leaving each branch anchored at only one end, and `hasMatch`
  /// would accept trailing or leading junk.
  static const hostValidationRegex = '^$_hostname\$';
  static const ipValidationRegex = '^(?:$_octet(?:\\.$_octet){3}|$_hostname)\$';

  /// Matches while the user is still typing: any run of the characters an IP
  /// or hostname can contain. The shape is left to [ipValidationRegex] --
  /// enforcing it per keystroke would reject valid names mid-word.
  static const ipSubStringValidationRegex = r'^[a-zA-Z0-9.-]*$';
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
  static const sourceCodeLink = 'https://github.com/lcdss/swol';

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
