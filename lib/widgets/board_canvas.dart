import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'list_column.dart';
import 'stats_chip.dart';

/// The main Kanban surface: board header (title, stats, search, actions) and
/// a responsive grid of complete list columns.
class BoardCanvas extends ConsumerStatefulWidget {
  final Board board;

  const BoardCanvas({super.key, required this.board});

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
  final _scrollController = ScrollController();
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    final title = Row(
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
        Expanded(
          child: Tooltip(
            message: 'Click to rename',
            child: InkWell(
              onTap: _renameBoard,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  widget.board.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final search = TextField(
      controller: _searchController,
      onChanged: (value) =>
          ref.read(searchQueryProvider.notifier).state = value,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Search cards…',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: VaultColors.textSecondary,
        ),
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
    );
    final addList = FilledButton.tonalIcon(
      onPressed: _addList,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('New list'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 850) {
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    const StatsChip(),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: search),
                    const SizedBox(width: 12),
                    addList,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      addList,
                    ],
                  ),
                  if (ref.watch(boardStatsProvider).total > 0) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: StatsChip(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 14.0;
              final width = math.max(0.0, constraints.maxWidth - 32);
              final count = widget.board.lists.length;
              // Fit whole columns, then wrap. Never expose half a list.
              final columns = math.max(
                1,
                math.min(count, ((width + gap) / (240 + gap)).floor()),
              );
              final rows = math.max(1, (count / columns).ceil());
              final columnWidth = (width - gap * (columns - 1)) / columns;
              final availableHeight = math.max(0.0, constraints.maxHeight - 24);
              final rowHeight = math.max(
                240.0,
                (availableHeight - gap * (rows - 1)) / rows,
              );

              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('board-scroll'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: count == 0
                      ? SizedBox(
                          height: rowHeight,
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: _addList,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add your first list'),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (var i = 0; i < count; i++)
                              SizedBox(
                                key: ValueKey(widget.board.lists[i].id),
                                width: columnWidth,
                                height: rowHeight,
                                child: _ListDropZone(
                                  boardId: widget.board.id,
                                  insertIndex: i,
                                  child: ListColumn(
                                    boardId: widget.board.id,
                                    list: widget.board.lists[i],
                                    index: i,
                                    listCount: count,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Drop a list into the hovered position, including the final slot in a row.
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
      onAcceptWithDetails: (details) {
        final board = ref
            .read(boardsProvider)
            .firstWhere((b) => b.id == boardId);
        final fromIndex = board.lists.indexWhere(
          (l) => l.id == details.data.listId,
        );
        ref
            .read(boardsProvider.notifier)
            .moveList(
              boardId: boardId,
              listId: details.data.listId,
              toIndex: insertIndex + (fromIndex < insertIndex ? 1 : 0),
            );
      },
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (active)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: VaultColors.accent, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
