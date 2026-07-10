import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'card_tile.dart';
import 'dialogs.dart';

/// One Kanban column: header, scrollable card stack (drop target) and a
/// quick-add field. The whole column accepts drops at the end; each card is
/// its own drop target that inserts before itself.
class ListColumn extends ConsumerStatefulWidget {
  final String boardId;
  final KanbanList list;

  /// Position of this list on the board, used for move-left/right actions.
  final int index;
  final int listCount;

  const ListColumn({
    super.key,
    required this.boardId,
    required this.list,
    required this.index,
    required this.listCount,
  });

  @override
  ConsumerState<ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends ConsumerState<ListColumn> {
  final _scrollController = ScrollController();
  final _addController = TextEditingController();
  final _addFocus = FocusNode();
  bool _adding = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  BoardsNotifier get _notifier => ref.read(boardsProvider.notifier);

  void _drop(CardDragData data, int toIndex) {
    _notifier.moveCard(
      boardId: widget.boardId,
      cardId: data.card.id,
      fromListId: data.fromListId,
      toListId: widget.list.id,
      toIndex: toIndex,
    );
  }

  void _submitNewCard(String value) {
    final title = value.trim();
    if (title.isEmpty) return;
    _notifier.addCard(widget.boardId, widget.list.id, title);
    _addController.clear();
    _addFocus.requestFocus(); // Keep the field armed for rapid entry.
  }

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'left':
        _notifier.moveListBy(widget.boardId, widget.list.id, -1);
      case 'right':
        _notifier.moveListBy(widget.boardId, widget.list.id, 1);
      case 'rename':
        final name = await promptText(
          context,
          title: 'Rename list',
          initial: widget.list.title,
        );
        if (name != null) {
          _notifier.renameList(widget.boardId, widget.list.id, name);
        }
      case 'clear':
        _notifier.clearDoneCards(widget.boardId, widget.list.id);
      case 'delete':
        final confirmed = await confirmAction(
          context,
          title: 'Delete list',
          message:
              'Delete "${widget.list.title}" and its ${widget.list.cards.length} card(s)?',
        );
        if (confirmed) _notifier.deleteList(widget.boardId, widget.list.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final cards = widget.list.cards;

    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _drop(details.data, cards.length),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 300,
          decoration: BoxDecoration(
            color: VaultColors.column,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovering
                  ? theme.colorScheme.primary.withValues(alpha: 0.65)
                  : VaultColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              Flexible(
                child: cards.isEmpty
                    ? _EmptyListHint(hovering: hovering)
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                          itemCount: cards.length,
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return _InsertDropTarget(
                              onAccept: (data) => _drop(data, index),
                              child: CardTile(
                                boardId: widget.boardId,
                                listId: widget.list.id,
                                card: card,
                                dimmed:
                                    query.isNotEmpty && !card.matches(query),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              _buildAddArea(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final doneCount = widget.list.cards.where((c) => c.isDone).length;
    final titleText = Text(
      widget.list.title,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      child: Row(
        children: [
          // The header is the drag handle for reordering whole lists, so
          // in-column gestures (card drags, scrolling) stay unaffected.
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Draggable<ListDragData>(
                data: ListDragData(
                  listId: widget.list.id,
                  title: widget.list.title,
                  cardCount: widget.list.cards.length,
                ),
                feedback: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: VaultColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.65)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_indicator_rounded,
                            size: 16, color: VaultColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.list.title} · ${widget.list.cards.length}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.4, child: titleText),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator_rounded,
                        size: 15, color: VaultColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: titleText),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: VaultColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.list.cards.length}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: VaultColors.textSecondary),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'List options',
            icon: const Icon(Icons.more_horiz_rounded,
                size: 18, color: VaultColors.textSecondary),
            onSelected: _onMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'left',
                enabled: widget.index > 0,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_back_rounded, size: 18),
                  title: Text('Move left'),
                ),
              ),
              PopupMenuItem(
                value: 'right',
                enabled: widget.index < widget.listCount - 1,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_forward_rounded, size: 18),
                  title: Text('Move right'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, size: 18),
                  title: Text('Rename list'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: doneCount > 0,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cleaning_services_outlined,
                      size: 18),
                  title: Text('Clear $doneCount done card(s)'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFFEF5350)),
                  title: Text('Delete list',
                      style: TextStyle(color: Color(0xFFEF5350))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddArea(ThemeData theme) {
    if (!_adding) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: VaultColors.textSecondary,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          onPressed: () {
            setState(() => _adding = true);
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add card'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: TextField(
        controller: _addController,
        focusNode: _addFocus,
        autofocus: true,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Card title — Enter to add',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () {
              _addController.clear();
              setState(() => _adding = false);
            },
          ),
        ),
        onSubmitted: _submitNewCard,
        onTapOutside: (_) {
          if (_addController.text.trim().isEmpty) {
            setState(() => _adding = false);
          }
        },
      ),
    );
  }
}

/// Drop target rendered above each card: shows an accent insertion line while
/// a dragged card hovers, and inserts before this card on release.
class _InsertDropTarget extends StatelessWidget {
  final void Function(CardDragData data) onAccept;
  final Widget child;

  const _InsertDropTarget({required this.onAccept, required this.child});

  @override
  Widget build(BuildContext context) {
    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: active ? 3 : 0,
              margin: EdgeInsets.symmetric(
                  horizontal: 4, vertical: active ? 3 : 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _EmptyListHint extends StatelessWidget {
  final bool hovering;

  const _EmptyListHint({required this.hovering});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hovering
              ? Theme.of(context).colorScheme.primary
              : VaultColors.border,
        ),
      ),
      child: Center(
        child: Text(
          hovering ? 'Release to drop' : 'No cards yet',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: VaultColors.textSecondary),
        ),
      ),
    );
  }
}
