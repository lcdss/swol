import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:swol/l10n/app_localizations.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:swol/constants.dart';

import '../../services/data.dart';
import '../../services/network.dart';
import '../../services/utilities.dart';
import '../../widgets/layout_elements.dart';
import '../../widgets/universal_ui_components.dart';
import 'bottom_sheet_form.dart';

class DiscoverPage extends StatefulWidget {
  final Function(List<StorageDevice>, String?) updateDevicesList;
  final List<StorageDevice> devices;

  const DiscoverPage({
    super.key,
    required this.updateDevicesList,
    required this.devices,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  @override
  void initState() {
    super.initState();
    // Scanning spawns 25 concurrent ping chains; starting it while the page
    // is still animating in drops frames on the push transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final animation = ModalRoute.of(context)?.animation;

      if (animation == null || animation.isCompleted) {
        _deviceDiscovery();
      } else {
        _routeAnimation = animation..addStatusListener(_startScanWhenSettled);
      }
    });
  }

  Animation<double>? _routeAnimation;

  void _startScanWhenSettled(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    _routeAnimation?.removeStatusListener(_startScanWhenSettled);
    _routeAnimation = null;
    _deviceDiscovery();
  }

  String? _subnet;

  /// The Wi-Fi address and submask, or null when there is no usable Wi-Fi
  /// address.
  ///
  /// `getWifiIP` returns null when Wi-Fi is off or the platform withholds the
  /// address, so this has to be allowed to fail rather than be waited on. A
  /// missing or malformed submask falls back to the /24 the scan always
  /// assumed before.
  Future<({String ip, String submask})?> _resolveNetwork() async {
    final ip = await NetworkInfo().getWifiIP();

    // A malformed quad would blow up in the subnet math downstream.
    if (ip == null || !isValidIpv4(ip)) return null;

    final submask = await NetworkInfo().getWifiSubmask();
    final usable = submask != null && maskToPrefix(submask) != null;

    return (ip: ip, submask: usable ? submask : '255.255.255.0');
  }

  // variables for discovering network devices and showing the progress in the ui
  StreamSubscription<NetworkDevice>? _subscription;
  final List<NetworkDevice> _devices = [];
  double _progress = 0.0;

  // method to discover devices on the network
  Future<void> _deviceDiscovery() async {
    setState(() {
      _devices.clear();
      _progress = 0.0;
    });

    final network = await _resolveNetwork();

    if (!mounted) return;

    setState(() {
      _subnet = network == null
          ? null
          : cidrNotation(network.ip, network.submask);
    });

    // No network means nothing to scan; the card falls back to
    // discoverCardSubnetNoNetwork and a pull-to-refresh can retry.
    if (network == null) return;

    final stream = findDevicesInNetwork(network.ip, network.submask, (
      progress,
    ) {
      if (!mounted) {
        // Exit the loop if the widget is no longer mounted.
        return;
      }

      // Probes finish in bursts of up to 25; repainting the page for each one
      // drops frames while the add-device sheet animates in. The bar cannot
      // show finer than a percent anyway.
      final samePercent = (progress * 100).floor() == (_progress * 100).floor();

      if (samePercent && progress < 1) return;

      setState(() {
        _progress = progress;
      });
    });

    _subscription = stream.listen(
      (device) {
        if (!mounted) {
          // Cancel before dropping the reference; dispose() has already run
          // by the time mounted is false, so nothing else will.
          _subscription?.cancel();
          _subscription = null;
          return;
        }
        setState(() {
          _devices.add(device);
          //_devices.sort();
          _devices.sort((NetworkDevice a, NetworkDevice b) => -a.compareTo(b));
        });
      },
      onDone: () {
        if (!mounted) return;

        setState(() {
          _subscription = null;
        });
      },
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_startScanWhenSettled);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.discoverTitle)),
      floatingActionButton: ActionButton(
        onPressed: () => showCustomBottomSheet(
          context: context,
          formPage: NetworkDeviceFormPage(
            title: AppLocalizations.of(context)!.discoverAddDeviceAlertTitle,
            device: NetworkDevice(),
            devices: widget.devices,
            onSubmitDeviceCallback: widget.updateDevicesList,
          ),
        ),
        text: AppLocalizations.of(context)!.discoverAddCustomDeviceButton,
        icon: const Icon(Icons.add),
      ),
      body: buildListview(),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildListview() {
    return RefreshIndicator(
      // on refresh call network method and update the list
      onRefresh: () async {
        // on refresh should just be called when a scan of the network is done
        if (_subscription == null) {
          await _deviceDiscovery();
        }
      },
      child: Column(
        children: [
          Visibility(
            visible: _subscription != null,
            child: LinearProgressIndicator(value: _progress),
          ),
          Expanded(
            child: ListView(
              padding: AppConstants.screenPaddingScrollView,
              children: [
                TextTitle(children: [getSubnetInfo()]),
                TextTitle(
                  title: AppLocalizations.of(context)!
                      .discoverNetworkDevicesTitle,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_devices.isNotEmpty)
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              String? title, subtitle;
                              if (_devices[index].hostName != "") {
                                title = _devices[index].hostName;
                                subtitle = _devices[index].ipAddress;
                              } else {
                                title = _devices[index].ipAddress;
                              }
                              return DeviceCard(
                                title: title,
                                subtitle: subtitle,
                                onTap: () => showCustomBottomSheet(
                                  context: context,
                                  formPage: NetworkDeviceFormPage(
                                    title: AppLocalizations.of(context)!
                                        .discoverAddDeviceAlertTitle,
                                    device: _devices[index].copyWith(
                                      wolPort: 9,
                                    ),
                                    devices: widget.devices,
                                    onSubmitDeviceCallback:
                                        widget.updateDevicesList,
                                  ),
                                ),
                              );
                            },
                          ),
                        // if (_subscription == null)
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget getSubnetInfo() {
    String subnet =
        _subnet ?? AppLocalizations.of(context)!.discoverCardSubnetNoNetwork;
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .secondaryContainer, //primaryContainer
      child: InkWell(
        borderRadius: AppConstants.borderRadius,
        child: ListTile(
          title: Text(AppLocalizations.of(context)!.discoverCardTitle),
          subtitle: Text(
            "${AppLocalizations.of(context)!.discoverCardSubnet} $subnet",
          ),
          minLeadingWidth: 0,
          leading: const SizedBox(
            height: double.infinity,
            child: Icon(Icons.wifi),
          ),
        ),
      ),
    );
  }
}
