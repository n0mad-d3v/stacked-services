import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:stacked_shared/stacked_introspection.dart';

enum _D { info }

enum _S { info }

Widget _app() => MaterialApp(
      navigatorKey: StackedService.navigatorKey,
      navigatorObservers: [StackedService.routeObserver],
      home: const Scaffold(body: SizedBox()),
    );

LentActionProvider? _active(String id) {
  for (final p in LentActionProviders.active) {
    if (p.id == id) return p;
  }
  return null;
}

Iterable<String> _activeIds() => LentActionProviders.active.map((p) => p.id);

ActionSpec _action(LentActionProvider provider, String name) =>
    provider.actions.firstWhere((a) => a.name == name);

Future<void> _invoke(
  LentActionProvider provider,
  String name, [
  Object? rawInput,
]) async {
  final spec = _action(provider, name);
  await spec.invoke!(ActionInput.normalize(rawInput, spec.params));
}

void main() {
  late DialogService dialogService;
  late BottomSheetService bottomSheetService;
  late SnackbarService snackbarService;

  setUp(() {
    LentActionProviders.reset();
    dialogService = DialogService();
    bottomSheetService = BottomSheetService();
    snackbarService = SnackbarService();
    dialogService.registerCustomDialogBuilders({
      _D.info: (context, request, completer) => Text(request.title!),
    });
    bottomSheetService.setCustomSheetBuilders({
      _S.info: (context, request, completer) => Text(request.title!),
    });
  });

  tearDown(LentActionProviders.reset);

  group('DialogOverlayProvider -', () {
    testWidgets('custom dialog is described and respond completes it',
        (tester) async {
      await tester.pumpWidget(_app());

      final f = dialogService.showCustomDialog(
        variant: _D.info,
        title: 'Hello',
        description: 'World',
      );
      await tester.pumpAndSettle();

      expect(_activeIds(), contains('dialog'));
      final provider = _active('dialog')!;
      expect(provider.overlay, {
        'type': 'dialog',
        'variant': 'info',
        'title': 'Hello',
        'description': 'World',
      });
      expect(provider.actions.map((a) => a.name), ['respond', 'dismiss']);

      await _invoke(provider, 'respond', {'confirmed': true});
      await tester.pumpAndSettle();

      expect((await f)!.confirmed, true);
      expect(_activeIds(), isNot(contains('dialog')));
      expect(dialogService.openRequests, isEmpty);
    });

    testWidgets('respond with no input means confirmed: true', (tester) async {
      await tester.pumpWidget(_app());

      final f = dialogService.showCustomDialog(variant: _D.info, title: 'Hi');
      await tester.pumpAndSettle();

      await _invoke(_active('dialog')!, 'respond');
      await tester.pumpAndSettle();

      expect((await f)!.confirmed, true);
    });

    testWidgets('respond passes data through', (tester) async {
      await tester.pumpWidget(_app());

      final f = dialogService.showCustomDialog(variant: _D.info, title: 'Hi');
      await tester.pumpAndSettle();

      await _invoke(
        _active('dialog')!,
        'respond',
        {'confirmed': false, 'data': 'abc'},
      );
      await tester.pumpAndSettle();

      final response = (await f)!;
      expect(response.confirmed, false);
      expect(response.data, 'abc');
    });

    testWidgets('dismiss closes the dialog with a null result', (tester) async {
      await tester.pumpWidget(_app());

      final f = dialogService.showCustomDialog(
        variant: _D.info,
        title: 'Hello',
      );
      await tester.pumpAndSettle();
      expect(_activeIds(), contains('dialog'));

      await _invoke(_active('dialog')!, 'dismiss');
      await tester.pumpAndSettle();

      expect(await f, isNull);
      expect(_activeIds(), isNot(contains('dialog')));
    });

    testWidgets('platform dialog is described and respond completes it',
        (tester) async {
      await tester.pumpWidget(_app());

      final f = dialogService.showDialog(title: 'T', description: 'D');
      await tester.pumpAndSettle();

      final provider = _active('dialog')!;
      expect(provider.overlay!['type'], 'dialog');
      expect(provider.overlay!['title'], 'T');
      expect(provider.overlay!['description'], 'D');
      expect(provider.overlay!['mainButtonTitle'], 'Ok');

      await _invoke(provider, 'respond');
      await tester.pumpAndSettle();

      expect((await f)!.confirmed, true);
      expect(_activeIds(), isNot(contains('dialog')));
    });
  });

  group('SheetOverlayProvider -', () {
    testWidgets('custom sheet is described and respond completes it',
        (tester) async {
      await tester.pumpWidget(_app());

      final f = bottomSheetService.showCustomSheet(
        variant: _S.info,
        title: 'Hello',
        description: 'World',
      );
      await tester.pumpAndSettle();

      expect(_activeIds(), contains('sheet'));
      final provider = _active('sheet')!;
      expect(provider.overlay, {
        'type': 'sheet',
        'variant': 'info',
        'title': 'Hello',
        'description': 'World',
      });

      await _invoke(provider, 'respond', {'confirmed': true});
      await tester.pumpAndSettle();

      expect((await f)!.confirmed, true);
      expect(_activeIds(), isNot(contains('sheet')));
      expect(bottomSheetService.openRequests, isEmpty);
    });

    testWidgets('dismiss closes the sheet with a null result', (tester) async {
      await tester.pumpWidget(_app());

      final f = bottomSheetService.showCustomSheet(
        variant: _S.info,
        title: 'Hello',
      );
      await tester.pumpAndSettle();

      await _invoke(_active('sheet')!, 'dismiss');
      await tester.pumpAndSettle();

      expect(await f, isNull);
      expect(_activeIds(), isNot(contains('sheet')));
    });

    testWidgets('general bottom sheet is described', (tester) async {
      await tester.pumpWidget(_app());

      final f = bottomSheetService.showBottomSheet(
        title: 'T',
        description: 'D',
        cancelButtonTitle: 'No',
      );
      await tester.pumpAndSettle();

      expect(_active('sheet')!.overlay, {
        'type': 'sheet',
        'title': 'T',
        'description': 'D',
        'mainButtonTitle': 'Ok',
        'secondaryButtonTitle': 'No',
      });

      await _invoke(_active('sheet')!, 'respond', {'confirmed': false});
      await tester.pumpAndSettle();
      expect((await f)!.confirmed, false);
    });
  });

  group('SnackbarOverlayProvider -', () {
    testWidgets('showSnackbar records the snackbar and lends closeSnackbar',
        (tester) async {
      await tester.pumpWidget(_app());

      snackbarService.showSnackbar(message: 'Saved', title: 'Done');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
          snackbarService.lastSnackbar, {'title': 'Done', 'message': 'Saved'});

      // Get's snackbar reports open in the widget test environment.
      expect(snackbarService.isSnackbarOpen, true);
      final provider = _active('snackbar')!;
      expect(provider.overlay, {
        'type': 'snackbar',
        'title': 'Done',
        'message': 'Saved',
      });
      expect(provider.actions.map((a) => a.name), ['closeSnackbar']);

      // closeSnackbar's future only completes once the exit animation has
      // been pumped, so don't await it before pumping.
      final closed = _invoke(provider, 'closeSnackbar');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await closed;
      expect(_activeIds(), isNot(contains('snackbar')));
    });
  });

  group('no overlay -', () {
    testWidgets('no provider is active when nothing is open', (tester) async {
      await tester.pumpWidget(_app());

      expect(_activeIds(), isEmpty);
      expect(dialogService.openRequests, isEmpty);
      expect(bottomSheetService.openRequests, isEmpty);
      expect(snackbarService.lastSnackbar, isNull);
    });
  });
}
