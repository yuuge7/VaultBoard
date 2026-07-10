import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

/// Thin persistence layer over a single Hive box.
///
/// Everything is stored locally on disk (no network, ever). Boards are
/// serialized as one JSON string so the whole app state survives restarts
/// atomically.
class VaultStorage {
  static const _boxName = 'vaultboard';
  static const _boardsKey = 'boards';
  static const _selectedKey = 'selectedBoardId';

  static late Box<String> _box;

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  static List<Board> loadBoards() {
    final raw = _box.get(_boardsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Board.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt payload: fail safe with an empty vault rather than crashing.
      return [];
    }
  }

  static Future<void> saveBoards(List<Board> boards) => _box.put(
        _boardsKey,
        jsonEncode(boards.map((b) => b.toJson()).toList()),
      );

  static String? loadSelectedBoardId() => _box.get(_selectedKey);

  static Future<void> saveSelectedBoardId(String? id) =>
      id == null ? _box.delete(_selectedKey) : _box.put(_selectedKey, id);
}
