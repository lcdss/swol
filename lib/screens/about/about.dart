import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:swol/l10n/app_localizations.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../widgets/layout_elements.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.title, required this.packageInfo});

  final PackageInfo packageInfo;
  final String title;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Uri _url = Uri.parse(AppConstants.sourceCodeLink);

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      log('Could not launch $url');
    }
  }

  String? _wifiAddress;

  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  Map<String, dynamic> _deviceData = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    initWifiAddress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // not in initSate because buildContext is needed
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    var deviceData = <String, dynamic>{};
    final localizations = AppLocalizations.of(context);

    if (localizations == null) return;

    try {
      if (kIsWeb) {
        deviceData = <String, dynamic>{
          'Error:': localizations.aboutWebPlatformError,
        };
      } else {
        deviceData = switch (defaultTargetPlatform) {
          TargetPlatform.android => _readAndroidBuildData(
            await deviceInfoPlugin.androidInfo,
          ),
          TargetPlatform.fuchsia => {
            'Error:': localizations.aboutFuchsiaPlatformError,
          },
          TargetPlatform.linux => {
            'Error:': localizations.aboutLinuxPlatformError,
          },
          TargetPlatform.macOS => {
            'Error:': localizations.aboutMacOSPlatformError,
          },
          TargetPlatform.windows => {
            'Error:': localizations.aboutWindowsPlatformError,
          },
          // Android is the only target that ships. The wildcard also means a
          // TargetPlatform added by a future SDK degrades to a message here
          // instead of failing to compile.
          _ => {'Error:': localizations.aboutNoPlatformDetected},
        };
      }
    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': localizations.aboutNoPlatformDetected,
      };
    }

    if (!mounted) return;

    setState(() {
      _deviceData = deviceData;
    });
  }

  Future<void> initWifiAddress() async {
    String? wifiAddress = await NetworkInfo().getWifiIP();

    if (!mounted) return;

    setState(() {
      _wifiAddress = wifiAddress;
    });
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{'model': build.model};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: [
          TextTitle(
            title: AppLocalizations.of(context)!.aboutInfoTitle,
            children: [
              TextBox(text: AppLocalizations.of(context)!.aboutInfoText),
            ],
          ),
          TextTitle(
            title: AppLocalizations.of(context)!.aboutDevice,
            children: [getDeviceInfoCard()],
          ),
          TextTitle(
            title: AppLocalizations.of(context)!.aboutOpenSourceTitle,
            children: [
              SpacedRow(
                children: [
                  IconTextButton(
                    text: AppLocalizations.of(context)!
                        .aboutOpenSourceCodeButton,
                    icon: AppConstants.sourceCodeIcon,
                    onPressed: () async {
                      await _launchUrl(_url);
                    },
                  ),
                  IconTextButton(
                    text: AppLocalizations.of(context)!
                        .aboutOpenSourceLicenseButton,
                    icon: AppConstants.licenseIcon,
                    onPressed: () => {showLicensePage(context: context)},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              VersionText(text: widget.packageInfo.appName),
              VersionText(text: widget.packageInfo.packageName),
              VersionText(
                text: AppLocalizations.of(context)!.aboutVersionText(
                  widget.packageInfo.version,
                  widget.packageInfo.buildNumber,
                ),
              ),
            ],
          ),
        ],
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  /// return card with device info
  Widget getDeviceInfoCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .secondaryContainer, //primaryContainer
      child: InkWell(
        borderRadius: AppConstants.borderRadius,
        child: ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _deviceData.keys.map((String property) {
              return Text(_deviceData[property].toString());
            }).toList(),
          ),
          subtitle: Text(
            "${AppConstants.ipText}: $_wifiAddress",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          minLeadingWidth: 0,
          leading: const SizedBox(
            height: double.infinity,
            child: Icon(Icons.phone_iphone),
          ),
        ),
      ),
    );
  }
}

/// return text with Version styling
class VersionText extends StatelessWidget {
  const VersionText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.grey));
  }
}
