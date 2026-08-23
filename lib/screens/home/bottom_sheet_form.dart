import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:swol/l10n/app_localizations.dart';
import 'package:rich_text_controller/rich_text_controller.dart';

import 'package:swol/constants.dart';
import 'package:swol/screens/home/discover.dart';
import 'package:swol/screens/home/home.dart';
import 'package:swol/services/data.dart';
import 'package:swol/widgets/layout_elements.dart';

import '../../services/database.dart';
import '../../services/form_input_formatters.dart';
import '../../widgets/chip_cards.dart';
import '../../widgets/universal_ui_components.dart';

abstract class ModularBottomFormPage extends StatefulWidget {
  final String title;
  final Device device;
  final List<StorageDevice> devices;
  final Function(List<StorageDevice>, String?) onSubmitDeviceCallback;
  final bool deleteButton;

  const ModularBottomFormPage({
    super.key,
    required this.device,
    required this.devices,
    required this.title,
    required this.onSubmitDeviceCallback,
    this.deleteButton = false,
  });

  /// Persists [edited] -- the device as the form currently describes it -- and
  /// returns the new device list along with the saved device.
  Future<(List<StorageDevice>, StorageDevice)> dataOperationOnSave(
    Device edited,
  );

  /// Removes [edited] from storage and returns the new device list.
  Future<List<StorageDevice>> dataOperationOnDelete(Device edited) =>
      const DeviceStorage().deleteDevice((edited as StorageDevice).id, devices);

  @override
  State<ModularBottomFormPage> createState() => _ModularBottomFormPageState();
}

class _ModularBottomFormPageState extends State<ModularBottomFormPage> {
  // set label of chipsWolPorts to the translated string
  late List<CustomChoiceChip<int>> chipsWolPorts =
      AppConstants.getChipsWolPorts(context: context);

  final _controllerName = TextEditingController();
  final _controllerPort = TextEditingController();
  final _controllerIcon = TextEditingController();

  // Rich Text Controllers needed, so delimiter symbols are colored differently
  late final RichTextController _controllerIp;
  late final RichTextController _controllerMac;

  // One Form for the whole sheet: fields (the icon selector included) manage
  // their own error display through it instead of ad-hoc state.
  final _formKey = GlobalKey<FormState>();

  // variables for the chip selectors and initial port value
  int? indexWolSelector;
  int? indexIconSelector;

  bool get _portTextInvalid {
    final text = _controllerPort.text;

    return text.isNotEmpty &&
        !RegExp(AppConstants.portValidationRegex).hasMatch(text);
  }

  /// The device as the form currently describes it.
  Device get _editedDevice {
    // tryParse: "save with errors" lets junk through, and a throw here would
    // be silently lost after the sheet has already been popped.
    final wolPort = int.tryParse(_controllerPort.text);
    final deviceType = _controllerIcon.text.isEmpty
        ? null
        : _controllerIcon.text;

    return switch (widget.device) {
      StorageDevice(:final id, :final isOnline) => StorageDevice(
        id: id,
        hostName: _controllerName.text,
        ipAddress: _controllerIp.text,
        macAddress: _controllerMac.text,
        modified: DateTime.now(),
        wolPort: wolPort,
        isOnline: isOnline,
        deviceType: deviceType,
      ),
      NetworkDevice() => NetworkDevice(
        hostName: _controllerName.text,
        ipAddress: _controllerIp.text,
        macAddress: _controllerMac.text,
        wolPort: wolPort,
        deviceType: deviceType,
      ),
    };
  }

