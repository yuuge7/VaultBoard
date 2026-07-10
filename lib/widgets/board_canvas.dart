import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'list_column.dart';
import 'stats_chip.dart';

/// The main Kanban surface: board header (title, stats, search, actions) and
/// a horizontally scrolling row of list columns.
class BoardCanvas extends ConsumerStatefulWidget {
  final Board board;

  const BoardCanvas({super.key, required this.board});

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
  final _hScrollController = ScrollController();
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _renameBoard() async {
    final name = await promptText(
      context,
      title: 'Rename board',
      initial: widget.board.name,
    );
    if (name != null) {
      ref.read(boardsProvider.notifier).renameBoard(widget.board.id, name);
    }
  }

  Future<void> _addList() async {
    final title = await promptText(
      context,
      title: 'New list',
      hint: 'e.g. "Review"',
      confirmLabel: 'Add',
    );
    if (title != null) {
      ref.read(boardsProvider.notifier).addList(widget.board.id, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.watch(searchQueryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Header ---------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.board.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Tooltip(
                  message: 'Click to rename',
                  child: InkWell(
                    onTap: _renameBoard,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Text(
                        widget.board.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const StatsChip(),
              const Spacer(),
              SizedBox(
                width: 270,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).state = value,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search cards…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: VaultColors.textSecondary),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _addList,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New list'),
              ),
            ],
          ),
        ),
        // ---- Canvas ---------------------------------------------------------
        Expanded(
          child: Scrollbar(
            controller: _hScrollController,
            thumbVisibility: true,
            child: ListView(
              controller: _hScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              children: [
                for (var i = 0; i < widget.board.lists.length; i++)
                  _ListDropZone(
                    boardId: widget.board.id,
                    insertIndex: i,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ListColumn(
                          key: ValueKey(widget.board.lists[i].id),
                          boardId: widget.board.id,
                          list: widget.board.lists[i],
                          index: i,
                          listCount: widget.board.lists.length,
                        ),
                      ),
                    ),
                  ),
                _ListDropZone(
                  boardId: widget.board.id,
                  insertIndex: widget.board.lists.length,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 300,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VaultColors.textSecondary,
                          side: const BorderSide(color: VaultColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _addList,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add list'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Drop target for whole-list drags: shows a vertical accent bar on its left
/// edge while a dragged list hovers, and moves the list before [insertIndex]
/// on release.
class _ListDropZone extends ConsumerWidget {
  final String boardId;
  final int insertIndex;
  final Widget child;

  const _ListDropZone({
    required this.boardId,
    required this.insertIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ListDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          ref.read(boardsProvider.notifier).moveList(
                boardId: boardId,
                listId: details.data.listId,
                toIndex: insertIndex,
              ),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: active ? 3 : 0,
              margin: EdgeInsets.symmetric(
                  vertical: 4, horizontal: active ? 4 : 0),
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
