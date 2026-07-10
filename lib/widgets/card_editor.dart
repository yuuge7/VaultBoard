import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'dialogs.dart';

Future<void> showCardEditor(
  BuildContext context, {
  required String boardId,
  required String listId,
  required KanbanCard card,
}) {
  return showDialog(
    context: context,
    builder: (_) =>
        CardEditorDialog(boardId: boardId, listId: listId, card: card),
  );
}

/// Full card editor: title, description, priority, completion and delete.
class CardEditorDialog extends ConsumerStatefulWidget {
  final String boardId;
  final String listId;
  final KanbanCard card;

  const CardEditorDialog({
    super.key,
    required this.boardId,
    required this.listId,
    required this.card,
  });

  @override
  ConsumerState<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends ConsumerState<CardEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late CardPriority _priority;
  late bool _isDone;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descController = TextEditingController(text: widget.card.description);
    _priority = widget.card.priority;
    _isDone = widget.card.isDone;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    ref.read(boardsProvider.notifier).updateCard(
          widget.boardId,
          widget.listId,
          widget.card.copyWith(
            title: title,
            description: _descController.text.trim(),
            priority: _priority,
            isDone: _isDone,
          ),
        );
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete card',
      message: 'Permanently delete "${widget.card.title}"?',
    );
    if (!confirmed || !mounted) return;
    ref
        .read(boardsProvider.notifier)
        .deleteCard(widget.boardId, widget.listId, widget.card.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created =
        DateFormat('MMM d, yyyy · HH:mm').format(widget.card.createdAt);

    return AlertDialog(
      backgroundColor: VaultColors.surfaceRaised,
      title: Row(
        children: [
          const Expanded(child: Text('Edit card')),
          IconButton(
            tooltip: 'Delete card',
            onPressed: _delete,
            icon: Icon(Icons.delete_outline_rounded,
                color: theme.colorScheme.error),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs to be done?',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Details, links, notes…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Text('Priority',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: VaultColors.textSecondary)),
              const SizedBox(height: 8),
              SegmentedButton<CardPriority>(
                showSelectedIcon: false,
                segments: [
                  for (final p in CardPriority.values)
                    ButtonSegment(
                      value: p,
                      label: Text(p.label),
                      icon: Icon(Icons.flag_rounded, size: 16, color: p.color),
                    ),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) =>
                    setState(() => _priority = selection.first),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Completed'),
                value: _isDone,
                onChanged: (value) => setState(() => _isDone = value),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: VaultColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Created $created',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: VaultColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
