import 'package:get/get.dart';
import 'package:stacked_services/src/bottom_sheet/bottom_sheet_service.dart';
import 'package:stacked_services/src/dialog/dialog_service.dart';
import 'package:stacked_services/src/models/overlay_request.dart';
import 'package:stacked_services/src/models/overlay_response.dart';
import 'package:stacked_services/src/snackbar/snackbar_service.dart';
import 'package:stacked_shared/stacked_introspection.dart';

const List<ActionParam> _respondParams = [
  ActionParam(name: 'confirmed', type: 'bool', required: false),
  ActionParam(name: 'data', type: 'any', required: false),
];

String? _variantName(dynamic variant) {
  if (variant == null) return null;
  if (variant is Enum) return variant.name;
  return variant.toString();
}

Map<String, Object?> _describeRequest(String type, OverlayRequest request) {
  final data = StackedJson.encode(request.data);
  // ignore: deprecated_member_use_from_same_package
  final customData = StackedJson.encode(request.customData);
  return <String, Object?>{
    'type': type,
    if (request.variant != null) 'variant': _variantName(request.variant),
    if (request.title != null) 'title': request.title,
    if (request.description != null) 'description': request.description,
    if (request.mainButtonTitle != null)
      'mainButtonTitle': request.mainButtonTitle,
    if (request.secondaryButtonTitle != null)
      'secondaryButtonTitle': request.secondaryButtonTitle,
    if (request.additionalButtonTitle != null)
      'additionalButtonTitle': request.additionalButtonTitle,
    if (data != null) 'data': data,
    if (customData != null) 'customData': customData,
  };
}

/// Lends `respond` and `dismiss` while a dialog shown through [DialogService]
/// is open.
class DialogOverlayProvider implements LentActionProvider {
  DialogOverlayProvider(this.service);

  final DialogService service;

  @override
  String get id => 'dialog';

  @override
  bool get isActive => service.openRequests.isNotEmpty;

  @override
  Map<String, Object?>? get overlay {
    final requests = service.openRequests;
    if (requests.isEmpty) return null;
    return _describeRequest('dialog', requests.last);
  }

  @override
  List<ActionSpec> get actions => [
        ActionSpec(
          name: 'respond',
          params: _respondParams,
          invoke: (i) => service.completeDialog(
            DialogResponse(
              confirmed: ActionInput.booleanOrNull(i, 'confirmed') ?? true,
              data: ActionInput.any(i, 'data'),
            ),
          ),
        ),
        ActionSpec(name: 'dismiss', invoke: (_) => Get.back()),
      ];
}

/// Lends `respond` and `dismiss` while a sheet shown through
/// [BottomSheetService] is open.
class SheetOverlayProvider implements LentActionProvider {
  SheetOverlayProvider(this.service);

  final BottomSheetService service;

  @override
  String get id => 'sheet';

  @override
  bool get isActive => service.openRequests.isNotEmpty;

  @override
  Map<String, Object?>? get overlay {
    final requests = service.openRequests;
    if (requests.isEmpty) return null;
    return _describeRequest('sheet', requests.last);
  }

  @override
  List<ActionSpec> get actions => [
        ActionSpec(
          name: 'respond',
          params: _respondParams,
          invoke: (i) => service.completeSheet(
            SheetResponse(
              confirmed: ActionInput.booleanOrNull(i, 'confirmed') ?? true,
              data: ActionInput.any(i, 'data'),
            ),
          ),
        ),
        ActionSpec(name: 'dismiss', invoke: (_) => Get.back()),
      ];
}

/// Lends `closeSnackbar` while a snackbar shown through [SnackbarService] is
/// open.
class SnackbarOverlayProvider implements LentActionProvider {
  SnackbarOverlayProvider(this.service);

  final SnackbarService service;

  @override
  String get id => 'snackbar';

  @override
  bool get isActive => service.isSnackbarOpen && service.lastSnackbar != null;

  @override
  Map<String, Object?>? get overlay {
    final last = service.lastSnackbar;
    if (last == null) return null;
    return <String, Object?>{
      'type': 'snackbar',
      if (last['title'] != null) 'title': last['title'],
      if (last['message'] != null) 'message': last['message'],
    };
  }

  @override
  List<ActionSpec> get actions => [
        ActionSpec(
          name: 'closeSnackbar',
          invoke: (_) => service.closeSnackbar(),
        ),
      ];
}
