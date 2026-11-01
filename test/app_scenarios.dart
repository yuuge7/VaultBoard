import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vaultboard/data/save_file.dart';
import 'package:vaultboard/data/storage.dart';
import 'package:vaultboard/main.dart';
import 'package:vaultboard/providers/providers.dart';
import 'package:vaultboard/widgets/card_tile.dart';
import 'package:vaultboard/widgets/list_column.dart';

import 'fixtures.dart';
import 'file_selector_stub.dart';

void registerAppScenarios({bool screenshots = false}) {
  late Directory directory;
  late TestFileSelector picker;
  late FileSelectorPlatform originalPicker;
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('vaultboard-ui-test-');
    Hive.init(directory.path);
    await VaultStorage.init();
  });
  setUp(() async {
    originalPicker = FileSelectorPlatform.instance;
    picker = TestFileSelector();
    FileSelectorPlatform.instance = picker;
    await VaultStorage.saveBoards([exampleBoard()]);
    await VaultStorage.saveSelectedBoardId('board-1');
  });
  tearDown(() => FileSelectorPlatform.instance = originalPicker);
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> openApp(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: boundaryKey, child: const VaultBoardApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!screenshots) return;
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory('build/verification');
      await output.create(recursive: true);
      await File(
        '${output.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(VaultBoardApp)));

  Future<void> menu(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Import / export save file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1440, 900),
    const Size(1280, 720),
    const Size(1100, 700),
    const Size(1024, 768),
    const Size(900, 600),
    const Size(640, 480),
    const Size(420, 700),
    const Size(1000, 360),
  ]) {
    testWidgets(
      'complete columns fit ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.runAsync(
          () => VaultStorage.saveBoards([exampleBoard(cardCount: 12)]),
        );
        await openApp(tester, size);
        final columns = find.byType(ListColumn);
        expect(columns, findsNWidgets(3));
        final rects = [
          for (var i = 0; i < 3; i++) tester.getRect(columns.at(i)),
        ];
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(size.width < 1100 ? 80 : 268));
          expect(rect.right, lessThanOrEqualTo(size.width - 15));
          expect(rect.width, closeTo(rects.first.width, 0.01));
          expect(rect.height, greaterThanOrEqualTo(240));
        }
        if (size.width >= 900) {
          expect(rects.map((r) => r.top).toSet().length, 1);
        }
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'layout-${size.width.toInt()}x${size.height.toInt()}',
        );
      },
    );
  }

  testWidgets(
    'additional lists wrap and remain reachable after live resizing',
    (tester) async {
      await tester.runAsync(
        () => VaultStorage.saveBoards([
          exampleBoard(listCount: 8, cardCount: 15),
        ]),
      );
      await openApp(tester, const Size(1280, 720));
      expect(find.byType(ListColumn), findsNWidgets(8));
      await capture(tester, 'eight-lists');
      tester.view.physicalSize = const Size(640, 480);
      await tester.pumpAndSettle();
      final columns = find.byType(ListColumn);
      for (var i = 0; i < 8; i++) {
        final rect = tester.getRect(columns.at(i));
        expect(rect.right, lessThanOrEqualTo(625));
        expect(rect.left, greaterThanOrEqualTo(80));
      }
      await tester.ensureVisible(columns.last);
      await tester.pumpAndSettle();
      expect(find.text('Review 7').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'eight-lists-narrow');
    },
  );

  testWidgets('search, quick add, inner scrolling, and new list work', (
    tester,
  ) async {
    await tester.runAsync(
      () => VaultStorage.saveBoards([exampleBoard(cardCount: 18)]),
    );
    await openApp(tester, const Size(900, 600));
    await tester.enterText(find.byType(TextField).first, 'save files');
    await tester.pumpAndSettle();
    expect(container(tester).read(searchQueryProvider), 'save files');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(container(tester).read(searchQueryProvider), '');
    await tester.tap(find.text('Add card').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'New responsive task');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      container(
        tester,
      ).read(currentBoardProvider)!.lists.first.cards.last.title,
      'New responsive task',
    );
    // Scroll the card stack independently from the surrounding board.
    final inner = find
        .descendant(
          of: find.byType(ListColumn).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(inner),
        scrollDelta: const Offset(0, 5000),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New responsive task').hitTestable(), findsOneWidget);
    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Quality review');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(ListColumn), findsNWidgets(4));
    expect(find.text('Quality review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card and list dragging survive responsive layout', (
    tester,
  ) async {
    await openApp(tester, const Size(900, 600));
    final to = tester.getCenter(find.byType(ListColumn).at(1));
    await tester.dragFrom(
      tester.getCenter(find.byType(CardTile).first),
      to - tester.getCenter(find.byType(CardTile).first),
    );
    await tester.pumpAndSettle();
    expect(
      container(tester).read(currentBoardProvider)!.lists[1].cards.length,
      1,
    );
    final start = tester.getCenter(find.text('To Do'));
    final end = tester.getCenter(find.text('Done'));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(
      container(tester).read(currentBoardProvider)!.lists.first.title,
      'In Progress',
    );
    expect(
      container(tester).read(currentBoardProvider)!.lists.last.title,
      'To Do',
    );
    final back = tester.getCenter(find.text('To Do'));
    await tester.dragFrom(
      back,
      tester.getCenter(find.text('In Progress')) - back,
    );
    await tester.pumpAndSettle();
    expect(
      container(tester).read(currentBoardProvider)!.lists.first.title,
      'To Do',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('save export and previewed import round-trip in the app', (
    tester,
  ) async {
    await openApp(tester, const Size(1280, 720));
    picker.savePath = '${directory.path}/app-backup.vaultboard';
    await menu(tester, 'Export save file');
    // Native test I/O must finish outside the widget clock.
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !await File(picker.savePath!).exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => File(picker.savePath!).exists()),
      isTrue,
    );
    final saved = VaultSaveFile.decode(
      (await tester.runAsync(() => File(picker.savePath!).readAsString()))!,
    );
    expect(saved.cardCount, 2);
    expect(find.textContaining('Save file exported'), findsOneWidget);
    picker.selected = XFile(picker.savePath!);
    await menu(tester, 'Import save file');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 board · 3 lists · 2 cards'), findsOneWidget);
    await capture(tester, 'import-preview');
    await tester.tap(find.text('Import boards'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(container(tester).read(boardsProvider).length, 2);
    expect(container(tester).read(currentBoardProvider)!.id, isNot('board-1'));
    expect(VaultStorage.loadBoards().length, 2);
    expect(find.textContaining('Imported 1 board and 2 cards'), findsOneWidget);
    await capture(tester, 'import-complete');
  });

  testWidgets('canceling save dialogs and import preview keeps boards intact', (
    tester,
  ) async {
    await openApp(tester, const Size(900, 600));
    await menu(tester, 'Export save file');
    await menu(tester, 'Import save file');
    expect(container(tester).read(boardsProvider).length, 1);
    final file = File('${directory.path}/cancel.vaultboard');
    await tester.runAsync(
      () =>
          file.writeAsString(VaultSaveFile(boards: [exampleBoard()]).encode()),
    );
    picker.selected = XFile(file.path);
    await menu(tester, 'Import save file');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container(tester).read(boardsProvider).length, 1);
  });

  testWidgets('invalid and empty files show useful feedback without changes', (
    tester,
  ) async {
    await openApp(tester, const Size(900, 600));
    final file = File('${directory.path}/invalid.vaultboard');
    picker.selected = XFile(file.path);
    for (final contents in ['{bad', const VaultSaveFile(boards: []).encode()]) {
      await tester.runAsync(() => file.writeAsString(contents));
      await menu(tester, 'Import save file');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          contents == '{bad' ? 'not a valid' : 'no boards to import',
        ),
        findsOneWidget,
      );
      expect(container(tester).read(boardsProvider).length, 1);
      await capture(tester, contents == '{bad' ? 'invalid-file' : 'empty-file');
    }
  });

  testWidgets('empty vault can import from the compact sidebar', (
    tester,
  ) async {
    await tester.runAsync(() => VaultStorage.saveBoards([]));
    await openApp(tester, const Size(640, 480));
    expect(find.text('Your vault is empty'), findsOneWidget);
    await tester.tap(find.byTooltip('Import / export save file'));
    await tester.pumpAndSettle();
    expect(find.text('Import save file'), findsOneWidget);
    await capture(tester, 'save-file-menu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('file read and write failures show feedback and allow retry', (
    tester,
  ) async {
    await openApp(tester, const Size(900, 600));
    picker.savePath = '${directory.path}/missing/backup.vaultboard';
    await menu(tester, 'Export save file');
    expect(
      find.textContaining('Could not write the save file'),
      findsOneWidget,
    );
    picker.selected = XFile('${directory.path}/missing.vaultboard');
    await menu(tester, 'Import save file');
    expect(find.textContaining('Could not read the save file'), findsOneWidget);
    expect(container(tester).read(boardsProvider).length, 1);
    picker.selected = null;
    await menu(tester, 'Import save file');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty board can add its first responsive list', (tester) async {
    await tester.runAsync(
      () => VaultStorage.saveBoards([exampleBoard(listCount: 0)]),
    );
    await openApp(tester, const Size(640, 480));
    await tester.tap(find.text('Add your first list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'First list');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(ListColumn), findsOneWidget);
    expect(tester.getSize(find.byType(ListColumn)).width, closeTo(544, 0.01));
    expect(tester.takeException(), isNull);
  });
}
