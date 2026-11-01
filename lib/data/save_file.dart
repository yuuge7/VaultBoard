import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// Portable, versioned snapshot. Validation finishes before any vault changes.
class VaultSaveFile {
  static const format = 'vaultboard';
  static const version = 1;
  static const maxBytes = 20 * 1024 * 1024;

  final List<Board> boards;
  final String? selectedBoardId;

  const VaultSaveFile({required this.boards, this.selectedBoardId});

  int get listCount => boards.fold(0, (sum, b) => sum + b.lists.length);
  int get cardCount => boards.fold(
    0,
    (sum, b) => sum + b.lists.fold(0, (sum, list) => sum + list.cards.length),
  );

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'version': version,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'selectedBoardId': selectedBoardId,
    'boards': boards.map((board) => board.toJson()).toList(),
  });

  factory VaultSaveFile.decode(String contents) {
    Never invalid() => throw const FormatException(
      'This file is not a valid VaultBoard save file.',
    );
    Map<String, dynamic> object(dynamic value) {
      if (value is! Map<String, dynamic>) invalid();
      return value;
    }

    List<dynamic> array(dynamic value) {
      if (value is! List) invalid();
      return value;
    }

    String text(dynamic value) {
      if (value is! String || value.trim().isEmpty) invalid();
      return value;
    }

    void date(dynamic value) {
      if (DateTime.tryParse(text(value)) == null) invalid();
    }

    void unique(dynamic value, Set<String> ids) {
      if (!ids.add(text(value))) invalid();
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      invalid();
    }
    final root = object(decoded);
    if (root['format'] != format) invalid();
    if (root['version'] != version) {
      throw const FormatException(
        'This save-file version is not supported. Update VaultBoard and try again.',
      );
    }
    final boardIds = <String>{};
    final boards = array(root['boards']);
    for (final value in boards) {
      final board = object(value);
      unique(board['id'], boardIds);
      text(board['name']);
      date(board['createdAt']);
      final color = board['colorValue'];
      if (color is! int || color < 0 || color > 0xFFFFFFFF) invalid();
      final listIds = <String>{};
      final cardIds = <String>{};
      for (final value in array(board['lists'])) {
        final list = object(value);
        unique(list['id'], listIds);
        text(list['title']);
        for (final value in array(list['cards'])) {
          final card = object(value);
          unique(card['id'], cardIds);
          text(card['title']);
          date(card['createdAt']);
          if (card['description'] is! String ||
              card['isDone'] is! bool ||
              !CardPriority.values.any((p) => p.name == card['priority'])) {
            invalid();
          }
        }
      }
    }
    final selected = root['selectedBoardId'];
    if (selected != null &&
        (selected is! String || !boardIds.contains(selected))) {
      invalid();
    }
    return VaultSaveFile(
      boards: boards.map((b) => Board.fromJson(object(b))).toList(),
      selectedBoardId: selected as String?,
    );
  }
}

/// Native file dialogs on Windows and Linux; no network or shared storage.
class SaveFileService {
  static const fileTypes = [
    XTypeGroup(
      label: 'VaultBoard save file',
      extensions: ['vaultboard', 'json'],
    ),
  ];

  Future<String?> exportFile(VaultSaveFile snapshot) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final location = await getSaveLocation(
      acceptedTypeGroups: fileTypes,
      suggestedName: 'VaultBoard-$date.vaultboard',
      confirmButtonText: 'Export',
    );
    if (location == null) return null;
    final bytes = utf8.encode(snapshot.encode());
    if (bytes.length > VaultSaveFile.maxBytes) {
      throw const FormatException(
        'This vault exceeds the 20 MB save-file limit.',
      );
    }
    // Write beside the destination, then rename so a failed write cannot
    // truncate an existing backup.
    final temporary = File(
      '${location.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(location.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return location.path;
  }

  Future<VaultSaveFile?> importFile() async {
    final file = await openFile(
      acceptedTypeGroups: fileTypes,
      confirmButtonText: 'Preview import',
    );
    if (file == null) return null;
    if (await file.length() > VaultSaveFile.maxBytes) {
      throw const FormatException('Choose a save file smaller than 20 MB.');
    }
    return VaultSaveFile.decode(await File(file.path).readAsString());
  }
}

final saveFileServiceProvider = Provider<SaveFileService>(
  (ref) => SaveFileService(),
);
