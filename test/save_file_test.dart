import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vaultboard/data/save_file.dart';
import 'package:vaultboard/data/storage.dart';
import 'package:vaultboard/providers/providers.dart';

import 'fixtures.dart';
import 'file_selector_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('vaultboard-save-test-');
    Hive.init(directory.path);
    await VaultStorage.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('save round-trip preserves every field, Unicode and ordering', () {
    final board = exampleBoard(listCount: 5, cardCount: 4);
    final original = VaultSaveFile(boards: [board], selectedBoardId: board.id);
    final restored = VaultSaveFile.decode(original.encode());
    expect(restored.boards.map((b) => b.toJson()), [board.toJson()]);
    expect(restored.selectedBoardId, board.id);
    expect(restored.listCount, 5);
    expect(restored.cardCount, 4);
  });

  test('empty vault is a valid portable save file', () {
    final restored = VaultSaveFile.decode(
      const VaultSaveFile(boards: []).encode(),
    );
    expect(restored.boards, isEmpty);
    expect(restored.selectedBoardId, isNull);
  });

  test('corrupt JSON, wrong formats and unsupported versions are rejected', () {
    for (final contents in [
      '{broken',
      '[]',
      '{}',
      '{"format":"another-app"}',
      '{"format":"vaultboard","version":999,"boards":[]}',
    ]) {
      expect(() => VaultSaveFile.decode(contents), throwsFormatException);
    }
  });

  test('malformed nested fields and duplicate identities are rejected', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (j) => j['boards'] = {},
      (j) => j['selectedBoardId'] = 'missing',
      (j) => j['boards'][0]['name'] = 42,
      (j) => j['boards'][0]['colorValue'] = -1,
      (j) => j['boards'][0]['createdAt'] = 'yesterday',
      (j) => j['boards'][0]['lists'] = null,
      (j) => j['boards'][0]['lists'][0]['cards'] = 'bad',
      (j) => j['boards'][0]['lists'][0]['cards'][0]['title'] = ' ',
      (j) => j['boards'][0]['lists'][0]['cards'][0]['description'] = null,
      (j) => j['boards'][0]['lists'][0]['cards'][0]['priority'] = 'urgent',
      (j) => j['boards'][0]['lists'][0]['cards'][0]['isDone'] = 'true',
      (j) => j['boards'].add(j['boards'][0]),
      (j) => j['boards'][0]['lists'][1]['id'] = 'list-0',
      (j) => j['boards'][0]['lists'][0]['cards'][1]['id'] = 'card-0',
    ];
    for (final mutate in mutations) {
      final json =
          jsonDecode(VaultSaveFile(boards: [exampleBoard()]).encode())
              as Map<String, dynamic>;
      mutate(json);
      expect(
        () => VaultSaveFile.decode(jsonEncode(json)),
        throwsFormatException,
      );
    }
  });

  test(
    'import adds copies, selects the saved board, persists across reload',
    () async {
      final existing = exampleBoard();
      final second = exampleBoard().toJson()..['id'] = 'board-2';
      await VaultStorage.saveBoards([existing]);
      final notifier = BoardsNotifier();
      addTearDown(notifier.dispose);
      final snapshot = VaultSaveFile.decode(
        jsonEncode({
          'format': 'vaultboard',
          'version': 1,
          'selectedBoardId': 'board-2',
          'boards': [existing.toJson(), second],
        }),
      );
      final selected = await notifier.importBoards(
        snapshot.boards,
        snapshot.selectedBoardId,
      );
      expect(notifier.state.length, 3);
      expect(notifier.state.first.toJson(), existing.toJson());
      expect(selected, notifier.state.last.id);
      final copy = notifier.state[1];
      expect(copy.id, isNot(existing.id));
      expect(copy.lists.first.id, isNot(existing.lists.first.id));
      expect(
        copy.lists.first.cards.first.id,
        isNot(existing.lists.first.cards.first.id),
      );
      expect(
        copy.lists.first.cards.first.toJson()..remove('id'),
        existing.lists.first.cards.first.toJson()..remove('id'),
      );
      expect(
        copy.toJson()
          ..remove('id')
          ..remove('lists'),
        existing.toJson()
          ..remove('id')
          ..remove('lists'),
      );
      expect(
        VaultStorage.loadBoards().map((b) => b.toJson()),
        notifier.state.map((b) => b.toJson()),
      );
      expect(await notifier.importBoards([], null), isNull);
      expect(notifier.state.length, 3);
      await notifier.importBoards(snapshot.boards, null);
      final allIds = notifier.state
          .expand(
            (b) => [
              b.id,
              ...b.lists.map((l) => l.id),
              ...b.lists.expand((l) => l.cards.map((c) => c.id)),
            ],
          )
          .toList();
      expect(allIds.toSet().length, allIds.length);
    },
  );

  test('failed persistence does not publish an imported tree', () async {
    await VaultStorage.saveBoards([exampleBoard()]);
    final notifier = BoardsNotifier();
    addTearDown(notifier.dispose);
    await Hive.box<String>('vaultboard').close();
    await expectLater(
      notifier.importBoards([exampleBoard()], null),
      throwsA(isA<HiveError>()),
    );
    expect(notifier.state.length, 1);
    await VaultStorage.init();
  });

  group('native selector service with real filesystem', () {
    late TestFileSelector picker;
    late FileSelectorPlatform original;
    final service = SaveFileService();
    setUp(() {
      original = FileSelectorPlatform.instance;
      picker = TestFileSelector();
      FileSelectorPlatform.instance = picker;
    });
    tearDown(() => FileSelectorPlatform.instance = original);

    test('export writes UTF-8 file and import reads it back', () async {
      picker.savePath = '${directory.path}/round-trip.vaultboard';
      final snapshot = VaultSaveFile(boards: [exampleBoard()]);
      expect(await service.exportFile(snapshot), picker.savePath);
      picker.selected = XFile(picker.savePath!);
      final restored = await service.importFile();
      expect(restored!.boards.first.toJson(), snapshot.boards.first.toJson());
    });
    test(
      'export replaces an existing backup and cleans temporary files',
      () async {
        picker.savePath = '${directory.path}/replace.vaultboard';
        await File(picker.savePath!).writeAsString('old backup');
        await service.exportFile(VaultSaveFile(boards: [exampleBoard()]));
        expect(
          VaultSaveFile.decode(
            await File(picker.savePath!).readAsString(),
          ).boards.length,
          1,
        );
        expect(
          directory.listSync().where((f) => f.path.endsWith('.tmp')),
          isEmpty,
        );
      },
    );
    test('canceling either dialog returns without work', () async {
      expect(await service.exportFile(const VaultSaveFile(boards: [])), isNull);
      expect(await service.importFile(), isNull);
    });
    test(
      'unwritable destination and missing source propagate failures',
      () async {
        picker.savePath = '${directory.path}/missing/fail.vaultboard';
        await expectLater(
          service.exportFile(const VaultSaveFile(boards: [])),
          throwsA(isA<FileSystemException>()),
        );
        picker.selected = XFile('${directory.path}/missing.vaultboard');
        await expectLater(
          service.importFile(),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
    test('oversized import is rejected before reading', () async {
      final file = File('${directory.path}/oversized.vaultboard');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(VaultSaveFile.maxBytes + 1);
      await handle.close();
      picker.selected = XFile(file.path);
      await expectLater(service.importFile(), throwsFormatException);
    });
  });
}