  @override
  void initState() {
    super.initState();

    _controllerIp = RichTextController(
      onMatch: (List<String> match) {},
      targetMatches: [
        MatchTargetItem(
          regex: AppConstants.ipPattern,
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          allowInlineMatching: true,
        ),
      ],
    );

    _controllerMac = RichTextController(
      onMatch: (List<String> match) {},
      targetMatches: [
        MatchTargetItem(
          regex: AppConstants.macPattern,
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          allowInlineMatching: true,
        ),
      ],
    );

    // initialize the text controllers
    _controllerName.text = widget.device.hostName;
    _controllerIp.text = widget.device.ipAddress;
    _controllerMac.text = widget.device.macAddress;

    // Labels need a BuildContext to localize, so match on value only here.
    final wolPorts = AppConstants.getChipsWolPorts();
    final wolElement = wolPorts.where(
      (element) => element.value == widget.device.wolPort,
    );
    if (wolElement.isNotEmpty) {
      indexWolSelector = wolPorts.indexOf(wolElement.first);
    }
    if (widget.device.wolPort != null) {
      _controllerPort.text = widget.device.wolPort.toString();
    }

    // initialize the icon selector
    final deviceTypes = AppConstants.getChipsDeviceTypes();
    final deviceType = deviceTypes.where(
      (element) => element.value == widget.device.deviceType,
    );
    if (deviceType.isNotEmpty) {
      indexIconSelector = deviceTypes.indexOf(deviceType.first);
    }
    if (widget.device.deviceType != null) {
      _controllerIcon.text = widget.device.deviceType.toString();
    }
  }

