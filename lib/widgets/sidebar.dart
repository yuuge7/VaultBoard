import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'dialogs.dart';

/// Opens the board creation dialog and selects the new board.
Future<void> createBoardFlow(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<({String name, int colorValue})>(
    context: context,
    builder: (_) => const CreateBoardDialog(),
  );
  if (result == null) return;
  final id = ref
      .read(boardsProvider.notifier)
      .addBoard(result.name, colorValue: result.colorValue);
  ref.read(selectedBoardIdProvider.notifier).select(id);
  ref.read(searchQueryProvider.notifier).state = '';
}

/// Collapsible board switcher pinned to the left edge.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final boards = ref.watch(boardsProvider);
    final selectedId = ref.watch(currentBoardProvider)?.id;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 64 : 252,
      decoration: const BoxDecoration(
        color: VaultColors.surface,
        border: Border(right: BorderSide(color: VaultColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, ref, collapsed, theme),
          const Divider(height: 1),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'BOARDS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: VaultColors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final board in boards)
                  _BoardTile(
                    board: board,
                    selected: board.id == selectedId,
                    collapsed: collapsed,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: collapsed
                ? IconButton.filledTonal(
                    tooltip: 'New board',
                    onPressed: () => createBoardFlow(context, ref),
                    icon: const Icon(Icons.add_rounded),
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => createBoardFlow(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New board'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool collapsed,
    ThemeData theme,
  ) {
    final toggle = IconButton(
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      onPressed: () =>
          ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
      icon: Icon(
        collapsed
            ? Icons.keyboard_double_arrow_right_rounded
            : Icons.keyboard_double_arrow_left_rounded,
        size: 20,
        color: VaultColors.textSecondary,
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            const Icon(Icons.lock_rounded, color: VaultColors.accent, size: 22),
            const SizedBox(height: 6),
            toggle,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: VaultColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'VaultBoard',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          toggle,
        ],
      ),
    );
  }
}

class _BoardTile extends ConsumerWidget {
  final Board board;
  final bool selected;
  final bool collapsed;

  const _BoardTile({
    required this.board,
    required this.selected,
    required this.collapsed,
  });

  void _select(WidgetRef ref) {
    ref.read(selectedBoardIdProvider.notifier).select(board.id);
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'rename':
        final name = await promptText(
          context,
          title: 'Rename board',
          initial: board.name,
        );
        if (name != null) {
          ref.read(boardsProvider.notifier).renameBoard(board.id, name);
        }
      case 'delete':
        final confirmed = await confirmAction(
          context,
          title: 'Delete board',
          message:
              'Permanently delete "${board.name}" and everything inside it? '
              'This cannot be undone.',
        );
        if (!confirmed) return;
        final notifier = ref.read(boardsProvider.notifier);
        notifier.deleteBoard(board.id);
        final remaining = ref.read(boardsProvider);
        ref
            .read(selectedBoardIdProvider.notifier)
            .select(remaining.isEmpty ? null : remaining.first.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: board.name,
          child: InkWell(
            onTap: () => _select(ref),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? board.color.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: board.color,
                  child: Text(
                    board.name.isEmpty ? '?' : board.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D0F13),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? board.color.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _select(ref),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: board.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    board.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Board options',
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 16, color: VaultColors.textSecondary),
                  onSelected: (action) => _onMenu(context, ref, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Rename'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFFEF5350)),
                        title: Text('Delete',
                            style: TextStyle(color: Color(0xFFEF5350))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
