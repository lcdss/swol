import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:swol/l10n/app_localizations.dart';

import 'package:swol/constants.dart';

import '../../services/data.dart';
import '../../services/database.dart';
import '../../widgets/chip_cards.dart';
import '../../widgets/layout_elements.dart';
import '../../widgets/universal_ui_components.dart';
import 'data_ops.dart';

// import 'package:adaptive_theme/adaptive_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int? themeValue = 1;
  bool colors = true;

  DeviceStorage deviceStorage = DeviceStorage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: [
          TextTitle(
            title: AppLocalizations.of(context)!.settingsAppearanceTitle,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.settingsThemeSelectorTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const ThemeSwitcher(),
                ],
              ),
            ],
          ),
          TextTitle(
            title: AppLocalizations.of(context)!.settingsAppDataTitle,
            children: [
              SpacedRow(
                children: [
                  IconTextButton(
                    text: AppLocalizations.of(context)!.settingsExport,
                    icon: Icons.arrow_upward_outlined,
                    onPressed: shareJsonFile,
                  ),
                  IconTextButton(
                    text: AppLocalizations.of(context)!.settingsImport,
                    icon: Icons.arrow_downward_outlined,
                    onPressed: importJsonFile,
                  ),
                ],
              ),
              Row(
                children: [
                  IconTextButton(
                    text: AppLocalizations.of(context)!.settingsReset,
                    icon: Icons.delete_forever_outlined,
                    onPressed: () {
                      buildResetDialog(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    // This trailing comma makes auto-formatting nicer for build methods.
  }

  Future<dynamic> buildResetDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return customDualChoiceAlertdialog(
          title: AppLocalizations.of(context)!.settingsReset,
          icon: AppConstants.warningIcon,
          iconColor: Theme.of(context).colorScheme.error,
          child: Text(AppLocalizations.of(context)!.settingsResetDialogText),
          leftText: AppLocalizations.of(context)!.cancel,
          leftOnPressed: () => Navigator.pop(context),
          rightText: AppLocalizations.of(context)!.settingsResetDialogButton,
          rightOnPressed: () => {
            Navigator.pop(context),
            deviceStorage.deleteAllDevices(),
          },
          rightColor: Theme.of(context).colorScheme.error,
        );
      },
    );
  }

  void showInvalidJsonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return customDualChoiceAlertdialog(
          title: AppLocalizations.of(context)!
              .settingsResetDialogWrongJsonFormatTitle,
          iconColor: Theme.of(context).colorScheme.error,
          child: Text(
            AppLocalizations.of(context)!
                .settingsResetDialogWrongJsonFormatText,
          ),
          icon: AppConstants.warningIcon,
          rightText: AppLocalizations.of(context)!.ok,
          rightOnPressed: () => Navigator.pop(context),
        );
      },
    );
  }

  // get the file form the user and show an alert dialog
  Future<void> importJsonFile() async {
    File? file = await getJsonFile();
    List<StorageDevice> importedDevices = [];

    if (file == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    String fileExt = file.path.split('.').last;

    if (fileExt != 'json') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return customDualChoiceAlertdialog(
            title: AppLocalizations.of(context)!
                .settingsResetDialogWrongFormatTitle,
            iconColor: Theme.of(context).colorScheme.error,
            child: Text(
              AppLocalizations.of(context)!
                  .settingsResetDialogWrongFormatText(fileExt),
            ),
            icon: AppConstants.warningIcon,
            rightText: AppLocalizations.of(context)!.ok,
            rightOnPressed: () => Navigator.pop(context),
          );
        },
      );
      return;
    }

    try {
      importedDevices = parseStorageDevices(await file.readAsString());
    } on FileSystemException {
      if (!mounted) return;
      showInvalidJsonDialog();

      return;
    } on FormatException {
      if (!mounted) return;
      showInvalidJsonDialog();

      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return customDualChoiceAlertdialog(
          title: AppLocalizations.of(context)!.genericWarning,
          icon: AppConstants.warningIcon,
          iconColor: Theme.of(context).colorScheme.error,
          child: Text(
            AppLocalizations.of(context)!.settingsResetDialogConfirmText,
          ),
          leftText: AppLocalizations.of(context)!.cancel,
          leftOnPressed: () => Navigator.pop(context),
          rightText: AppLocalizations.of(context)!
              .settingsResetDialogConfirmButton,
          rightOnPressed: () => {
            deviceStorage.deleteAllDevices(),
            deviceStorage.saveDevices(importedDevices),
            Navigator.pop(context),
          },
        );
      },
    );
  }
}