  @override
  void dispose() {
    _controllerName.dispose();
    _controllerPort.dispose();
    _controllerIcon.dispose();
    _controllerIp.dispose();
    _controllerMac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    // GestureDetector is required to close the keyboard when the user taps outside of the text input fields
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          15,
          20,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            primary: true,
            shrinkWrap: true,
            children: [
              dragIndicator(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  buildSaveButton(context),
                ],
              ),
              getCustomTextFormField(
                label: AppLocalizations.of(context)!.formNameHint,
                controller: _controllerName,
                validator: createValidator(
                  AppConstants.nameValidationRegex,
                  AppLocalizations.of(context)!.formNameError,
                ),
              ),
              getCustomTextFormField(
                label: AppLocalizations.of(context)!.formIpHint,
                controller: _controllerIp,
                validator: createValidator(
                  AppConstants.ipValidationRegex,
                  AppLocalizations.of(context)!.formIpError,
                ),
                inputFormatters: [IPAddressFormatter()],
              ),
              getCustomTextFormField(
                label: AppLocalizations.of(context)!.formMacHint,
                controller: _controllerMac,
                validator: createValidator(
                  AppConstants.macValidationRegex,
                  AppLocalizations.of(context)!.formMacError,
                ),
                inputFormatters: [MACAddressFormatter()],
              ),
              const SizedBox(height: 20),
              buildPortSelector(textTheme),
              buildIconSelector(textTheme),
              if (widget.deleteButton) buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// return a button for saving the user input on the form to the device storage
  Padding buildSaveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Transform.translate(
        offset: const Offset(0, 0),
        child: ActionButton(
          onPressed: () => {
            validateFormFields(
              onSubmitDeviceCallback: () async {
                Navigator.popUntil(context, (route) => route.isFirst);
                (List<StorageDevice>, StorageDevice) updatedDevices =
                    await widget.dataOperationOnSave(_editedDevice);
                // sent device to callback function in order to update the UI
                widget.onSubmitDeviceCallback(
                  updatedDevices.$1,
                  updatedDevices.$2.id,
                );
              },
            ),
          },
          text: AppLocalizations.of(context)!.formApplyButtonText,
          icon: const Icon(AppConstants.formIcon),
        ),
      ),
    );
  }

  /// validates the user input on the form and calls the [onSubmitDeviceCallback] if the input is valid
  /// otherwise it shows an error dialog which lists the invalid fields
  /// the user has the option to save the device anyway and the [onSubmitDeviceCallback] is called again or to cancel the operation
  /// [onSubmitDeviceCallback] the callback function that is called when the user decides to save the device
  void validateFormFields({Function()? onSubmitDeviceCallback}) {
    final l10n = AppLocalizations.of(context)!;

    // Paints every field's own error text in one pass.
    _formKey.currentState!.validate();

    bool matches(String regEx, TextEditingController controller) =>
        RegExp(regEx).hasMatch(controller.text);

    final errorMessage = [
      if (!matches(AppConstants.nameValidationRegex, _controllerName))
        l10n.formErrorMessageName,
      if (!matches(AppConstants.ipValidationRegex, _controllerIp))
        l10n.formErrorMessageIp,
      if (!matches(AppConstants.macValidationRegex, _controllerMac))
        l10n.formErrorMessageMac,
      if (!matches(AppConstants.portValidationRegex, _controllerPort))
        l10n.formErrorMessagePort,
      if (indexIconSelector == null) l10n.formErrorMessageType,
    ];

    if (errorMessage.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return customDualChoiceAlertdialog(
            title: AppLocalizations.of(context)!.formIconErrorTitle,
            icon: AppConstants.formWrongFormatIcon,
            iconColor: Theme.of(context).colorScheme.error,
            child: Column(
              children: errorMessage
                  .map(
                    (error) => Row(
                      children: [
                        Icon(
                          AppConstants.formInvalidArgument,
                          size: 15,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 5),
                        Text(error),
                      ],
                    ),
                  )
                  .toList(),
            ),
            leftText: AppLocalizations.of(context)!.back,
            leftOnPressed: () {
              Navigator.of(context).pop();
            },
            rightText: AppLocalizations.of(context)!.saveWithError,
            rightColor: Theme.of(context).colorScheme.error,
            rightOnPressed: onSubmitDeviceCallback,
          );
        },
      );
    } else if (onSubmitDeviceCallback != null) {
      onSubmitDeviceCallback();
    }
  }

  /// Pill shaped container which tries to indicate that the bottom sheet can be dragged
  Center dragIndicator() {
    return Center(
      child: Container(
        height: 5.0,
        width: 40.0,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    );
  }

  /// returns a custom text form field
  /// * [label] the label of the text form field
  /// * [controller] the TextEditingController of the text form field
  /// * [validator] a validator function which can be created with [createValidator]
  /// * [onChanged] called with the new text on every edit
  Widget getCustomTextFormField({
    String? label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: TextFormField(
        inputFormatters: inputFormatters,
        // Not `always`: that painted every field red the moment the form
        // opened, before the user had touched anything.
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        controller: controller,
        onChanged: onChanged,
        cursorColor: Theme.of(context).colorScheme.primaryContainer,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          errorStyle: const TextStyle(height: 0.1),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
        ),
      ),
    );
  }

  /// returns a custom selector and text input field for the port
  /// * [textTheme] the text theme of the current context
  Row buildPortSelector(TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.formPortLabel,
              style: textTheme.labelLarge,
            ),
            SizedBox(
              height: 45,
              child: Wrap(
                spacing: 5.0,
                children: List<Widget>.generate(chipsWolPorts.length, (index) {
                  String? label = chipsWolPorts[index].label;
                  IconData? icon = chipsWolPorts[index].icon;
                  return ChoiceChip(
                    label: IntrinsicWidth(
                      child: Row(
                        children: [
                          if (label != null) Text(label),
                          if (icon != null) const SizedBox(width: 10.0),
                          if (icon != null) Icon(icon),
                        ],
                      ),
                    ),
                    // Checked directly: calling validate() during build
                    // force-displayed the field errors the form opens with.
                    side: _portTextInvalid
                        ? BorderSide(color: Theme.of(context).colorScheme.error)
                        : null,
                    selected: indexWolSelector == index,
                    onSelected: (bool selected) {
                      setState(() {
                        indexWolSelector = selected ? index : null;
                        (selected)
                            ? _controllerPort.text = chipsWolPorts[index].value
                                  .toString()
                            : _controllerPort.text = '';
                      });
                    },
                  );
                }),
              ),
            ),
          ],
        ),
        SizedBox(
          width: 90,
          child: getCustomTextFormField(
            label: AppLocalizations.of(context)!.formPortHint,
            controller: _controllerPort,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: createValidator(
              AppConstants.portValidationRegex,
              AppLocalizations.of(context)!.formPortError,
            ),
            // Keep the chips in step with what is typed. The old version
            // hung off onSaved, which nothing ever called.
            onChanged: (String value) {
              final match = chipsWolPorts.indexWhere(
                (chip) => chip.value.toString() == value,
              );
              setState(() {
                indexWolSelector = match == -1 ? null : match;
              });
            },
          ),
        ),
      ],
    );
  }

  /// returns a custom selector for the icon of the device
  /// * [textTheme] the text theme of the current context
  /// A real [FormField], so error display follows the same
  /// validate-on-interaction rules as every text field instead of being
  /// faked from raw state (which painted the error before any interaction).
  Widget buildIconSelector(TextTheme textTheme) {
    List<CustomChoiceChip<String>> chipsDeviceTypes =
        AppConstants.getChipsDeviceTypes(context: context);
    return FormField<int>(
      initialValue: indexIconSelector,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (index) =>
          index == null ? AppLocalizations.of(context)!.formIconError : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            AppLocalizations.of(context)!.formIconLabel,
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: 3.0),
          SizedBox(
            height: 45,
            child: ListView(
              primary: true,
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: [
                Wrap(
                  spacing: 5.0,
                  runSpacing: 0.0,
                  children: List<Widget>.generate(chipsDeviceTypes.length, (
                    index,
                  ) {
                    String? label = chipsDeviceTypes[index].label;
                    IconData? icon = chipsDeviceTypes[index].icon;
                    return ChoiceChip(
                      label: IntrinsicWidth(
                        child: Row(
                          children: [
                            if (label != null) Text(label),
                            if (icon != null) const SizedBox(width: 10.0),
                            if (icon != null) Icon(icon),
                          ],
                        ),
                      ),
                      side: field.hasError
                          ? BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                      selected: field.value == index,
                      onSelected: (bool selected) {
                        setState(() {
                          indexIconSelector = selected ? index : null;
                          if (selected) {
                            _controllerIcon.text = chipsDeviceTypes[index].value
                                .toString();
                          } else {
                            _controllerIcon.text = '';
                          }
                        });
                        field.didChange(selected ? index : null);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  /// return a button to delete the device
  /// * [textTheme] the text theme of the current context
  Widget buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        onPressed: () {
          showDeleteDialog();
        },
        child: Text(
          AppLocalizations.of(context)!.formDeleteAlertTitle,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return customDualChoiceAlertdialog(
          title: AppLocalizations.of(context)!.formDeleteAlertTitle,
          icon: Icons.delete_outlined,
          iconColor: Theme.of(context).colorScheme.error,
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: AppLocalizations.of(context)!.formDeleteAlertText,
                ),
                if (_controllerName.text.isNotEmpty)
                  TextSpan(
                    text: _controllerName.text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          leftText: AppLocalizations.of(context)!.cancel,
          leftOnPressed: () {
            Navigator.of(context).pop();
          },
          rightText: AppLocalizations.of(context)!.formDeleteAlertDelete,
          rightColor: Theme.of(context).colorScheme.error,
          rightOnPressed: () async {
            Navigator.popUntil(context, (route) => route.isFirst);
            List<StorageDevice> devices = await widget.dataOperationOnDelete(
              _editedDevice,
            );
            // sent device to callback function in order to update the UI
            widget.onSubmitDeviceCallback(devices, null);
          },
        );
      },
    );
  }
}

/// An implementation of the [ModularBottomFormPage] for adding a new [NetworkDevice] from the [DiscoverPage]
class NetworkDeviceFormPage extends ModularBottomFormPage {
  const NetworkDeviceFormPage({
    super.key,
    required super.device,
    required super.devices,
    required super.title,
    required super.onSubmitDeviceCallback,
  });

  @override
  Future<(List<StorageDevice>, StorageDevice)> dataOperationOnSave(
    Device edited,
  ) => const DeviceStorage().addDevice(edited as NetworkDevice, devices);
}

/// An implementation of the [ModularBottomFormPage] for editing an already existing [StorageDevice] from the [HomePage]
class EditDeviceFormPage extends ModularBottomFormPage {
  const EditDeviceFormPage({
    super.key,
    required super.device,
    required super.title,
    required super.devices,
    required super.onSubmitDeviceCallback,
  }) : super(deleteButton: true);

  @override
  Future<(List<StorageDevice>, StorageDevice)> dataOperationOnSave(
    Device edited,
  ) => const DeviceStorage().updateDevice(edited as StorageDevice, devices);
}

/// return a validator function which can be passed to a [TextFormField] in order to validate the Input.
/// [regEx] is the RegEx to be evaluated, [msg] ist the error message being shown, if the input doesn't satisfy the RegEx
String? Function(String?) createValidator(String regEx, String msg) =>
    (String? value) => !RegExp(regEx).hasMatch(value ?? '') ? msg : null;
