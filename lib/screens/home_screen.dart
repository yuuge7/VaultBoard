import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/board_canvas.dart';
import '../widgets/sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(currentBoardProvider);

    return Scaffold(
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: board == null
                ? const _EmptyVault()
                : BoardCanvas(key: ValueKey(board.id), board: board),
          ),
        ],
      ),
    );
  }
}

class _EmptyVault extends ConsumerWidget {
  const _EmptyVault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: VaultColors.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: VaultColors.border),
            ),
            child: const Icon(Icons.lock_open_rounded,
                size: 44, color: VaultColors.accent),
          ),
          const SizedBox(height: 22),
          Text(
            'Your vault is empty',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a board to start organizing tasks.\n'
            'Everything stays on this machine — no cloud, no account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: VaultColors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => createBoardFlow(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first board'),
          ),
        ],
      ),
    );
  }
}
