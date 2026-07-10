import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'card_editor.dart';

/// A draggable task card. [dimmed] is set while a search query is active and
/// this card does not match, keeping list positions stable during filtering.
class CardTile extends ConsumerWidget {
  final String boardId;
  final String listId;
  final KanbanCard card;
  final bool dimmed;

  const CardTile({
    super.key,
    required this.boardId,
    required this.listId,
    required this.card,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _CardBody(
      boardId: boardId,
      listId: listId,
      card: card,
      onTap: () => showCardEditor(
        context,
        boardId: boardId,
        listId: listId,
        card: card,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.22 : 1,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<CardDragData>(
            data: CardDragData(card: card, fromListId: listId),
            feedback: SizedBox(
              width: 284,
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                child: _CardBody(
                  boardId: boardId,
                  listId: listId,
                  card: card,
                  isDragPreview: true,
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.28, child: body),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  final String boardId;
  final String listId;
  final KanbanCard card;
  final VoidCallback? onTap;
  final bool isDragPreview;

  const _CardBody({
    required this.boardId,
    required this.listId,
    required this.card,
    this.onTap,
    this.isDragPreview = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('MMM d').format(card.createdAt);

    return Material(
      color: VaultColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority color rail.
                Container(
                  width: 4,
                  color: card.priority == CardPriority.none
                      ? Colors.transparent
                      : card.priority.color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DoneToggle(
                              boardId: boardId,
                              listId: listId,
                              card: card,
                              enabled: !isDragPreview,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                card.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: card.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: card.isDone
                                      ? VaultColors.textSecondary
                                      : VaultColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (card.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              card.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: VaultColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Row(
                            children: [
                              if (card.priority != CardPriority.none)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: card.priority.color
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    card.priority.label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: card.priority.color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Icon(Icons.calendar_today_rounded,
                                  size: 11, color: VaultColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                dateLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: VaultColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneToggle extends ConsumerWidget {
  final String boardId;
  final String listId;
  final KanbanCard card;
  final bool enabled;

  const _DoneToggle({
    required this.boardId,
    required this.listId,
    required this.card,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: card.isDone ? 'Mark as not done' : 'Mark as done',
      child: GestureDetector(
        onTap: enabled
            ? () => ref.read(boardsProvider.notifier).updateCard(
                  boardId,
                  listId,
                  card.copyWith(isDone: !card.isDone),
                )
            : null,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Icon(
            card.isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: card.isDone
                ? const Color(0xFF66BB6A)
                : VaultColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
