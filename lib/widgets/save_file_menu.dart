import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/save_file.dart';
import '../providers/providers.dart';
import '../theme.dart';

String _count(int count, String noun) => '$count $noun${count == 1 ? '' : 's'}';

class SaveFileMenu extends ConsumerStatefulWidget {
  final bool collapsed;

  const SaveFileMenu({super.key, required this.collapsed});

  @override
  ConsumerState<SaveFileMenu> createState() => _SaveFileMenuState();
}

class _SaveFileMenuState extends ConsumerState<SaveFileMenu> {
  bool _busy = false;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(saveFileServiceProvider);
      if (action == 'export') {
        final path = await service.exportFile(
          VaultSaveFile(
            boards: ref.read(boardsProvider),
            selectedBoardId: ref.read(currentBoardProvider)?.id,
          ),
        );
        if (path != null) _message('Save file exported to $path');
      } else {
        final snapshot = await service.importFile();
        if (snapshot == null || !mounted) return;
        if (snapshot.boards.isEmpty) {
          _message('This save file is empty. There are no boards to import.');
          return;
        }
        setState(() => _busy = false);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: VaultColors.surfaceRaised,
            title: const Text('Import save file'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_count(snapshot.boards.length, 'board')} · '
                      '${_count(snapshot.listCount, 'list')} · '
                      '${_count(snapshot.cardCount, 'card')}',
                    ),
                    const SizedBox(height: 16),
                    for (final board in snapshot.boards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(board.name),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'Boards will be added as new copies. '
                      'Your current boards stay as they are.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import boards'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() => _busy = true);
        final selected = await ref
            .read(boardsProvider.notifier)
            .importBoards(snapshot.boards, snapshot.selectedBoardId);
        if (!mounted) return;
        ref.read(selectedBoardIdProvider.notifier).select(selected);
        ref.read(searchQueryProvider.notifier).state = '';
        _message(
          'Imported ${_count(snapshot.boards.length, 'board')} and '
          '${_count(snapshot.cardCount, 'card')}.',
        );
      }
    } on FormatException catch (error) {
      _message(error.message);
    } on FileSystemException {
      _message(
        'Could not ${action == 'export' ? 'write' : 'read'} the save file. '
        'Check folder access and try again.',
      );
    } on PlatformException {
      _message('Could not open the file dialog. Please try again.');
    } catch (_) {
      _message('Could not $action the save file. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save_outlined, size: 20);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: PopupMenuButton<String>(
        tooltip: 'Import / export save file',
        enabled: !_busy,
        onSelected: _run,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'export',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.file_upload_outlined),
              title: Text('Export save file'),
              subtitle: Text('Save all boards to a file'),
            ),
          ),
          PopupMenuItem(
            value: 'import',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.file_download_outlined),
              title: Text('Import save file'),
              subtitle: Text('Add boards from a saved file'),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: widget.collapsed
              ? Center(child: icon)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Text(_busy ? 'Working…' : 'Save file'),
                  ],
                ),
        ),
      ),
    );
  }
}
