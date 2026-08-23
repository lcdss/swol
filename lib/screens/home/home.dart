import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:swol/l10n/app_localizations.dart';

import 'package:swol/constants.dart';
import 'package:swol/screens/home/discover.dart';

import '../../services/data.dart';
import '../../services/database.dart';
import '../../services/network.dart';
import '../../widgets/chip_cards.dart';
import '../../widgets/layout_elements.dart';
import '../../widgets/universal_ui_components.dart';
import 'bottom_sheet_form.dart';

// This is the type used by the popup menu below.
enum SortingOrder { alphabetical, recently, type }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    required this.onSelectedMenuChange,
    required this.selectedMenu,
    required this.onSelectedDeviceTypesChange,
    required this.deviceTypesValues,
  });

  final String title;

  final ValueChanged<SortingOrder> onSelectedMenuChange;
  final SortingOrder selectedMenu;

  final ValueChanged<List<bool>> onSelectedDeviceTypesChange;
  final List<bool> deviceTypesValues;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _deviceStorage = DeviceStorage();
  List<StorageDevice> _devicesRaw = [];
  List<StorageDevice> _devices = [];
  bool _isLoading = false;

  Timer? _pingDevicesTimer;

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!listEquals(oldWidget.deviceTypesValues, widget.deviceTypesValues)) {
      filterDevicesByType();
    }
    if (oldWidget.selectedMenu != widget.selectedMenu) {
      sortDevices();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDevices().then(
      (value) => {filterDevicesByType(), sortDevices(), _pingDevices()},
    );
  }

  @override
  void dispose() {
    _pingDevicesTimer?.cancel();
    super.dispose();
  }

  /// loads a list of devices from the device storage
  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devices = await _deviceStorage.loadDevices();
      setState(() {
        _devicesRaw = devices;
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to load devices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// sort Devices by chipsDeviceTypes selection
  void filterDevicesByType() {
    List<StorageDevice> sortedDevices = [];
    for (StorageDevice device in _devicesRaw) {
      if (device.deviceType == null) {
        sortedDevices.add(device);
      } else {
        final types = AppConstants.deviceTypeIcons.keys.toList();
        for (int i = 0; i < types.length; i++) {
          if (widget.deviceTypesValues[i] && device.deviceType == types[i]) {
            sortedDevices.add(device);
            break;
          }
        }
      }
    }
    setState(() {
      _devices = sortedDevices;
    });
  }

  /// sort devices by selectedMenu value. [alphabetical], [recently] and [type] are possible.
  void sortDevices() {
    final Comparator<StorageDevice> comparator = switch (widget.selectedMenu) {
      SortingOrder.alphabetical => (a, b) => a.hostName.toLowerCase().compareTo(
        b.hostName.toLowerCase(),
      ),
      SortingOrder.recently => (a, b) => b.modified.compareTo(a.modified),
      SortingOrder.type => (a, b) => (a.deviceType ?? '').compareTo(
        b.deviceType ?? '',
      ),
    };

    setState(() => _devices.sort(comparator));
  }

  /// ping devices periodically in the background to get the current status
  /// of the devices and update the ui accordingly
  void _pingDevices() {
    checkAllDevicesStatus();
    _pingDevicesTimer = Timer.periodic(
      const Duration(seconds: AppConstants.homePingInterval),
      (timer) {
        checkAllDevicesStatus();
      },
    );
  }

  /// updates the status of all devices, including ones the type filter is
  /// currently hiding -- otherwise those reappear with a stale status
  Future<void> checkAllDevicesStatus() async {
    for (StorageDevice device in _devicesRaw) {
      checkDeviceStatus(device);
    }
  }

  /// ping a device and update the ui accordingly
  /// [device] is the device to ping
  /// if the widget is not mounted anymore, the function will stop
  Future<void> checkDeviceStatus(StorageDevice device) async {
    bool isOnline = await pingDevice(ipAddress: device.ipAddress);
    if (mounted) {
      setState(() {
        device.isOnline = isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: PopupMenuButton<SortingOrder>(
          icon: AppConstants.sort,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
          ),
          // The menu should appear below the button. The offset is dependent of the selected menu item so the offset is calculated dependent of
          // the current selected menu item.
          offset: Offset(0, 00 + 50.0 * (widget.selectedMenu.index + 1)),
          initialValue: widget.selectedMenu,
          // Callback that sets the selected popup menu item.
          // The parent owns the value, so the resulting didUpdateWidget sorts.
          onSelected: widget.onSelectedMenuChange,
          itemBuilder: (BuildContext context) => <PopupMenuEntry<SortingOrder>>[
            PopupMenuItem<SortingOrder>(
              value: SortingOrder.alphabetical,
              child: Text(AppLocalizations.of(context)!.homeSortAlphabetical),
            ),
            PopupMenuItem<SortingOrder>(
              value: SortingOrder.recently,
              child: Text(AppLocalizations.of(context)!.homeSortRecent),
            ),
            PopupMenuItem<SortingOrder>(
              value: SortingOrder.type,
              child: Text(AppLocalizations.of(context)!.homeSortType),
            ),
          ],
        ),
      ),
      floatingActionButton: ActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiscoverPage(
              updateDevicesList: updateDevicesList,
              devices: _devices,
            ),
          ),
        ),
        text: AppLocalizations.of(context)!.homeAddDeviceButton,
        icon: AppConstants.add,
      ),
      body: buildListview(),
    );
  }

  /// callback function for updating the list of devices
  /// [devices] is the list of devices
  /// [deviceId] is the changed device id. This devices gets pinged additionally to the background timer to get the current status.
  /// If it is set to null, no device gets pinged (e.g. if device gets deleted, this devices doesn't need to get pinged)
  void updateDevicesList(List<StorageDevice> devices, String? deviceId) {
    setState(() {
      _devicesRaw = devices;
      filterDevicesByType();
      sortDevices();
      if (deviceId != null) {
        StorageDevice device = devices.firstWhere(
          (element) => element.id == deviceId,
        );
        // set online state to null because online state is not known yet
        device.isOnline = null;
        checkDeviceStatus(device);
      }
    });
  }

  Widget buildListview() {
    return RefreshIndicator(
      onRefresh: () async {
        _pingDevicesTimer?.cancel();
        // set online state for all devices to null because online state is not known yet
        for (StorageDevice device in _devicesRaw) {
          device.isOnline = null;
        }
        _pingDevices();
      },
      child: ListView(
        padding: AppConstants.screenPaddingScrollView,
        children: [
          TextTitle(
            title: AppLocalizations.of(context)!.homeFilterDevicesTitle,
            children: [SizedBox(height: 50, child: filterDevicesChipsV2())],
          ),
          TextTitle(
            title: AppLocalizations.of(context)!.homeDeviceListTitle,
            children: [buildDeviceList()],
          ),
        ],
      ),
    );
  }

  /// returns a List of Chips for filtering devices
  ListView filterDevicesChipsV2() {
    List<CustomChoiceChip<String>> chipsDeviceTypes =
        AppConstants.getChipsDeviceTypes(context: context);
    return ListView(
      primary: true,
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      children: [
        Wrap(
          spacing: 5.0,
          children: List<Widget>.generate(chipsDeviceTypes.length, (index) {
            String? label = chipsDeviceTypes[index].label;
            IconData? icon = chipsDeviceTypes[index].icon;
            return ActionChip(
              avatar: Icon(icon),
              label: Row(children: [if (label != null) Text(label)]),
              backgroundColor: widget.deviceTypesValues[index]
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: widget.deviceTypesValues[index]
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.secondary,
                width: 1.0,
              ),
              onPressed: () {
                // Toggling in place would mutate the parent's own list behind
                // its back, so hand it a new one and let it rebuild us.
                final toggled = [...widget.deviceTypesValues];
                toggled[index] = !toggled[index];
                widget.onSelectedDeviceTypesChange(toggled);
              },
            );
          }),
        ),
      ],
    );
  }

  /// returns the list of devices
  Widget buildDeviceList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _devices.isEmpty
        ? Text(
            AppLocalizations.of(context)!.homeNoDevices,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return buildDevice(device);
            },
          );
  }

  /// returns a single device card
  Widget buildDevice(StorageDevice device) {
    String title;
    String? subtitle;
    if (device.hostName != "") {
      title = device.hostName;
      subtitle = device.ipAddress;
    } else {
      title = device.ipAddress;
    }
    return DeviceCard(
      isOnline: device.isOnline,
      title: title,
      subtitle: subtitle,
      deviceType: device.deviceType,
      onTap: () {
        showDeviceOptionsDialog(device: device);
      },
    );
  }

  /// shows the alert dialog for waking and editing the device
  void showDeviceOptionsDialog({required StorageDevice device}) {
    String title = "", subtitle1 = "", subtitle2 = "";
    if (device.hostName != "") {
      title = device.hostName;
      subtitle1 = "${AppConstants.ipText}: ${device.ipAddress}";
      subtitle2 = "${AppConstants.macText}: ${device.macAddress}";
    } else if (device.macAddress != "") {
      title = device.ipAddress;
      subtitle1 = "${AppConstants.macText}: ${device.macAddress}";
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return deviceInfoDialog(
          device: device,
          title: title,
          subtitle1: subtitle1,
          subtitle2: subtitle2,
        );
      },
    );
  }

  /// returns the actual alert dialog for waking and editing the device
  Widget deviceInfoDialog({
    required StorageDevice device,
    required String title,
    required String subtitle1,
    required String subtitle2,
  }) {
    return customDualChoiceAlertdialog(
      title: title != "" ? title : null,
      child: (subtitle1 != "" || subtitle2 != "" || device.isOnline != null)
          ? Column(
              children: [
                if (device.isOnline != null)
                  Text(
                    device.isOnline!
                        ? AppLocalizations.of(context)!.homeDeviceCardOnline
                        : AppLocalizations.of(context)!.homeDeviceCardOffline,
                    style: TextStyle(
                      color: device.isOnline!
                          ? AppConstants.successMessageColor
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (subtitle1 != "") Text(subtitle1),
                if (subtitle2 != "") Text(subtitle2),
              ],
            )
          : null,
      icon: getIcon(device.deviceType),
      iconColor: device.isOnline != null
          ? device.isOnline!
                ? AppConstants.successMessageColor
                : Theme.of(context).colorScheme.error
          : null,
      leftText: AppLocalizations.of(context)!.homeDeviceCardWakeButton,
      rightText: AppLocalizations.of(context)!.homeDeviceCardEditButton,
      leftIcon: AppConstants.wakeUp,
      rightIcon: AppConstants.edit,
      leftOnPressed: () => {Navigator.pop(context), showWakeUpDialog(device)},
      rightOnPressed: () => {
        Navigator.of(context).pop(),
        showCustomBottomSheet(
          context: context,
          formPage: EditDeviceFormPage(
            title: AppLocalizations.of(context)!.homeEditDeviceAlertTitle,
            device: device,
            devices: _devices,
            onSubmitDeviceCallback: updateDevicesList,
          ),
        ),
      },
    );
  }

  /// shows the Alert Dialog for waking the device.
  /// [device] is the device to wake.
  Future<dynamic> showWakeUpDialog(StorageDevice device) {
    // Created once, outside the builder: dialog rebuilds (rotation, theme or
    // inset changes) would otherwise create a new stream each time --
    // resending the magic packets and restarting the ping loop.
    final messages = sendWolAndGetMessages(device: device.toNetworkDevice());

    return showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<Message>>(
          stream: messages,
          builder:
              (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
                final l10n = AppLocalizations.of(context)!;
                final errorColor = Theme.of(context).colorScheme.error;

                // set color, text and icon of dialog box according to the arrived messages
                Color? color;
                String rightText = l10n.cancel;
                IconData? rightIcon = AppConstants.denyIcon;
                if (snapshot.hasData &&
                    snapshot.data!.last.type == MsgType.online) {
                  color = AppConstants.successMessageColor;
                  rightText = l10n.done;
                  rightIcon = AppConstants.checkIcon;
                }

                if (snapshot.hasError ||
                    (snapshot.hasData &&
                        snapshot.data!.last.type == MsgType.error)) {
                  color = errorColor;
                  rightText = l10n.ok;
                  rightIcon = null;
                }

                final Widget body;
                if (snapshot.hasError) {
                  body = Text(
                    l10n.homeWolCardUnexpectedError,
                    style: TextStyle(color: errorColor),
                  );
                } else if (snapshot.hasData) {
                  body = SizedBox(
                    width: 200,
                    child: ListView.separated(
                      separatorBuilder: (context, index) => const Divider(),
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final Message message = snapshot.data![index];
                        return Text(
                          messageText(l10n, message),
                          style: TextStyle(
                            color: (message.type == MsgType.error)
                                ? errorColor
                                : (message.type == MsgType.check ||
                                      message.type == MsgType.online)
                                ? AppConstants.successMessageColor
                                : null,
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  body = const Center(child: CircularProgressIndicator());
                }

                return customDualChoiceAlertdialog(
                  title: l10n.homeWolCardTitle,
                  child: body,
                  icon: AppConstants.wakeUp,
                  iconColor: color,
                  rightText: rightText,
                  rightIcon: rightIcon,
                  rightOnPressed: () => {Navigator.of(context).pop()},
                );
              },
        );
      },
    );
  }
}

/// Renders a wake-sequence [Message] for display.
String messageText(AppLocalizations l10n, Message message) => switch (message) {
  WolHostUnresolved(:final host) => l10n.homeWolCardHost(host),
  WolInvalidIp(:final ip) => l10n.homeWolCardIp(ip),
  WolInvalidMac(:final mac) => l10n.homeWolCardMac(mac),
  WolInvalidPort(:final port) => l10n.homeWolCardPort(port),
  WolInvalid() => l10n.homeWolCardInvalid,
  WolValid() => l10n.homeWolCardValid,
  WolSending() => l10n.homeWolCardSendWol,
  WolSent(:final ip) => l10n.homeWolCardSendWolSuccess(ip),
  WolSendFailed(:final ip) => l10n.homeWolCardSendWolFail(ip),
  PingStarted() => l10n.homeWolCardPingInfo,
  PingAttempt(:final attempt) => l10n.homeWolCardPing(attempt),
  PingSucceeded() => l10n.homeWolCardPingSuccess,
  PingFailed() => l10n.homeWolCardPingFail,
};
